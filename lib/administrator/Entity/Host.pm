# Host.pm - Object class of Ḿotherboard (Administrator side)

#    Copyright © 2011-2012 Hedera Technology SAS
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

package Entity::Host;
use base "Entity";

use strict;
use warnings;

use Kanopya::Exceptions;
use Operation;
use General;
use Externalnode::Node;

use Entity::ServiceProvider;
use Entity::Container;
use Entity::Interface;
use Entity::Iface;

use Log::Log4perl "get_logger";
use Data::Dumper;
my $log = get_logger("administrator");
my $errmsg;

=head2 Host Attributes

hostmodel_id : Int : Identifier of host model.
processormodel_id : Int : Identifier of host processor model
kernel_id : Int : kernel identifier which will be used by host if non specified by cluster
host_serial_number : String : This is the serial number attributed to host

host_powersupply_id : Int : Facultative identifier to know which powersupplycard and port is used.
Powersupplyid is created during host creation.
host_desc :  String : This is a free field to enter a description of host. It is generally used to
specify owner, team, ...

active : Int : This is an internal parameter used to activate or deactivate resources on Kanopya System
host_hostname : Hostname is also internally managed. Host hostname will be generated from the mac address
It is generated when a host is added into a cluster
host_initiatorname : This attributes is generated when a host is added in a cluster and allow to connect
to internal storage to get the systemimage
host_state : String : This parameter is internally managed, it allows to follow migration step.
It could be :
- WaitingStart
- Starting
- ReadyStart
- Up

- WaitingStop
- ReadyStop
- Stopping
- Down
=cut

use constant ATTR_DEF => {
    host_manager_id => {
        pattern => '^[0-9\.]*$',
        is_mandatory => 1,
        is_extended => 0
    },
    hostmodel_id => {
        pattern      => '^\d*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    processormodel_id => {
        pattern      => '^\d*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    kernel_id => {
        pattern      => '^\d*$',
        is_mandatory => 1,
        is_extended  => 0
    },
    host_serial_number => {
        pattern      => '^.*$',
        is_mandatory => 1,
        is_extended  => 0
    },
    host_powersupply_id => {
        pattern      => '^\w*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_desc => {
        pattern      => '^.*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    active => {
        pattern      => '^[01]$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_hostname => {
        pattern      => '^\w*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_ram => {
        pattern      => '^\d*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_core => {
        pattern      => '^\d*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_initiatorname => {
        pattern      => '^.*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    host_state => {
        pattern      => '^up:\d*|down:\d*|starting:\d*|stopping:\d*|locked:\d*|broken:\d*$',
        is_mandatory => 0,
        is_extended  => 0
    },
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        'create'    => {'description' => 'create a new host',
                        'perm_holder' => 'mastergroup',
        },
        'get'        => {'description' => 'view this host',
                        'perm_holder' => 'entity',
        },
        'update'    => {'description' => 'save changes applied on this host',
                        'perm_holder' => 'entity',
        },
        'remove'    => {'description' => 'delete this host',
                        'perm_holder' => 'entity',
        },
        'activate'=> {'description' => 'activate this host',
                        'perm_holder' => 'entity',
        },
        'deactivate'=> {'description' => 'deactivate this host',
                        'perm_holder' => 'entity',
        },
        'addHarddisk'=> {'description' => 'add a hard disk to this host',
                        'perm_holder' => 'entity',
        },
        'removeHarddisk'=> {'description' => 'remove a hard disk from this host',
                        'perm_holder' => 'entity',
        },
        'removeIface'=> {'description' => 'remove an interface from this host',
                        'perm_holder' => 'entity',
        },
        'addIface'=> {'description' => 'add one or more interface to  this host',
                        'perm_holder' => 'entity',
        },
        'getAdminIp'=> {'description' => 'get ip address for administration interface',
                        'perm_holder' => 'entity',
        },
        'getIfaces'=> {'description' => 'get network interfaces',
                        'perm_holder' => 'entity',
        },
        'setperm'    => {'description' => 'set permissions on this host',
                        'perm_holder' => 'entity',
        },
        'getRemoteSessionURL'   => {
            'description'   => 'get the url for remote session',
            'perm_holder'   => 'entity'
        },
        'getHostType'           => {
            'description'   => 'get the host type from host manager',
            'perm_holder'   => 'entity'
        }
    };
}

=head2 create

=cut

sub create {
    my $class   = shift;
    my %args    = @_;

    General::checkParams(args   => \%args,
                         required => ['host_manager_id', 'host_core', 'kernel_id',
                                      'host_ram', 'host_serial_number' ]);

    my $manager = Entity::ServiceProvider->get(id => $args{host_manager_id});
    $manager->createHost(%args);
}

=head2 getServiceProvider

    desc: Return the service provider that provides the host.

=cut

sub getServiceProvider {
    my $self = shift;

    my $service_provider_id = $self->getHostManager->getAttr(name => 'service_provider_id');

    return Entity::ServiceProvider->get(id => $service_provider_id);
}

=head2 getHostManager

    desc: Return the component/conector that manage this host.

=cut

sub getHostManager {
    my $self = shift;

    return Entity->get(id => $self->getAttr(name => 'host_manager_id'));
}

=head2 getState

=cut

sub getState {
    my $self = shift;
    my $state = $self->host_state;
    return wantarray ? split(/:/, $state) : $state;
}

sub getPrevState {
    my $self = shift;
    my $state = $self->host_prev_state;
    return wantarray ? split(/:/, $state) : $state;
}

=head2 setState

=cut

sub setState {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['state']);
    my $new_state = $args{state};
    my $current_state = $self->getState();

    $self->setAttr(name => 'host_prev_state', value => $current_state);
    $self->setAttr(name => 'host_state', value => $new_state.":".time);
    $self->save();
}

=head2 getNodeState

=cut

sub getNodeState {
    my $self = shift;
    my $state = $self->node->node_state;
    return wantarray ? split(/:/, $state) : $state;
}

=head2 getNodeNumber

=cut
sub getNodeNumber {
    my $self = shift;
    my $node_number = $self->node->node_number;
    return $node_number;
}

=head2 getNodeSystemimage

=cut

sub getNodeSystemimage {
    my $self = shift;
    return $self->node->systemimage;
}

sub getNode {
    my $self = shift;
    return $self->node;
}

sub setNodeNumber {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['node_number']);

    $self->node->setAttr(name => 'node_number', value => $args{'node_number'});
    $self->node->save();
}

sub getPrevNodeState {
    my $self = shift;
    my $state = $self->node->node_prev_state;
    return wantarray ? split(/:/, $state) : $state;
}

=head2 setNodeState

=cut

sub setNodeState {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'state' ]);

    my $new_state = $args{state};
    my $current_state = $self->getNodeState();

    $self->node->setAttr(name => 'node_prev_state', value => $current_state);
    $self->node->setAttr(name => 'node_state', value => $new_state . ":" . time);
    $self->node->save();
}

=head2 updateCPU

=cut

sub updateCPU {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'cpu_number' ]);

    $self->setAttr(name  => "host_core",
                   value => $args{cpu_number});
    $self->save();
}

=head2 updateMemory

=cut

sub updateMemory {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'memory' ]);

    $self->setAttr(name  => "host_ram",
                   value => $args{memory});
    $self->save();
}

=head2 Entity::Host->becomeNode (%args)

    Class : Public

    Desc : Create a new node instance in db from host linked to cluster (in params).

    args:
        inside_id : Int : inside identifier
        master_node : Int : 0 or 1 to say if the host is the master node
    return: Node identifier

=cut

sub becomeNode {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ 'inside_id', 'master_node',
                                       'node_number', 'systemimage_id' ]);

    my $adm = Administrator->new();
    my $node = Externalnode::Node->new(
                  inside_id           => $args{inside_id},
                  host_id             => $self->getAttr(name => 'host_id'),
                  master_node         => $args{master_node},
                  node_number         => $args{node_number},
                  systemimage_id      => $args{systemimage_id},
    );

    my $cluster = Entity::ServiceProvider->get(id => $args{inside_id});
    $self->associateInterfaces(cluster => $cluster);

    return $node->id;
}

sub becomeMasterNode{
    my $self = shift;

    if(not defined $self->node) {
        $errmsg = "Entity::Host->becomeMasterNode :Host " . $self->id . " is not a node!";
        $log->error($errmsg);
        throw Kanopya::Exception::DB(error => $errmsg);
    }
    $self->node->setAttr(name => 'master_node', value => 1);
    $self->node->save();
}

=head2 Entity::Host->stopToBeNode (%args)

    Class : Public

    Desc : Remove a node instance for a dedicated host.

    args:
        cluster_id : Int : Cluster identifier

=cut

sub stopToBeNode{
    my $self = shift;

    if(not defined $self->node) {
        $errmsg = "Host " . $self->id . " is not a node!";
        $log->error($errmsg);
        #throw Kanopya::Exception::DB(error => $errmsg);
    }
    else {
        $self->node->delete();
    }

    # Dissociate iface from cluster interfaces
    $self->dissociateInterfaces();

    # Remove node entry
    $self->setState(state => 'down');
}

sub associateInterfaces {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'cluster' ]);

    my @ifaces = $self->getIfaces;

    # Try to find a proper iface to assign to each interfaces.
    foreach my $interface (@{$args{cluster}->getNetworkInterfaces}) {
        my $assigned = 0;
        for my $iface (@ifaces) {
            if (not $iface->isAssociated) {
                eval {
                    $iface->associateInterface(interface => $interface);
                    $assigned = 1;
                };
                if ($@) { $log->debug($@); }
                if ($assigned) { last; }
            }
        }
        if (not $assigned) {
            throw Kanopya::Exception::Internal(
                      error => "Unable to associate interface <" . $interface->getAttr(name => 'entity_id') .
                               "> to any iface of the host <" . $self->getAttr(name => 'entity_id') . ">"
                  );
        }
    }
}

sub dissociateInterfaces {
    my $self = shift;
    my %args = @_;

    for my $iface (@{$self->getIfaces}) {
        if ($iface->isAssociated) {
            $iface->dissociateInterface();
        }
    }
}

=head2 Entity::Host->addIface (%args)

    Class : Public

    Desc : Create a new iface instance in db.

    args:
        iface_name : Char : interface identifier
        iface_mac_addr : Char : the mac address linked to iface
        iface_pxe:Int :0 or 1
        host_id: Int

    return: iface identifier

=cut

sub addIface {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'iface_name', 'iface_mac_addr', 'iface_pxe' ]);

    my $adm = Administrator->new();
    my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id},
                                                   method    => 'addIface');
    if(not $granted) {
        throw Kanopya::Exception::Permission::Denied(
                  error => "Permission denied to add an interface to this host"
              );
    }
    my $iface = Entity::Iface->new(iface_name     => $args{iface_name},
                                   iface_mac_addr => $args{iface_mac_addr},
                                   iface_pxe      => $args{iface_pxe},
                                   host_id        => $self->getAttr(name => 'host_id'));

    return $iface->getAttr(name => 'entity_id');
}

=head2 getIfaces

=cut

sub getIfaces {
    my $self = shift;
    my %args = @_;
    my @ifaces = ();

    # Make sure to have all pxe ifaces before non pxe ones within the resulting array
    foreach my $pxe (1, 0) {
        my @ifcs = Entity::Iface->search(hash => { host_id   => $self->getAttr(name => 'host_id'),
                                                   iface_pxe => $pxe });
        for my $iface (@ifcs) {
            if (defined ($args{role})) {
                if (my $interface_id = $iface->isAssociated) {
                    my $interface = Entity::Interface->get(id => $iface->getAttr(name => 'interface_id'));
                    if ($interface->getRole->getAttr(name => 'interface_role_name') ne $args{role}) {
                        next;
                    }
                }
            }

            push @ifaces, $iface;
        }
    }

    return wantarray ? @ifaces : \@ifaces;
}

=head2 getPXEIface

=cut

sub getPXEIface {
    my $self = shift;

    my @pxe_ifaces = Entity::Iface->search(hash => {
                         host_id   => $self->getAttr(name => 'host_id'),
                         iface_pxe => 1,
                     });

    for my $iface (@pxe_ifaces) {
        # An iface not associated to any cluster interface
        # will not be assigned to an ip.
        if ($iface->getAttr(name => 'interface_id')) {
            return $iface;
        }
    }
    throw Kanopya::Exception::Internal::NotFound(
              error => "No pxe iface associated to a cluster interface found."
          );
}

sub removeIface {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['iface_id']);

    my $adm = Administrator->new();
    # removeIface method concerns an existing entity so we use his entity_id
    my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'removeIface');
    if(not $granted) {
        throw Kanopya::Exception::Permission::Denied(error => "Permission denied to remove an interface from this host");
    }

    my $ifc = Entity::Iface->find(hash => { host_id => $self->id, iface_id => $args{iface_id} });
    $ifc->delete();
}

sub getAdminIface {
    my $self = shift;
    my %args = @_;

    # Can we make it smarter ?
    my @ifaces = $self->getIfaces(role => "admin");
    if (scalar (@ifaces) == 0 and defined $args{throw}) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Host <" . $self->getAttr(name => 'entity_id') .
                           "> Could not find any iface associate to a admin interface."
              );
    }
    return $ifaces[0];
}

sub getAdminIp {
    my $self = shift;
    my %args = @_;

    my $iface = $self->getAdminIface();
    if ($iface and $iface->hasIp) {
        if (defined ($iface) and $iface->hasIp) {
            return $iface->getIPAddr;
        }
    }
}

=head2 getHosts

=cut

sub getHosts {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    return $class->search(%args);
}

sub getHost {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    my @Hosts = $class->search(%args);
    return pop @Hosts;
}

sub getHostFromIP {
    my $class = shift;
    my %args = @_;

    throw Kanopya::Exception::NotImplemented();
}

sub getFreeHosts {
    my $class = shift;
    my %args = @_;

    my $hash = { active => 1, host_state => {-like => 'down:%'} };

    if (defined $args{host_manager_id}) {
        $hash->{host_manager_id} = $args{host_manager_id}
    }

    my @hosts = $class->getHosts(hash => $hash);
    my @free;
    foreach my $m (@hosts) {
        if(not $m->node) {
            push @free, $m;
        }
    }
    return @free;
}

=head2 update

=cut

sub update {}

=head2 remove

=cut

sub remove {
    my $self = shift;

    $log->debug("New Operation RemoveHost with host_id : <" . $self->getAttr(name => "host_id") . ">");

    Operation->enqueue(
        priority => 200,
        type     => 'RemoveHost',
        params   => {
            context  => {
                host => $self,
            },
        },
    );
}

sub extension {
    return "hostdetails";
}

sub getHarddisks {
    my $self = shift;
    my $hds = [];
    my $harddisks = $self->{_dbix}->harddisks;
    while(my $hd = $harddisks->next) {
        my $tmp = {};
        $tmp->{harddisk_id} = $hd->get_column('harddisk_id');
        $tmp->{harddisk_device} = $hd->get_column('harddisk_device');
        push @$hds, $tmp;
    }
    return $hds;

}

sub addHarddisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['device']);

    my $adm = Administrator->new();
    # addHarddisk method concerns an existing entity so we use his entity_id
    my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'addHarddisk');
    if(not $granted) {
        throw Kanopya::Exception::Permission::Denied(error => "Permission denied to add a hard disk to this host");
    }

    $self->{_dbix}->harddisks->create({
        harddisk_device => $args{device},
        host_id => $self->getAttr(name => 'host_id'),
    });
}

sub removeHarddisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['harddisk_id']);

    my $adm = Administrator->new();
    # removeHarddisk method concerns an existing entity so we use his entity_id
    my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'removeHarddisk');
    if(not $granted) {
        throw Kanopya::Exception::Permission::Denied(error => "Permission denied to remove a hard disk from this host");
    }

    my $hd = $self->{_dbix}->harddisks->find($args{harddisk_id});
    $hd->delete();
}

sub activate{
    my $self = shift;

    $log->debug("New Operation ActivateHost with host_id : " . $self->getAttr(name=>'host_id'));
    Operation->enqueue(
        priority => 200,
        type     => 'ActivateHost',
        params   => {
            context => {
                host => $self
           }
       }
   );
}

sub deactivate{
    my $self = shift;

    $log->debug("New Operation EDeactivateHost with host_id : " . $self->getAttr(name=>'host_id'));
    Operation->enqueue(
        priority => 200,
        type     => 'DeactivateHost',
        params   => {
            context => {
                host => $self
           }
       }
   );
}

=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my $self = shift;

    return 'Entity::Host <' . $self->getAttr(name => "entity_id") .'>';
}

sub getClusterId {
    my $self = shift;
    return $self->node->service_provider->id;
}

sub getPowerSupplyCardId {
    my $self = shift;
    my $row = $self->host_powersupply;
    if (defined $row) {
        return $row->id;
    }
    else {
        return;
    }
}

sub getModel {
    my $self = shift;
    return $self->hostmodel;
}

sub getRemoteSessionURL {
    my $self = shift;

   return $self->getHostManager->getRemoteSessionURL(host => $self);
}

=head2

    desc: return the host type from hostmanager

=cut

sub getHostType {
    my $self    = shift;

    return $self->getHostManager->getHostType;
}

=head2

    Check if the host can be stopped, raise an exception otherwise

=cut

sub checkStoppable {
    return {};
}

1;
