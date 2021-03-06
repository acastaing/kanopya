# Copyright © 2011-2013 Hedera Technology SAS
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

TODO

=end classdoc
=cut

package Harddisk;
use base 'BaseDB';

use strict;
use warnings;
use Log::Log4perl 'get_logger';

my $log = get_logger("");

use constant ATTR_DEF => {
    host_id => {
        pattern      => '^\d+',
        is_delegatee => 1,
        is_mandatory => 1,
        description  => 'The host with this disk',
    },
    harddisk_device => {
        label        => 'root device',
        type         => 'string',
        pattern      => '^.*$',
        default      => 'autodetect',
        is_mandatory => 1,
        is_editable  => 1,
        description  => 'Device name of this disk',
    },
    harddisk_size => {
        label        => 'Hard disk size',
        type         => 'integer',
        unit         => 'byte',
        pattern      => '^\d*$',
        is_mandatory => 0,
        is_editable  => 1,
        description  => 'Total size of the hard disk',
    }
};

sub getAttrDef { return ATTR_DEF; }

sub methods { return {}; }

1;
