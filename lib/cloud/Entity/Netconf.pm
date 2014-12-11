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

package Entity::Netconf;
use base "Entity";

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    netconf_name => {
        label        => 'Name',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
        description  => 'Netconf Name. A netconf is the configuration of a network interface.'.
                        'It can be composed by vlans associated with ip pool',
    },
    netconf_vlans => {
        label        => 'VLANs',
        type         => 'relation',
        relation     => 'multi',
        link_to      => 'vlan',
        is_mandatory => 0,
        is_editable  => 1,
        description  => 'Vlans attached to the network interface',
    },
    netconf_poolips => {
        label        => 'Pools IPs',
        type         => 'relation',
        relation     => 'multi',
        link_to      => 'poolip',
        is_mandatory => 0,
        is_editable  => 1,
        description  => 'IP pool consumed by the netconf',
    },
    netconf_role_id => {
        label        => 'Role',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^.*$',
        is_mandatory => 0,
        is_editable  => 1,
        description  => 'It is the role assigned to the network interface (bridge for vm (vm),'.
                        ' load balancing interface (public), private network (private)',
    },
};

sub getAttrDef { return ATTR_DEF; }

1;
