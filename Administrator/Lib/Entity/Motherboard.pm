package Entity::Motherboard;

use strict;

use base "Entity";

# contructor 

sub getStruct{
	my $struct = {};
	return $struct;
}

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new( %args );

    return $self;
}

sub specific {
	print "\nje peux faire des trucs specifiques à motherboard!\n";
}

1;
