#    Copyright © 2012-2013 Hedera Technology SAS
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

=pod
=begin classdoc

TODO

=end classdoc
=cut

package EEntity::EOperation::EMigrateHost;
use base EEntity::EOperation;

use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;
use Kanopya::Exceptions;
use Entity::Host;
use EntityState;
use CapacityManagement;

my $log = get_logger("");
my $errmsg;

sub check {
    my ($self, %args) = @_;

    General::checkParams(args => $self->{context}, required => [ "host", "vm" ]);

    if (not defined $self->{context}->{cloudmanager_comp}) {
        $self->{context}->{cloudmanager_comp} = $self->{context}->{vm}->getHostManager();
    }

    $self->{context}->{hv_cluster} = $self->{context}->{host}->node->service_provider;
    $self->{context}->{host_manager_sp} = $self->{context}->{cloudmanager_comp}->service_provider;
}


sub prepare {
    my ($self, %args) = @_;

    # Check the hostmanager service provider state
    my ($host_manager_sp_state, $host_manager_sp_timestamp) = $self->{context}->{host_manager_sp}->reload->getState;

    # Check the IAAS cluster state
    my @entity_states = $self->{context}->{host_manager_sp}->entity_states;

    for my $entity_state (@entity_states) {
        $log->debug('Analysing entity state <'.$entity_state->id.'> state <'.$entity_state->state.'>');
        if (! (($entity_state->state eq 'migrating') || ($entity_state->state eq 'scaleout') || ($entity_state->state eq 'optimizing'))) {
            throw Kanopya::Exception::Execution::InvalidState(
                      error => "The iaas cluster <"
                               .$self->{context}->{host_manager_sp}->cluster_name
                               .'> is <'.$entity_state->state
                               .'> which is not a correct state to accept migration'
                  );
        }
    }

    # Check the hypervisor cluster state
    @entity_states = $self->{context}->{hv_cluster}->entity_states;

    for my $entity_state (@entity_states) {
        if (! ($entity_state->state eq 'migrating')) {
            throw Kanopya::Exception::Execution::InvalidState(
                      error => "The hypervisor cluster <"
                               .$self->{context}->{hv_cluster}->cluster_name
                               .'> is <'.$entity_state->state
                               .'> which is not a correct state to accept migration'
                  );
        }
    }

    my @es_vm_mig = $self->{context}->{vm}->searchRelated(filters => ['entity_states'],
                                                          hash    => {state => 'migrating'});

    my @es_hv_mig = $self->{context}->{host}->searchRelated(filters => ['entity_states'],
                                                          hash    => {state => 'migrating'});

    if (scalar (@es_vm_mig) > 0 || scalar (@es_hv_mig) > 0) {
        throw Kanopya::Exception::Execution::InvalidState(
                   error => "The hypervisor <" .$self->{context}->{host}->node->node_hostname
                       .'> or the VM <'.$self->{context}->{vm}->node->node_hostname
                       .'> is already a migration operation'
              );
    }

    my @es_hv_sco = $self->{context}->{host}->searchRelated(filters => ['entity_states'],
                                                            hash    => {state => 'scaleout'});

    if (scalar (@es_hv_sco) > 0) {
        throw Kanopya::Exception::Execution::InvalidState(
                   error => "The hypervisor <" .$self->{context}->{host}->node->node_hostname
                       .'> is already in a scaleout operation'
              );
    }

    $self->{context}->{host_manager_sp}->setConsumerState(state => 'migrating', consumer => $self->workflow);
    $self->{context}->{vm}->setConsumerState(state => 'migrating', consumer => $self->workflow);
    $self->{context}->{host}->setConsumerState(state => 'migrating', consumer => $self->workflow);
    $self->{context}->{hv_cluster}->setConsumerState(state => 'migrating', consumer => $self->workflow);

    $self->{context}->{hv_cluster}->setState(state => 'migrating');
    $self->{context}->{host_manager_sp}->setState(state => 'migrating');
}

sub prerequisites {
    my ($self, %args) = @_;

    if (defined $self->{params}->{optimiaas}) {
        return 0;
    }

    my $diff_infra_db = $self->{context}->{cloudmanager_comp}
                             ->checkHypervisorVMPlacementIntegrity(host => $self->{context}->{host});
    eval {
        $diff_infra_db = $self->{context}->{cloudmanager_comp}
                              ->checkVMPlacementIntegrity(host          => $self->{context}->{vm},
                                                          diff_infra_db => $diff_infra_db);
    };
    if ($@) {
        my $error = $@;

        # Vm is not found in infrastructure
        # Enqueue synchronization in *new* workflow to repair DB
        # Throw exception to stop migration
        $self->_executor->enqueue(
            priority => 200,
            type     => 'SynchronizeInfrastructure',
            params   => {
                context => {
                    hypervisor => $self->{context}->{host},
                    vm         => $self->{context}->{vm},
                },
                diff_infra_db => $diff_infra_db,
            }
        );
        throw Kanopya::Exception(error => $error);
    }

    if (! $self->{context}->{cloudmanager_comp}->isInfrastructureSynchronized(hash => $diff_infra_db)) {

        # Repair infra before retrying AddNode

        $self->workflow->enqueueBefore(
            current_operation => $self,
            operation => {
                priority => 200,
                type     => 'SynchronizeInfrastructure',
                params   => {
                    context => {
                        hypervisor => $self->{context}->{host},
                        vm         => $self->{context}->{vm},
                    },
                    diff_infra_db => $diff_infra_db,
                }
            }
        );
        return -1;
    }
    return 0;
}

sub execute {
    my ($self, %args) = @_;

    # check if host is deactivated
    if ($self->{context}->{host}->active == 0) {
        throw Kanopya::Exception::Internal(error => 'hypervisor is not active');
    }

    # check if host is up
    if (not $self->{context}->{host}->checkUp()) {
        throw Kanopya::Exception::Internal(error => 'hypervisor is not up');
    }

    # check if VM is up
    if (not $self->{context}->{vm}->checkUp()) {
        throw Kanopya::Exception::Internal(error => 'VM is not up');
    }

    # Check if the destination differs from the source
    my $vm_state = $self->{context}->{cloudmanager_comp}->getVMState(
        host => $self->{context}->{vm},
    );

    $log->info('Destination hv <' . $self->{context}->{host}->node->node_hostname .
               '> vs cloud manager hv <' . $vm_state->{hypervisor} . '>');

    if ($self->{context}->{host}->node->node_hostname eq $vm_state->{hypervisor}) {
        $log->info('VM is on the same hypervisor, no need to migrate');
        $self->{params}->{no_migration} = 1;
    }
    else {
        # Check if there is enough resource in destination host
        my $vm_id = $self->{context}->{vm}->getAttr(name => 'entity_id');
        my $hv_id = $self->{context}->{'host'}->id();
        my $cm = CapacityManagement->new(
                     cloud_manager => $self->{context}->{cloudmanager_comp},
                 );

        my $check = $cm->isMigrationAuthorized(vm_id => $vm_id, hv_id => $hv_id);

        if ($check->{authorization} == 0) {
            throw Kanopya::Exception::Internal(error => $check->{error});
        }
    }

    if (defined $self->{params}->{no_migration}) {
        delete $self->{params}->{no_migration};
    }
    else {
        $self->{context}->{cloudmanager_comp}->migrateHost(
            host               => $self->{context}->{vm},
            hypervisor_dst     => $self->{context}->{host},
        );

        $log->info("VM <" . $self->{context}->{vm}->id .
                   "> is migrating to <" . $self->{context}->{host}->id . ">");
    }
}

sub finish {
    my ($self, %args) = @_;

    my ($hv_cluster_state, $timestamp) = $self->{context}->{hv_cluster}->reload->getState;
    my ($host_manager_sp_state, $timestamp2) = $self->{context}->{host_manager_sp}->reload->getState;

    my $state;
    eval {
        $state = $self->{context}
                 ->{host_manager_sp}
                 ->findRelated(filters => ['entity_states'],
                               hash    => {consumer_id => $self->workflow->id})->state;
    };


    if (defined $state && $state eq 'migrating') {
        # Do not remove state during optimiaas
        $self->{context}->{vm}->removeState(consumer => $self->workflow);
        $self->{context}->{host}->removeState(consumer => $self->workflow);
        $self->{context}->{hv_cluster}->removeState(consumer => $self->workflow);
        $self->{context}->{host_manager_sp}->removeState(consumer => $self->workflow);

        eval {
            # Check if there is no migration anymore
            $self->{context}->{hv_cluster}->findRelated(filters => ['entity_states'],
                                                        hash    => {state => 'migrating'});
        };
        if ($@) {
            $self->{context}->{hv_cluster}->setState(state => 'up');
        }
        else {
            $log->debug('Still one migration is present, cluster state stay in migration')
        }
        eval {
            # Check if there is no migration anymore
            $self->{context}->{host_manager_sp}->findRelated(filters => ['entity_states'],
                                                        hash    => {state => 'migrating'});
        };
        if ($@) {
            $self->{context}->{host_manager_sp}->setState(state => 'up');
        }
        else {
            $log->debug('Still one migration is present, cluster state stay in migration')
        }
    }

    delete $self->{context}->{host_manager_sp};
    delete $self->{context}->{vm};
    delete $self->{context}->{host};
    delete $self->{context}->{hv_cluster};
}

sub postrequisites {
    my $self = shift;

    my $migr_state = $self->{context}->{cloudmanager_comp}->getVMState(
                         host => $self->{context}->{vm},
                     );

    $log->info('Virtual machine <' . $self->{context}->{vm}->id . '> state: <'. $migr_state->{state} .
               '>, current hypervisor: <' . $migr_state->{hypervisor} .
               '>, dest hypervisor: <' . $self->{context}->{host}->node->node_hostname . '>');

    if ($migr_state->{state} eq 'runn') {
        # On the targeted hv
        if ($migr_state->{hypervisor} eq $self->{context}->{host}->node->node_hostname) {

            # After checking migration -> store migration in DB
            $self->{context}->{cloudmanager_comp}->_entity->migrateHost(
                host               => $self->{context}->{vm},
                hypervisor_dst     => $self->{context}->{host},
            );
            return 0;
        }
        else {
            # Vm is running but not on its hypervisor
            my $error = 'Migration of vm <' . $self->{context}->{vm}->id . '> failed, but still running...';
            $log->warn($error);
            Message->send(
                from    => 'EMigrateHost',
                level   => 'error',
                content => $error,
            );
            throw Kanopya::Exception(error => $error);
        }
    }
    elsif ($migr_state->{state} eq 'migr') {
        # vm is still migrating
        return 15;
    }
    throw Kanopya::Exception(error => 'Unattended state <'.$migr_state->{state}.'>');
}


=pod
=begin classdoc

Restore

=end classdoc
=cut

sub cancel {
    my ($self, %args) = @_;

    my ($hv_cluster_state, $timestamp) = $self->{context}->{hv_cluster}->reload->getState;
    my ($host_manager_sp_state, $timestamp2) = $self->{context}->{host_manager_sp}->reload->getState;

    my $state = $self->{context}
                     ->{host_manager_sp}
                     ->findRelated(filters => ['entity_states'],
                                   hash    => {consumer_id => $self->workflow->id})->state;

    if ($state eq 'migrating') {
        # Do not remove state during optimiaas
        $self->{context}->{vm}->removeState(consumer => $self->workflow);
        $self->{context}->{host}->removeState(consumer => $self->workflow);
        $self->{context}->{hv_cluster}->removeState(consumer => $self->workflow);
        $self->{context}->{host_manager_sp}->removeState(consumer => $self->workflow);

        eval {
            # Check if there is no migration anymore
            $self->{context}->{hv_cluster}->findRelated(filters => ['entity_states'],
                                                        hash    => {state => 'migrating'});
        };
        if ($@) {
            $self->{context}->{hv_cluster}->setState(state => 'up');
        }
        else {
            $log->debug('Still one migration is present, cluster state stay in migration')
        }
        eval {
            # Check if there is no migration anymore
            $self->{context}->{host_manager_sp}->findRelated(filters => ['entity_states'],
                                                        hash    => {state => 'migrating'});
        };
        if ($@) {
            $self->{context}->{host_manager_sp}->setState(state => 'up');
        }
        else {
            $log->debug('Still one migration is present, cluster state stay in migration')
        }
    }

    delete $self->{context}->{host_manager_sp};
    delete $self->{context}->{vm};
    delete $self->{context}->{host};
    delete $self->{context}->{hv_cluster};
}

1;
