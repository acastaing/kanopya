# Entity::Vlan.pm  

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
# Created 16 july 2010

=head1 NAME

Entity::Vlan

=head1 SYNOPSIS

=head1 DESCRIPTION

blablabla

=cut

package Entity::Vlan;
use base "Entity";

use constant ATTR_DEF => {
	vlan_name			=> { pattern        => '^\w*$',
							 is_mandatory   => 1,                               
                             is_extended    => 0,
                             is_editable    => 0,
                           },
    vlan_desc			=> { pattern      => '^.*$',
							 is_mandatory => 0,
							 is_extended  => 0,
							 is_editable  => 1,
						   },
                           
    vlan_number			=> { pattern      => '^\d*$',
							 is_mandatory => 1,
							 is_extended  => 0,
							 is_editable  => 0,
							 },
};

sub getAttrDef { return ATTR_DEF; }
sub getVlans {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    return $class->search(%args);
}
=head2 create

=cut

sub create {
    my $self = shift;
    my $admin = Administrator->new();
    $self->save();
}
=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my $self = shift;
    my $string = $self->{_dbix}->get_column('vlan_desc');
    return $string;
}


sub associateVlanpoolip {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['vlan_id','poolip_id']);

    my $adm = Administrator->new();
    # my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'associateVlanpoolip');
    #if(not $granted) {
     #   throw Kanopya::Exception::Permission::Denied(error => "Permission denied to associate pool ip to this vlan");
    #}
    my $res =$adm->{db}->resultset('VlanPoolip')->create(
		{	poolip_id=>$args{poolip_id},
            vlan_id =>$self->getAttr(name=>'vlan_id')
        }
    );

    return $res->get_column("poolip_id");
}

1;
