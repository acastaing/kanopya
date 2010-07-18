package Entity::Operation;

use strict;

use base "Entity";

# contructor 

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new( %args );
    return $self;
}

# delete related parameters
sub delete {
	my $self = shift;

	my $params_rs = $self->{_data}->operation_parameters;
	$params_rs->delete;
	
	$self->SUPER::delete( );	
}

sub addParams {
	my $self = shift;
	my ($params) = @_;	
	my $data = $self->{_data};
	
	# create_related will automatically insert _data in db
	# we don't want this behaviour
	# TODO comprendre comment marche le new_related (et ensuite accéder aux related data, ajouter dans la base, cascade_update...)
	if ( ! $self->{_data}->in_storage ) {
		die "Error: Please save your Operation before call addParams";
	}
	
	foreach my $k (keys %$params) {
			$data->create_related( 'operation_parameters', { name => $k, value => $params->{$k} } );
	}
	return 0;
}

# return a hash ref { p1 => v1, p2 => v2, ...}
sub getParams {
	my $self = shift;
	
	my %params = ();
	my $params_rs = $self->{_data}->operation_parameters;
#	my $params_rs = $self->getValue(name => "operation_parameters");
	
	while ( my $param = $params_rs->next ) {
		$params{ $param->name } = $param->value;
	}
	return \%params;
}

sub getUser {
	my $self = shift;
	return $self->getValue(name => "user_id");
}

# getParamValue( param_name ) : param_value
sub getParamValue {
	my $self = shift;
	my ($param_name) = @_;
	my $params_rs = $self->{_data}->operation_parameters;
	
	my $param = $params_rs->search( { name => $param_name } )->next;
	return $param->value;
}

1;
