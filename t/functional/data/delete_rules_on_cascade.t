#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;
use Data::Dumper;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({level=>'DEBUG', file=>'delete_rule.log', layout=>'%F %L %p %m%n'});
my $log = get_logger("");

use BaseDB;
use Entity::ServiceProvider::Externalcluster;
use Entity::Component::MockMonitor;
use Entity::Indicator;
use Entity::CollectorIndicator;
use Node;
use Entity::Combination::NodemetricCombination;
use Entity::NodemetricCondition;
use Entity::Rule::NodemetricRule;
use VerifiedNoderule;
use WorkflowNoderule;
use Entity::Clustermetric;
use Entity::AggregateCondition;
use Entity::Combination::AggregateCombination;
use Kanopya::Tools::TestUtils 'expectedException';

BaseDB->authenticate( login =>'admin', password => 'K4n0pY4' );

my $indicator_deleted;
my $indicator_other;
my $service_provider;
my $external_cluster_mockmonitor;
my $cmd;
my $cm2;
my $cm3;
my $ac3;
my $acd2;
my $acd1;
my $acombd1;
my $acombd2;
my $acomb3;
my $rule1d;
my $rule2d;
my $rule3d;
my $rule4;
my $ncombd1;
my $ncombd2;
my $ncomb3;
my $ncd1;
my $ncd2;
my $ncd3;
my $nc3;
my $nrule1d;
my $nrule2d;
my $nrule3d;
my $nrule4;

my $testing = 0;

main ();

sub main {

    if ($testing == 1) {
        BaseDB->beginTransaction;
    }

    $service_provider = Entity::ServiceProvider::Externalcluster->new(
            externalcluster_name => 'Test Service Provider',
    );

    $external_cluster_mockmonitor = Entity::ServiceProvider::Externalcluster->new(
            externalcluster_name => 'Test Monitor',
    );

    my $mock_monitor = Entity::Component::MockMonitor->new(
            service_provider_id => $external_cluster_mockmonitor->id,
    );

    $service_provider->addManager(
        manager_id   => $mock_monitor->id,
        manager_type => 'CollectorManager',
    );

    # Create one node
    my $node = Node->new(
        node_hostname => 'test_node',
        service_provider_id   => $service_provider->id,
        monitoring_state    => 'up',
    );

    $indicator_deleted = Entity::CollectorIndicator->find(
                            hash => {
                                collector_manager_id        => $mock_monitor->id,
                                'indicator.indicator_oid'   => 'Memory/PercentMemoryUsed'
                            }
                        );

    $indicator_other = Entity::CollectorIndicator->find(
                            hash => {
                                collector_manager_id        => $mock_monitor->id,
                                'indicator.indicator_oid'   => 'Memory/Pool Paged Bytes'
                            }
                        );

    _service_rule_objects_creation();
    _node_rule_objects_creation();

    lives_ok {
        Entity::Indicator->find(hash => {indicator_oid => $indicator_deleted->indicator->indicator_oid})->delete();

        expectedException {
            Entity::Clustermetric->get(id => $cmd->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error Clustermetric not deleted';

        expectedException {
            Entity::Combination::AggregateCombination->get(id => $acombd1->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateCombination not deleted';

        expectedException {
            Entity::Combination::AggregateCombination->get(id => $acombd2->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateCombination not deleted';

        expectedException {
            Entity::AggregateCondition->get(id => $acd1->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateCondition not deleted';

        expectedException {
            Entity::AggregateCondition->get(id => $acd2->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateCondition not deleted';

        expectedException {
            Entity::Combination::ConstantCombination->get(id => $acd1->right_combination_id)
        } 'Kanopya::Exception::Internal::NotFound', 'Error ConstantCombination not deleted';

        expectedException {
            Entity::Combination::ConstantCombination->get(id => $acd2->right_combination_id)
        } 'Kanopya::Exception::Internal::NotFound', 'Error ConstantCombination not deleted';

        expectedException {
            Entity::Rule::AggregateRule->get(id => $rule1d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateRule not deleted';

        expectedException {
            Entity::Rule::AggregateRule->get(id => $rule2d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateRule not deleted';

        expectedException {
            Entity::Rule::AggregateRule->get(id => $rule3d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error AggregateRule not deleted';

        expectedException {
            Entity::Combination->get(id => $ncombd1->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricCombination not deleted';

        expectedException {
            Entity::Combination->get(id => $ncombd2->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricCombination not deleted';

        expectedException {
            Entity::NodemetricCondition->get(id => $ncd1->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricCondition not deleted';

        expectedException {
            Entity::NodemetricCondition->get(id => $ncd2->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricCondition not deleted';

        $ncd1->left_combination_id;
        $ncd1->right_combination_id;

        expectedException {
            Entity::Combination->get(id => $ncd1->left_combination_id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error left combination not deleted';

        expectedException {
            Entity::Combination->get(id => $ncd1->right_combination_id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error right combination not deleted';


        $ncd2->left_combination_id;
        $ncd2->right_combination_id;

        expectedException {
            Entity::Combination->get(id => $ncd2->left_combination_id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error  left combination not deleted';

        expectedException {
            Entity::Combination->get(id => $ncd2->right_combination_id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error right combination not deleted';

        expectedException {
            Entity::Rule::NodemetricRule->get(id => $nrule1d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricRule not deleted';

        expectedException {
            Entity::Rule::NodemetricRule->get(id => $nrule2d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricRule not deleted';

        expectedException {
            Entity::Rule::NodemetricRule->get(id => $nrule3d->id);
        } 'Kanopya::Exception::Internal::NotFound', 'Error NodemetricRule not deleted';

        Entity::Clustermetric->get(id => $cm2->id);
        Entity::Clustermetric->get(id => $cm3->id);
        Entity::Combination->get(id => $acomb3->id);
        Entity::AggregateCondition->get(id => $ac3->id);
        Entity::Rule::AggregateRule->get(id => $rule4->id);
        Entity::Combination->get(id => $ncomb3->id);
        Entity::Combination->get(id => Entity::NodemetricCondition->get(id => $nc3->id)->left_combination_id);
        Entity::Combination->get(id => Entity::NodemetricCondition->get(id => $nc3->id)->right_combination_id);
        Entity::Rule::NodemetricRule->get(id => $nrule4->id);

    } 'Delete indicator on cascade';

    test_rrd_remove();

    Entity::Indicator->new(
        indicator_label => 'RAM used',
        indicator_name => 'RAM used',
        indicator_oid => 'Memory/PercentMemoryUsed',
        indicator_color => 'FF000099',
        indicatorset_id => 5,
        indicator_unit => '%'
    );

    if ($testing == 1) {
        BaseDB->rollbackTransaction;
    }
}

sub test_rrd_remove {
    my @cms = Entity::Clustermetric->search (hash => {
        clustermetric_service_provider_id => $service_provider->id
    });

    my @cm_ids = map {$_->id} @cms;
    while (@cms) { (pop @cms)->delete(); };

    my @acs = Entity::Combination::AggregateCombination->search (hash => {
        service_provider_id => $service_provider->id
    });

    if ((scalar @acs) != 0) { die 'Error in all aggregate combinations are deleted';}

    my @ars = Entity::Rule::AggregateRule->search (hash => {
        service_provider_id => $service_provider->id
    });
    
    if ((scalar @acs) != 0) {die 'Error in all aggregate rules are deleted'; }

    my $one_rrd_remove = 0;
    for my $cm_id (@cm_ids) {
        if (defined open(FILE,'/var/cache/kanopya/monitor/timeDB_'.$cm_id.'.rrd')) {
            $one_rrd_remove++;
        }
        close(FILE);
    }
    if ($one_rrd_remove != 0) { die "Error in check all have been removed, still $one_rrd_remove rrd";}
    $service_provider->delete();
    $external_cluster_mockmonitor->delete();
}

sub _service_rule_objects_creation {

    $cmd = Entity::Clustermetric->new(
        clustermetric_service_provider_id => $service_provider->id,
        clustermetric_indicator_id => ($indicator_deleted->id),
        clustermetric_statistics_function_name => 'mean',
        clustermetric_window_time => '1200',
    );

    $cm2 = Entity::Clustermetric->new(
        clustermetric_service_provider_id => $service_provider->id,
        clustermetric_indicator_id => ($indicator_other->id),
        clustermetric_statistics_function_name => 'mean',
        clustermetric_window_time => '1200',
    );

    $cm3 = Entity::Clustermetric->new(
        clustermetric_service_provider_id => $service_provider->id,
        clustermetric_indicator_id => ($indicator_other->id),
        clustermetric_statistics_function_name => 'std',
        clustermetric_window_time => '1200',
    );

    $acombd1 = Entity::Combination::AggregateCombination->new(
        service_provider_id             =>  $service_provider->id,
        aggregate_combination_formula   => 'id'.($cmd->id).' + id'.($cm2->id),
    );

    $acombd2 = Entity::Combination::AggregateCombination->new(
        service_provider_id             =>  $service_provider->id,
        aggregate_combination_formula   => 'id'.($cm3->id).' - id'.($cmd->id),
    );

    $acomb3 = Entity::Combination::AggregateCombination->new(
        service_provider_id             =>  $service_provider->id,
        aggregate_combination_formula   => 'id'.($cm2->id).' + id'.($cm3->id),
    );

    $acd1 = Entity::AggregateCondition->new(
        aggregate_condition_service_provider_id => $service_provider->id,
        left_combination_id => $acombd1->id,
        comparator => '>',
        threshold => '0',
    );

    Entity::Combination::ConstantCombination->get(id => $acd1->right_combination_id);

    $acd2 = Entity::AggregateCondition->new(
        aggregate_condition_service_provider_id => $service_provider->id,
        left_combination_id => $acombd2->id,
        comparator => '<',
        threshold => '0',
    );

    Entity::Combination::ConstantCombination->get(id => $acd2->right_combination_id);

    $ac3 = Entity::AggregateCondition->new(
        aggregate_condition_service_provider_id => $service_provider->id,
        left_combination_id => $acomb3->id,
        comparator => '<',
        threshold => '0',
    );

    $rule1d = Entity::Rule::AggregateRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$acd1->id.' && id'.$acd2->id,
        state => 'enabled'
    );

    $rule2d = Entity::Rule::AggregateRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$ac3->id.' || id'.$acd2->id,
        state => 'enabled'
    );

    $rule3d = Entity::Rule::AggregateRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$acd2->id.' && id'.$ac3->id,
        state => 'enabled'
    );

    $rule4 = Entity::Rule::AggregateRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$ac3->id.' || id'.$ac3->id,
        state => 'enabled'
    );

}



sub _node_rule_objects_creation {
    my $rule1;
    my $rule2;

    # Create nodemetric rule objects
    $ncombd1 = Entity::Combination::NodemetricCombination->new(
        service_provider_id             => $service_provider->id,
        nodemetric_combination_formula  => 'id'.($indicator_deleted->id).' + id'.($indicator_other->id),
    );

    $ncombd2 = Entity::Combination::NodemetricCombination->new(
        service_provider_id             => $service_provider->id,
        nodemetric_combination_formula  => 'id'.($indicator_other->id).' + id'.($indicator_deleted->id),
    );

    $ncomb3 = Entity::Combination::NodemetricCombination->new(
        service_provider_id             => $service_provider->id,
        nodemetric_combination_formula  => 'id'.($indicator_other->id).' + id'.($indicator_other->id),
    );

    $ncd1 = Entity::NodemetricCondition->new(
        nodemetric_condition_service_provider_id => $service_provider->id,
        left_combination_id => $ncombd1->id,
        nodemetric_condition_comparator => '>',
        nodemetric_condition_threshold => '0',
    );

    $ncd2 = Entity::NodemetricCondition->new(
        nodemetric_condition_service_provider_id => $service_provider->id,
        left_combination_id => $ncombd2->id,
        nodemetric_condition_comparator => '<',
        nodemetric_condition_threshold => '0',
    );

    $nc3 = Entity::NodemetricCondition->new(
        nodemetric_condition_service_provider_id => $service_provider->id,
        left_combination_id => $ncomb3->id,
        nodemetric_condition_comparator => '>',
        nodemetric_condition_threshold => '0',
    );

    $nrule1d = Entity::Rule::NodemetricRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$ncd1->id.' && id'.$ncd2->id,
        state => 'enabled'
    );

    $nrule2d = Entity::Rule::NodemetricRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$ncd1->id.' || id'.$nc3->id,
        state => 'enabled'
    );

    $nrule3d = Entity::Rule::NodemetricRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$nc3->id.' || id'.$ncd2->id,
        state => 'enabled'
    );

    $nrule4 = Entity::Rule::NodemetricRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$nc3->id.' || id'.$nc3->id,
        state => 'enabled'
    );
}

