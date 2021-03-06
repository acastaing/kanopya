#    Copyright © 2011-2013 Hedera Technology SAS
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

Prepare the node removal. Select a node to remove if not defined,

@since    2012-Aug-20
@instance hash
@self     $self

=end classdoc
=cut

package EEntity::EOperation::EPreStopNode;
use base "EEntity::EOperation";

use strict;
use warnings;

use Kanopya::Exceptions;
use Entity::Host;
use EEntity;

use String::Random;
use Date::Simple (':all');

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;


=pod
=begin classdoc

@param cluster the cluster on which remove a node
@param host    the host corresponding to the node to remove

=end classdoc
=cut

sub check {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => $self->{context}, required => [ "cluster" ]);


    my $cluster = $self->{context}->{cluster};
    $self->{context}->{host_manager}
        = EEntity->new(entity => $cluster->getManager(manager_type => 'HostManager'));

    # TODO: Move this virtual machine specific code to the host manager
    if ($self->{context}->{host_manager}->hostType eq 'Virtual Machine') {
        $self->{context}->{host_manager_sp} = $self->{context}->{host_manager}->service_provider;
    }
}


=pod
=begin classdoc

Check if the cluster is stable.

=end classdoc
=cut

sub prepare {
    my ($self, %args) = @_;
    $self->{context}->{host_manager}->increaseConsumers(operation => $self);
}


=pod
=begin classdoc

Select a node to remove in function of its weight vis-a-vis of the cluster.

=end classdoc
=cut

sub prerequisites {
    my ($self, %args) = @_;
    my $delay = 10;

    # Choose a random non master node
    if (not defined $self->{context}->{host}) {
        $log->info('No node selected, select a random node');

        # Search the less important non master node
        my @nodes = $self->{context}->{cluster}->nodesByWeight(master_node => 0);
        if (not scalar (@nodes)) {
            throw Kanopya::Exception(
                      error => 'Cannot remove a node from cluster <' . $self->{context}->{cluster}->id .
                               '>, only master nodes left');
        }
        my $node = pop @nodes;

        $log->info('Node <' . $node->id . '> selected to be removed among <' . (scalar @nodes) . '> nodes');
        $self->{context}->{host} = EEntity->new(data => $node->host);
    }

    if ($self->{context}->{host}->checkStoppable == 0) {
        $log->info('Need to flush the hypervisor before stopping it');

        my $operation_to_enqueue = {
            type     => 'FlushHypervisor',
            priority => 1,
            params   => { context => { flushed_hypervisor => $self->{context}->{host} } }
        };

        $self->workflow->enqueueBefore(
            operation         => $operation_to_enqueue,
            current_operation => $self,
        );
        $log->info('Enqueue "add hypervisor" operations before starting a new virtual machine');
        return -1;
    }

    return 0;
}


=pod
=begin classdoc

Configure the components for the node removal.

=end classdoc
=cut

sub execute {
    my $self = shift;

    my @components = $self->{context}->{cluster}->getComponents(category => "all");
    $log->info('Inform cluster components about node removal');

    foreach my $component (@components) {
        EEntity->new(data => $component)->preStopNode(
            host      => $self->{context}->{host},
            cluster   => $self->{context}->{cluster},
            erollback => $self->{erollback}
        );
    }
    $self->{context}->{host}->setNodeState(state => "pregoingout");
}


=pod
=begin classdoc

Ask to the cluster component if they are ready for th node removal

=end classdoc
=cut

sub postrequisites {
    my $self  = shift;
    my %args  = @_;
    my $delay = 10;

    if (! $self->{context}->{cluster}->readyNodeRemoving(host => $self->{context}->{host})) {
        $log->debug("Cluster <" . $self->{context}->{cluster}->label .
                    "> not ready for node removing, retrying in $delay seconds");
        return $delay;
    }

    $log->info("Cluster <" . $self->{context}->{cluster}->label .
               "> ready for node removing, releasing node.");
    return 0;
}


=pod
=begin classdoc

Set host state

=end classdoc
=cut

sub finish {
    my ($self, %args) = @_;

    # Ask to the deployment manager t release the node
    # Merge all manager parameters for the deployment manager
    my $managers_params = $self->{context}->{cluster}->getManagerParameters();
    $self->{context}->{cluster}->getManager(manager_type => 'DeploymentManager')->releaseNode(
        node            => $self->{context}->{host}->node,
        workflow        => $self->workflow,
        network_manager => $self->{context}->{cluster}->getManager(manager_type => 'NetworkManager'),
        %{ $managers_params }
    );
    $self->{context}->{host_manager}->decreaseConsumers(operation => $self);
    return 0;
}


=pod
=begin classdoc

Restore the clutser and host states.

=end classdoc
=cut

sub cancel {
    my ($self, %args) = @_;

    $self->{context}->{cluster}->restoreState();
    if (defined $self->{context}->{host_manager_sp}) {
        $self->{context}->{host_manager_sp}->setState(state => 'up');
    }

    $self->{context}->{host_manager}->decreaseConsumers(operation => $self);
}

1;
