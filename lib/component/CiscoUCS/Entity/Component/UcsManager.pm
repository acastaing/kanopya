#    UCSManager.pm - Cisco UCS connector
#    Copyright © 2012 Hedera Technology SAS
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

=pod
=begin classdoc

TODO

=end classdoc
=cut

package Entity::Component::UcsManager;
use parent Entity::Component::Virtualization;
use parent Manager::HostManager;
use parent Manager::NetworkManager;

use Manager::HostManager;
use Entity::Processormodel;
use Entity::Host;
use Entity::Hostmodel;
use Entity::Network;
use Entity::Vlan;
use Data::Dumper;

use warnings;

use Cisco::UCS;
use Cisco::UCS::VLAN;
use Log::Log4perl "get_logger";

use constant ATTR_DEF => {
    executor_component_id => {
        label        => 'Workflow manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
    # TODO: move this virtual attr to HostManager attr def when supported
    host_type => {
        is_virtual => 1
    }
};

my ($schema, $config, $oneinstance);
my $log = get_logger("");

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        get_service_profiles => {
            description => 'call get_service_profile with UCS API',
        },
        get_service_profile_templates => {
            description => 'call get_service_profile_templates with UCS API',
        },
        get_blades => {
            description => 'call get_blades with UCS API',
        }
    }
}

sub getBootPolicies {
    return (Manager::HostManager->BOOT_POLICIES->{pxe_iscsi},
            Manager::HostManager->BOOT_POLICIES->{pxe_nfs},
            Manager::HostManager->BOOT_POLICIES->{boot_on_san});
}

sub hostType {
    return "UCS blade";
}

sub get {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::get(%args);

    $self->init();

    return $self;
}

sub init {
    my $self = shift;

    my $ucs = Entity->get(id => $self->getAttr(name => "service_provider_id"));

    $self->{api} = Cisco::UCS->new(
                       proto    => "http",
                       port     => 80,
                       cluster  => $ucs->getAttr(name => "ucs_addr"),
                       username => $ucs->getAttr(name => "ucs_login"),
                       passwd   => $ucs->getAttr(name => "ucs_passwd")
                   );

    $self->{state} = ($self->{api}->login() ? "up" : "down");
    $self->{ou} = $ucs->getAttr(name => "ucs_ou");
    $self->{ucs} = $ucs;

    return $self->{api};
}

sub AUTOLOAD {
    my $self = shift;
    my %args = @_;

    my @autoload = split(/::/, $AUTOLOAD);
    my $method = $autoload[-1];

    if (not defined $self->{api}) {
        $self->init();
    }

    return $self->{api}->$method(%args);
}

sub DESTROY {
    my $self = shift;

    if (defined $self->{api}) {
        $self->{api}->logout();
        $self->{api} = undef;
    }
}

=pod
=begin classdoc

@return the manager params definition.

=end classdoc
=cut

sub getManagerParamsDef {
    my ($self, %args) = @_;

    return {
        %{ $self->SUPER::getManagerParamsDef },
        service_profile_template_id => {
            label        => 'Service profile',
            type         => 'enum',
            is_mandatory => 1,
            options      => [ 'sptmpl_kanopya01-A', 'sptmpl_kanopya01-B' ]
        }
    };
}

sub checkHostManagerParams {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ "service_profile_template_id" ]);
}

sub getHostManagerParams {
    my $self = shift;
    my %args = @_;

    return {
        service_profile_template_id => $self->getManagerParamsDef->{service_profile_template_id}
    };
}


sub synchronize {
    my $self = shift;
    my %args = @_;

    $self->login();

    my @blades = $self->get_blades();

    # Get a "random" kernel for his id :
    my $kernelhash =  Entity::Kernel->find(hash => {});
    my $kernelid = $kernelhash->getAttr('name' => 'kernel_id');

    # Get the hostmanager for his id :
    my $hostmanagerid = $self->getAttr('name' => 'entity_id');

    foreach my $blade (@blades) {
        # Check if an entry with the same serial number exist in table
        my @existing_hosts = Entity::Host->search(
                                 hash => {
                                     host_serial_number => $blade->{dn},
                                     host_manager_id    => $hostmanagerid
                                 }
                             );

        next if scalar @existing_hosts;

        # Look for an existing processor model
        my $board = $self->{api}->get(dn => $blade->{dn} . "/board");
        my @cpus = $board->children("processorUnit");
        my $cpu = $cpus[0];
        my $processormodel;

        eval {
            $processormodel = Entity::Processormodel->find(
                                  hash => {
                                      processormodel_name => $cpu->{model}
                                  }
                              );
        };
        if ($@) {
            $processormodel = Entity::Processormodel->new(
                                  processormodel_brand       => $cpu->{vendor},
                                  processormodel_name        => $cpu->{model},
                                  processormodel_core_num    => $blade->{numOfCores} * 2,
                                  processormodel_clock_speed => $cpu->{speed},
                                  processormodel_l2_cache    => 1,
                                  processormodel_max_tdp     => 0,
                                  processormodel_64bits      => 1,
                                  processormodel_virtsupport => 1
                              );
        }

        # Look for an existing host model
        my $hostmodelid;
        eval {
            $hostmodel = Entity::Hostmodel->find(
                             hash => {
                                 hostmodel_name => $blade->{model}
                             }
                         );
        };
        if ($@) {
            my $budget = $self->{api}->get(dn => $blade->{dn} . "/budget");
            $hostmodel = Entity::Hostmodel->new(
                             hostmodel_brand         => $blade->{vendor},
                             hostmodel_name          => $blade->{model},
                             hostmodel_chipset       => "unknown",
                             hostmodel_processor_num => $blade->{numOfCores},
                             hostmodel_consumption   => $budget->{idlePower},
                             hostmodel_iface_num     => 1,
                             hostmodel_ram_slot_num  => 1,
                             hostmodel_ram_max       => $blade->{totalMemory} * 1024 * 1024,
                             processormodel_id       => $processormodel->getAttr(name => 'processormodel_id'),
                         );
        }

        Entity::Host->new(
            kernel_id           => $kernelid,
            host_serial_number  => $blade->{dn},
            host_ram            => $blade->{totalMemory} * 1024 * 1024,
            host_core           => $blade->{numOfCores},
            hostmodel_id        => $hostmodel->getAttr(name => 'hostmodel_id'),
            processormodel_id   => $processormodel->getAttr(name => 'processormodel_id'),
            host_desc           => $blade->{dn},
            active              => "1",
            host_manager_id     => $hostmanagerid,
        );
    }

    # Synchronize VLANs from UCS to Kanopya
    my @ucsvlans = $self->get_vlans();

    foreach my $ucsvlan (@ucsvlans) {
        # Get Vlans existing in Kanopya
        eval {
            Entity::Vlan->find(hash => { vlan_name => $ucsvlan->{name} });
        };
        if ($@) {
            # If the vlan not exist in Kanopya, create it
            Entity::Vlan->new(
                vlan_name   => $ucsvlan->{name},
                vlan_number => $ucsvlan->{id},
            );
        }
    }

    # Synchronize VLANs from Kanopya to UCS
    # Get all VLANs on Kanopya
    my @vlans = Entity::Vlan->search(hash => {});
    foreach my $vlan (@vlans) {
        my $vlan_id = $vlan->vlan_number;

        # We must ignore the VLAN 0 on Kanopya side, this is the default UCS Vlan too
        if ($vlan_id ne "0") {
            # Create VLANs on UCS
            # Creation is encapsulated in an eval for avoid "already created" errors
            eval {
                Cisco::UCS::VLAN->create(
                    ucs         => $self,
                    defaultNet  => "no",
                    id          => $vlan_id,
                    name        => $vlan->vlan_name,
                    pubNwName   => "",
                    sharing     => "none",
                    status      => "created",
                );
            };
        }
    }

    $self->logout();
}


sub getRemoteSessionURL {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    $self->init();
    my $blade = $self->{api}->get(dn => $args{host}->getAttr(name => 'host_serial_number'));

    return $blade->KVM();
}


=pod
=begin classdoc

Apply a VLAN on an interface of a host

=end classdoc
=cut

sub applyVLAN {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'iface', 'vlan' ]);

    my $api = $self->init();
    my $blade = $api->get(dn => $args{iface}->host->host_serial_number);
    my $sp = $api->get(dn => $blade->{assignedToDn});

    my @ethernets = $sp->children("vnicEther");
    for my $ethernet (@ethernets) {
        if ($ethernet->{name} eq 'v' . $args{iface}->iface_name) {
            $log->info("Applying vlan " . $args{vlan}->vlan_name .
                       " on " . $ethernet->{name} . " interface of " . $args{iface}->host->host_serial_number);
            $ethernet->applyVLAN(name   => $args{vlan}->vlan_name,
                                 delete => (defined ($args{delete}) and $args{delete}) ? 1 : 0);
        }
    }
}


=pod
=begin classdoc

Override relation used when deletion in order to skip AUTOLOAD

=end classdoc
=cut

sub entity_lock_entity {
    my $self = shift;
    return $self->SUPER::entity_lock_entity;
}


=pod
=begin classdoc

Override relation used when deletion in order to skip AUTOLOAD

=end classdoc
=cut

sub param_preset {
    my $self = shift;
    return $self->SUPER::param_preset;
}
1;
