#    Copyright © 2011 Hedera Technology SAS
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

=pod

=begin classdoc

Concrete class for nfs container accesses. Nfs container accesses are disk exports provided
by components that use the Nfs protocol to give access to remote disks. It extends base 
container by specifying nfs export options.

@since    2012-Feb-23
@instance hash
@self     $self

=end classdoc

=cut

package Entity::ContainerAccess::NfsContainerAccess;
use base "Entity::ContainerAccess";

use strict;
use warnings;

use Entity::NfsContainerAccessClient;

use constant ATTR_DEF => {
    options => {
        pattern => '^.*$',
        is_mandatory => 1,
        is_extended => 0
    },
};

sub getAttrDef { return ATTR_DEF; }


=pod

=begin classdoc

Accessor to get nfs container access clients for this access.

@return the access clients list

=end classdoc

=cut

sub getClients {
    my $self = shift;

    return Entity::NfsContainerAccessClient->find(
               hash => {
                   nfs_container_access_id => $self->getAttr(name => "nfs_container_access_id")
               }
           );
}

1;
