# Kernel.pm - This object allows to manipulate Kernel configuration
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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 7 july 2010


=pod
=begin classdoc

TODO

=end classdoc
=cut

package Entity::Kernel;
use base "Entity";

use strict;
use warnings;

use Kanopya::Exceptions;
use General;
use Log::Log4perl "get_logger";
my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    kernel_name => { pattern => '^.*$', is_mandatory => 1, is_extended => 0 },
    kernel_version => { pattern => '^.*$', is_mandatory => 1, is_extended => 0 },
    kernel_desc => { pattern => '^.*$', is_mandatory => 0, is_extended => 0 },

};


sub getKernels {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    return $class->search(%args);
}

sub remove {}

sub getAttrDef{
    return ATTR_DEF;
}

=pod
=begin classdoc

Return a string representation of the entity

@return string representation of the entity

=end classdoc
=cut

sub toString {
    my $self = shift;
    my $string = $self->{_dbix}->get_column('kernel_name');
    return $string;
}

1;
