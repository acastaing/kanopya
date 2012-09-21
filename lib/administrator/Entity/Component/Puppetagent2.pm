# Puppetagent2.pm - Puppet agent (Adminstrator side)
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
# Created 4 sept 2010

=head1 NAME

<Entity::Component::Puppetagent2> <Puppet agent component concret class>

=head1 VERSION

This documentation refers to <Entity::Component::Puppetagent2> version 1.0.0.

=head1 SYNOPSIS

=head1 DESCRIPTION

Entity::Component::Puppetagent2 is class allowing to instantiate an Puppet agent component
This Entity is empty but present methods to set configuration.

=head1 METHODS

=cut

package Entity::Component::Puppetagent2;
use base "Entity::Component";

use strict;
use warnings;

use Kanopya::Exceptions;
use Kanopya::Config;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    puppetagent2_options => {
        label         => 'Puppet agent options',
        type          => 'string',
        pattern       => '^.*$',
        is_mandatory  => 0,
        is_editable   => 1,
    },
    puppetagent2_mode => {
        label         => 'Puppet Master to use',
        type          => 'enum',
        options       => ['kanopya','custom'],
        pattern       => '^.*$',
        is_mandatory  => 1,
        is_editable   => 1,
    },
    puppetagent2_masterip => {
        label         => 'Puppet Master IP',
        type          => 'string',
        pattern       => '^.*$',
        is_mandatory  => 0,
        is_editable   => 1,
    },
    puppetagent2_masterfqdn => {
        label         => 'Puppet Master FQDN',
        type          => 'string',
        pattern       => '^.*$',
        is_mandatory  => 0,
        is_editable   => 1,
    },
};
sub getAttrDef { return ATTR_DEF; }

sub getConf {
    my ($self) = @_;
    my %conf = ();
    my $confindb = $self->{_dbix};
    if($confindb) {
        %conf = $confindb->get_columns();
    } else {
        %conf = %{getBaseConfiguration()};
    }
    return \%conf; 
}

sub setConf {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['conf']);

    my $conf = $args{conf};
    if ($conf->{puppetagent2_mode} eq 'kanopya') {        
        my $config = Kanopya::Config::get('executor');
        my $kanopya_cluster = Entity->get(id => $config->{cluster}->{executor});
        $conf->{puppetagent2_masterip} = $kanopya_cluster->getMasterNodeIp();
        $conf->{puppetagent2_masterfqdn} = $kanopya_cluster->getMasterNodeFQDN();
    }
    
    if (not $conf->{puppetagent2_id}) {
        # new configuration -> creat
        $self->{_dbix}->create($conf);
    } else {
        # old configuration -> update
        $self->{_dbix}->update($conf);
    }
}

sub getHostsEntries {
    my ($self) = @_;
    my $entry = {};
    my $fqdn = $self->{_dbix}->get_column('puppetagent2_masterfqdn');
    my @tmp = split(/\./, $fqdn);
    $entry->{ip} = $self->{_dbix}->get_column('puppetagent2_masterip');
    $entry->{hostname} = shift @tmp;
    $entry->{domainname} = join('.', @tmp);
    
    return [ $entry ];
}

sub getBaseConfiguration {
	return {
        puppetagent2_options    => '',
        puppetagent2_mode       => 'kanopya',
        puppetagent2_masterip   => '',
        puppetagent2_masterfqdn => '' 
    };
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
