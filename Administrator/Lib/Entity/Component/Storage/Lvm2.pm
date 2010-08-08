package Entity::Component::Storage::Lvm2;

use strict;

use base "Entity::Component::Storage";
use Log::Log4perl "get_logger";
my $log = get_logger("administrator");
# contructor

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new( %args );
    return $self;
}

sub getMainVg{
	my $self = shift;
	my $vgname = $self->{_dbix}->lvm2_vgs->single->get_column('lvm2_vg_name');
	my $vgid = $self->{_dbix}->lvm2_vgs->single->get_column('lvm2_vg_id');
	$log->debug("Main VG founds, its id is <$vgid>");
	#TODO getMainVg, return id or name ?
	return {vgid => $vgid, vgname =>$vgname};
}

sub lvCreate{
	my $self = shift;
	my %args = @_;
	
	if ((! exists $args{lvm2_lv_name} or ! defined $args{lvm2_lv_name}) ||
		(! exists $args{lvm2_lv_size} or ! defined $args{lvm2_lv_size}) ||
		(! exists $args{lvm2_lv_filesystem} or ! defined $args{lvm2_lv_filesystem}) ||
		(! exists $args{lvm2_vg_id} or ! defined $args{lvm2_vg_id})) { 
		throw Mcs::Exception::Internal::IncorrectParam(error => "Lvm2->LvCreate need a lvm2_lv_name, lvm2_lv_size, lvm2_vg_id and lvm2_lv_filesystem named argument!"); }
# ICI Recuperer le bon vg et ensuite suivre le lien lv et new dedans
	$log->debug("lvm2_lv_name is $args{lvm2_lv_name}, lvm2_lv_size is $args{lvm2_lv_size}, lvm2_lv_filesystem is $args{lvm2_lv_filesystem}, lvm2_vg_id is $args{lvm2_vg_id}");
	my $lv_rs = $self->{_dbix}->lvm2_vgs->single( {lvm2_vg_id => $args{lvm2_vg_id}})->lvm2_lvs;
	$lv_rs->create(\%args);
}

sub lvRemove{
	my $self = shift;
	my %args = @_;
	
	if ((! exists $args{lvm2_lv_name} or ! defined $args{lvm2_lv_name}) ||
		(! exists $args{lvm2_vg_id} or ! defined $args{lvm2_vg_id})) { 
		throw Mcs::Exception::Internal::IncorrectParam(error => "Lvm2->LvRemove need a lvm2_lv_name, lvm2_lv_size, lvm2_vg_id and lvm2_lv_filesystem named argument!"); }
# ICI Recuperer le bon vg et ensuite suivre le lien lv et new dedans
	$log->debug("lvm2_lv_name is $args{lvm2_lv_name}, lvm2_vg_id is $args{lvm2_vg_id}");
	my $lv_row = $self->{_dbix}->lvm2_vgs->single( {lvm2_vg_id => $args{lvm2_vg_id}})->lvm2_lvs->single({lvm2_lv_name => $args{lvm2_lv_name}});
	$lv_row->delete();
}

1;
