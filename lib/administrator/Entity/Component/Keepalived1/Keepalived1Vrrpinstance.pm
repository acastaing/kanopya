#    Copyright © 2012 Hedera Technology SAS
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

package Entity::Component::Keepalived1::Keepalived1Vrrpinstance;
use base 'BaseDB';

use constant ATTR_DEF => {
    vrrpinstance_name => {
        label        => 'Name',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
    },
    vrrpinstance_password => {
        label        => 'Password',
        type         => 'password',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
    },
    interface_id => {
        label        => 'Interface',
        pattern      => '^\d+$',
        type         => 'relation',
        relation     => 'single',
        is_mandatory => 1,
        is_editable  => 1
    },
    virtualip_id => {
        label        => 'Ip',
        type         => 'relation',
        relation     => 'single',
        is_mandatory => 0,
        is_editable  => 0
    },
    virtualip_interface_id => {
        label        => 'Ip interface',
        type         => 'relation',
        relation     => 'single',
        is_mandatory => 1,
        is_editable  => 1
    },
};

sub getAttrDef { return ATTR_DEF; }

1;
