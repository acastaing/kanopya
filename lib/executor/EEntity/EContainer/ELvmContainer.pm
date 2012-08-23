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

package EEntity::EContainer::ELvmContainer;
use base "EEntity::EContainer";

use strict;
use warnings;

use Entity;

use Log::Log4perl "get_logger";
use Operation;

my $log = get_logger("");

sub getDefaultExportManager {
    my $self = shift;
    my %args = @_;

    my $manager = $self->getDiskManager();
    my $cluster = Entity->get(id => $manager->getAttr(name => 'service_provider_id'));

    return $cluster->getComponent(name => "Iscsitarget", version => "1");
}

1;
