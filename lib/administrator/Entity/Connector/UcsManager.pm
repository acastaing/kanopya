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

package Entity::Connector::UcsManager;
use base "Entity::Connector";
use base "Manager::HostManager";

use Administrator;
use Manager::HostManager;
use Entity::Processormodel;
use Entity::Hostmodel;
use Entity::Network;
use Entity::Network::Vlan;
use Data::Dumper;

use warnings;

use Cisco::UCS;
use Cisco::UCS::VLAN;
use Log::Log4perl "get_logger";

use constant ATTR_DEF => {};

my ($schema, $config, $oneinstance);
my $log = get_logger("");

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        'getHostType' => {
            'description' => 'Return the type of managed hosts.',
            'perm_holder' => 'entity',
        },
        'get_service_profiles'          => {
            'description'   => 'call get_service_profile with UCS API',
            'perm_holder'   => 'entity'
        },
        'get_service_profile_templates' => {
            'description'   => 'call get_service_profile_templates with UCS API',
            'perm_holder'   => 'entity'
        },
        'get_blades'                    => {
            'description'   => 'call get_blades with UCS API',
            'perm_holder'   => 'entity'
        }
    }
}

sub getBootPolicies {
    return (Manager::HostManager->BOOT_POLICIES->{pxe_iscsi},
            Manager::HostManager->BOOT_POLICIES->{pxe_nfs},
            Manager::HostManager->BOOT_POLICIES->{boot_on_san});
}

sub getHostType {
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

sub checkHostManagerParams {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ "service_profile_template_id" ]);
}

=head2 getPolicyParams

=cut

sub getPolicyParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'policy_type' ]);

    if ($args{policy_type} eq 'hosting') {
        return [ { name   => 'service_profile_template_id',
                   label  => 'Service profile',
                   values => [ 'sptmpl_kanopya01-A', 'sptmpl_kanopya01-B' ] } ];
    }
    return [];
}

=head2 synchronize

    Desc: synchronize ucs information with kanopya database
    
=cut

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
            Entity::Network->find(hash => { network_name => $ucsvlan->{name} });
        };
        if ($@) {
            # If the vlan not exist in Kanopya, create it
            Entity::Network::Vlan->new(
                network_name => $ucsvlan->{name},
                vlan_number  => $ucsvlan->{id},
            );
        }
    }

    # Synchronize VLANs from Kanopya to UCS
    # Get all VLANs on Kanopya
    my @vlans = Entity::Network::Vlan->search(hash => {});
    foreach my $vlan (@vlans) {
        my $vlan_id = $vlan->getAttr('name' => 'vlan_number');

        # We must ignore the VLAN 0 on Kanopya side, this is the default UCS Vlan too
        if ($vlan_id ne "0") {
            # Create VLANs on UCS
            # Creation is encapsulated in an eval for avoid "already created" errors
            eval {
                Cisco::UCS::VLAN->create(
                    ucs         => $self,
                    defaultNet  => "no",
                    id          => $vlan_id,
                    name        => $vlan->getAttr('name' => 'network_name'),
                    pubNwName   => "",
                    sharing     => "none",
                    status      => "created",
                );
            };
        }
    }

    $self->logout();
}

=head2 getRemoteSessionURL

    Desc: return an URL to a remote session to the host

=cut

sub getRemoteSessionURL {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    $self->init();
    my $blade = $self->{api}->get(dn => $args{host}->getAttr(name => 'host_serial_number'));

    return $blade->KVM();
}

1;
