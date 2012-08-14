# PowerSupplyCard.pm - This object allows to manipulate PowerSupplyCard configuration
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
# Created 17 july 2010
package Entity::Powersupplycard;
use base "Entity";

use strict;
use warnings;

use Kanopya::Exceptions;
use Administrator;
use General;
use Log::Log4perl "get_logger";
my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    powersupplycard_name => { pattern => 'm/\w*/s',
                          is_mandatory => 1,
                          is_extended => 0 },
    
    powersupplycard_ip => { pattern => 'm/\d+\.\d+\.\d+\.\d+/m',
                          is_mandatory => 1,
                          is_extended => 0 },
    
    powersupplycard_mac_address => { pattern => 'm//s',
                         is_mandatory => 1,
                         is_extended => 0 },
                         
    powersupplycardmodel_id => { pattern => 'm//s',
                         is_mandatory => 0,
                         is_extended => 0 },
                         
    active => { pattern => 'm//s',
                is_mandatory => 0,
                is_extended => 0 },        
};

sub methods {
    return {
        'create'    => {'description' => 'create a new power supply card', 
                        'perm_holder' => 'mastergroup',
        },
        'get'        => {'description' => 'view this power supply card', 
                        'perm_holder' => 'entity',
        },
        'update'    => {'description' => 'save changes applied on this power supply card', 
                        'perm_holder' => 'entity',
        },
        'remove'    => {'description' => 'delete this power supply card', 
                        'perm_holder' => 'entity',
        },
        'activate'=> {'description' => 'activate this power supply card', 
                        'perm_holder' => 'entity',
        },
        'deactivate'=> {'description' => 'deactivate this power supply card', 
                        'perm_holder' => 'entity',
        },
        'setperm'    => {'description' => 'set permissions on this power supply card', 
                        'perm_holder' => 'entity',
        },
    };
}

=head2 getPowerSupplyCards

=cut

sub getPowerSupplyCards {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    return $class->search(%args);
}

=head2 update

=cut

sub update {}

=head2 remove

=cut

sub remove {}

sub getAttrDef{
    return ATTR_DEF;
}

=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my $self = shift;
    my $string = $self->{_dbix}->get_column('powersupplycard_name'). " with mac address ". $self->{_dbix}->get_column('powersupplycard_mac_address') . " and ip " .$self->{_dbix}->get_column('powersupplycard_ip');;
    return $string;
}

=head2 addPowerSupplyCard

Desc : This function insert a new power supply card in Kanopya
    args: 
        name : String : Power supply card name (SN or internal naming convention)
        mac_address : String : mac_address allow to use dhcp to configure power supply card network
        internalip : String : internal ip get from  $adm->getFreeInternalIP();
    optionals args:
        model_id : Int : Power supply model id
=cut

#sub addPowerSupplyCard{
#    my $self = shift;
#    my %args = @_;
#    if ((! exists $args{name} or ! defined $args{name}) ||
#        (! exists $args{mac_address} or ! defined $args{mac_address}) ||
#        (! exists $args{internalip} or ! defined $args{internalip})){
#        $errmsg = "Administrator->addPowerSupplyCard need a name, mac_Address and an internalip named argument!";
#        $log->error($errmsg);
#        throw Kanopya::Exception::Internal(error => $errmsg);
#    }
#    my $psc = {powersupplycard_name => $args{name},
#               powersupplycard_mac_address => $args{mac_address}};
#    $psc->{powersupply_ip} = $args{internalip}; #$self->getFreeInternalIP();
#
#    if (exists $args{model_id} and defined $args{model_id}) {
#        $psc->{powersupply_model_id} = $args{model_id};
#    }
#    $self->{db}->resultset('Powersupplycard')->create($psc);
#    return;    
#}

#sub getPowerSupplyCards{
#    my $self = shift;
#    my %args = @_;    
#    my $r = $self->{db}->resultset('Powersupplycard')->search(undef, { 
#        order_by => { -desc => [qw/powersupplycard_id/], }, 
#    });
#    my @arr = ();
#    while (my $row = $r->next) {
#        push @arr, { 
#            'NAME' => $row->get_column('powersupplycard_name'), 
#            'IP' => $row->get_column('powersupplycard_ip'), 
#            'MAC' => $row->get_column('powersupplycard_mac_address')
#        };
#    }
#    return @arr;
#}

#sub findPowerSupplyCard{
#    my $self = shift;
#    my %args = @_;
#    if ((! exists $args{powersupplycard_id} or ! defined $args{powersupplycard_id})){
#        $errmsg = "Administrator->findPowerSupplyCard need an id named argument!";
#        $log->error($errmsg);
#        throw Kanopya::Exception::Internal(error => $errmsg);
#    }
#    my $r = $self->{db}->resultset('Powersupplycard')->find($args{powersupplycard_id});
#    if(! $r){
#        $errmsg = "Administrator->findPowerSupplyCard can not find power supply card with id : $args{powersupplycard_id}";
#        $log->error($errmsg);
#        throw Kanopya::Exception::Internal(error => $errmsg);
#    }
#    my $psc = {'powersupplycard_name' => $r->get_column('powersupplycard_name'), 
#                'powersupplycard_ip' => $r->get_column('powersupplycard_ip'), 
#                'powersupplycard_mac_address' => $r->get_column('powersupplycard_mac_address')};
#    return $psc;
#}

sub getHostPort{
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['host_powersupply_id']);

    return $self->{_dbix}->powersupplies->find($args{host_powersupply_id})->get_column('powersupplyport_number');
}

sub addPowerSupplyPort {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['powersupplyport_number']);

    my $powersupply_schema = $self->{_dbix}->powersupplies;
    my $powersupply = $powersupply_schema->create({
                                powersupplycard_id => $self->getAttr(name=>"powersupplycard_id"),
                                powersupplyport_number => $args{powersupplyport_number}});
    
    return $powersupply->get_column('powersupply_id');
}

sub isPortUsed {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['powersupplyport_number']);

    my $psp = $self->{_dbix}->powersupplies->single({powersupplyport_number=>$args{powersupplyport_number}});
    if ($psp){
        return $psp->get_column("powersupply_id");
    }
    return;            
}

sub delPowerSupply {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['powersupply_id']);

    my $powersupply = $self->{_dbix}->powersupplies->find($args{powersupply_id})->delete();
}

sub getPowerSupply {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => ['powersupply_id']);

    my $row = $self->{db}->resultset('Powersupply')->find($args{powersupply_id});
    my $powersupply = { powersupplycard_id => $row->get_column('powersupplycard_id'),
                        powersupplyport_id => $row->get_column('powersupplyport_id')};
    return $powersupply;
}
1;
