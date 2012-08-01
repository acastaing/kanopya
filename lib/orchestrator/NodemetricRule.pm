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
package NodemetricRule;

use strict;
use warnings;
use base 'BaseDB';
use Data::Dumper;
use Externalnode;
use NodemetricCondition;
use Entity::ServiceProvider;
use VerifiedNoderule;
use List::MoreUtils qw {any} ;
use Switch;
# logger
use Log::Log4perl "get_logger";
my $log = get_logger("orchestrator");

use constant ATTR_DEF => {
    nodemetric_rule_id        =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 0},
    nodemetric_rule_label     =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_rule_formula   =>  {pattern       => '^((id\d+)|and|or|not|[ ()!&|])+$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1,
                                 description    => "Construct a formula by condition's names with logical operators (and, or, not). It's possible to use parenthesis with spaces between each element of the formula. Press a letter key to obtain the available choice."},
    nodemetric_rule_last_eval =>  {pattern       => '^(0|1)$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_rule_timestamp =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_rule_state     =>  {pattern       => '(enabled|disabled|disabled_temp)$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_rule_service_provider_id =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    workflow_def_id           =>  {pattern       => '^.*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 1},
    nodemetric_rule_description =>  {pattern       => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
  return {
    'toString'              => {
      'description' => 'toString',
      'perm_holder' => 'entity'
    },
    'isVerifiedForANode'    => {
      'description' => 'isverifiedForANode',
      'perm_holder' => 'entity'
    }
  }
}

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(%args);
    if(!defined $args{nodemetric_rule_label} || $args{nodemetric_rule_label} eq ''){
        $self->setAttr(name=>'nodemetric_rule_label', value => $self->toString());
        $self->save();
    }
    # When enabled, set undef for each node (will be update next orchestrator loop) 
    if($self->getAttr('name' => 'nodemetric_rule_state') eq 'enabled'){
        $self->setUndefForEachNode();
    } 
    return $self;
}


sub setUndefForEachNode{
    my ($self) = @_;
    #ADD A ROW IN VERIFIED_NODERULE TABLE indicating undef data
#    my $extcluster = Entity::ServiceProvider::Outside::Externalcluster->get(
#                        'id' => $self->getAttr(name => 'nodemetric_rule_service_provider_id'),
#                     );
    my $service_provider = Entity::ServiceProvider->get(
                        'id' => $self->getAttr(name => 'nodemetric_rule_service_provider_id'),
                     );

    my $nodes = $service_provider->getNodes();

    foreach my $node (@$nodes) {
        $self->{_dbix}
        ->verified_noderules
        ->update_or_create({
            verified_noderule_externalnode_id    =>  $node->{'id'},
            verified_noderule_state              => 'undef',
        });
    }
}

sub toString{
    my ($self, %args) = @_;
    my $depth;
    if(defined $args{depth}) {
        $depth = $args{depth};
    }
    else {
        $depth = -1;
    }

    if($depth == 0) {
        return $self->getAttr(name => 'nodemetric_rule_label');
    }
    else{
        my $formula = $self->getAttr(name => 'nodemetric_rule_formula');
        my @array = split(/(id\d+)/,$formula);
        for my $element (@array) {
            if( $element =~ m/id(\d+)/)
            {
                $element = NodemetricCondition->get('id'=>substr($element,2))->toString(depth => $depth - 1);
            }
         }
         return "@array";
    }
};

#C/P of homonym method in AggregateRulePackage 
sub getDependantConditionIds {
    my $self = shift;
    my $formula = $self->getAttr(name => 'nodemetric_rule_formula');
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

sub evalOnOneNode{
    my $self = shift;
    my %args = @_;
    
    my $monitored_values_for_one_node = $args{monitored_values_for_one_node};
    
    my $formula = $self->getAttr(name => 'nodemetric_rule_formula');

    #Split nodemetric_rule id from $formula
    my @array = split(/(id\d+)/,$formula);
    
    #replace each id by its evaluation
    for my $element (@array) {
        
        if( $element =~ m/id(\d+)/){
            $element = NodemetricCondition->get('id'=>substr($element,2))
                                          ->evalOnOneNode(
                                            'monitored_values_for_one_node' => $monitored_values_for_one_node
                                          );
            if(not defined $element){
                return undef;
            }
           
        }
    }
    my $res = undef;
    my $arrayString = '$res = '."(@array)"; 

    $log->info("NM rule evaluation: $arrayString");
    #Evaluate the logic formula
    eval $arrayString;
    my $store = ($res)?1:0;
    return $res;
};

sub isVerifiedForANode{
    my $self = shift;
    my %args = @_;

    my $externalnode_id;
    if(defined $args{externalnode_hostname}){
        my $node = Externalnode->find(hash => {externalnode_hostname => $args{externalnode_hostname}});
       $externalnode_id = $node->getId(); 
    }
    else {
        $externalnode_id = $args{externalnode_id};
    }


    my $row = $self->{_dbix}
        ->verified_noderules
        ->find({
            verified_noderule_externalnode_id    => $externalnode_id,
        });

    if(defined $row){
        my $state = $row->verified_noderule_state;
        switch ($state){
            case 'verified'{
                return 1;
            }
            case 'undef'{
                return undef;
            }
        }
        return 1;
    }else{
        return 0;
    }

};

sub deleteVerifiedRule  {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => [ 'externalnode_id' ]);

    my $externalnode_id = $args{externalnode_id};

    my $verified_noderule;
    eval{
        $verified_noderule = VerifiedNoderule->find(hash=>{
            verified_noderule_externalnode_id    => $args{externalnode_id},
            verified_noderule_nodemetric_rule_id => $self->getId(),
        });
    };

    if (defined $verified_noderule) {
        $verified_noderule->delete();
    }
}

=head2 deleteVerifiedRuleWfDefId
    Desc: delete the workflow def id indication in verified_noderule table to indicate
          that the verified rule has no more running workflow

    Args: $hostname, $service_provider_id

    Return: $workflow_def_id or 0

=cut

sub deleteVerifiedRuleWfDefId {
    my ($self,%args) = @_;

    my $hostname            = $args{hostname};
    my $service_provider_id = $args{service_provider_id};
    my $rule_id             = $self->getAttr(name => 'nodemetric_rule_id');
    my $service_provider    = Entity::ServiceProvider->get('id' => $service_provider_id);
    my $nodes               = $service_provider->getNodes();
    my $node_id;

    foreach my $node (@$nodes) {
        if($node->{hostname} eq $hostname) {
            $node_id = $node->{id};
        }
    }

    if(not defined $node_id){
        my $errmsg = "unknown node $hostname in service provider $service_provider_id";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
    }
    else {
        my $verified_noderule = VerifiedNoderule->find(hash => {
                                    verified_noderule_externalnode_id    => $node_id,
                                    verified_noderule_nodemetric_rule_id => $rule_id
                                });
        $verified_noderule->setAttr(name => 'workflow_def_id', value => 'null');
        $verified_noderule->save();
    }
}

sub setVerifiedRule{
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'externalnode_id',
                                                       'state',
    ]);

    $self->{_dbix}
         ->verified_noderules
         ->update_or_create({
               verified_noderule_externalnode_id  => $args{externalnode_id},
               verified_noderule_state            => $args{state},
    });
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
        if( $element =~ m/id\d+/)
        {
            if (!(NodemetricCondition->search(hash => {'nodemetric_condition_id'=>substr($element,2)}))){
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

sub disable {
    my $self = shift;
    my $verified_rule_dbix = 
        $self->{_dbix}
        ->verified_noderules->delete_all;

    $self->setAttr(name => 'nodemetric_rule_state', value => 'disabled');
    $self->save();
};

sub enable {
    my $self = shift;
    $self->setUndefForEachNode();
    $self->setAttr(name => 'nodemetric_rule_state', value => 'enabled');
    $self->save();
}

sub setAllRulesUndefForANode{
    my (%args) = @_;
    
    General::checkParams(args => \%args, required => ['cluster_id', 'node_id']);
    
    my $cluster_id     = $args{cluster_id};
    my $node_id        = $args{node_id};
    
    my @nodemetric_rules = NodemetricRule->search(
                               hash => {
                                   nodemetric_rule_service_provider_id => $cluster_id,
                                   nodemetric_rule_state               => 'enabled',
                               },
                           );
    
    foreach my $nodemetric_rule (@nodemetric_rules){
        $nodemetric_rule->{_dbix}
            ->verified_noderules
            ->update_or_create({
                verified_noderule_externalnode_id    =>  $node_id,
                verified_noderule_state              => 'undef',
        });
    }
} 

1;
