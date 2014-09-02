#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

TODO

=cut

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;

use File::Basename;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level  => 'DEBUG',
    file   => basename(__FILE__).'.log',
    layout => '%F %L %p %m%n'
});
my $log = get_logger("");

use Kanopya::Database;
use Daemon::RulesEngine;
use Daemon::Aggregator;
use Entity::ServiceProvider::Externalcluster;
use Entity::Component::MockMonitor;
use Entity::NodemetricCondition;
use Entity::Rule::NodemetricRule;
use Entity::Metric::Clustermetric;
use Entity::Metric::Combination::AggregateCombination;
use Entity::Metric::Combination::NodemetricCombination;
use VerifiedNoderule;
use Entity::Node;

use Kanopya::Tools::TestUtils 'expectedException';

use String::Random;
my $random = String::Random->new;

my $postfix = $random->randpattern("nnCccCCnnncCCnncnCCn");

my $testing = 1;
my $acomb1;
my $nrule1;
my $service_provider;
my $aggregator;
my $mock_monitor;
my $ind_oid = '.1.3.6.1.4.1.2021.4.5.0';
main();

sub main {
    Kanopya::Database::authenticate( login =>'admin', password => 'K4n0pY4' );

    if($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    # Delete unused Indicators from DB in order to speed up the test
    map {$_->delete()} Entity::Indicator->search(
                           hash => { -not => {indicator_oid => $ind_oid}}
                       );

    node_disabling();
    test_rrd_remove();

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}

sub node_disabling {
    $aggregator = Daemon::Aggregator->new();
    my $rulesengine = Daemon::RulesEngine->new();
    $rulesengine->{config}->{time_step} = 0;

    # Create externalcluster with a mock monitor
    my $external_cluster_mockmonitor = Entity::ServiceProvider::Externalcluster->new(
        externalcluster_name => 'Test Monitor ' . $postfix,
    );

    $mock_monitor = Entity::Component::MockMonitor->new(
        service_provider_id => $external_cluster_mockmonitor->id,
    );

    $service_provider = Entity::ServiceProvider::Externalcluster->new(
        externalcluster_name => 'Test Service Provider ' . $postfix,
    );

    $service_provider->addManager(
        manager_id   => $mock_monitor->id,
        manager_type => 'CollectorManager',
    );

    # Create three nodes
    my $node1 = Entity::Node->new(
        node_hostname => 'test_node_1',
        service_provider_id   => $service_provider->id,
    );
    $service_provider->enableNode(node_id => $node1->id);

    my $node2 = Entity::Node->new(
        node_hostname => 'test_node_2',
        service_provider_id   => $service_provider->id,
    );
    $service_provider->enableNode(node_id => $node2->id);

    my $node3 = Entity::Node->new(
        node_hostname => 'test_node_3',
        service_provider_id   => $service_provider->id,
    );
    $service_provider->enableNode(node_id => $node3->id);

    my $agg_rule_ids  = _service_rule_objects_creation();
    my $node_rule_ids = _node_rule_objects_creation();

    lives_ok {
        diag('Check if no values before launching aggregator');
        if ( not defined $acomb1->evaluate() ) {
            diag('## checked');
        }
        else {
            die 'Presence of values before launching aggregator for combination <'.$acomb1->id.'>';
        }

        sleep 5;
        $aggregator->update();

        diag('Check if 3 nodes in aggregator');
        my $node_num = $acomb1->evaluate();
        if ($node_num == 3) {
            diag('## checked');
        }
        else {
            die 'Not 3 nodes in aggregator (got <'.$node_num.'> instead)';
        }

        $service_provider->disableNode(node_id => $node3->id);

        sleep(5);
        $aggregator->update();

        # Reload object to get changes
        $node3 = Entity::Node->get(id => $node3->id);
        diag('Check disabling node 3');
        if ( $node3->monitoring_state eq 'disabled' ) {
            diag('## disabled');
        }
        else {
            die 'Node 3 not disabled';
        }

        diag('Check if 2 nodes in aggregator');
        if ( $acomb1->evaluate() == 2 ) {
            diag('## checked');
        }
        else {
            die 'Not 2 nodes in aggregator';
        }

        $service_provider->enableNode(node_id => $node3->id);
        $node3 = Entity::Node->get(id => $node3->id);
        diag('Check enabling node 3');
        if ( $node3->monitoring_state ne 'disabled' ) {
            diag('## enabled');
        }
        else {
            die 'Node 3 not enabled';
        }

        sleep(5);
        $aggregator->update();

        diag('Check if 3 nodes in aggregator');
        if ( $acomb1->evaluate() == 3 ) {
            diag('## checked');
        }
        else {
            die 'Not 3 nodes in aggregator';
        }
    } 'Aggregator behavior when disabling nodes';

    lives_ok {

        sleep 5;
        $aggregator->update();
        $rulesengine->oneRun();

        diag('Check nodes rule verification');
        check_rule_verification(
            nrule1_id => $nrule1->id,
            node1_id  => $node1->id,
            node2_id  => $node2->id,
            node3_id  => $node3->id
        );

        $service_provider->disableNode(node_id => $node3->id);

        expectedException {
            VerifiedNoderule->find(hash => {
                verified_noderule_node_id            => $node3->id,
                verified_noderule_nodemetric_rule_id => $nrule1->id,
                verified_noderule_state              => 'verified',
            });
        } 'Kanopya::Exception::Internal::NotFound',
        'Disabled node 3 and check rule not verified';

        sleep 5;
        $aggregator->update();
        $rulesengine->oneRun();

        expectedException {
            VerifiedNoderule->find(hash => {
                verified_noderule_node_id            => $node3->id,
                verified_noderule_nodemetric_rule_id => $nrule1->id,
                verified_noderule_state              => 'verified',
            });
        } 'Kanopya::Exception::Internal::NotFound',
        'Run rules engine, disabled node 3 and check rule not verified';
    } 'Rules Engine behavior when disabling nodes';
}

sub check_rule_verification {
    my %args = @_;
    diag('# Node 1 rule verification');
    VerifiedNoderule->find(hash => {
        verified_noderule_node_id    => $args{node1_id},
        verified_noderule_nodemetric_rule_id => $args{nrule1_id},
        verified_noderule_state              => 'verified',
    });
    diag('## verified');

    diag('# Node 2 rule verification');
    VerifiedNoderule->find(hash => {
        verified_noderule_node_id    => $args{node2_id},
        verified_noderule_nodemetric_rule_id => $args{nrule1_id},
        verified_noderule_state              => 'verified',
    });
    diag('## verified');

    diag('# Node 3 rule verification');
    VerifiedNoderule->find(hash => {
        verified_noderule_node_id    => $args{node3_id},
        verified_noderule_nodemetric_rule_id => $args{nrule1_id},
        verified_noderule_state              => 'verified',
    });
    diag('## verified');
}

sub test_rrd_remove {
    lives_ok {
        my @cms = Entity::Metric::Clustermetric->search (hash => {
                      clustermetric_service_provider_id => $service_provider->id
                  });

        my @cm_ids = map {$_->id} @cms;
        while (@cms) { (pop @cms)->delete(); };

        my @acs = Entity::Metric::Combination::AggregateCombination->search (hash => {
            service_provider_id => $service_provider->id
        });
        if ( scalar @acs ne 0 ) {
            die 'All aggregate combinations have not been deleted';
        }

        my @ars = Entity::Rule::AggregateRule->search (hash => {
            service_provider_id => $service_provider->id
        });
        if ( scalar @ars ne 0 ) {
            die 'All aggregate rules have not been deleted';
        }

        my $one_rrd_remove = 0;
        for my $cm_id (@cm_ids) {
            my $db_name = '/var/cache/kanopya/monitor/timeDB_'.$cm_id.'.rrd';
            if (defined open(FILE,$db_name)) {
                $one_rrd_remove++;
            }
            close(FILE);
        }

        my @nodes = $service_provider->nodes;
        my @node_names = map {$_->node_hostname} @nodes;
        while (@nodes) { $service_provider->unregisterNode(node => pop (@nodes)) };

        my $used_indicators = $aggregator->_getUsedIndicators(service_provider     => $service_provider,
                                                              include_nodemetric   => 1);

        for my $indicator (values %{$used_indicators->{indicators}}) {
            for my $node_name (@node_names) {
                my $db_name = '/var/cache/kanopya/monitor/timeDB_'.$indicator->id.'_'.$node_name.'.rrd';
                if (defined open(FILE,$db_name)) {
                    $one_rrd_remove++;
                }
                close(FILE);
            }
        }

        if ($one_rrd_remove ne 0) {
            die "All rrd have not been removed : $one_rrd_remove rrd are still remaining";
        }
    } 'Test rrd remove';
}

sub _service_rule_objects_creation {
    my $service_provider = Entity::ServiceProvider::Externalcluster->find(
        hash => { externalcluster_name => 'Test Service Provider ' . $postfix }
    );

    my $indicator = Entity::Indicator->find(hash => {indicator_oid => $ind_oid});
    my $collector_indicator = $indicator->find(
                                  related => 'collector_indicators',
                                  hash    => {collector_manager_id => $mock_monitor->id}
                              );

    my $cm1 = Entity::Metric::Clustermetric->new(
                  clustermetric_service_provider_id => $service_provider->id,
                  clustermetric_indicator_id => $collector_indicator->id,
                  clustermetric_statistics_function_name => 'count',
                  clustermetric_window_time => '1200',
              );

    $acomb1 = Entity::Metric::Combination::AggregateCombination->new(
                  service_provider_id           =>  $service_provider->id,
                  aggregate_combination_formula => 'id' . ($cm1->id),
              );
}

sub _node_rule_objects_creation {
    my $service_provider = Entity::ServiceProvider::Externalcluster->find(
        hash => {externalcluster_name => 'Test Service Provider ' . $postfix}
    );

    my $indicator = Entity::Indicator->find(hash => {indicator_oid => $ind_oid});
    my $collector_indicator = $indicator->find(
                                  related => 'collector_indicators',
                                  hash    => {collector_manager_id => $mock_monitor->id}
                              );
    # Create nodemetric rule objects
    my $ncomb1 = Entity::Metric::Combination::NodemetricCombination->new(
                     service_provider_id             => $service_provider->id,
                     nodemetric_combination_formula  => 'id' . $collector_indicator->id
                                                        . ' + id' . $collector_indicator->id,
                 );

    my $nc1 = Entity::NodemetricCondition->new(
        nodemetric_condition_service_provider_id => $service_provider->id,
        left_combination_id => $ncomb1->id,
        nodemetric_condition_comparator => '>',
        nodemetric_condition_threshold => '0',
    );

    $nrule1 = Entity::Rule::NodemetricRule->new(
        service_provider_id => $service_provider->id,
        formula => 'id'.$nc1->id,
        state => 'enabled'
    );
}
