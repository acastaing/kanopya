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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package Entity::Component::Iscsi;
use base "Entity::Component";
use base "Manager::ExportManager";

use strict;
use warnings;

use Kanopya::Exceptions;
use Entity::Component::Iscsi::IscsiPortal;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    iscsi_portals => {
        label        => 'ISCSI portals',
        type         => 'relation',
        relation     => 'single_multi',
        is_mandatory => 0,
        is_editable  => 1,
    },
    export_type => {
        is_virtual => 1
    }
};

sub getAttrDef { return ATTR_DEF; }

sub methods {}

sub exportType {
    return "Unmanaged ISCSI target";
}

sub checkExportManagerParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "iscsi_portals", "target", "lun" ]);
}

sub getPolicyParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'policy_type' ]);

    my $portals = {};
    if ($args{policy_type} eq 'storage') {
        for my $portal (@{ $self->getConf->{iscsi_portals} }) {
            $portals->{$portal->{iscsi_portal_id}} = $portal->{iscsi_portal_ip} . ':' . $portal->{iscsi_portal_port}
        }
        return [ { name => 'iscsi_portals', label => 'ISCSI portals', values => $portals },
                 { name => 'target', label => 'ISCSI target' },
                 { name => 'lun', label => 'LUN number' } ];
    }
    return [];
}

sub getConf {
    my $self = shift;
    my $conf = {};
    my @portals = ();

    for my $portal ($self->iscsi_portals) {
        push @portals, { iscsi_portal_ip   => $portal->iscsi_portal_ip,
                         iscsi_portal_port => $portal->iscsi_portal_port,
                         iscsi_portal_id   => $portal->iscsi_portal_id,
                         iscsi_id          => $self->id };
    }

    $conf->{iscsi_portals} = \@portals;
    return $conf;
}

sub setConf {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'conf' ]);

    my $conf = $args{conf};
    my $configured = {};
    for my $portal (@{ $conf->{iscsi_portals} }) {
        my $portal_id = $portal->{iscsi_portal_id};
        if (not $portal_id) {
            $portal_id = Entity::Component::Iscsi::IscsiPortal->new(
                             iscsi_id          => $self->id,
                             iscsi_portal_ip   => $portal->{iscsi_portal_ip},
                             iscsi_portal_port => $portal->{iscsi_portal_port},
                         )->id;
        }
        $configured->{$portal_id} = 1;
    }
    for my $existing ($self->iscsi_portals) {
        if (not defined $configured->{$existing->id}) {
            $existing->remove();
        }
    }
}

# Insert default configuration in db for this component 
sub insertDefaultConfiguration {
    my $self = shift;

    my $ip = $self->service_provider->getMasterNodeIp;
    if (not $ip) {
        throw Kanopya::Exception::Internal(
                  error => "Could not find master not ip while " .
                           "inserting default configuration"
              );
    }

    Entity::Component::Iscsi::IscsiPortal->new(
        iscsi_id          => $self->id,
        iscsi_portal_ip   => $ip,
        iscsi_portal_port => 3261
    );
}

sub getNetConf {
    return { 3260 => ['tcp'] };
}

sub getReadOnlyParameter {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'readonly' ]);

    my $value;
    if ($args{readonly}) { $value = 'ro'; }
    else                 { $value = 'wb'; }
    return {
        name  => 'iomode',
        value => $value,
    }
}

1;
