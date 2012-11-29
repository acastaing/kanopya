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

package EEntity::EComponent::EIscsi;
use base "EEntity::EComponent";
use base 'EManager::EExportManager';

use strict;
use warnings;

use General;
use EFactory;

use Data::Dumper;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

sub createExport {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'container' ]);

}

sub removeExport {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'container_access' ]);

    if (! $args{container_access}->isa("EEntity::EContainerAccess::EIscsiContainerAccess")) {
        throw Kanopya::Exception::Execution(
                  error => "ContainerAccess must be a EEntity::EContainerAccess::EIscsiContainerAccess, not " .
                           ref($args{container_access})
              );
    }

    $args{container_access}->delete();
}

1;