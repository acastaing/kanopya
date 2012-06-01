# Copyright © 2011-2012 Hedera Technology SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package WorkflowInstance;
use base 'BaseDB';

use strict;
use warnings;

use Kanopya::Exceptions;

use General;
use ScopeParameter;
use Scope;
use WorkflowInstanceParameter;
use Entity::ServiceProvider::Outside;
use Node;
use Workflow;
use WorkflowDef;
use Entity::Host;
use Data::Dumper;
use Hash::Merge;
use Log::Log4perl 'get_logger';

my $log = get_logger('administrator');
my $errmsg;

use constant ATTR_DEF => {
    workflow_def_id => {
        pattern      => '^.*$',
        is_mandatory => 1,
        is_extended  => 0
    },
    aggregate_rule_id => {
        pattern      => '^.*$',
        is_mandatory => 0,
        is_extended  => 0
    },
    nodemetric_rule_id => {
        pattern      => '^.*$',
        is_mandatory => 0,
        is_extended  => 0
    },
};

sub getAttrDef { return ATTR_DEF; }

sub getWorkflowDef(){
    my ($self,%args) = @_;
    my $workflow_def_id = $self->getAttr(name => 'workflow_def_id');
    return WorkflowDef->get(id => $workflow_def_id);
}

sub getValues {
    my ($self,%args) = @_;
    General::checkParams(args => \%args, required => ['scope_id','all_params']);
    #required also node_id and cluster_id

    if((! defined $args{node_id}) && (! defined $args{cluster_id})){
        throw Kanopya::Exception(error => "node_id OR cluster_id is missing");
    }

    my $specific_parameter_values = $self->_getSpecificValues();
    my $automatic_values          = $self->getAutomaticValues(
                                               scope_id => $args{scope_id},
                                               all_params => $args{all_params},
                                               %args,
                                     );

    my $merge = Hash::Merge->new('RIGHT_PRECEDENT');
    my $fusion = $merge->merge($specific_parameter_values, $automatic_values);

    return $fusion;
}

sub setSpecificValues {
    my ($self,%args) = @_;
    General::checkParams(args => \%args, required => [ 'specific_params', 'workflow_instance_id' ]);

    my $specific_params      = $args{specific_params};
    my $workflow_instance_id = $args{workflow_instance_id};

    while (my ($param, $value) = each (%$specific_params)) {
        my $wfparams = {
            workflow_instance_parameter_name  => $param,
            workflow_instance_parameter_value => $value,
            workflow_instance_id              => $workflow_instance_id,
        };
        WorkflowInstanceParameter->new(%$wfparams);
    }
}

sub getScopeParameterNameList {
    my ($self,%args) = @_;
    General::checkParams(args => \%args, required => [ 'scope_id' ]);

    my @scopeParameterList = ScopeParameter->search(hash=>{scope_id => $args{scope_id}});
    my @array = map {$_->getAttr(name => 'scope_parameter_name')} @scopeParameterList;
    return \@array;
}

sub getSpecificParams {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'scope_name', 'all_params' ]);
    my $all_params = $args{all_params};
    my $scope_name = $args{scope_name};
    my $scope_id   = Scope->getIdFromName(scope_name => $scope_name);
    my $scope_parameter_list = $self->getScopeParameterNameList(
        scope_id => $scope_id
    );

    # Remove automatic params
    for my $scope_parameter (@$scope_parameter_list){
        delete $all_params->{$scope_parameter};
    };

    return $all_params;
}

sub _getSpecificValues {
    my ($self,%args) = @_;

    my $workflow_instance_id = $self->getAttr(name => 'workflow_instance_id');

    my @specific_parameter = WorkflowInstanceParameter->search(
        hash => {workflow_instance_id => $workflow_instance_id}
    );

    my $specific_parameter_values;
    my $specific_parameter_name;
    my $specific_parameter_value;

    foreach my $specific_parameter (@specific_parameter) {
        $specific_parameter_name  = $specific_parameter->getAttr (name => 'workflow_instance_parameter_name');
        $specific_parameter_value = $specific_parameter->getAttr (name => 'workflow_instance_parameter_value');
        $specific_parameter_values->{$specific_parameter_name} = $specific_parameter_value;
    }

    return $specific_parameter_values;
}

sub _getAutomaticParams {
    my ($self,%args) = @_;
    General::checkParams(args => \%args, required => [ 'scope_id', 'all_params' ]);
    my $all_params = $args{all_params};
    my $scope_id   = $args{scope_id};
    my $scope_parameter_list = $self->getScopeParameterNameList(
        scope_id => $scope_id
    );

    my $automatic_params = {};

    for my $param (@$scope_parameter_list) {
        if (exists $all_params->{$param}){
            $automatic_params->{$param} = undef;
        }
    }

    return $automatic_params;
}

sub getAutomaticValues {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => ['scope_id','all_params']);
    # need also node_id XOR cluster_id

    my $automatic_params = $self->_getAutomaticParams(
        scope_id    => $args{scope_id},
        all_params  => $args{all_params},
    );

    delete $args{scope_id};
    delete $args{all_params};

    for my $automatic_param_name (keys %$automatic_params){
        my $param_value = $self->_getAutomaticValue(
                              automatic_param_name => $automatic_param_name,
                              %args,
                          );
        $automatic_params->{$automatic_param_name} = $param_value;
    }

    return $automatic_params;
}

sub _getAutomaticValue {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => ['automatic_param_name']);

    if(defined $args{node_id}) {
        return $self->_getAutomaticNodeValue(%args);
    }
    elsif(defined $args{node_id}) {
        return $self->_getAutomaticClusterValue(%args);
    }
    else {
        throw Kanopya::Exception(error => "node_id OR cluster_id is missing");
    }
}

sub _getAutomaticNodeValue{
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => ['automatic_param_name','node_id']);
    my $automatic_param_name = $args{automatic_param_name};
    my $node_id              = $args{node_id};

    if($automatic_param_name eq 'node_id'){
        return $node_id;
    }
    elsif($automatic_param_name eq 'node_ip'){

        my $node                = Node->get(id => $node_id);
        my $host_id             = $node->getAttr(name => 'host_id');
        my $host                = Entity::Host->get(id=>$host_id);
        return $host->getAdminIp();

    }
    elsif($automatic_param_name eq 'node_name'){

        my $node                = Node->get(id => $node_id);
        my $host_id             = $node->getAttr(name => 'host_id');
        my $host                = Entity::Host->get(id=>$host_id);
        return $host->getAttr(name => 'host_hostname');

    }
    elsif($automatic_param_name eq 'ou_from'){

        my $node                = Node->get(id => $node_id);
        my $service_provider_id = $node->getAttr(name => 'inside_id');
        my $outside    = Entity::ServiceProvider::Outside
                              ->get('id' => $service_provider_id);
        my $directoryServiceConnector = $outside->getConnector(
                                                      'category' => 'DirectoryService'
                                                  );
        my $ou_from    = $directoryServiceConnector->getAttr(
                                                         'name' => 'ad_nodes_base_dn'
                                                 );
    }
    else{
        throw Kanopya::Exception(error => "Unknown automatic parameter $automatic_param_name in node scope");
    }
}

sub _getAutomaticClusterValue{
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => ['automatic_param_name','cluster_id']);
    my $automatic_param_name = $args{automatic_param_name};
    my $cluster_id           = $args{cluster_id};
    if($automatic_param_name eq 'cluster_id'){
        return $cluster_id;
    }
    else{
        throw Kanopya::Exception(error => "Unknown automatic parameter $automatic_param_name in node scope");
    }
}

sub _parse{
    my ($self, %args) = @_;

#   Template specific file may be moved if necessary

    General::checkParams(args => \%args, required => ['tt_file_path']);

    my $tt_file_path = $args{tt_file_path};

    my $scope_parameter_names;
    my $given_params;

    #open workflow template file
    open (my $FILE, "<", $tt_file_path);

    while (my $line = <$FILE>) {
        #$line =~ m/\[\% (.*?) \%\]/g;
        my @spl = split(/\[\% | \%\]/,$line);

        #stock the parameters in a list
        for(my $i = 1 ; $i < (scalar @spl) ;$i+=2 ){
            $given_params->{$spl[$i]} = undef;
        }
    }
    close ($FILE);

    return $given_params;
}

sub run {
    my ($self, %args) = @_;
    General::checkParams(args => \%args);
    if((! defined $args{node_id}) && (! defined $args{cluster_id})){
        throw Kanopya::Exception(error => "node_id OR cluster_id is missing");
    }

    my $workflow_def_params = $self->getWorkflowDef()->getParamPreset();

    my $template_dir     = $workflow_def_params->{template_dir};
    my $template_file    = $workflow_def_params->{template_file};
    my $output_directory = $workflow_def_params->{output_dir};
    my $scope_id         = $workflow_def_params->{scope_id};

    my $all_params = $self->_parse(tt_file_path => $template_dir.'/'.$template_file);

    my $params_wf     = $self->getValues(
                             all_params => $all_params,
                             scope_id   => $scope_id,
                             %args
                             );

    my $workflow_params     = {
        template_dir     => $template_dir,
        template_file    => $template_file,
        output_directory => $output_directory,
        filename         => 'workflow_'.time(),
        vars             => $params_wf,
    };

    my $workflow_def = $self->getWorkflowDef();
    my $name = $workflow_def->getAttr(name => 'workflow_def_name');
    Workflow->run(name=>$name,params => $workflow_params);
    return $params_wf;
}

1;
