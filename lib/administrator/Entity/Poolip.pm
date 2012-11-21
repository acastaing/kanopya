# Entity::Poolip.pm  

#    Copyright © 2011 Hedera Technology SAS
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
# Created 14 february 2012

=head1 NAME

Entity::Poolip

=head1 SYNOPSIS

=head1 DESCRIPTION

    desc:

=cut

package Entity::Poolip;
use base "Entity";

use Ip;
use NetAddr::IP;
use Kanopya::Exceptions;

use Log::Log4perl "get_logger";
use Data::Dumper;
my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    poolip_name => {
        pattern      => '.*',
        is_mandatory => 1,
    },
    poolip_first_addr => {
        pattern      => '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$',
        is_mandatory => 1,
    },
    poolip_size => {
        pattern      => '[0-9]{1,2}',
        is_mandatory => 1,
    },
};

sub getAttrDef { return ATTR_DEF; }

sub popIp {
    my $self = shift;
    my %args = @_;

    my $network = NetAddr::IP->new(
                      $self->getAttr(name => 'poolip_addr'),
                      $self->getAttr(name => 'poolip_netmask'),
                  );

    # Firstly iterate until the first ip of the range.
    # TODO: make it smarter...
    my $ipaddr;
    my $index = 0;
    while ($ipaddr = $network->nth($index)) {
        $index++;

        # If current ip is lower than the starting ip, continue
        if ($ipaddr < $network) {
            next;
        }
        # If current ip index is higher than poolip size, exit loop
        elsif (($ipaddr - $network + 1 ) > $self->getAttr(name => 'poolip_mask')) {
            last;
        }

        # Check if the current ip isn't already used
        eval {
            Ip->find(hash => { ip_addr   => $ipaddr->addr,
                               poolip_id => $self->getAttr(name => 'entity_id') });
        };
        if ($@) {
            # Create a new Ip instead.
            $log->debug("New ip <" . $ipaddr->addr . "> from pool <" .
                        $self->getAttr(name => 'poolip_name') . ">");

            return Ip->new(ip_addr   => $ipaddr->addr,
                           poolip_id => $self->getAttr(name => 'entity_id'));
        }
        next;
    }
    throw Kanopya::Exception::Internal::NotFound(
              error => "No free ip in pool <" . $self->getAttr(name => 'poolip_name') . ">"
          );
}

sub freeIp {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['ip']);

    # Need other stuff ?
    $args{ip}->delete();
}

sub getPoolip {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    return $class->search(%args);
}

sub create {
    my ($class, %args) = @_;

    $class->checkAttrs(attrs => \%args);

    my $addrip = new NetAddr::IP($args{poolip_addr});
    if(not defined $addrip) {
        $errmsg = "Poolip->create : wrong value for address!";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }

    my $poolip = Entity::Poolip->new(
        poolip_name    => $args{poolip_name},
        poolip_addr    => $args{poolip_addr},
        poolip_mask    => $args{poolip_mask},
        poolip_netmask => $args{poolip_netmask},
        poolip_gateway => $args{poolip_gateway},
    );
}

sub remove {
    my $self = shift;
    $self->SUPER::delete(); 
};

sub toString {
    my $self = shift;
    my $string = $self->{_dbix}->get_column('poolip_name'). " ". $self->{_dbix}->get_column('poolip_addr');
    return $string;
}


sub getAllIps {
    my $self = shift;
    my $ips = [];
 
    my $ip = new NetAddr::IP($self->getAttr(name => 'poolip_addr'), $self->getAttr(name => 'poolip_netmask'));   
    
    for (my $i = 0; $i < $self->getAttr(name => 'poolip_mask'); ++$i) {
        push(@{$ips}, $ip);
        ++$ip;
    }
    
    return $ips;
}


1;
