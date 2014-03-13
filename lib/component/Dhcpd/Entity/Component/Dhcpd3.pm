#    Copyright © 2011 Hedera Technology SAS
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

package Entity::Component::Dhcpd3;
use base Entity::Component;

use strict;
use warnings;

use General;
use Kanopya::Exceptions;
use Entity::ServiceProvider::Cluster;
use Dhcpd3Host;
use Dhcpd3Subnet;

use Hash::Merge qw(merge);
use NetAddr::IP;

use TryCatch;

use Log::Log4perl "get_logger";
my $log = get_logger("");


use constant ATTR_DEF => {};
sub getAttrDef { return ATTR_DEF; }

sub addHost {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => [ 'host' ],
                                         optional => { pxe => 0 });

    my $cluster = $args{host}->node->service_provider;
    my $pxe_iface = $args{host}->getPXEIface;
    my $subnet = ($pxe_iface->networks)[0];
    if (! defined $subnet) {
        throw Kanopya::Exception::Internal(
                  error => "PXE iface <" . $pxe_iface->id .  "> on host <" . $args{host}->id .
                           "> is not connected to any network."
              );
    }

    my $dhcp_subnet = Dhcpd3Subnet->findOrCreate(network_id => $subnet->id,
                                                 dhcpd3_id  => $self->id);

    return Dhcpd3Host->findOrCreate(iface_id         => $pxe_iface->id,
                                    dhcpd3_hosts_pxe => $args{pxe},
                                    dhcpd3_subnet_id => $dhcp_subnet->id);
}

sub removeHost {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => [ 'host' ]);

    my $pxe_iface = $args{host}->getPXEIface;
    my $network = ($pxe_iface->networks)[0];
    
    my $dhcp_subnet = $self->findRelated(
                          filters => [ "dhcpd3_subnets" ],
                          hash => {
                              network_id => $network->id,
                          }
                      );

    my $host = Dhcpd3Host->find(hash => { iface_id => $pxe_iface->id });

    $host->delete();
}

sub getNetConf {
    return {
        dhcpd => {
            port => 67,
            protocols => ['udp']
        }
    };
}

sub getPuppetDefinition {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => [ 'cluster', 'host' ]);

    my $cluster = $self->service_provider;
    my $pxeserver = $cluster->getComponent(category => "Tftpserver");
    my $ip = $pxeserver->getAccessIp(service => 'tftp');
    my @interfaces = map { $_->iface_name } $args{host}->getIfaces();
    my $hosts = {};
    my $pools = {};

    for my $dhcp_subnet ($self->dhcpd3_subnets) {
        my $subnet = $dhcp_subnet->network;
        my $addr = NetAddr::IP->new($subnet->network_addr, $subnet->network_netmask);
        my $first = (split('/', $addr->first))[0];
        my $last = (split('/', $addr->last))[0];

        $pools->{"pool-" . $subnet->id} = {
            network => $subnet->network_addr,
            gateway => $subnet->network_gateway,
            mask => $subnet->network_netmask,
            parameters => 'deny unknown-clients',
            range => [ "$first $last" ],
            tag => 'kanopya::dhcpd'
        };

        DHCP_HOST:
        for my $dhcp_host ($dhcp_subnet->dhcpd3_hosts) {
            try {
                my $iface = $dhcp_host->iface;
                my $host = $iface->host;

                my $gateway = undef;
                if (defined $args{cluster}->default_gateway) {
                    if ($iface->getPoolip->network->id == $args{cluster}->default_gateway->id) {
                        $gateway = $args{cluster}->default_gateway->network_gateway;
                    }
                }

                $hosts->{$host->node->node_hostname} = {
                    mac => $iface->iface_mac_addr,
                    ip  => $iface->getIPAddr,
                    tag => 'kanopya::dhcpd',
                    $dhcp_host->dhcpd3_hosts_pxe ? (pxeserver => $ip, pxefilename => "pxelinux.0")
                                                 : ()
                };
            }
            catch ($err) {
                $log->error("Unable to handle dhcp for dhcp_host:\n$err");
                next DHCP_HOST;
            }
        };
    }

    return merge($self->SUPER::getPuppetDefinition(%args), {
        dhcpd => {
            classes => {
                "kanopya::dhcpd" => {
                    interfaces => \@interfaces,
                    # pxeserver => $ip,
                    # pxefilename => 'pxelinux.0',
                    ntpservers => [ $ip ],
                    dnsdomain => [ $cluster->cluster_domainname ],
                    nameservers => [ $cluster->cluster_nameserver1,
                                     $cluster->cluster_nameserver2 ],
                    hosts => $hosts,
                    pools => $pools,
                }
            }
        }
    } );
}

sub getHostsEntries {
    my $self = shift;

    my @entries;
    for my $cluster (Entity::ServiceProvider::Cluster->search()) {
        @entries = (@entries, $cluster->getHostEntries());
    }

    return \@entries;
}

1;
