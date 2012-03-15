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

package Entity::ContainerAccess::FileContainerAccess;
use base "Entity::ContainerAccess";

use strict;
use warnings;

use Entity::Component::Nfsd3;

use constant ATTR_DEF => { };

sub getAttrDef { return ATTR_DEF; }

sub getContainerAccess {
    my $self = shift;
    my %args = @_;

    return {};
}

=head2 getExportManager

    desc: Return the component/conector that manages this container access.

=cut

sub getExportManager {
    my $self = shift;

    return Entity::Component->get(id => $self->getAttr(name => 'export_manager_id'));
}

1;
