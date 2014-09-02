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
    file   => 'workflow_manager.log',
    layout => '%d [ %H - %P ] %p -> %M - %m%n'
});
my $log = get_logger("");

use Kanopya::Database;
use BaseDB;
use General;
use Entity;
use Entity::ServiceProvider::Externalcluster;
use Entity::Component::Kanopyaworkflow0;
use Entity::Component::KanopyaExecutor;
use Entity::Component::Sco;
use Kanopya::Test::TestUtils 'expectedException';
use Data::Compare;

Kanopya::Database::authenticate(login => 'admin', password => 'K4n0pY4');

my $wfmanager;
my $sco_wfmanager;
my $workflow;
my $service_provider;
my @wfdefs = ();
my @sco_wfdefs = ();
my @rules = ();
my @associations = ();
my $external_cluster_name;

main();

sub main {
    Kanopya::Database::beginTransaction;

    createObjects();
    unitTests();
    paramsManagement();
    Kanopya::Database::rollbackTransaction;
}

sub paramsManagement {
    lives_ok {

        my $template = 'Node hostname = [% node_hostname %],'
                        .'other = [% other %]'
                        .'ou = [% ou_from %]'
                        .'SP name = [% service_provider_name %]';

        my $params = {data     => {template_content => $template},
                      internal => {scope_id => 1}};

        my $sco_workflow_def = $sco_wfmanager->createWorkflowDef(workflow_name => 'sco_wf_def_with_params',
                                                                 params        => $params);

        my $pp = $sco_workflow_def->paramPresets();

        if ($pp->{data}->{template_content} ne $template
            || $pp->{internal}->{scope_id} ne 1
            || ! exists $pp->{specific}->{other}
            || ! exists $pp->{specific}->{service_provider_name}
            || ! exists $pp->{automatic}->{ou_from}
            || ! exists $pp->{automatic}->{node_hostname}
            ) {
            die 'Wrong parameter management';
        }

        my $automatic_values = $sco_wfmanager->_getAutomaticValues(
                                   automatic_params => {ou_from => undef, node_hostname => undef},
                                   scope_id         => 1,
                               );

        if (defined $automatic_values->{ou_from} || defined $automatic_values->{node_hostname}) {
            die 'Automatic values must not be defined';
        }

        $automatic_values = $sco_wfmanager->_getAutomaticValues(
                                automatic_params    => {ou_from => undef, node_hostname => undef},
                                scope_id            => 1,
                                host_name           => 'my_hostname',
                            );

        if (defined $automatic_values->{ou_from} || $automatic_values->{node_hostname} ne 'my_hostname') {
            die 'Only node_hostname must be defined';
        }

        $automatic_values = $sco_wfmanager->_getAutomaticValues(
                                automatic_params    => {service_provider_name => undef},
                                scope_id            => 2,
                            );

        if (defined $automatic_values->{service_provider_name}) {
            die 'Param should not be defined';
        }

        $automatic_values = $sco_wfmanager->_getAutomaticValues(
                                automatic_params    => {service_provider_name => undef},
                                scope_id            => 2,
                                service_provider_id => $service_provider->id
                            );

        if ($automatic_values->{service_provider_name} ne $external_cluster_name) {
            die 'Param should not be defined';
        }

        my $all_params = {
            internal  =>  {scope_id => 1, output_dir => '/tmp/test'},
            automatic =>  {node_hostname => 'my node'},
            specific  =>  {specific_param => 'my specific param'},
        };

        my $final_params = $sco_wfmanager->_defineFinalParams(
                               all_params        => $all_params,
                               workflow_def_name => $sco_wfdefs[1]->workflow_def_name,
                               rule_id           => $rules[0]->id,
                               sp_id             => $service_provider->id,
                           );

        my $output_file = $final_params->{output_file};
        delete $final_params->{output_file};

        my $waited_params = {workflow_values => {specific_param => $all_params->{specific}->{specific_param},
                                                 node_hostname  => $all_params->{automatic}->{node_hostname}},
                            template_content => undef,
                            period           => undef,
                            sp_id            => $service_provider->id,
                            rule_id          => $rules[0]->id,
                            scope_name       => 'node',
                            output_directory => $all_params->{internal}->{output_dir}
            };

        if (! Compare($final_params, $waited_params)) {
            die 'Params are not as expected';
        }

        $output_file =~ s/_\d+$//;

        my $waited_string = 'workflow_'.$sco_wfdefs[1]->workflow_def_name;

        if ($output_file ne $waited_string) {
            die 'Not expected output file name';
        }

        $automatic_values = $wfmanager->_getAutomaticValues(
                                automatic_params    => {context => { cluster => undef }},
                                scope_id            => 2,
                                service_provider_id => $service_provider->id
                            );

        if ($automatic_values->{context}->{cluster}->id ne $service_provider->id) {
            die 'Wrong automatic cluster parameter';
        }

    } 'params Management';
}


sub unitTests {
    lives_ok {
        my @workflow_defs = WorkflowDefManager->search(hash => { manager_id => $wfmanager->id });
        my @sids = sort map { $_->workflow_def_id } grep { $_->workflow_def->workflow_def_name != m/NotifyWorkflow/ } @workflow_defs;

        for my $i (0..@sids-1) {
            if ($sids[$i] != $wfdefs[$i]->id) {
                die 'wrong id got <'.($sids[$i]).'> instead of <'.($wfdefs[$i]->id).'>';
            }
        }

        my @wfds = $wfmanager->workflow_defs;

        # Should be 3 as 3 workflow de have been created, but do not forget the both notify workflow
        # added at workflow manager instanciation.
        if (scalar @wfds != 5) {
            die 'Got <'.(scalar @wfds).'> k wfdefs instead of <3>';
        }

        @wfds = $sco_wfmanager->workflow_defs;

        # Should be 2 as 2 workflow de have been created, but do not forget the both notify workflow
        # added at workflow manager instanciation.
        if (scalar @wfds != 4) {
            die 'Got <'.(scalar @wfds).'> sco wfdefs instead of <2>';
        }

        if ($sco_wfdefs[1]->workflow_def_name ne $sco_wfdefs[0]->workflow_def_name) {
            die 'Wrong workflow name, got <' . $sco_wfdefs[1]->workflow_def_name .
                '> expected <' . $sco_wfdefs[0]->workflow_def_name . '>';
        }

        if ($sco_wfdefs[2]->workflow_def_name ne $sco_wfdefs[0]->workflow_def_name) {
            die 'Wrong workflow name, got <' . $sco_wfdefs[0]->workflow_def_name .
                '> expected <' . $sco_wfdefs[0]->workflow_def_name . '>';
        }

        my @pps = ();
        for my $wf (@wfdefs, @sco_wfdefs) {
            push @pps, $wf->paramPresets();
        }

        if ($pps[0]->{param_0} ne 'param_0'  || keys $pps[1] ne 0 || $pps[2]->{param_2} ne 'param_2'
            || $pps[4]->{sco_param_0} ne 'sco_param_0'
            || $pps[5]->{sco_param_0} ne 'sco_param_0'
            || $pps[6]->{sco_param_0} ne 'sco_param_0'
            ) {
                die 'wrong params';
        }

        for my $association (@associations) {
            if ($association->paramPresets->{specific}->{specific_1} ne 'specific_1') {
                die 'wrong params in workflow_def_rule additional params.';
            }
        }

        my $expected_parameters;

        my $node_parameters    = ScopeParameter->getNames(scope_id => 1);
        $expected_parameters = {node_hostname => 1, ou_from => 1};
        for my $param (@$node_parameters) {
            if (! defined $expected_parameters->{$param}) {
                die 'Unknown node parameter';
            }
        }

        my $service_parameters = ScopeParameter->getNames(scope_id => 2);
        $expected_parameters = {service_provider_name => 1};
        for my $param (@$service_parameters) {
            if (! defined $expected_parameters->{$param}) {
                die 'Unknown node parameter';
            }
        }

        $rules[0] = $rules[0]->reload();
        if (! defined $rules[0]->workflow_def) {
            die 'Workflow not associated to rule';
        }

        $rules[0]->deassociateWorkflow(workflow_def_id => $sco_wfdefs[1]->id);

        $rules[0] = $rules[0]->reload();
        if (defined $rules[0]->workflow_def) {
            die 'Workflow not deassociated to rule';
        }
    } 'Unit tests';
}

sub createObjects {
    lives_ok {
        # Nodo creade a Service Provider with service_provider_name then change Sco->_getAutomaticValues
        # so that it works with ServiceProvider instances
        $external_cluster_name = 'My External Cluster Name';
        $service_provider = Entity::ServiceProvider::Externalcluster->new(
                                externalcluster_name => $external_cluster_name
                            );

        # Create workflow defs for Entity::Component::Kanopyaworkflow0
        $wfmanager = Entity::Component::Kanopyaworkflow0->new(service_provider_id => $service_provider->id);
        $wfdefs[0] = $wfmanager->createWorkflowDef(workflow_name => 'my_workflow_def',
                                                   params        => {param_0 => 'param_0'});

        $wfdefs[1] = $wfmanager->createWorkflowDef(
                         workflow_name          => 'my_workflow_def_with_origin_no_params',
                     );

        $wfdefs[2] = $wfmanager->createWorkflowDef(
                         workflow_name          => 'my_workflow_def_with_origin_and_params',
                         params                 => {param_2 => 'param_2'},
                     );

        # Create workflow defs for Entity::Component::Sco
        $sco_wfmanager = Entity::Component::Sco->new(service_provider_id => $service_provider->id,
                                                     executor_component_id => Entity::Component::KanopyaExecutor->find->id);
        $sco_wfdefs[0] = $sco_wfmanager->createWorkflowDef(workflow_name => 'myscoworkflowdef',
                                                           params        => {sco_param_0 => 'sco_param_0'});

        # Create a service provider managed by Entity::Component::Sco
        my $sp_managed_by_sco = Entity::ServiceProvider->new();
        $sp_managed_by_sco->addManager(manager_id => $sco_wfmanager->id, manager_type => "WorkflowManager");

        $rules[0] = Entity::Rule::NodemetricRule->new(
                        service_provider_id => $sp_managed_by_sco->id,
                        formula => ' ',
                        state => 'enabled'
                    );

        $rules[1] = Entity::Rule::NodemetricRule->new(
                        service_provider_id => $sp_managed_by_sco->id,
                        formula             => ' ',
                        state               => 'enabled'
                   );

        $associations[0] = $rules[0]->associateWorkflow(
                              workflow_def_id => $sco_wfdefs[0]->id,
                              specific_params => {specific_1 => 'specific_1'},
                          );
        $sco_wfdefs[1] = $associations[0]->workflow_def;

        $associations[1] = $rules[0]->cloneAssociatedWorkflow(dest_rule => $rules[1]);
        $sco_wfdefs[2]  = $associations[1]->workflow_def;

        $sco_wfdefs[3] = $sco_wfmanager->createWorkflowDef(workflow_name => 'my_sco_workflow_def_2',
                                                           params        => {automatic => 'automatic_param',
                                                                             specific  => 'specific_param',});

        # Create a service provider managed by Entity::Component::Kanopyaworkflow0
        my $sp_managed_by_kwf = Entity::ServiceProvider->new();
        $sp_managed_by_kwf->addManager(manager_id => $wfmanager->id, manager_type => "WorkflowManager");

        $rules[2] = Entity::Rule::NodemetricRule->new(
                        service_provider_id => $sp_managed_by_kwf->id,
                        formula             => ' ',
                        state               => 'enabled'
                    );

        $wfdefs[3] = $rules[2]->associateWorkflow(
                         workflow_def_id => $wfdefs[0]->id,
                     )->workflow_def;

    } 'Objects creation';
}
1;