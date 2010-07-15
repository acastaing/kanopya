# Executor.pm - 

# Copyright (C) 2009, 2010, 2011, 2012, 2013
#   Free Software Foundation, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 14 july 2010

=head1 NAME

Executor - Executor object

=head1 SYNOPSIS

    use Executor;
    
    # Creates executor
    my $executor = Executor->new();
    
    # Create object
    $executor->newobject($type : String, %ObjectDefinition);


=head1 DESCRIPTION

Executor is the main object use to create execution objects

=head1 METHODS

=cut
package Executor;

use strict;
use warnings;
use Log::Log4perl "get_logger";
use vars qw(@ISA $VERSION);

my $log = get_logger("executor");

$VERSION = do { my @r = (q$Revision: 0.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

=head2 new

    my $executor = Executor->new();

Executor::new creates a new executor object.

=cut

sub new {
    my $class = shift;
    my $self = {};

	$log->warn("New Object Executor");    
    bless $self, $class;
        
    $self->_init();
    
    # PLus tard rajouter autre chose
    
    return $self;
}

=head2 _init

Executor::_init is a private method used to define internal parameters.

=cut

sub _init {
	my $self = shift;
	die "Error d'init";
	return;
}

=head2 getObj

Executor::getObj is a public method used to get object from its type.

=cut

sub getObj {
	my $self = shift;
    my %args = @_;
    
}
__END__

=head1 AUTHOR

Copyright (c) 2010 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut