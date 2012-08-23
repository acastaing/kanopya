# ERemoveMasterimage.pm - Operation class implementing Master image deletion operation

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
# Created 14 july 2010

=head1 NAME

EOperation::ERemoveMasterimage - Operation class implementing Master image deletion operation

=head1 SYNOPSIS

This Object represent an operation.
It allows to implement Master image deletion operation

=head1 DESCRIPTION



=head1 METHODS

=cut
package EEntity::EOperation::ERemoveMasterimage;
use base "EEntity::EOperation";

use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;

use EFactory;
use Kanopya::Exceptions;
use Entity::ServiceProvider::Inside::Cluster;
use Entity::Masterimage;
use File::Basename;

our $VERSION = '1.00';
my $log = get_logger("executor");
my $errmsg;

=head2 prepare

    $op->prepare();

=cut

sub prepare {
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    General::checkParams(args => $self->{context}, required => [ "masterimage" ]);

    # Check if the masterimage is used by any clusters
    my $masterimage_id = $self->{context}->{masterimage}->getAttr(name => 'entity_id');
    my @clusters = Entity::ServiceProvider::Inside::Cluster->search(hash => {
                       masterimage_id => $masterimage_id
                   });

    if (scalar(@clusters)) {
        throw Kanopya::Exception::Internal::WrongValue(
                  error => "Masterimage <$masterimage_id> is used by at least one cluster."
              );        
    }
}

sub execute {
    my $self = shift;
    $self->SUPER::execute();

    # delete master image directory
    my $directory = dirname($self->{context}->{masterimage}->getAttr(name => 'masterimage_file'));

    if (dirname($directory) eq '/') {
        throw Kanopya::Exception::Internal::WrongValue(
                  error => "Sounld not remove $directory, aborting..."
              );
    }

    my $cmd = "rm -rf $directory";
    
    $self->getEContext->execute(command => $cmd);
    $self->{context}->{masterimage}->delete();
}

=head1 DIAGNOSTICS

Exceptions are thrown when mandatory arguments are missing.
Exception : Kanopya::Exception::Internal::IncorrectParam

=head1 CONFIGURATION AND ENVIRONMENT

This module need to be used into Kanopya environment. (see Kanopya presentation)
This module is a part of Administrator package so refers to Administrator configuration

=head1 DEPENDENCIES

This module depends of 

=over

=item KanopyaException module used to throw exceptions managed by handling programs

=item Entity::Component module which is its mother class implementing global component method

=back

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to <Maintainer name(s)> (<contact address>)

Patches are welcome.

=head1 AUTHOR

<HederaTech Dev Team> (<dev@hederatech.com>)

=head1 LICENCE AND COPYRIGHT

Kanopya Copyright (C) 2009, 2010, 2011, 2012, 2013 Hedera Technology.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; see the file COPYING.  If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301 USA.

=cut

1;
