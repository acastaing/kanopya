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
package NodemetricCombination;

use strict;
use warnings;
use base 'BaseDB';
use Indicator;
use Data::Dumper;
# logger
use Log::Log4perl "get_logger";
my $log = get_logger("orchestrator");

use constant ATTR_DEF => {
    nodemetric_combination_id      =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 0},
    nodemetric_combination_label     =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_combination_service_provider_id =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_combination_formula =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
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
    my $self = $class->SUPER::new(%args);
    if(!defined $args{nodemetric_combination_label} || $args{nodemetric_combination_label} eq ''){
        $self->setAttr(name=>'nodemetric_combination_label', value => $self->toString());
        $self->save();
    }
    return $self;
}

=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my $self = shift;

    my $formula             = $self->getAttr(name => 'nodemetric_combination_formula');
    my $service_provider_id = $self->getAttr(name => 'nodemetric_combination_service_provider_id');
    my $service_provider    = Entity::ServiceProvider->find (
        hash => { service_provider_id => $service_provider_id
        }
    );
    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            #Remove "id" from the begining of $element, get the corresponding aggregator and get the lastValueFromDB
            $element = $service_provider->getIndicatorNameFromId (indicator_id => substr($element,2));
        }
    }
    return "@array";
}

# C/P of homonym method of AggregateCombination
sub getDependantIndicatorIds{
    my $self = shift;
    my $formula = $self->getAttr(name => 'nodemetric_combination_formula');
    
    my @indicator_ids;
    
    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    
    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            push @indicator_ids, substr($element,2);
        }
     }
     return @indicator_ids;
}



=head2 computeValueFromMonitoredValues

    desc: Compute Node Combination Value with the formula from given Indicator values 

=cut
sub computeValueFromMonitoredValues {
    my $self = shift;
    my %args = @_;

    my $monitored_values_for_one_node = $args{monitored_values_for_one_node};
    my $service_provider_id = $self->getAttr(name => 'nodemetric_combination_service_provider_id');

    my $service_provider = Entity::ServiceProvider->find (
        hash => { service_provider_id => $service_provider_id
        }
    );

    my $formula = $self->getAttr(name => 'nodemetric_combination_formula');

    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);

    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            #Remove "id" from the begining of $element, get the corresponding aggregator and get the lastValueFromDB
            my $indicator_id  = substr($element,2);
            my $indicator_oid = $service_provider->getIndicatorOidFromId(indicator_id => $indicator_id);

            # Replace $element by its value
            $element          = $monitored_values_for_one_node->{$indicator_oid};

            if(not defined $element){
                return undef;
            }
        }
     }

    my $res = -1;
    my $arrayString = '$res = '."@array"; 
    #print $arrayString."\n";

    #Evaluate the logic formula
    eval $arrayString;

    $log->info("NM Combination value = $arrayString");
    return $res;
}



sub checkFormula{
    my ($class, %args) = @_;

    my $formula = $args{formula};
    my $service_provider_id = $args{service_provider_id};

    my $service_provider = Entity::ServiceProvider->find (
        hash => { service_provider_id => $service_provider_id
        }
    );
    my $indicators_ids = $service_provider->getIndicatorsIds();

    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    
    my @unkownIds;
    #replace each rule id by its evaluation
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {   
            #Check if element is a SCOM indicator
            my $indicator_id = substr($element,2);
            if (not (grep {$_ eq $indicator_id} @$indicators_ids)) {
                push @unkownIds, $indicator_id;
            }
        }
    }
    return @unkownIds;
}
1;





