#    Copyright © 2012 Hedera Technology SAS
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
package AggregateCombination;

use strict;
use warnings;
use Data::Dumper;
use base 'BaseDB';
use Clustermetric;
use TimeData::RRDTimeData;
use Kanopya::Exceptions;
use List::Util qw {reduce};
use List::MoreUtils qw {any} ;
# logger
use Log::Log4perl "get_logger";
my $log = get_logger("orchestrator");

use constant ATTR_DEF => {
    aggregate_combination_id      =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 0},
    aggregate_combination_label     =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    aggregate_combination_service_provider_id => {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    aggregate_combination_formula =>  {pattern       => '^((id\d+)|[ .+*()-/]|\d)+$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1,
                                 description    => "Construct a formula by service metric's names with all mathematical operators. It's possible to use parenthesis with spaces between each element of the formula. Press a letter key to obtain the available choice."},
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
  return {
    'toString'  => {
      'description' => 'toString',
      'perm_holder' => 'entity'
    }
  }
}


sub new {
    my $class = shift;
    my %args = @_;

    my $formula = (\%args)->{aggregate_combination_formula};

    _verify($formula);
    my $self = $class->SUPER::new(%args);
    if(!defined $args{aggregate_combination_label} || $args{aggregate_combination_label} eq ''){
        $self->setAttr(name=>'aggregate_combination_label', value => $self->toString());
        $self->save();
    }
    return $self;
}

sub _verify {

    my $formula = shift;

    my @array = split(/(id\d+)/,$formula);

    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            if (!(Clustermetric->search(hash => {'clustermetric_id'=>substr($element,2)}))){
             my $errmsg = "Creating combination formula with an unknown clusterMetric id ($element) ";
             $log->error($errmsg);
             throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
            }
        }
    }
}


=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my ($self, %args) = @_;
    my $depth;
    if(defined $args{depth}) {
        $depth = $args{depth};
    }
    else {
        $depth = -1;
    }
    
    if ($depth == 0) {
        return $self->getAttr(name => 'aggregate_combination_label');
    }
    else {
        my $formula = $self->getAttr(name => 'aggregate_combination_formula');

        # Split aggregate_rule id from $formula
        my @array = split(/(id\d+)/, $formula);
        # replace each rule id by its evaluation
        for my $element (@array) {
            if( $element =~ m/id\d+/)
            {
                # Remove "id" from the begining of $element, get the corresponding aggregator and get the lastValueFromDB
                $element = Clustermetric->get('id'=>substr($element,2))->toString(depth => $depth - 1);
            }
        }
        return List::Util::reduce { $a . $b } @array;
    }
}

sub computeValues{
    my $self = shift;
    my %args = @_;

    General::checkParams args => \%args, required => ['start_time','stop_time'];

    my @cm_ids = $self->dependantClusterMetricIds();
    my %allTheCMValues;
    foreach my $cm_id (@cm_ids){
        my $cm = Clustermetric->get('id' => $cm_id);
        $allTheCMValues{$cm_id} = $cm -> getValuesFromDB(%args);
    }
    return $self->computeFromArrays(%allTheCMValues);
}

sub computeLastValue{
    my $self = shift;

    my $formula = $self->getAttr(name => 'aggregate_combination_formula');

    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            #Remove "id" from the begining of $element, get the corresponding aggregator and get the lastValueFromDB
            $element = Clustermetric->get('id'=>substr($element,2))->getLastValueFromDB();
            if(not defined $element){
                return undef;
            }
        }
     }

    my $res = undef;
    my $arrayString = '$res = '."@array";


    #Evaluate the logic formula
    #print 'Evaluate combination :'.($self->toString())."\n";
    #$log->info('Evaluate combination :'.($self->toString()));
    eval $arrayString;
    # print "$arrayString = ";
    $log->info("$arrayString");
    return $res;
}

sub compute{
    my $self = shift;
    my %args = @_;

    my @requiredArgs = $self->dependantClusterMetricIds();

    checkMissingParams(args => \%args, required => \@requiredArgs);

    foreach my $cm_id (@requiredArgs){
        if( ! defined $args{$cm_id}){
            return undef;
        }
    }

    my $formula = $self->getAttr(name => 'aggregate_combination_formula');

    # print Dumper \%args;

    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            $element = $args{substr($element,2)};
            if (!defined $element){
                return undef;
            }
        }
     }

    my $res = undef;
    my $arrayString = '$res = '."@array";

    #Evaluate the logic formula
    #print 'Evaluate combination :'.($self->toString())."\n";
    #$log->info('Evaluate combination :'.($self->toString()));
    eval $arrayString;
    # print "$arrayString = $res\n";
    $log->info("$arrayString");
    return $res;
}
#sub getDependantClusterMetric() {
#   my $self = shift;
#   my @ids = dependantClusterMetricIds();
#   my @rep;
#   foreach my $id (@ids){
#       push @rep,Clustermetric->get('id' => $id);
#   }
#   return @rep;
#};


sub dependantClusterMetricIds() {
    my $self = shift;
    my $formula = $self->getAttr(name => 'aggregate_combination_formula');

    my @clusterMetricsList;

    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);

    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            push @clusterMetricsList, substr($element,2);
        }
     }
     return @clusterMetricsList;
}

# Remove duplicate from an array, return array without doublons
sub uniq {
    return keys %{{ map { $_ => 1 } @_ }};
}

sub computeFromArrays{
    my $self = shift;
    my %args = @_;

    # print Dumper \%args;

    my @requiredArgs = $self->dependantClusterMetricIds();

#    print "******* @requiredArgs \n";
#    print Dumper \%args;

    General::checkParams args => \%args, required => \@requiredArgs;

    #Merge all the timestamps keys in one arrays

    my @timestamps;
    foreach my $cm_id (@requiredArgs){
       @timestamps = (@timestamps, (keys %{$args{$cm_id}}));
    }
    @timestamps = uniq @timestamps;

    # print " @timestamps \n";
    my %rep;
    foreach my $timestamp (@timestamps){
        my %valuesForATimeStamp;
        foreach my $cm_id (@requiredArgs){
            $valuesForATimeStamp{$cm_id} = $args{$cm_id}->{$timestamp};
        }
        # print Dumper \%valuesForATimeStamp;
        $rep{$timestamp} = $self->compute(%valuesForATimeStamp);
    }
    # print Dumper \%rep;
    return %rep;
}

sub checkMissingParams {
    my %args = @_;

    my $caller_args = $args{args};
    my $required = $args{required};
    my $caller_sub_name = (caller(1))[3];

    for my $param (@$required) {
        if (! exists $caller_args->{$param} ) {
            my $errmsg = "$caller_sub_name needs a '$param' named argument!";

            # Log in general logger
            # TODO log in the logger corresponding to caller package;
            $log->error($errmsg);
            # print "$caller_sub_name : $errmsg \n";
            throw Kanopya::Exception::Internal::IncorrectParam();
        }
    }
}

sub useClusterMetric {
    my $self = shift;
    my $clustermetric_id = shift;

    my @dep_cm = $self->dependantClusterMetricIds();
    my $rep = any {$_ eq $clustermetric_id} @dep_cm;
    return $rep;
}

sub getAllTheCombinationsRelativeToAClusterId{
    my $class      = shift;
    my $cluster_id = shift;

    my @combinations = $class->search(hash => {});
    my @rep;

    COMBINATION:
    foreach my $combination (@combinations) {
        my @dependantClusterMetricIds = $combination->dependantClusterMetricIds();

        foreach my $cm_id (@dependantClusterMetricIds){
            my $clustermetric = Clustermetric->get('id' => $cm_id);
            if($clustermetric->getAttr(name => 'clustermetric_service_provider_id') eq $cluster_id)
            {
                push @rep, $combination;
                next COMBINATION;
            }
        }
    }

    return @rep;
}

1;
