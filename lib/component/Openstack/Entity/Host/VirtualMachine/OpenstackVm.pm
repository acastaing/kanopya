# Copyright © 2013 Hedera Technology SAS
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

package Entity::Host::VirtualMachine::OpenstackVm;
use base "Entity::Host::VirtualMachine";

use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    nova_controller_id => {
        pattern      => '^\d*$',
        type         => 'relation',
        relation     => 'single',
        is_mandatory => 1,
        is_extended  => 0
    },
    openstack_vm_uuid => {
        pattern      => '^[0-9a-f-]*$',
        type         => 'integer',
        is_mandatory => 0,
        is_extended  => 0
    }
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {};
}

1;
