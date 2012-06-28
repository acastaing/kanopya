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
package AggregateRule;

use strict;
use warnings;
use TimeData::RRDTimeData;
use base 'BaseDB';
use AggregateCondition;
use Data::Dumper;
use Switch;
use List::Util qw {reduce};
use List::MoreUtils qw {any} ;

# logger
use Log::Log4perl "get_logger";
my $log = get_logger("orchestrator");

use constant ATTR_DEF => {
    aggregate_rule_id          =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 0},
    aggregate_rule_label       =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    aggregate_rule_service_provider_id =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    aggregate_rule_formula     =>  {pattern       => '^((id\d+)|and|AND|or|OR|not|NOT|[ ()!&|])+$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1,
                                 description    => "Construct a formula by condition's names with AND, OR and NOT keywords. It's possible to use parenthesis with spaces between each element of the formula. Press a letter key to obtain the availalbe choice."},
    aggregate_rule_last_eval   =>  {pattern       => '^(0|1)$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    aggregate_rule_timestamp   =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    aggregate_rule_state       =>  {pattern       => '(enabled|disabled|disabled_temp|triggered)$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    workflow_def_id            =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    aggregate_rule_description =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
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
    
    my $formula = (\%args)->{aggregate_rule_formula};
    
    _verify($formula);
    my $self = $class->SUPER::new(%args);

    if((!defined $args{aggregate_rule_label}) || $args{aggregate_rule_label} eq ''){
        $self->setAttr(name=>'aggregate_rule_label', value => $self->toString());
        $self->save();
    }
    return $self;
}

sub setLabel{
    my ($self,%args) = @_;
    if((!defined $args{label}) || $args{label} eq ''){
        $self->setAttr(name=>'aggregate_rule_label', value => $self->toString());
    }else{
        $self->setAttr(name=>'aggregate_rule_label', value => $args{label});
    }
    $self->save();
}

sub _verify {

    my $formula = shift;
    
    my @array = split(/(id\d+)/,$formula);

    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            if (!(AggregateCondition->search(hash => {'aggregate_condition_id'=>substr($element,2)}))){
             my $errmsg = "Creating rule formula with an unknown aggregate condition id ($element) ";
             $log->error($errmsg);
             throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
            }
        }
    }
}

sub toString(){
    my ($self, %args) = @_;
    my $depth;
    if(defined $args{depth}) {
        $depth = $args{depth};
    }
    else {
        $depth = -1;
    }

    if($depth == 0) {
        return $self->getAttr(name => 'aggregate_rule_label');
    }
    else{

       my $formula = $self->getAttr(name => 'aggregate_rule_formula');
        my @array = split(/(id\d+)/,$formula);
        for my $element (@array) {

            if( $element =~ m/id(\d+)/)
            {
                $element = AggregateCondition->get('id'=>substr($element,2))->toString(depth => $depth - 1);
            }
         }
         return "@array";
    }     #return List::Util::reduce {$a.$b} @array;
}


sub eval {
    my $self = shift;
    
    my $formula = $self->getAttr(name => 'aggregate_rule_formula');
    
    #Split aggregate_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    
    #replace each rule id by its evaluation
    for my $element (@array) {
        
        if( $element =~ m/id(\d+)/)
        {
            $element = AggregateCondition->get('id'=>substr($element,2))->eval();
            if( !defined $element) {
                return undef;
            }
        }
     }
    
    
    
    my $res = -1;
    my $arrayString = '$res = '."@array"; 
    
    #Evaluate the logic formula
    eval $arrayString;
    
    if (defined $res){
        my $store = ($res)?1:0;
        $self->setAttr(name => 'aggregate_rule_last_eval',value=>$store);
        $self->setAttr(name => 'aggregate_rule_timestamp',value=>time());
        $self->save();
        return $store;
    } else {
        $self->setAttr(name => 'aggregate_rule_last_eval',value=>undef);
        $self->setAttr(name => 'aggregate_rule_timestamp',value=>time());
        $self->save();
        return undef;
    }

    
}


sub enable(){
    my $self = shift;
    $self->setAttr(name => 'aggregate_rule_state', value => 'enabled');
    #$self->setAttr(name => 'aggregate_rule_timestamp', value => time());
    $self->setAttr(name => 'aggregate_rule_last_eval', value => undef);
    $self->save();
}

sub disable(){
    my $self = shift;
    $self->setAttr(name => 'aggregate_rule_state', value => 'disabled');
    #$self->setAttr(name => 'aggregate_rule_timestamp', value => time());
    $self->save();
}

sub disableTemporarily(){
    my $self = shift;
    my %args = @_;
    General::checkParams args => \%args, required => ['length'];
    
    my $length = $args{length};
        
    $self->setAttr(name => 'aggregate_rule_state', value => 'disabled_temp');
    $self->setAttr(name => 'aggregate_rule_timestamp', value => time() + $length);
    $self->save();
}

sub isEnabled(){
    my $self = shift;
    #$self->updateState();
    return ($self->getAttr(name=>'aggregate_rule_state') eq 'enabled'); 
}

sub getRules() {
    my $class = shift;
    my %args = @_;

    my $state               = $args{'state'};
    my $service_provider_id = $args{'service_provider_id'};
    
    my @rules;
    if (defined $service_provider_id) {
        @rules = AggregateRule->search(hash => {'aggregate_rule_service_provider_id' => $service_provider_id});
    } else {
        @rules = AggregateRule->search(hash => {});
    }
    
    
    switch ($state){
        case "all"{
            return @rules; #All THE rules
        } 
        else {
            my @rep;
            foreach my $rule (@rules){
                #update state and return $rule only if state is corresponding
                #$rule->updateState();
                
                if($rule->getAttr(name=>'aggregate_rule_state') eq $state){
                    push @rep, $rule;
                }
            }
            return @rep;
        }
    }
}

sub updateState() {
    my $self = shift;
    
    if ($self->getAttr(name=>'aggregate_rule_state') eq 'disabled_temp') {
        if( $self->getAttr(name => 'aggregate_rule_timestamp') le time()) {
            $self->setAttr(name => 'aggregate_rule_timestamp', value => time());
            $self->setAttr(name => 'aggregate_rule_state'    , value => 'enabled');
            $self->save();
        }
    }
}

sub getDependantConditionIds {
    my $self = shift;
    my $formula = $self->getAttr(name => 'aggregate_rule_formula');
    my @array = split(/(id\d+)/,$formula);
    
    my @conditionIds;
    
    for my $element (@array) {
        if( $element =~ m/id\d+/)
        {
            push @conditionIds, substr($element,2);
        }
    }
    return @conditionIds;
}


sub isCombinationDependant{
    my $self         = shift;
    my $condition_id = shift;
    
    my @dep_cond_id = $self->getDependantConditionIds();
    my $rep = any {$_ eq $condition_id} @dep_cond_id;
    return $rep;
}

sub checkFormula {
    my $class = shift;
    my %args = @_;
    
    my $formula = (\%args)->{formula};
    
    my @array = split(/(id\d+)/,$formula);;

    for my $element (@array) {
        if( $element =~ m/id\d+/){
            if (!(AggregateCondition->search(hash => {'aggregate_condition_id'=>substr($element,2)}))){
                return {
                    value     => '0',
                    attribute => substr($element,2),
                };
            }
        }
    }
    return {
        value     => '1',
    };
}

sub setAttr {
    my $class = shift;
    my %args = @_;
    if ($args{name} eq 'aggregate_rule_formula'){
        _verify($args{value});
    }   
    my $self = $class->SUPER::setAttr(%args);
};

1;
