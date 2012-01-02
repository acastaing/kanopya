# EPreStartNode.pm - Operation class implementing Cluster creation operation

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
# Created 14 july 2010

=head1 NAME

EEntity::Operation::EAddHost - Operation class implementing Host creation operation

=head1 SYNOPSIS

This Object represent an operation.
It allows to implement Host creation operation

=head1 DESCRIPTION

EPreStartNode allows to prepare cluster for node addition.
It takes as parameters :
- host_id : Int (Scalar) : host_id identifies host 
    which will be migrated into cluster to become a node.
- cluster_id : Int (Scalar) : cluster_id identifies cluster which will grow.

=head1 METHODS

=cut
package EOperation::EPreStartNode;
use base "EOperation";

use Kanopya::Exceptions;
use EFactory;
use Entity::Cluster;
use Entity::Host;
use Operation;
use strict;
use warnings;

use Log::Log4perl "get_logger";
use Data::Dumper;
use String::Random;
use Date::Simple (':all');
use Template;

my $log = get_logger("executor");
my $errmsg;

my $config = {
    INCLUDE_PATH => '/templates/internal/',
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 0,               # cleanup whitespace 
    EVAL_PERL    => 1,               # evaluate Perl code blocks
    RELATIVE => 1,                   # desactive par defaut
};


=head2 new

    my $op = EOperation::EAddHost->new();

    # Operation::EAddHost->new creates a new AddMotheboard operation.
    # RETURN : EOperation::EAddHost : Operation add motherboar on execution side

=cut

sub new {
    my $class = shift;
    my %args = @_;
    
    $log->debug("Class is : $class");
    my $self = $class->SUPER::new(%args);
    $self->_init();
    
    return $self;
}

=head2 _init

    $op->_init();
    # This private method is used to define some hash in Operation

=cut

sub _init {
    my $self = shift;
    $self->{nas} = {};
    $self->{executor} = {};
    $self->{bootserver} = {};
    $self->{monitor} = {};
    $self->{_objs} = {};
    return;
}

=head2 prepare

    $op->prepare(internal_cluster => \%internal_clust);

=cut

sub prepare {
    
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    $log->info("EPreStartNode Operation preparation");

    if (! exists $args{internal_cluster} or ! defined $args{internal_cluster}) { 
        $errmsg = "EPreStartNode->prepare need an internal_cluster named argument!";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }

    my $params = $self->_getOperation()->getParams();

    
    #### Get instance of Cluster Entity
    $log->info("Load cluster instance");
    $self->{_objs}->{cluster} = Entity::Cluster->get(id => $params->{cluster_id});
    $log->debug("get cluster self->{_objs}->{cluster} of type : " . ref($self->{_objs}->{cluster}));

    #### Get cluster components Entities
    $log->info("Load cluster component instances");
    $self->{_objs}->{components}= $self->{_objs}->{cluster}->getComponents(category => "all");
    $log->debug("Load all component from cluster");

    # Get instance of Host Entity
    $log->info("Load Host instance");
    my @free_hosts = Entity::Host->getFreeHosts();
    if ( scalar @free_hosts == 0) {
        $errmsg = "EPreStartNode->prepare no free host!";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal::IncorrectParam(error => $errmsg);
    }
    $self->{_objs}->{host} = $free_hosts[0];
    $log->debug("get Host self->{_objs}->{host} of type : " . ref($self->{_objs}->{host}));

    my $master_node_id = $self->{_objs}->{cluster}->getMasterNodeId();
    my $node_count = $self->{_objs}->{cluster}->getCurrentNodesCount();
    if (! $master_node_id && $node_count){
        $errmsg = "No master node when host <$free_hosts[0]> migrating, pls wait...";
        $log->error($errmsg);

        throw Kanopya::Exception::Internal(error => $errmsg);
    }

}

sub execute {
    my $self = shift;
    $log->debug("Before EOperation exec");
    $self->SUPER::execute();
    $log->debug("After EOperation exec and before new Adm");
    my $adm = Administrator->new();
    
        
    #TODO  component migrate (node, exec context?)
    my $components = $self->{_objs}->{components};
    $log->info('Processing cluster components configuration for this node');
    foreach my $i (keys %$components) {
        
        my $tmp = EFactory::newEEntity(data => $components->{$i});
        $log->debug("component is ".ref($tmp));
        $tmp->preStartNode(host => $self->{_objs}->{host}, 
                            cluster => $self->{_objs}->{cluster});
    }
    $self->{_objs}->{host}->becomeNode(cluster_id => $self->{_objs}->{cluster}->getAttr(name=>"cluster_id"),
                                                master_node => 0,node_number=>$self->{_objs}->{cluster}->getBestNodeNumber());
    $self->{_objs}->{host}->setNodeState(state=>"pregoingin");

} 
#node_number=>0,
sub _cancel {
    my $self = shift;

    my $params = $self->_getOperation()->getParams();

    my $cluster = Entity::Cluster->get(id => $params->{cluster_id});
    my $hosts = $cluster->getHosts();
    if (! scalar keys %$hosts) {
        $cluster->setState(state => 'down');
    }
}
1;
__END__

=head1 AUTHOR

Copyright (c) 2010 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
