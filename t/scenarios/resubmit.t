#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

These test needs :
One IAAS Opennebula with 2 hypervisors
4 vms on the first hypervisor

Warning : hypervisor 2 is eth0 down at the end of the test

=cut

use strict;
use warnings;
use Test::More 'no_plan';
use Test::Exception;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level=>'DEBUG',
    file=>'rules_on_state.log',
    layout=>'%d [ %H - %P ] %p -> %M - %m%n'
});

use Kanopya::Database;
use Daemon::Aggregator;
use Daemon::RulesEngine;
use Entity;
use Entity::Component::Virtualization::Opennebula3;
use Entity::ServiceProvider::Externalcluster;
use Entity::Component::MockMonitor;
use Entity::Metric::Clustermetric;
use Entity::AggregateCondition;
use Entity::Metric::Combination::AggregateCombination;
use Entity::Rule::AggregateRule;
use Entity::Metric::Combination::NodemetricCombination;
use Entity::NodemetricCondition;
use Entity::Rule::NodemetricRule;
use VerifiedNoderule;
use Entity::Workflow;
use Entity::WorkflowDef;
use Kanopya::Config;
use Entity::Component::Kanopyacollector1;

use Kanopya::Test::Execution;
use Kanopya::Test::TestUtils 'expectedException';

use Data::Dumper;

my $testing = 0;

my $aggregator;
my $rulesengine;

my ($hv1, $hv2);
my $one;

main();

sub main {
    Kanopya::Database::authenticate( login =>'admin', password => 'K4n0pY4' );

    if($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    my $config = Kanopya::Config::get('monitor');
    $config->{time_step} = 5;

    Kanopya::Config::set(
        subsystem => 'monitor',
        config    => $config,
    );

    $aggregator  = Daemon::Aggregator->new();
    $rulesengine = Daemon::RulesEngine->new();

    #get orchestrator configuration

    $one = Entity::Component::Virtualization::Opennebula3->find(hash => {});
    my @hvs = $one->hypervisors;

    if ($hvs[0]->node->node_hostname eq 'one1') {
        ($hv1, $hv2) = @hvs;
    }
    else {
        ($hv2, $hv1) = @hvs;
    }

    _check_no_operation_and_no_lock();
    _add_mock_monitor();

    diag('Maintenance hypervisor');
    _split_2_2();
    maintenance_hypervisor();

    diag('resubmit_vm_on_state');
    _split_2_2();
    resubmit_vm_on_state();

    diag('Resubmit hypervisor on state');
    _split_2_2();
    resubmit_hv_on_state();

    diag('Resubmit hypervisor');
    _split_2_2();
    resubmit_hypervisor();

    _remove_mock_monitor();

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}

sub _remove_mock_monitor {
    my @spms = $one->service_provider_managers;
    my $vm_cluster = $spms[0]->service_provider;
    my @hvs = $one->hypervisors;
    my $hv_cluster = $hvs[0]->node->inside;

    my $external_cluster_mockmonitor = Entity::ServiceProvider::Externalcluster->find(
            hash => {externalcluster_name => 'Test Monitor'},
    );

    $external_cluster_mockmonitor->remove();

    my $kc = Entity::Component::Kanopyacollector1->find(hash => {});
    my $kanopya_collector_id = $kc->id;

    $vm_cluster->addManager(
        manager_id      => $kanopya_collector_id,
        manager_type    => 'CollectorManager',
        no_default_conf => 1,
    );

    $hv_cluster->addManager(
        manager_id      => $kanopya_collector_id,
        manager_type    => 'CollectorManager',
        no_default_conf => 1,
    );
}

sub _add_mock_monitor {

    my @spms = $one->service_provider_managers;
    my $vm_cluster = $spms[0]->service_provider;
    my @hvs = $one->hypervisors;
    my $hv_cluster = $hvs[0]->node->inside;

    my $external_cluster_mockmonitor = Entity::ServiceProvider::Externalcluster->new(
            externalcluster_name => 'Test Monitor',
    );

    my $mock_monitor = Entity::Component::MockMonitor->new(
            service_provider_id => $external_cluster_mockmonitor->id,
    );

    my @clusters = ($vm_cluster, $hv_cluster);

    for my $cluster (@clusters) {

        my $kanopya_collector_manager = ServiceProviderManager->find( hash => {
            manager_type        => 'CollectorManager',
            service_provider_id => $cluster->id,
        });

        $kanopya_collector_manager->remove();

        $cluster->addManager(
            manager_id      => $mock_monitor->id,
            manager_type    => 'CollectorManager',
            no_default_conf => 1,
        );
    }
}

sub resubmit_hv_on_state {
    lives_ok {
        my @hvs = $one->hypervisors;
        die 'There is not 2 hypervisors in the infra' if (scalar @hvs != 2);

        my @hv1_vms = $hv1->virtual_machines;
        my @hv2_vms = $hv2->virtual_machines;

        die 'Hv1 has not 2 vms' if (scalar @hv1_vms != 2);
        die 'Hv2 has not 2 vms' if (scalar @hv2_vms != 2);

        my $hv_cluster = $hv1->node->inside;

        # Get indicators
        my $indic = Entity::CollectorIndicator->find (
            hash => { 'indicator.indicator_label' => 'state/Up' }
        );

        #  Nodemetric combination
        my $ncomb = Entity::Metric::Combination::NodemetricCombination->new(
                        service_provider_id             => $hv_cluster->id,
                        nodemetric_combination_formula  => 'id'.($indic->id),
                    );

        my $ncond = Entity::NodemetricCondition->new(
            nodemetric_condition_service_provider_id => $hv_cluster->id,
            left_combination_id             => $ncomb->id,
            nodemetric_condition_comparator => '==',
            nodemetric_condition_threshold  => '0',
        );

        my $rule = Entity::Rule::NodemetricRule->new(
            service_provider_id => $hv_cluster->id,
            formula => 'id'.$ncond->id,
            state => 'enabled'
        );

        my $node = $hv1->node;

        $node->setAttr(name => 'node_state', value => 'in:'.time());
        $node->save();

        $hv_cluster->addManagerParameter(
            manager_type    => 'CollectorManager',
            name            => 'mockmonit_config',
            value           =>  "{'default':{'const':1},'nodes':{'one1':{'const':1}, 'one2':{'const':1}}}",
        );

        my %indicators;
        $indicators{$indic->indicator->indicator_oid} = $indic->indicator;

        my $nodes_metrics = $hv_cluster->getNodesMetrics(
            indicators => \%indicators,
            time_span  => 1200,
        );

        die 'Hv1 is not up' if ($nodes_metrics ->{$hv1->node->node_hostname}->{'Host is up'} != 1);
        die 'Hv1 is not activated' if ($hv1->active != 1);

        $rulesengine->oneRun();

        $node->setAttr(name => 'node_state', value => 'broken:'.time());
        $node->save();

        $hv_cluster->addManagerParameter(
            manager_type    => 'CollectorManager',
            name            => 'mockmonit_config',
            value           =>  "{'default':{'const':1},'nodes':{'one1':{'const':0}, 'one2':{'const':1}}}",
        );

        $nodes_metrics = $hv_cluster->getNodesMetrics(
            indicators => \%indicators,
            time_span  => 1200,
        );

        die 'Hv1 is not broken' if ($nodes_metrics ->{$hv1->node->node_hostname}->{'Host is up'} != 0);

        expectedException {
            VerifiedNoderule->find( hash => {
                verified_noderule_node_id       => $hv1->id,
                verified_noderule_nodemetric_rule_id    => $rule->id,
            });
        } 'Kanopya::Exception::Internal::NotFound',
        'Rule not verified';

        $rulesengine->oneRun();

        my $verifNodeRule = VerifiedNoderule->find( hash => {
            verified_noderule_node_id       => $hv1->node->id,
            verified_noderule_nodemetric_rule_id    => $rule->id,
            verified_noderule_state                 => 'verified',
        });
        diag 'Rule verified' if (defined $verifNodeRule);

        my $wf_manager = $hv_cluster->findRelated(
                             filters    => ['service_provider_managers'],
                             hash       => { manager_type => 'WorkflowManager' }
                         )->manager;

        my $workflow_def = Entity::WorkflowDef->find(hash => {workflow_def_name => 'ResubmitHypervisor'});

        $rule->associateWorkflow(workflow_def_id => $workflow_def->id, specific_params => { delay => 60 });

        $rulesengine->oneRun();

        my @operations = Entity::Operation->search(hash => {}, order_by => 'execution_rank asc');
        if (scalar @operations == 1) {
            diag('1 operation enqueued')
        }
        else {
            die '1 operation not enqueued';
        }

        die '### operation ResubmitHypervisor not enqueued' if ( (shift @operations)->type ne 'ResubmitHypervisor');

        Kanopya::Test::Execution->oneRun();

        @operations = Entity::Operation->search(hash => {}, order_by => 'execution_rank asc');
        shift @operations; # Remove old ResubmitHypervisor operation
        if (scalar @operations == 6) {
            diag('6 operations enqueued');
        }
        else {
            die '6 operations not enqueued';
        }

        die '### operation ResubmitNode not enqueued' if ( (shift @operations)->type ne 'ResubmitNode');
        die '### operation ScaleCpuHost not enqueued' if ( (shift @operations)->type ne 'ScaleCpuHost');
        die '### operation ScaleMemoryHost not enqueued' if ( (shift @operations)->type ne 'ScaleMemoryHost');
        die '### operation ResubmitNode not enqueued' if ( (shift @operations)->type ne 'ResubmitNode');
        die '### operation ScaleCpuHost not enqueued' if ( (shift @operations)->type ne 'ScaleCpuHost');
        die '### operation ScaleMemoryHost not enqueued' if ( (shift @operations)->type ne 'ScaleMemoryHost');

        Kanopya::Test::Execution->executeAll();

        $rulesengine->oneRun();
        sleep(10);

        # With 60 sec delay, workflow is not relaunched
        $rulesengine->oneRun();
        @operations = Entity::Operation->search(hash => {});
        if (scalar @operations == 0) {
            diag ('no operation waiting for delay');
        }
        else {
            die 'Operation is waiting for delay';
        }

        @hv1_vms = $hv1->virtual_machines;
        @hv2_vms = $hv2->virtual_machines;
        die 'Hv1 has not 0 vm' if (scalar @hv1_vms != 0);
        die 'Hv2 has not 4 vms' if (scalar @hv2_vms != 4);

        sleep(55);

        $rulesengine->oneRun();

        @operations = Entity::Operation->search(hash => {});

        if (scalar @operations == 1) {
            diag ('End of delay, workflow re-enqueud');
        }
        else {
            die 'End of delay, workflow not re-enqueud';
        }

        while (@operations) { (pop @operations)->delete(); }
        $ncomb->delete();
    } 'Resubmit a simulated broken hypervisor using a nodemetric rule';
}

sub resubmit_vm_on_state {
    lives_ok {
        my @spms = $one->service_provider_managers;
        my $vm_cluster = $spms[0]->service_provider;

        # Get indicators
        my $indic = Entity::CollectorIndicator->find (
            hash => { 'indicator.indicator_label' => 'state/Up' }
        );

        #  Nodemetric combination
        my $ncomb = Entity::Metric::Combination::NodemetricCombination->new(
                        service_provider_id             => $vm_cluster->id,
                        nodemetric_combination_formula  => 'id'.($indic->id),
                    );

        my $ncond = Entity::NodemetricCondition->new(
            nodemetric_condition_service_provider_id => $vm_cluster->id,
            left_combination_id             => $ncomb->id,
            nodemetric_condition_comparator => '==',
            nodemetric_condition_threshold  => 0,
        );

        my $rule = Entity::Rule::NodemetricRule->new(
            service_provider_id => $vm_cluster->id,
            formula => 'id'.$ncond->id,
            state => 'enabled'
        );

        my @vms = $one->opennebula3_vms;
        my $vm = $vms[0];
        my $node = $vm->node;
        my $old_ram = $vm->host_ram;
        my $old_cpu = $vm->host_core;

        $node->setAttr(name => 'node_state', value => 'in:'.time());
        $node->save();

    $vm_cluster->addManagerParameter(
        manager_type    => 'CollectorManager',
        name            => 'mockmonit_config',
        value           =>  "{'default':{'const':1},'nodes':{'vm1':{'const':1}, 'vm2':{'const':1}}}",
    );

        my %indicators;
        $indicators{$indic->indicator->indicator_oid} = $indic->indicator;

        my $nodes_metrics = $vm_cluster->getNodesMetrics(
            indicators => \%indicators,
            time_span  => 1200,
        );

        die 'Host is not up' if ($nodes_metrics ->{$vm->node->node_hostname}->{'Host is up'} != 1);

        $rulesengine->oneRun();

        my $evm = EEntity->new(data => $vm);

        eval {
            $evm->getEContext->execute(command => 'ifconfig eth0 down ; ifconfig eth1 down');
        };
        diag('Vm ifdown');

        $node->setAttr(name => 'node_state', value => 'broken:'.time());
        $node->save();

        $vm_cluster->addManagerParameter(
            manager_type    => 'CollectorManager',
            name            => 'mockmonit_config',
            value           =>  "{'default':{'const':1},'nodes':{'vm1':{'const':0}, 'vm2':{'const':1}}}",
        );

        $nodes_metrics = $vm_cluster->getNodesMetrics(
            indicators => \%indicators,
            time_span  => 1200,
        );

        if ($nodes_metrics ->{$vm->node->node_hostname}->{'Host is up'} == 0) {
            diag('Host is down');
        }
        else {
            die 'Host is not down';
        }

        expectedException {
            VerifiedNoderule->find( hash => {
                verified_noderule_node_id       => $vm->id,
                verified_noderule_nodemetric_rule_id    => $rule->id,
            });
        } 'Kanopya::Exception::Internal::NotFound',
        'Rule not verified';

        $rulesengine->oneRun();

        diag('Rule verification');
        my $verifNodeRule = VerifiedNoderule->find( hash => {
            verified_noderule_node_id       => $vm->node->id,
            verified_noderule_nodemetric_rule_id    => $rule->id,
            verified_noderule_state                 => 'verified',
        });
        diag('### Rule verified') if (defined $verifNodeRule);

        my $wf_manager = $vm_cluster->findRelated(
                             filters    => ['service_provider_managers'],
                             hash       => { manager_type => 'WorkflowManager' }
                         )->manager;

        my $workflow_def = Entity::WorkflowDef->find(hash => {workflow_def_name => 'ResubmitNode'});

        $rule->associateWorkflow(workflow_def_id => $workflow_def->id, specific_params => { delay => 60 });

        $rulesengine->oneRun();

        my @operations = Entity::Operation->search(hash => {}, order_by => 'execution_rank asc');
        if (scalar @operations == 3) {
            diag('3 operations enqueued');
        }
        else {
            die '3 operations not enqueued';
        }

        die 'operation ResubmitNode not enqueued' if ( (shift @operations)->type ne 'ResubmitNode');
        die 'operation ScaleCpuHost not enqueued' if ( (shift @operations)->type ne 'ScaleCpuHost');
        die 'operation ScaleMemoryHost not enqueued' if ( (shift @operations)->type ne 'ScaleMemoryHost');

        Kanopya::Test::Execution->executeAll();

        _check_vm_ram(vm =>$vm, ram => $old_ram);
        _check_vm_cpu(vm =>$vm, cpu => $old_cpu);

        my ($state, $foo) = $vm->getNodeState();

        if ($state eq 'in') {
            diag('Node in');
        }
        else {
            die 'Node not in';
        }

        $rulesengine->oneRun();
        sleep(10);

        # With 60 sec delay, workflow is not relaunched
        $rulesengine->oneRun();
        @operations = Entity::Operation->search(hash => {});
        if (scalar @operations == 0) {
            diag('no operation waiting for delay');
        }
        else {
            die('Operation waiting for delay');
        }

        sleep(55);

        $rulesengine->oneRun();

        @operations = Entity::Operation->search(hash => {});

        if (scalar @operations == 3) {
            diag ('End of delay, workflow re-enqueud');
        }
        else {
            die 'End of delay, workflow not re-enqueud';
        }

        while (@operations) { (pop @operations)->delete(); }
        $ncomb->delete();
    } 'Resubmit a simulated broken state and unreachable virtual machine using rule';
}

sub resubmit_hypervisor {
    lives_ok {
        my @hv1_vms = $hv1->virtual_machines;
        my @hv2_vms = $hv2->virtual_machines;

        my @old_rams = map {$_->host_ram} @hv2_vms;
        my @old_cpus = map {$_->host_core} @hv2_vms;


        die '1st hv has not 2 vms' if (scalar @hv1_vms != 2);
        die '2nd hv has not 2 vms' if (scalar @hv2_vms != 2);

        my $ehyp = EEntity->new(data => $hv2);

        eval {
            $ehyp->getEContext->execute(command => 'ifconfig eth0 down ; ifconfig eth1 down');
        };

        diag('Hypervisor ifdown');

        $hv2->resubmitVms;
        diag('EResubmitHypervisor execution');
        Kanopya::Test::Execution->oneRun;

        my @ops = Entity::Operation->search(hash => {}, order_by => 'execution_rank ASC');

        my $id = 0;

        die 'No operation ResubmitHypervisor' if ($ops[$id++]->type ne 'ResubmitHypervisor');
        die 'No operation ResubmitNode' if ($ops[$id++]->type ne 'ResubmitNode');
        die 'No operation ScaleCpuHost' if ($ops[$id++]->type ne 'ScaleCpuHost');
        die 'No operation ScaleMemoryHost' if ($ops[$id++]->type ne 'ScaleMemoryHost');
        die 'No operation ResubmitNode' if ($ops[$id++]->type ne 'ResubmitNode');
        die 'No operation ScaleCpuHost' if ($ops[$id++]->type ne 'ScaleCpuHost');
        die 'No operation ScaleMemoryHost' if ($ops[$id++]->type ne 'ScaleMemoryHost');

        Kanopya::Test::Execution->executeAll();

        _check_no_operation_and_no_lock();

        die 'Hv1 has not 4 vms' if (scalar $hv1->reload->virtual_machines != 4);
        die 'Hv2 has not 0 vm' if (scalar $hv2->reload->virtual_machines != 0);

        for my $i (0..(@hv2_vms-1)) {
            _check_vm_cpu(vm => $hv2_vms[$i], cpu => $old_cpus[$i]);
            _check_vm_ram(vm => $hv2_vms[$i], ram => $old_rams[$i]);
        }
    } 'Resubmit an unreachable hypervisor';
}

sub maintenance_hypervisor {
    lives_ok {
        my @hv1_vms = $hv1->virtual_machines;
        my @hv2_vms = $hv2->virtual_machines;
        die 'Hv1 has not 2 vms' if (scalar @hv1_vms != 2);
        die 'Hv2 has 2 vms' if (scalar @hv2_vms != 2);

        $hv2->maintenance;
        diag('EFlushHypervisor execution');
        Kanopya::Test::Execution->oneRun;

        my @ops = Entity::Operation->search(hash => {}, order_by => 'execution_rank ASC');

        die 'Operation 1 is not FlushHypervisor' if ($ops[0]->type ne 'FlushHypervisor');
        die 'Operation 2 is not MigrateHost' if ($ops[1]->type ne 'MigrateHost');
        die 'Operation 3 is not MigrateHost' if ($ops[2]->type ne 'MigrateHost');
        die 'Operation 4 is not DeactivateHost' if ($ops[3]->type ne 'DeactivateHost');

        Kanopya::Test::Execution->executeAll();

        @hv1_vms = $hv1->virtual_machines;
        @hv2_vms = $hv2->virtual_machines;
        die 'Hv1 has not 4 vms' if (scalar @hv1_vms != 4);
        die 'Hv2 has not 0 vm' if (scalar @hv2_vms != 0);

        $hv2 = $hv2->reload;
        die 'hypervisor 2 has not been deactivated' if ($hv2->active != 0);

        $hv2->setAttr( name => 'active', value => '1');
        $hv2->save();
        die 'hypervisor 2 has not been re-activated' if ($hv2->reload->active != 1);
    } 'Hypervisor maintenance';
}

sub _check_no_operation_and_no_lock {
    my @ops = Entity::Operation->search(hash => {});
    if (@ops > 0) { die 'Some operations are enqueued'; }
    my @locks = EntityLock->search(hash => {});
    if (@locks > 0) {die 'Some locks are present';}
}

sub _split_2_2 {
    my @vms = $one->opennebula3_vms;

    if ($hv1->virtual_machines > $hv2->virtual_machines) {
        while ($hv1->virtual_machines != $hv2->virtual_machines) {
            my @vms = $hv1->virtual_machines;
            my $vm = (pop @vms);
            $vm->migrate(hypervisor => $hv2);

            Kanopya::Test::Execution->executeAll();
            if ($vm->reload->hypervisor->id != $hv2->id) {die 'Vm has not migrated';}
        }
    }
    elsif ($hv1->virtual_machines < $hv2->virtual_machines) {
        while ($hv1->virtual_machines != $hv2->virtual_machines) {
            my @vms = $hv2->virtual_machines;
            my $vm = (pop @vms);
            $vm->migrate(hypervisor => $hv1);

            Kanopya::Test::Execution->executeAll();
            if ($vm->reload->hypervisor->id != $hv1->id) {die 'Vm has not migrated'};
        }
    }

    if (((scalar $hv1->virtual_machines) != 2) || ((scalar $hv2->virtual_machines) != 2) ) {
        die 'Put 2 vms on each hypervisors fail';
    }
}

sub _check_vm_ram {
    my %args = @_;
    my $vm = $args{vm}->reload;
    my $ram = $args{ram};

    if (!($vm->host_ram == $ram)) {
        die 'vm ram value in DB is wrong';
    }

    my $evm = EEntity->new(data => $vm);

    if (!($evm->getTotalMemory == $ram)) {
        die 'vm real ram value is wrong';
    }

    diag('# vm ram is ok');
}

sub _check_vm_cpu {
    my %args = @_;
    my $vm = $args{vm}->reload;
    my $cpu = $args{cpu};

    if (!($vm->host_core == $cpu)) {
        die 'vm cpu value in DB is wrong';
    }

    my $evm = EEntity->new(data => $vm);

    if (!($evm->getTotalCpu == $cpu)) {
        die 'real cpu value is wrong';
    }

    diag('# vm cpu is ok');
}
