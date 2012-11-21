# WorkflowManager.pm - Object class of Workflow Manager included in Administrator

#    Copyright © 2011 Hedera Technology SAS
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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.
# Created 7 June 2012

package Manager::WorkflowManager;
use base "Manager";

use strict;
use warnings;
use Kanopya::Exceptions;
use General;
use Hash::Merge;

use Log::Log4perl "get_logger";
my $log = get_logger("");
use Data::Dumper;

use Entity::AggregateRule;
use Entity::NodemetricRule;
use Entity::WorkflowDef;
use WorkflowDefManager;
use ParamPreset;
use Scope;

sub methods {
  return {
    'getWorkflowDefsIds'    => {
        'description'   => 'getWorkflowDefsIds',
        'perm_holder'   => 'entity'
    },
    'getWorkflowDefs'    => {
        'description'   => 'getWorkflowDefs',
        'perm_holder'   => 'entity'
    },
    'createWorkflow'        => {
        'description'   => 'createWorkflow',
        'perm_holder'   => 'entity'
    },
    '_getAllParams'             => {
        'description'   => 'getParams',
        'perm_holder'   => 'entity'
    },
    'associateWorkflow'     => {
        'description'   => 'associateWorkflow',
        'perm_holder'   => 'entity'
    },
    'deassociateWorkflow'     => {
        'description'   => 'deassociateWorkflow',
        'perm_holder'   => 'entity'
    }
  };
}

=head2 checkWorkflowManagerParams

=cut

sub checkWorkflowManagerParams {
    throw Kanopya::Exception::NotImplemented();
}

=head2 createWorkflow
    Desc: Create a new instance of WorkflowDef. Can be use for initial workflow
    instanciation, but also for workflow definition (with defined specific
    parameters)

    Args: $workflow_name (string), \%workflow_params, $workflow_def_origin (id)

    Return: created workflow (object)
=cut

sub createWorkflow {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_name' ]);

    my $workflow_def_name   = $args{workflow_name};
    my %workflow_def_params;
    my $workflow;

    #creation of a new instance of workflow_def
    if (defined $args{params}) {
        %workflow_def_params = %{$args{params}};

        if ((!exists $workflow_def_params{automatic}) && (!exists $workflow_def_params{specific})) {
            #sort the specific params from the automatic params
            my $params = $self->_getSortedParams(
                             params => \%workflow_def_params
                         );

            #append the automatic and specific params to workflow params
            $workflow_def_params{automatic} = $params->{automatic};
            $workflow_def_params{specific}  = $params->{specific};
        }

        $workflow = Entity::WorkflowDef->new(
                        workflow_def_name   => $workflow_def_name,
                        workflow_def_origin => $args{workflow_def_origin},
                        params              => \%workflow_def_params,
                    );
    } else {
        $workflow = Entity::WorkflowDef->new(
                        workflow_def_name   => $workflow_def_name,
                        workflow_def_origin => $args{workflow_def_origin}
                    );
    }

    #now associating the new workflow to the manager
    my $workflow_def_id = $workflow->getAttr(name => 'workflow_def_id');
    my $manager_id      = $self->getId;
    WorkflowDefManager->new(
        manager_id => $manager_id,
        workflow_def_id => $workflow_def_id
    );

    return $workflow;
}

=head2 deassociateWorkflow
    Desc: remove the instance of WorkflowDef associated to a rule

    Args:
          $rule_id
          $workflow_def_id

=cut

sub deassociateWorkflow {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'rule_id', 'workflow_def_id' ]);

    my $workflow_def    = Entity::WorkflowDef->find(hash => {workflow_def_id => $args{workflow_def_id}});
    my $workflow_params = $workflow_def->paramPresets;

    # Unlink workflow to rule
    $self->_linkWorkflowToRule(
               workflow => undef,
               rule_id  => $args{rule_id},
               scope_id => $workflow_params->{internal}->{scope_id}
           );

    # Delete workflow def
    $workflow_def->delete();
}

=head2 associateWorkflow
    Desc: create a new instance of WorkflowDef that has defined specific
          parameters. This instance will be used for future runs

    Args: $new_workflow_name (string),
          $origin_workflow_def_id,
          \%specific_params,
          $rule_id

    Return: created workflow object (get by calling createWorkflow())
=cut

sub associateWorkflow {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'new_workflow_name',
                                                       'origin_workflow_def_id',
                                                       'specific_params',
                                                       'rule_id', ]);

    my $workflow_def_id      = $args{origin_workflow_def_id};
    my $origin_workflow_name = $self->getWorkflowDef (workflow_def_id => $workflow_def_id)
                                   ->getAttr(name => 'workflow_def_name');
    my $specific_params      = $args{specific_params};

    #check if the workflow name is an already existing workflow. If not
    #throw an error => you can only associate an existing workflow to
    #a rule

    #get all workflow defs related to this manager
    my $workflow_defs = $self->getWorkflowDefs();
    #initiate a counter to recense existing workflows
    my $existing_origin_workflows = 0;

    #TODO fix algo issue: use only grep on @$workflow_defs to match good name
    #use: check that the to-associate workflow is a managed one

#    foreach my $workflow_def (@$workflow_defs) {
#        if((grep {$_->getAttr(name => 'workflow_def_name')
#        eq $origin_workflow_name} $workflow_def) == 1) {
#            $existing_origin_workflows++;
#        }
#    }
#    if ($existing_origin_workflows == 0) {
#        my $errmsg = 'Unknown workflow_def name '.$origin_workflow_name;
#        throw Kanopya::Exception(error => $errmsg);
#    }

    #get the original workflow's params and replace undefined specific params
    #with the now defined specific params
    my $workflow_params = $self->_getAllParams(
                              workflow_def_id => $workflow_def_id
                          );
    $workflow_params->{specific} = $specific_params;

    #add special parameter to indicate that the workflow is associated
    #to a rule
    $workflow_params->{internal}->{association} = 1;

    my $workflow = $self->createWorkflow(
                       workflow_name        => $args{new_workflow_name},
                       params               => $workflow_params,
                       workflow_def_origin  => $workflow_def_id
                   );

    #Then we finally link the workflow to the rule
    $self->_linkWorkflowToRule(
               workflow => $workflow,
               rule_id  => $args{rule_id},
               scope_id => $workflow_params->{internal}->{scope_id}
           );

    return $workflow;
}

=head2 cloneWorkflow
    Desc: create a new instance of WorkflowDef from an existing instance

    Args: workflow_def_id id of the workflow def to clone
          rule_id id of the rule linked to the cloned instance

=cut

sub cloneWorkflow {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_def_id', 'rule_id' ]);
    my $rule_id = $args{rule_id};

    # Get original workflow def and params
    my $wf_def      = WorkflowDef->get(id => $args{workflow_def_id});
    my $wf_params   = $wf_def->paramPresets;
    my $wf_name     = $wf_def->workflow_def_name;

    # Replacing in workflow name the id of original rule with id of this rule
    # TODO change associated workflow naming convention (currently: <ruleid>_<origin_wf_def_name>) UGLY!
    $wf_name =~ s/^[0-9]*/$rule_id/;

    # Associate to the rule a copy of the workflow
    $self->associateWorkflow(
        'new_workflow_name'         => $wf_name,
        'origin_workflow_def_id'    => $wf_def->workflow_def_origin,
        'specific_params'           => $wf_params->{specific} || {},
        'rule_id'                   => $rule_id,
    );
}

=head2 _linkWorkflowToRule
    Desc: link or unlink a workflow to a rule

    Args:   $workflow (object to bind or undef for unbind current workflow)
            $rule_id
            $scope_id

    Return:
=cut

sub _linkWorkflowToRule {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'rule_id', 'scope_id' ], optional => { 'workflow' => undef });

    my $workflow = $args{workflow};
    my $rule_id  = $args{rule_id};
    my $scope_id = $args{scope_id};
    my $rule;

    #get workflow def id
    my $workflow_def_id = defined $workflow ? $workflow->getAttr(name => 'workflow_def_id') : undef;

    #we get the scope name
    my $scope      = Scope->find(hash => {scope_id => $scope_id});
    my $scope_name = $scope->getAttr(name => 'scope_name');

    if ($scope_name eq 'node') {
        $rule = Entity::NodemetricRule->find (hash => {nodemetric_rule_id => $rule_id});
        $rule->setAttr (name => 'workflow_def_id', value => $workflow_def_id);
        $rule->save();

    } elsif ($scope_name eq 'service_provider') {
        $rule = Entity::AggregateRule->find(hash => {aggregate_rule_id => $rule_id});
        $rule->setAttr (name => 'workflow_def_id', value => $workflow_def_id);
        $rule->save();
    }
}

=head2 runWorkflow
    Desc: run a workflow

    Args:

    Return:
=cut

sub runWorkflow {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_def_id', 'rule_id', 'service_provider_id' ]);

    my $rule_id             = $args{rule_id};
    my $workflow_def_id     = $args{workflow_def_id};
    my $service_provider_id = $args{service_provider_id};

    my $workflow            = $self->getWorkflowDef(
                                  workflow_def_id => $workflow_def_id
                              );
    my $workflow_name       = $workflow->getAttr(
                                  name => 'workflow_def_name'
                              );

    #gather the workflow params
    my $all_params = $self->_getAllParams(
                        workflow_def_id => $workflow_def_id
                     );

    my $scope_id   = $all_params->{internal}->{scope_id};

    #resolve the automatic params values
    my $automatic_values;
    $automatic_values = $self->_getAutomaticValues(
            automatic_params => $all_params->{automatic},
            scope_id         => $scope_id,
            %args,
        );

    #replace the undefined automatic params with the defined ones
    $all_params->{automatic} = $automatic_values;

    #prepare final workflow params hash
    my $workflow_params = $self->_defineFinalParams(
                              all_params    => $all_params,
                              workflow_name => $workflow_name,
                              rule_id       => $rule_id,
                              sp_id         => $service_provider_id,
                          );

    #run the workflow with the fully defined params
    return Entity::Workflow->run(
               name       => $workflow_name,
               related_id => $service_provider_id,
               params     => $workflow_params,
               # TODO: Uncomment the following line once rules becomme entities.
               # rule    => Entity->get(id => $rule_id),
           );
}

=head2 getWorkflowDefs
    Desc: Get a list of workflow defs related to the manager

    Args: (optional) no_associate : if defined, returns only workflow defs not associated to a rule

    Return: array of objects, \@manager_workflow_defs
=cut

sub getWorkflowDefs {
    my ($self,%args) = @_;

    #first we gather all the workflow def related to the current manager
    my @manager_workflow_defs = WorkflowDefManager->search (
                            hash => {manager_id => $self->getId}
                        );

    #then we create a list of workflow_def from the manager workflow_defs
    my @workflow_defs;

    foreach my $manager_workflow_def (@manager_workflow_defs) {
        my $workflow_def = $manager_workflow_def->workflow_def;
        my $ok = 1;
        if ($args{no_associate}) {
            my $all_params = $workflow_def->paramPresets;
            if ($all_params->{internal}{association}) {
                $ok = 0;
            }
        }
        push @workflow_defs, $workflow_def if $ok;
    }

    return \@workflow_defs;
}

=head2 getWorkflowDef
    Desc: Get a workflow def from its id

    Args: workflow_def_id

    Return: reference on an object, $workflow_def
=cut

sub getWorkflowDef {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_def_id' ]);

    my $workflow_def = Entity::WorkflowDef->find (
                            hash => {workflow_def_id => $args{workflow_def_id}}
                       );

    return $workflow_def;
}

=head2 _getAutomaticParams
    Desc: Get the automatic params list for a workflow def.

    Args: workflow_def_id, \@all_params, $scope_id

    Return: \%automatic_params (param name as keys, undef as value)
=cut

sub _getAutomaticParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => ['data_params','scope_id']);

    my $data_params          = $args{data_params};
    my $scope_id             = $args{scope_id};
    my $scope_parameter_list = $self->getScopeParameterNameList(
                                    scope_id => $scope_id
                               );

    my %automatic_params;

    for my $param (@$scope_parameter_list) {
        if (exists $data_params->{$param}){
            $automatic_params{$param} = undef;
        }
    }

    return \%automatic_params;
}

=head2 getParams
    Desc: get specific and automatic params from workflow_def_id. Usefull for
          GUI when retriving specific and automatic params is required

    Args: $workflow_def_id

    Return: \%params ($params{automatic}, $params{specific})
=cut

sub getParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_def_id' ]);

    my $workflow_def_id = $args{workflow_def_id};
    my %params;
    $params{automatic} = undef;
    $params{specific}  = undef;

    #retrieve all workflow params
    my $all_params = $self->_getAllParams(workflow_def_id => $workflow_def_id);

    $params{automatic} = $all_params->{automatic};
    $params{specific}  = $all_params->{specific};

    return \%params;
}

=head2 _getSortedParams
    Desc: With the given params for a workflow def, extract the "data" params,
    and then differenciate between them the automatic and specific
    parameters.

    Args: \%params

    Return: \%sorted_params ($sorted_params{automatic}, $sorted_params{specific})
=cut

sub _getSortedParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'params' ]);

    #get all workflow params
    my $all_params         = $args{params};

    my $brut_data_params   = $all_params->{data};

    #extract the parameter from the raw data given as parameter to the workflow
    my $prepared_data_params = $self->_prepareParams(
                                data_params => $brut_data_params
                             );
    my $scope_id           = $all_params->{internal}->{scope_id};

    #now differenciate automatic params from specific ones
    my %sorted_params;
    $sorted_params{automatic}  = undef;
    $sorted_params{specific}   = undef;

    #get automatic params
    $sorted_params{automatic} = $self->_getAutomaticParams(
                                    data_params => $prepared_data_params,
                                    scope_id    => $scope_id
                                );
    #get specific params
    $sorted_params{specific} = $self->getSpecificParams(
                                data_params => $prepared_data_params,
                                scope_id    => $scope_id
                               );

    return \%sorted_params;
}

=head2 getSpecificParams
    Desc: Get the automatic params list for a workflow def.

    Args: workflow_def_id, \@all_params, $scope_id

    Return: \%all_params (param name as keys, undef as value)
=cut

sub getSpecificParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'scope_id', 'data_params' ]);
    my $data_params           = $args{data_params};
    my $scope_id              = $args{scope_id};
    my $scope_parameter_list  = $self->getScopeParameterNameList(
                                    scope_id => $scope_id
                               );

    # Remove automatic params
    for my $scope_parameter (@$scope_parameter_list) {
        delete $data_params->{$scope_parameter};
    };

    return $data_params;
}

sub getWorkflowDefsIds() {
    my ($self,%args)    = @_;

    my $manager_id      = $self->getId;
    my @wfids           = ();
    my @workflow_def    = WorkflowDefManager->search (
                            hash => {manager_id => $manager_id}
                        );
    for my $wf (@workflow_def) {
      push(@wfids, $wf->getAttr(name => 'workflow_def_id'));
    }
    return \@wfids;
}

=head2 _getAllParams
    Desc: Get the full params list for a workflow def.

    Args: workflow_def_id

    Return: \%all_params
=cut

sub _getAllParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_def_id' ]);

    my $workflow_def_id = $args{workflow_def_id};

    #get the param preset id from the workflow def
    my $workflow_def = $self->getWorkflowDef(workflow_def_id=>$workflow_def_id);
    my $all_params   = $workflow_def->paramPresets;

    return $all_params;
}

=head2 getScopeParameterNameList
    Desc: Get a params list for a scope

    Args: scope_id

    Return: \@scope_params
=cut

sub getScopeParameterNameList {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'scope_id' ]);

    my @scopeParameterList = ScopeParameter->search(
                                hash=>{scope_id => $args{scope_id}}
                             );
    my @scope_params = map {$_->getAttr(name => 'scope_parameter_name')}
                            @scopeParameterList;

    return \@scope_params;
}

=head2 _prepareParams
    Desc: Retrieve the list of effective parameters desired by the user in the
          final file

    Args: \%brut_data_params

    Return: \%prepared_data_params
=cut

sub _prepareParams { };

1;
