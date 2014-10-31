# Copyright © 2011-2012 Hedera Technology SAS
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

=pod

=begin classdoc

The network policy defines the parameters describing how a service
manage the network interfaces of it's hosts.

@since    2012-Aug-16
@instance hash
@self     $self

=end classdoc

=cut

package Entity::Policy::NetworkPolicy;
use base 'Entity::Policy';

use strict;
use warnings;

use Entity::Netconf;
use Entity::Network;

use Data::Dumper;
use Log::Log4perl 'get_logger';

use Clone qw(clone);

my $log = get_logger("");

use constant ATTR_DEF => {};

sub getAttrDef { return ATTR_DEF; }

use constant POLICY_ATTR_DEF => {
    cluster_domainname => {
        label        => 'Domain name',
        type         => 'string',
        pattern      => '^[a-z0-9-]+(\\.[a-z0-9-]+)+$',
        is_mandatory => 1,
        order        => 1,
    },
    cluster_nameserver1 => {
        label        => 'Name server 1',
        type         => 'string',
        pattern      => '^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$',
        is_mandatory => 2,
        order        => 2,
    },
    cluster_nameserver2 => {
        label        => 'Name server 2',
        type         => 'string',
        pattern      => '^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$',
        is_mandatory => 1,
        order        => 3,
    },
    default_gateway_id => {
        label        => 'Default gateway network',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^\d*$',
        is_mandatory => 1,
        order        => 4,
    },
    network_manager_id => {
        label        => "Network manager",
        type         => 'relation',
        relation     => 'single',
        pattern      => '^\d*$',
        reload       => 1,
        is_mandatory => 1,
        order        => 5,
    },
};

sub getPolicyAttrDef { return POLICY_ATTR_DEF; }

my $merge = Hash::Merge->new('RIGHT_PRECEDENT');


=pod
=begin classdoc

Add the available gateway networks list to the policy defintion

@return the dynamic attributes definition.

=end classdoc
=cut

sub getPolicyDef {
    my $self  = shift;
    my $class = ref($self) || $self;
    my %args  = @_;

    General::checkParams(args     => \%args,
                         required => [ 'attributes' ],
                         optional => { 'params' => {}, 'trigger' => undef });

    my $attributes = $self->SUPER::getPolicyDef(%args);

    # Build the default gateway network list
    my @networks;
    for my $network (Entity::Network->search(hash => {})) {
        push @networks, $network->toJSON();
    }
    $attributes->{attributes}->{default_gateway_id}->{options} = \@networks;

    return $attributes;
}

1;
