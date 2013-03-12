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
use parent "Entity::Component";

use strict;
use warnings;

use Kanopya::Exceptions;
use Entity::ServiceProvider::Cluster;

use Log::Log4perl "get_logger";
use Data::Dumper;
use General;

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {};
sub getAttrDef { return ATTR_DEF; }

=head2 getInternalSubNetId
B<Class>   : Public
B<Desc>    : This method return internal network subnet id
B<args>    : None
B<Return>  : String : internal network subnet id
B<Comment>  : TO Change when kanopya will manage different internal network
    Or when component dhcp will be a available to be installed on a cluster
    Before internal ip will be the first entry in dhcp component
B<throws>  : None      
=cut

sub getInternalSubNetId{
    #TODO Change when kanopya will manage different internal network
    # Or when component dhcp will be a available to be installed on a cluster
    # Before internal ip will be the first entry in dhcp component
    return 1;
}

sub getSubNet {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['dhcpd3_subnet_id']);
    
    my $dhcpd3_subnet =  $self->{_dbix}->dhcpd3_subnets->find($args{dhcpd3_subnet_id});
    return $dhcpd3_subnet->get_columns();
}

=head2 getConf
B<Class>   : Public
B<Desc>    : This method returns a structure to pass to the template processor 
B<args>    : None
B<Return>  : hashref : dhcpd configuration :
    B<domain_name> : String : domain name
    B<domain_name_server> : String : domain name server ip
    B<servername> : String : dhcpd server name
    B<server_ip> : String : dhcpd server ip
    B<subnet> : hash ref containing
        B<net> : String : network address of the subnet entry
        B<mask> : String : network mask of the subnet entry
        B<nodes> : table ref containing nodes (which are hash table) :
            B<ip_address> : String : Node ip address\
            B<mac_address> : String : Node mac address
            B<hostname> : String : Node hostname
            B<kernel_version> : String : Node kernel version
B<Comment>  : TO Change when kanopya will manage different internal network
    Or when component dhcp will be a available to be installed on a cluster
    Before internal ip will be the first entry in dhcp component
B<throws>  : None      
=cut

# return a data structure to pass to the template processor 
sub getConf {
    my $self = shift;

    my $dhcpd3 = $self->{_dbix};
    my $data   = {};

    $data->{domain_name}        = $dhcpd3->get_column('dhcpd3_domain_name');
    $data->{domain_name_server} = $dhcpd3->get_column('dhcpd3_domain_server');
    $data->{server_name}        = $dhcpd3->get_column('dhcpd3_servername');
    $data->{server_ip}          = $self->getMasterNode->adminIp;

    my $subnets = $dhcpd3->dhcpd3_subnets;
    my @data_subnets = ();
    while(my $subnet = $subnets->next) {
        my $hosts = $subnet->dhcpd3_hosts;
        my @data_hosts = ();
        while(my $host = $hosts->next) {
            push @data_hosts, {
                domain_name        => $host->get_column('dhcpd3_hosts_domain_name'),
                domain_name_server => $host->get_column('dhcpd3_hosts_domain_name_server'),
                ip_address         => $host->get_column('dhcpd3_hosts_ipaddr'),
                ntp_server         => $host->get_column('dhcpd3_hosts_ntp_server'),
                mac_address        => $host->get_column('dhcpd3_hosts_mac_address'),
                hostname           => $host->get_column('dhcpd3_hosts_hostname'),
                gateway            => $host->get_column('dhcpd3_hosts_gateway'),
            };
        }
        push @data_subnets, {
            net     => $subnet->get_column('dhcpd3_subnet_net'),
            mask    => $subnet->get_column('dhcpd3_subnet_mask'),
            gateway => $subnet->get_column('dhcpd3_subnet_gateway'),
            nodes   => \@data_hosts
        };
    }

    $data->{subnets} = \@data_subnets;
    return $data;
}

=head2 addHost
B<Class>   : Public
B<Desc>    : This method returns a structure to pass to the template processor 
B<args>    : 
    B<dhcpd3_subnet_id> : Int : Subnet identifier
    B<dhcpd3_hosts_ipaddr> : String : New host ip address
    B<dhcpd3_hosts_mac_address> : String : New host mac address
    B<dhcpd3_hosts_hostname> : String : New host hostname
    B<kernel_id> : Int : New host kernel id
B<Return>  : Int : New host id
B<Comment>  : None
B<throws>  : 
Kanopya::Exception::Internal::IncorrectParam thrown when args missed      
=cut

sub addHost {
    my $self = shift;
    my %args = @_;

    General::checkParams(
        args => \%args,
        required => [   'dhcpd3_subnet_id',
                        'dhcpd3_hosts_ipaddr',
                        'dhcpd3_hosts_mac_address', 
                        'dhcpd3_hosts_hostname',
                        'kernel_id', 
                        'dhcpd3_hosts_ntp_server',
                        'dhcpd3_hosts_domain_name', 
                        'dhcpd3_hosts_domain_name_server',
                    ]
    );

    my $dhcpd3_hosts_rs = $self->{_dbix}->dhcpd3_subnets->find($args{dhcpd3_subnet_id})->dhcpd3_hosts;
    my $res = $dhcpd3_hosts_rs->update_or_create(\%args);
    return $res->get_column('dhcpd3_hosts_id');
}

sub getHost {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['dhcpd3_hosts_id','dhcpd3_subnet_id']);
    
    my $dhcpd3_hosts_row = $self->{_dbix}->dhcpd3_subnets->find($args{dhcpd3_subnet_id})->dhcpd3_hosts->find($args{dhcpd3_hosts_id});
    my %host = $dhcpd3_hosts_row->get_columns();
    return \%host;
}

=head2 getHostId
B<Class>   : Public
B<Desc>    : This method returns host id in dhcpd component instance 
B<args>    : 
    B<dhcpd3_subnet_id> : Int : Subnet identifier
    B<dhcpd3_hosts_mac_address> : String : host mac address
B<Return>  : Int : host id
B<Comment>  : None
B<throws>  : 
Kanopya::Exception::Internal::IncorrectParam thrown when args missed      
=cut

sub getHostId {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['dhcpd3_hosts_mac_address','dhcpd3_subnet_id']);
    
    return $self->{_dbix}->dhcpd3_subnets->find($args{dhcpd3_subnet_id})->dhcpd3_hosts->search({ dhcpd3_hosts_mac_address=> $args{dhcpd3_hosts_mac_address}})->first()->get_column('dhcpd3_hosts_id');
}

=head2 removeHost
B<Class>   : Public
B<Desc>    : This method remove a host from dhcpd component configuration
B<args>    : 
    B<dhcpd3_subnet_id> : Int : Subnet identifier
    B<dhcpd3_hosts_id> : Int : host identifier
B<Return>  : None
B<Comment>  : None
B<throws>  : 
Kanopya::Exception::Internal::IncorrectParam thrown when args missed      
=cut

sub removeHost{
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['dhcpd3_hosts_id','dhcpd3_subnet_id']);

    return $self->{_dbix}->dhcpd3_subnets->find($args{dhcpd3_subnet_id})->dhcpd3_hosts->find( $args{dhcpd3_hosts_id})->delete();
}

=head2 getNetConf
B<Class>   : Public
B<Desc>    : This method return component network configuration in a hash ref, it's indexed by port and value is the port
B<args>    : None
B<Return>  : hash ref containing network configuration with following format : {port => protocol}
B<Comment> : None
B<throws>  : Nothing
=cut

sub getNetConf {
    return { 67 => ['udp'] };
}

sub getPuppetDefinition {
    my ($self, %args) = @_;

    return "class { 'kanopya::dhcpd': }\n";
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
