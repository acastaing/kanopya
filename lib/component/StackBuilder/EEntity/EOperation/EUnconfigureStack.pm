#    Copyright © 2009-2014 Hedera Technology SAS
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

Create all service required for a stack

@since    2014-Feb-2014
@instance hash
@self     $self

=end classdoc
=cut

package EEntity::EOperation::EUnconfigureStack;
use base "EEntity::EOperation";

use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl "get_logger";
use Date::Simple (':all');

my $log = get_logger("");


=pod
=begin classdoc

@param stack_builder the stack builder component

=end classdoc
=cut

sub check {
    my ($self, %args) = @_;

    General::checkParams(args => $self->{context}, required => [ "stack_builder", "user" ]);

    General::checkParams(args => $self->{params}, required => [ "stack_id" ]);
}


=pod
=begin classdoc

Disable accesses given to the user at configure stack step.

=end classdoc
=cut

sub execute {
    my ($self, %args) = @_;

    # Call the method on the corresponding component
    $self->{context}->{stack_builder}->unconfigureStack(
        user      => $self->{context}->{user},
        stack_id  => $self->{params}->{stack_id},
        erollback => $self->{erollback}
    );
}

1;
