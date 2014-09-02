#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;
use Data::Dumper;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
    level  => 'DEBUG',
    file   => 'workflowDef.log',
    layout => '%F %L %p %m%n'
});
my $log = get_logger("");
my $workflow;

use Kanopya::Database;
use BaseDB;
use General;
use Entity;
use Entity::Workflow;
use Entity::Operationtype;
use Entity::Component::KanopyaExecutor;

use Kanopya::Test::TestUtils 'expectedException';

Kanopya::Database::authenticate(login => 'admin', password => 'K4n0pY4');


main();

sub main {
#    Kanopya::Database::beginTransaction;
    createWorkflow();
    enqueueBefore();
    createWorkflow();
    enqueueNow();
    createWorkflow();
    paramPresetTransmission();
#    Kanopya::Database::rollbackTransaction;
}


sub createWorkflow {
    lives_ok {
        $workflow = Entity::Workflow->run(name => 'AddNode', workflow_manager => Entity::Component::KanopyaExecutor->find());
        my @operations = $workflow->operations;
        my @expectedOperationNames = ('AddNode','PreStartNode', 'PostStartNode');

        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrong operation name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'Workflow creation';
}

sub enqueueBefore {
    lives_ok {
        # Enqueue one operation before all operations;
        my @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my $op =  { priority => 200, type => "LaunchSCOWorkflow" };

        $workflow->enqueueBefore(current_operation => $operations[0], operation => $op);
        @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my @expectedOperationNames = ('LaunchSCOWorkflow', 'AddNode','PreStartNode', 'PostStartNode');

        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrond operation name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'EnqueueBefore one operation at the begining of an existing workflow';



    lives_ok {
        # Enqueue one operation before all operations;
        my @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my $op =  { priority => 200,
                    operationtype => Entity::Operationtype->find(hash => { operationtype_name => 'SynchronizeInfrastructure' }) };

        $workflow->enqueueBefore(current_operation => $operations[2], operation => $op);
        @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my @expectedOperationNames = ('LaunchSCOWorkflow', 'AddNode', 'SynchronizeInfrastructure',
                                      'PreStartNode', 'PostStartNode');


        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrond operation name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'EnqueueBefore one operation in an existing workflow';

    lives_ok {
        my @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');

        my $workflow_to_enqueue = { name => 'StopNode' };
        $workflow->enqueueBefore(current_operation => $operations[2], workflow  => $workflow_to_enqueue);

        @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my @expectedOperationNames = ('LaunchSCOWorkflow',
                                      'AddNode',
                                      'PreStopNode',
                                      'PostStopNode',
                                      'SynchronizeInfrastructure',
                                      'PreStartNode',
                                      'PostStartNode');

        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrond operation name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'EnqueueBefore a whole workflow in an existing workflow';
}


sub enqueueNow {
    lives_ok {
        # Enqueue one operation before all operations;
        my @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        $operations[0]->state('succeeded');
        $operations[1]->state('processing');

        my $op = { priority => 200, type => 'ActivateHost' };

        $workflow->enqueueNow(operation => $op);

        @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my @expectedOperationNames = ('AddNode','PreStartNode', 'ActivateHost', 'PostStartNode');

        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrond operation '.$i.' name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'EnqueueNow one Operation';

    lives_ok {
        my $workflow_to_enqueue = { name => 'StopNode' };
        $workflow->enqueueNow(workflow => $workflow_to_enqueue);

        my @operations = $workflow->searchRelated(filters => ['operations'], order_by=> 'execution_rank ASC');
        my @expectedOperationNames = ('AddNode','PreStartNode',
                                      'PreStopNode', 'PostStopNode',
                                      'ActivateHost', 'PostStartNode');

        for my $i (0..@expectedOperationNames-1) {
            if ($operations[$i]->operationtype->operationtype_name ne $expectedOperationNames[$i]) {
                die 'Wrond operation '.$i.' name <'.$operations[$i]->operationtype->operationtype_name.'> expected <'.$expectedOperationNames[$i].'>';
            }
        }
    } 'EnqueueNow one Workflow';
}

sub paramPresetTransmission {

    lives_ok {
        my $operation = $workflow->getNextOperation();

        if ($operation->operationtype->operationtype_name ne 'AddNode') {
            die 'Wrong next operation get <'.$operation->operationtype->operationtype_name.'> has to be <AddNode>';
        }

        $operation->state('succeeded');

        my $op1 =  {priority => 200,
                    type     => 'ActivateHost',
                    params   => {
                        param1 => 'parameter_1_1',
                        param2 => 'parameter_2_1',
                    }};

        my $op2 =  {priority => 200,
                    type     => 'SynchronizeInfrastructure',
                    params   => {
                        param1 => 'parameter_1_2',
                        param3 => 'parameter_3_2',
                    }};

        $workflow->enqueueNow(operation => $op2);
        $workflow->enqueueNow(operation => $op1);

        $operation = $workflow->prepareNextOperation(current => $operation);
        my $pp = $operation->param_preset->load();

        if ($operation->operationtype->operationtype_name ne 'ActivateHost'
            || $pp->{param1} ne 'parameter_1_1'
            || $pp->{param2} ne 'parameter_2_1'
            || defined $pp->{param3}) {

            die "Wrong execution.\n".
                "Got operation <".$operation->operationtype->operationtype_name."> expected <ActivateHost>".
                "Got param1 <".$pp->{param1}."> expected <parameter_1_1>".
                "Got param2 <".$pp->{param2}."> expected <parameter_2_1>".
                "Got param3 <".$pp->{param3}."> expected <>";
        }

        $operation->state('succeeded');

        $operation = $workflow->prepareNextOperation(current => $operation);
        $pp = $operation->param_preset->load();

        if ($operation->operationtype->operationtype_name ne 'SynchronizeInfrastructure'
            || $pp->{param1} ne 'parameter_1_2'
            || $pp->{param2} ne 'parameter_2_1'
            || $pp->{param3} ne 'parameter_3_2') {

            die "Wrong execution.\n".
                "Got operation <".$operation->operationtype->operationtype_name."> expected <SynchronizeInfrastructure>".
                "Got param1 <".$pp->{param1}."> expected <parameter_1_2>".
                "Got param2 <".$pp->{param2}."> expected <parameter_2_1>".
                "Got param3 <".$pp->{param3}."> expected <parameter_3_2>";
        }
    } 'Param preset transmission';
}