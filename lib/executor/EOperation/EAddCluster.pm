# EAddCluster.pm - Operation class implementing Cluster creation operation

#    Copyright © 2009-2012 Hedera Technology SAS
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

package EOperation::EAddCluster;
use base "EOperation";

use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;
use Kanopya::Exceptions;
use EFactory;

use Entity::ServiceProvider::Inside::Cluster;
use Entity::Systemimage;
use Entity::Gp;

my $log = get_logger("executor");
my $errmsg;
our $VERSION = '1.00';


=head2 prepare

    $op->prepare();

=cut

sub prepare {
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    General::checkParams(args => \%args, required => [ "internal_cluster" ]);
    
    my $params = $self->_getOperation()->getParams();

    $self->{_objs} = {};
    
    # Cluster instantiation
    eval {
        $self->{_objs}->{cluster} = Entity::ServiceProvider::Inside::Cluster->new(%$params);
    };
    if($@) {
        $errmsg = "EOperation::EAddCluster->prepare : Cluster instanciation failed because : " . $@;
        $log->error($errmsg);
        throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
    }

    $self->{econtext} = EFactory::newEContext(ip_source      => "127.0.0.1",
                                              ip_destination => "127.0.0.1");

}

sub execute {
    my $self = shift;

    my $ecluster = EFactory::newEEntity(data => $self->{_objs}->{cluster});
    $ecluster->create(econtext => $self->{econtext},erollback => $self->{erollback});
    
    $log->info("Cluster <".$self->{_objs}->{cluster}->getAttr(name=>"cluster_name") ."> is now added");
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

Kanopya Copyright (C) 2009-2012 Hedera Technology.

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
