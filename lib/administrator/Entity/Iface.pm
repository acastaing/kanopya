
# Copyright © 2011 Hedera Technology SAS
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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package Entity::Iface;
use base "Entity";

use Kanopya::Exceptions;
use Entity::Poolip;
use Ip;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    iface_name => {
        label        => 'Interface name',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
    },
    iface_mac_addr => {
        label        => 'MAC adress',
        type         => 'string',
        pattern      => '^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:' .
                        '[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}$',
        is_mandatory => 1,
        is_editable  => 1,
    },
    iface_pxe => {
        label        => 'PXE enabled',
        type         => 'boolean',
        pattern      => '^[01]$',
        is_mandatory => 1,
        is_editable  => 1,
    },
    host_id => {
        type         => 'relation',
        relation     => 'single',
        pattern      => '^\d+$',
        is_mandatory => 1,
    },
    interface_id => {
        type         => 'relation',
        relation     => 'single',
        pattern      => '^\d+$',
        is_mandatory => 0,
    },
};

sub getAttrDef { return ATTR_DEF; }

sub toString {
    my $self = shift;
    my $string = "Iface: " . $self->{_dbix}->get_column('iface_name') .
                 " - " . $self->{_dbix}->get_column('iface_mac_addr');
    return $string;
}

sub associateInterface {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'interface' ]);

    # Do not associate interface with role 'vms' to an pxe iface,
    # because 'vms' associate iface will not be assigned to an ip,
    # so could not be used as pxe boot iface.
    if ($args{interface}->getRole->getAttr(name => 'interface_role_name') eq 'vms' and
        $self->getAttr(name => 'iface_pxe')) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Could not associate interface <" . $args{interface}->getAttr(name => 'entity_id') .
                           "> with role 'vms' to a pxe iface <" . $self->getAttr(name => 'iface_mac_addr') . ">."
              );
    }

    $log->info("Associate iface " .  $self->getAttr(name => 'iface_mac_addr') .
               " to interface with role " . $args{interface}->getRole->getAttr(name => 'interface_role_name'));

    $self->setAttr(name  => 'interface_id',
                   value => $args{interface}->getAttr(name => 'entity_id'));
    $self->save();
}

sub dissociateInterface {
    my $self = shift;
    my %args = @_;

    @ips = Ip->search(hash => { iface_id => $self->getAttr(name => 'entity_id') });
    for my $ip (@{ips}) {
        my $poolip = Entity::Poolip->get(id => $ip->getAttr(name => 'poolip_id'));
        $poolip->freeIp(ip => $ip);
    }
    $self->setAttr(name => 'interface_id', value => undef);
    $self->save();
}

sub isAssociated {
    my $self = shift;
    my %args = @_;

    return $self->getAttr(name => 'interface_id');
}

sub assignIp {
    my $self = shift;
    my %args = @_;

    my $interface;
    eval {
        $interface = Entity::Interface->get(id => $self->getAttr(name => 'interface_id'));
    };
    if ($@) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Iface " . $self->getAttr(name => 'iface_name') .
                           " not associated to a cluster interface."
              );
    }
    $interface->assignIpToIface(iface => $self);
}

sub hasIp {
    my $self = shift;
    my %args = @_;

    my @ips = Ip->search(hash => { iface_id => $self->getAttr(name => 'entity_id') });
    return scalar(@ips);
}

sub getIPAddr {
    my $self = shift;
    my %args = @_;

    my $ip;
    eval {
        # TODO: handle multiple IP by Iface.
         $ip = Ip->find(hash => { iface_id => $self->getAttr(name => 'entity_id') });
    };
    if ($@) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Iface " . $self->getAttr(name => 'iface_name') .
                           " not associated to any IP."
              );
    }
    return $ip->getAttr(name => 'ip_addr');
}

sub getPoolip {
    my $self = shift;
    my %args = @_;

    my $ip;
    eval {
        # TODO: handle multiple IP by Iface.
        $ip = Ip->find(hash => { iface_id => $self->getAttr(name => 'entity_id') });
    };
    if ($@) {
        throw Kanopya::Exception::Internal::NotFound(
                  error => "Iface " . $self->getAttr(name => 'iface_name') .
                           " not associated to any IP."
              );
    }

    return Entity::Poolip->get(id => $ip->getAttr(name => 'poolip_id'));
}

sub getInterface {
    my $self = shift;

    return Entity::Interface->get(id => $self->getAttr(name => 'interface_id'));
}

1;
