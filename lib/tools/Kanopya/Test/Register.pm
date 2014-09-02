# Copyright © 2012 Hedera Technology SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

=pod

=begin classdoc

Kanopya module to handle register actions

@since 13/12/12
@instance hash
@self $self

=end classdoc

=cut

package Kanopya::Test::Register;

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Kanopya::Exceptions;
use Kanopya::Test::Retrieve;
use General;
use Entity::Host;
use Entity::ServiceProvider::Cluster;
use Entity::Component::Openssh5;
use Entity::Component::Linux::Debian;
use Entity::Vlan;
use Entity::Tag;
use EntityTag;
use Harddisk;
use NetconfVlan;
use IpmiCredentials;

=pod

=begin classdoc

Register an host into kanopya

@param board the host parameters (core, ram, and ifaces detail)

@return boolean

=end classdoc

=cut

sub registerHost {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'board' ]);

    my $board = $args{board};

    my $kanopya_cluster = Kanopya::Test::Retrieve->retrieveCluster();
    my $physical_hoster = $kanopya_cluster->getHostManager();

    my $host = Entity::Host->new(
                   active             => 1,
                   host_manager_id    => $physical_hoster->id,
                   host_serial_number => $board->{serial_number},
                   host_ram           => $board->{ram},
                   host_core          => $board->{core},
                   host_desc          => $board->{desc},
               );

    if (defined $board->{ifaces}) {
        foreach my $iface (@{ $board->{ifaces} }) {
            my $if = $host->addIface(
                         iface_name     => defined $iface->{name} ?  $iface->{name} : 'eth0',
                         iface_pxe      => $iface->{pxe},
                         iface_mac_addr => $iface->{mac},
                     );

            if (defined $iface->{master}) {
                $if->setAttr(name => 'master', value => $iface->{master});
                $if->save();
            }
        }
    }

    if (defined ($board->{harddisks})) {
        for my $harddisk (@{$board->{harddisks}}) {
            Harddisk->new(
                host_id         => $host->id,
                harddisk_device => $harddisk->{device},
                harddisk_size   => $harddisk->{size}
            );
        }
    }

    if (defined ($board->{tags})) {
        for my $tagname (@{$board->{tags}}) {
            my $tag = Entity::Tag->findOrCreate(tag => $tagname);
            EntityTag->new(entity_id => $host->id, tag_id => $tag->id);
        }
    }

    if (defined ($board->{ipmicredentials})) {
        for my $ipmicredentials (@{$board->{ipmicredentials}}) {
            IpmiCredentials->new(
                host_id                   => $host->id,
                ipmi_credentials_ip_addr  => $ipmicredentials->{ip_addr},
                ipmi_credentials_user     => $ipmicredentials->{user},
                ipmi_credentials_password => $ipmicredentials->{password}
            );
        }
    }

    return $host;
}


=pod

=begin classdoc

Register a VLAN into Kanopya

@param netconf network configuration

@param vlan_name name of the VLAN to be registered

@param vlan_number ID of the VLAN to be registered

=end classdoc

=cut

sub registerVlan {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'netconf', 'vlan_name', 'vlan_number' ]);

    my $netconf = $args{netconf};
    my $vlan_name = $args{vlan_name};
    my $vlan_number = $args{vlan_number};

    my $vlan = Entity::Vlan->new(vlan_name => $vlan_name, vlan_number => $vlan_number);
    NetconfVlan->new(netconf_id => $netconf->id, vlan_id => $vlan->id);
}


=pod

=begin classdoc

Register a node with components.

=end classdoc

=cut

sub registerNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'host', 'hostname', 'netconf', 'nameserver1', 'nameserver2', 'domainname' ],
                         optional => { 'components' => [], 'ip_addr' => undef });

    # Set the proper netconf to the host of the node
    my $iface = $args{host}->find(related => 'ifaces', hash => { iface_name => "eth0" });
    $iface->update(netconf_ifaces => [ $args{netconf} ]);

    my $node = Entity::Node->new(
                   host          => $args{host},
                   # Generate the hostname ourself as we are deploying the node ourself
                   node_hostname => $args{hostname},
                   node_state    => ($args{existing} ? 'in' : 'out') . ':' . time
               );

    diag('Add components on the node');
    my @toregister = @{ $args{components} };

    # TODO: find the proper system component type from the registred masterimage
    push @toregister, Entity::Component::Openssh5->new();
    push @toregister, Entity::Component::Linux::Debian->new(
                         nameserver1        => $args{nameserver1},
                         nameserver2        => $args{nameserver2},
                         domainname         => $args{domainname},
                         default_gateway_id => ($args{netconf}->poolips)[0]->network->id,
                     );

    for my $component (@toregister) {
        $component->registerNode(node => $node, master_node => 1);
    }

    if ($args{existing}) {
        diag('Set the down host to up, and out donw to in');
        $args{host}->setState(state => 'up');

        diag('Assign ip to the existing host');
        # The Ip should be the same than at deployement because the deployment
        # sequence has been rollbacked, and we are alone to use HCP
        $args{host}->find(related => 'ifaces', hash => { iface_name => "eth0" })->assignIp(ip_addr => $args{ip_addr});
    }

    return $node;
}


=pod

=begin classdoc

Register a node with components.

=end classdoc

=cut

sub registerComponentOnNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'componenttype', 'hostname' ],
                         optional => { 'component_params' => {}, 'ip_addr' => undef });

    my $node = Entity::Node->findOrCreate(node_hostname => $args{hostname});
    if (! defined $node->adminIp) {
        General::checkParams(args => \%args, required => [ 'ip_addr' ]);
        $node->admin_ip_addr($args{ip_addr});
    }

    my $component;
    eval {
        (my $componentname = $args{componenttype}) =~ s/\d+//g;
        $component = $node->getComponent(name => $componentname);
        diag('Component ' . $args{componenttype} . ' found on node ' . $node->label);
    };
    if ($@) {
        my $componentclass = BaseDB->_classType(classname => $args{componenttype});

        General::requireClass($componentclass);

        diag('Get any executor');
        my $executor = Entity::Component::KanopyaExecutor->find();

        # Create the component
        $component = $componentclass->new(executor_component => $executor, %{ $args{component_params} });

        # And register it on the node
        $component->registerNode(node => $node, master_node => 1);
        diag('Created and registred ' . $args{componenttype} . ' on node ' . $node->label);
    }
    return $component;
}

1;
