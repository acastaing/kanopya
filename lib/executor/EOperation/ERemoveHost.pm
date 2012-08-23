#    Copyright © 2011-2012 Hedera Technology SAS
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

=head1 NAME

EEntity::Operation::EAddHost - Operation class implementing Host creation operation

=head1 SYNOPSIS

This Object represent an operation.
It allows to implement Host creation operation

=head1 DESCRIPTION

Component is an abstract class of operation objects

=head1 METHODS

=cut
package EOperation::ERemoveHost;
use base "EOperation";

use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;
use Kanopya::Exceptions;
use EFactory;

use Entity::ServiceProvider;
use Entity::Host;

my $log = get_logger("");
my $errmsg;
our $VERSION = '1.00';

=head2 prepare

    $op->prepare();

=cut

sub prepare {
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    General::checkParams(args => $self->{context}, required => [ "host" ]);

    # check if host is not active
    if ($self->{context}->{host}->getAttr(name => 'active')) {
        $errmsg = "Host <" . $self->{context}->{host}->getAttr(name => 'entity_id') . "> is still active";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }

    eval {
        $self->{context}->{host_manager} =
            EFactory::newEEntity(data => $self->{context}->{host}->getHostManager);
    };
    if($@) {
        throw Kanopya::Exception::Internal::WrongValue(error => $@);
    }
}

sub execute{
    my $self = shift;

    $self->{context}->{host_manager}->removeHost(host      => $self->{context}->{host},
                                                 erollback => $self->{erollback});
}

__END__

=head1 AUTHOR

Copyright (c) 2010-2012 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
