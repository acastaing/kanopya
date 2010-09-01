package EEntity::EComponent::EExport::EIscsitarget1;

use strict;
use Date::Simple (':all');
use Log::Log4perl "get_logger";

use base "EEntity::EComponent::EExport";

my $log = get_logger("executor");
my $errmsg;

# contructor

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new( %args );
    return $self;
}

sub generateInitiatorname{
	my $self = shift;
	my %args  = @_;	

	if ((! exists $args{hostname} or ! defined $args{hostname})) { 
		$errmsg = "EEntity::EStorage::EIscsitarget1->generateInitiatorname need an hostname named argument to generate initiatorname!"; 
		$log->error($errmsg);
		throw Mcs::Exception::Internal(error => $errmsg);
	}
	my $today = today();
	my $res = "iqn." . $today->year . "-" . $today->format("%m") . ".com.hedera-technology." . $args{hostname};
	$log->info("InitiatorName generated is $res");
	return $res;
}
sub generateTargetname {
	my $self = shift;
	my %args  = @_;	
	
	if ((! exists $args{name} or ! defined $args{name})) { 
		throw Mcs::Exception::Internal(error => "EEntity::EStorage::EIscsitarget1->generateTargetname need a name and a type named argument to generate initiatorname!"); }
	my $today = today();
	my $res = "iqn." . $today->year . "-" . $today->format("%m") . ".com.hedera-technology.nas:$args{name}";
	$log->info("TargetName generated is $res");
	return $res;
}


sub addTarget {
	my $self = shift;
	my %args  = @_;	

	if ((! exists $args{iscsitarget1_target_name} or ! defined $args{iscsitarget1_target_name}) ||
		(! exists $args{mountpoint} or ! defined $args{mountpoint}) ||
		(! exists $args{mount_option} or ! defined $args{mount_option})) {
		$errmsg = "Component::Export::Iscsitarget1->addTarget needs a iscsitarget1_targetname and mountpoint named argument!";
		$log->error($errmsg);
		throw Mcs::Exception::Internal::IncorrectParam(error => $errmsg);
	}
#TODO add the real target addition in the iscitarget server
	return $self->_getEntity()->addTarget(%args);
}

sub reload {
	my $self = shift;

	$self->generateConf();

	
	$self->restart();
}

sub addLun {
	my $self = shift;
	my %args  = @_;	
#TODO add the real lun addition in the iscitarget server
	return $self->_getEntity()->addLun(%args);	
}

sub removeLun {
	my $self = shift;
	my %args  = @_;
	#TODO add the real lun remove in the iscitarget server
	return $self->_getEntity()->removeLun(%args);	
}

sub removeTarget{
	my $self = shift;
	my %args  = @_;	
	#TODO add the real target remove in the iscitarget server
	return $self->_getEntity()->removeTarget(%args);	
}

sub generateConf{
	
}
sub restart {
	
}

1;
