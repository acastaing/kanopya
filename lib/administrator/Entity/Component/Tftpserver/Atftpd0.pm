# Atftpd0.pm atftp (trivial ftp, part of pxe) component (Adminstrator side)
# Kanopya Copyright (C) 2009, 2010, 2011, 2012, 2013 Hedera Technology.

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
# Created 24 july 2010
=head1 NAME

<Entity::Component::Tftpserver::Atftpd0> <Atftpd component concret class>

=head1 VERSION

This documentation refers to <Entity::Component::Tftpserver::Atftpd0> version 1.0.0.

=head1 SYNOPSIS

use <Entity::Component::Tftpserver::Atftpd0>;

my $component_instance_id = 2; # component instance id

Entity::Component::Tftpserver::Atftpd0->get(id=>$component_instance_id);

# Cluster id

my $cluster_id = 3;

# Component id are fixed, please refer to component id table

my $component_id =2 

Entity::Component::Tftpserver::Atftpd0->new(component_id=>$component_id, cluster_id=>$cluster_id);

=head1 DESCRIPTION

Entity::Component::Tftpserver::Atftpd0 is class allowing to instantiate an Atftpd component
This Entity is empty but present methods to set configuration.

=head1 METHODS

=cut
package Entity::Component::Tftpserver::Atftpd0;
use base "Entity::Component::Tftpserver";

use strict;
use warnings;

use Kanopya::Exceptions;
use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("administrator");
my $errmsg;

=head2 get
B<Class>   : Public
B<Desc>    : This method allows to get an existing Atftpd component.
B<args>    : 
    B<component_instance_id> : I<Int> : identify component instance 
B<Return>  : a new Entity::Component::Tftpserver::Atftpd0 from Kanopya Database
B<Comment>  : To modify configuration use concrete class dedicated method
B<throws>  : 
    B<Kanopya::Exception::Internal::IncorrectParam> When missing mandatory parameters
	
=cut

sub get {
    my $class = shift;
    my %args = @_;

    if ((! exists $args{id} or ! defined $args{id})) { 
		$errmsg = "Entity::Component::Tftpserver::Atftpd0->get need an id named argument!";	
		$log->error($errmsg);
		throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
	}
   my $self = $class->SUPER::get( %args, table=>"ComponentInstance");
   return $self;
}

=head2 new
B<Class>   : Public
B<Desc>    : This method allows to create a new instance of Monitor component and concretly Atftpd.
B<args>    : 
    B<component_id> : I<Int> : Identify component. Refer to component identifier table
    B<cluster_id> : I<int> : Identify cluster owning the component instance
B<Return>  : a new Entity::Component::Tftpserver::Atftpd0 from parameters.
B<Comment>  : Like all component, instantiate it creates a new empty component instance.
        You have to populate it with dedicated methods.
B<throws>  : 
    B<Kanopya::Exception::Internal::IncorrectParam> When missing mandatory parameters
	
=cut

sub new {
	my $class = shift;
    my %args = @_;
	
	if ((! exists $args{cluster_id} or ! defined $args{cluster_id})||
		(! exists $args{component_id} or ! defined $args{component_id})){ 
		$errmsg = "Entity::Component::Tftpserver::Atftpd0->new need a cluster_id and a component_id named argument!";	
		$log->error($errmsg);
		throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
	}
	# We create a new DBIx containing new entity
	my $self = $class->SUPER::new( %args);

    return $self;

}

sub getConf{
	my $self = shift;
	my $conf_raw = $self->{_dbix}->atftpd0s->first();
	return {options => $conf_raw->get_column('atftpd0_options'),
			   repository => $conf_raw->get_column('atftpd0_repository'),
			   use_inetd => $conf_raw->get_column('atftpd0_use_inetd'),
			   logfile => $conf_raw->get_column('atftpd0_logfile')};

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
