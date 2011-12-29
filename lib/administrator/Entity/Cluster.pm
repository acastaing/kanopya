# Cluster.pm - This object allows to manipulate cluster configuration
#    Copyright 2011 Hedera Technology SAS
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
# Created 3 july 2010
package Entity::Cluster;
use base "Entity";

use strict;
use warnings;

use Kanopya::Exceptions;
use Entity::Component;
use Entity::Host;
use Entity::Systemimage;
use Entity::Tier;
use Operation;
use Administrator;
use General;

use Log::Log4perl "get_logger";
use Data::Dumper;

our $VERSION = "1.00";

my $log = get_logger("administrator");
my $errmsg;
use constant ATTR_DEF => {
    cluster_name            =>  {pattern        => '^\w*$',
                                 is_mandatory   => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    cluster_desc            =>  {pattern        => '^.*$',
                                 is_mandatory   => 0,
                                 is_extended    => 0,
                                 is_editable    => 1},
    cluster_type            =>  {pattern        => '^.*$',
                                 is_mandatory    => 0,
                                 is_extended    => 0,
                                 is_editable    => 0},
    cluster_si_location     =>  {pattern        => '^(diskless|local)$',
                                 is_mandatory    => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    cluster_si_access_mode  =>  {pattern        => '^(ro|rw)$',
                                 is_mandatory    => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    cluster_si_shared       =>  {pattern        => '^(0|1)$',
                                 is_mandatory    => 1,
                                 is_extended    => 0,
                                 is_editable    => 0},
    cluster_min_node        => {pattern         => '^\d*$',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 1},
    cluster_max_node        => {pattern            => '^\d*$',
                                is_mandatory    => 1,
                                is_extended        => 0,
                                is_editable        => 1},
    cluster_priority        => {pattern         => '^\d*$',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 1},
    active                    => {pattern            => '^[01]$',
                                is_mandatory    => 0,
                                is_extended        => 0,
                                is_editable        => 0},
    systemimage_id            => {pattern         => '\d*',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 0},
    kernel_id                => {pattern         => '^\d*$',
                                is_mandatory    => 0,
                                is_extended     => 0,
                                is_editable        => 1},
    cluster_state            => {pattern         => '^up:\d*|down:\d*|starting:\d*|stopping:\d*$',
                                is_mandatory    => 0,
                                is_extended     => 0,
                                is_editable        => 0},
    cluster_domainname      => {pattern         => '^[a-z0-9-]+(\.[a-z0-9-]+)+$',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 0},
    cluster_nameserver        => {pattern         => '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 0},
    cluster_basehostname            => {pattern         => '^[a-z_]+$',
                                is_mandatory    => 1,
                                is_extended     => 0,
                                is_editable        => 1},


    };

sub methods {
    return {
        'create'    => {'description' => 'create a new cluster',
                        'perm_holder' => 'mastergroup',
        },
        'get'        => {'description' => 'view this cluster',
                        'perm_holder' => 'entity',
        },
        'update'    => {'description' => 'save changes applied on this cluster',
                        'perm_holder' => 'entity',
        },
        'remove'    => {'description' => 'delete this cluster',
                        'perm_holder' => 'entity',
        },
        'addNode'    => {'description' => 'add a node to this cluster',
                        'perm_holder' => 'entity',
        },
        'removeNode'=> {'description' => 'remove a node from this cluster',
                        'perm_holder' => 'entity',
        },
        'activate'=> {'description' => 'activate this cluster',
                        'perm_holder' => 'entity',
        },
        'deactivate'=> {'description' => 'deactivate this cluster',
                        'perm_holder' => 'entity',
        },
        'start'=> {'description' => 'start this cluster',
                        'perm_holder' => 'entity',
        },
        'stop'=> {'description' => 'stop this cluster',
                        'perm_holder' => 'entity',
        },
        'forceStop'=> {'description' => 'force stop this cluster',
                        'perm_holder' => 'entity',
        },
        'setperm'    => {'description' => 'set permissions on this cluster',
                        'perm_holder' => 'entity',
        },
        'addComponent'    => {'description' => 'add a component to this cluster',
                        'perm_holder' => 'entity',
        },
        'removeComponent'    => {'description' => 'remove a component from this cluster',
                        'perm_holder' => 'entity',
        },
        'configureComponents'    => {'description' => 'configure components of this cluster',
                        'perm_holder' => 'entity',
        },
    };
}

=head2 get

=cut

sub get {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['id']);

    my $admin = Administrator->new();
    my $dbix_cluster = $admin->{db}->resultset('Cluster')->find($args{id});
    if(not defined $dbix_cluster) {
        $errmsg = "Entity::Cluster->get : id <$args{id}> not found !";
     $log->error($errmsg);
     throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
    }

    my $entity_id = $dbix_cluster->entitylink->get_column('entity_id');
    my $granted = $admin->{_rightchecker}->checkPerm(entity_id => $entity_id, method => 'get');
    if(not $granted) {
        throw Kanopya::Exception::Permission::Denied(error => "Permission denied to get cluster with id $args{id}");
    }
    my $self = $class->SUPER::get( %args,  table => "Cluster");
    $self->{_ext_attrs} = $self->getExtendedAttrs(ext_table => "clusterdetails");
    return $self;
}

=head2 getClusters

=cut

sub getClusters {
    my $class = shift;
    my %args = @_;
    my @objs = ();
    my ($rs, $entity_class);

    General::checkParams(args => \%args, required => ['hash']);

    return $class->SUPER::getEntities( %args,  type => "Cluster");
}

sub getCluster {
    my $class = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['hash']);

    my @clusters = $class->SUPER::getEntities( %args,  type => "Cluster");
    return pop @clusters;
}

=head2 new

=cut

sub new {
    my $class = shift;
    my %args = @_;

    # Check attrs ad throw exception if attrs missed or incorrect
    my $attrs = $class->checkAttrs(attrs => \%args);

    # We create a new DBIx containing new entity (only global attrs)
    my $self = $class->SUPER::new( attrs => $attrs->{global},  table => "Cluster");

    # Set the extended parameters
    $self->{_ext_attrs} = $attrs->{extended};

    return $self;
}

=head2 create

=cut

sub create {
    my $self = shift;

    my $admin = Administrator->new();
    my $mastergroup_eid = $self->getMasterGroupEid();
       my $granted = $admin->{_rightchecker}->checkPerm(entity_id => $mastergroup_eid, method => 'create');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to create a new user");
       }
    # Before cluster creation check some integrity configuration
    # Check if min node <
    $log->info("###### Cluster creation with min node <".$self->getAttr(name => "cluster_min_node") . "> and max node <". $self->getAttr(name=>"cluster_max_node").">");
    if ($self->getAttr(name => "cluster_min_node") > $self->getAttr(name=>"cluster_max_node")){
	throw Kanopya::Exception::Internal::WrongValue(error=> "Min node is superior to max node");
    }

    my %params = $self->getAttrs();
    $log->debug("New Operation Create with attrs : " . %params);
    Operation->enqueue(
        priority => 200,
        type     => 'AddCluster',
        params   => \%params,
    );
}

=head2 update

=cut

sub update {
    my $self = shift;
    my $adm = Administrator->new();
    # update method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'update');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to update this entity");
       }
    # TODO update implementation
}

=head2 remove

=cut

sub remove {
    my $self = shift;
    my $adm = Administrator->new();
    # delete method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'delete');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to delete this entity");
       }
    my %params;
    $params{'cluster_id'}= $self->getAttr(name =>"cluster_id");
    $log->debug("New Operation Remove Cluster with attrs : " . %params);
    Operation->enqueue(
        priority => 200,
        type     => 'RemoveCluster',
        params   => \%params,
    );
}

sub forceStop {
    my $self = shift;
    my $adm = Administrator->new();
    # delete method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'forceStop');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to force stop this entity");
       }
    my %params;
    $params{'cluster_id'}= $self->getAttr(name =>"cluster_id");
    $log->debug("New Operation Force Stop Cluster with attrs : " . %params);
    Operation->enqueue(
        priority => 200,
        type     => 'ForceStopCluster',
        params   => \%params,
    );
}

sub extension { return "clusterdetails"; }

sub activate {
    my $self = shift;

    $log->debug("New Operation ActivateCluster with cluster_id : " . $self->getAttr(name=>'cluster_id'));
    Operation->enqueue(priority => 200,
                   type     => 'ActivateCluster',
                   params   => {cluster_id => $self->getAttr(name=>'cluster_id')});
}

sub deactivate {
    my $self = shift;

    $log->debug("New Operation DeactivateCluster with cluster_id : " . $self->getAttr(name=>'cluster_id'));
    Operation->enqueue(priority => 200,
                   type     => 'DeactivateCluster',
                   params   => {cluster_id => $self->getAttr(name=>'cluster_id')});
}

sub getAttrDef{
    return ATTR_DEF;
}

sub getTiers {
    my $self = shift;
    
    my %tiers;
    my $rs_tiers = $self->{_dbix}->tiers;
    if (! defined $rs_tiers) {
        return;
    }
    else {
        my %tiers;
        while ( my $tier_row = $rs_tiers->next ) {
            my $tier_id = $tier_row->get_column("tier_id");
            $tiers{$tier_id} = Entity::Tier->get(id => $tier_id);
        }
    }
    return \%tiers;
}


=head2 toString

    desc: return a string representation of the entity

=cut

sub toString {
    my $self = shift;
    my $string = $self->{_dbix}->get_column('cluster_name');
    return $string;
}

=head2 getComponents

    Desc : This function get components used in a cluster. This function allows to select
            category of components or all of them.
    args:
        administrator : Administrator : Administrator object to instanciate all components
        category : String : Component category
    return : a hashref of components, it is indexed on component_instance_id

=cut

sub getComponents {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['category']);

#    my $adm = Administrator->new();
    my $comp_instance_rs = $self->{_dbix}->search_related("component_instances", undef,
                                            { '+columns' => {"component_name" => "component.component_name",
                                                            "component_version" => "component.component_version",
                                                            "component_category" => "component.component_category"},
#                                                [ "component.component_name",
#                                                              "component.component_category",
#                                                              "component.component_version"],
                                           join => ["component"]});

    my %comps;
    $log->debug("Category is $args{category}");
    while ( my $comp_instance_row = $comp_instance_rs->next ) {
        my $comp_category = $comp_instance_row->get_column('component_category');
        $log->debug("Component category: $comp_category");
        my $comp_instance_id = $comp_instance_row->get_column('component_instance_id');
        $log->debug("Component instance id: $comp_instance_id");
        my $comp_name = $comp_instance_row->get_column('component_name');
        $log->debug("Component name: $comp_name");
        my $comp_version = $comp_instance_row->get_column('component_version');
        $log->debug("Component version: $comp_version");
        if (($args{category} eq "all")||
            ($args{category} eq $comp_category)){
            $log->debug("One component instance found with " . ref($comp_instance_row));
#            my $class= "Entity::Component::" . $comp_category . "::" . $comp_name . $comp_version;
            my $class= "Entity::Component::" . $comp_name . $comp_version;
            my $loc = General::getLocFromClass(entityclass=>$class);
            eval { require $loc; };
            $comps{$comp_instance_id} = $class->get(id =>$comp_instance_id);
        }
    }
    return \%comps;
}

=head2 getComponent

    Desc : This function get component used in a cluster. This function allows to select
            a particular component with its name and version.
    args:
        administrator : Administrator : Administrator object to instanciate all components
        name : String : Component name
        version : String : Component version
    return : a component instance

=cut

sub getComponent{
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['name','version']);

    my $hash = {'component.component_name' => $args{name}, 'component.component_version' => $args{version}};
    my $comp_instance_rs = $self->{_dbix}->search_related("component_instances", $hash,
                                            { '+columns' => {"component_name" => "component.component_name",
                                                            "component_version" => "component.component_version",
                                                            "component_category" => "component.component_category"},
                                                    join => ["component"]});

    $log->debug("name is $args{name}, version is $args{version}");
    my $comp_instance_row = $comp_instance_rs->next;
    if (not defined $comp_instance_row) {
        throw Kanopya::Exception::Internal(error => "Component with name '$args{name}' version $args{version} not installed on this cluster");
    }
    $log->debug("Comp name is " . $comp_instance_row->get_column('component_name'));
    $log->debug("Component instance found with " . ref($comp_instance_row));
    my $comp_category = $comp_instance_row->get_column('component_category');
    my $comp_instance_id = $comp_instance_row->get_column('component_instance_id');
    my $comp_name = $comp_instance_row->get_column('component_name');
    my $comp_version = $comp_instance_row->get_column('component_version');
#    my $class= "Entity::Component::" . $comp_category . "::" . $comp_name . $comp_version;
    my $class= "Entity::Component::" . $comp_name . $comp_version;
    my $loc = General::getLocFromClass(entityclass=>$class);
    eval { require $loc; };
    return "$class"->get(id =>$comp_instance_id);
}

sub getComponentByInstanceId{
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['component_instance_id']);

    my $hash = {'component_instance_id' => $args{component_instance_id}};
    my $comp_instance_rs = $self->{_dbix}->search_related("component_instances", $hash,
                                            { '+columns' => {"component_name" => "component.component_name",
                                                            "component_version" => "component.component_version",
                                                            "component_category" => "component.component_category"},
                                                    join => ["component"]});

    my $comp_instance_row = $comp_instance_rs->next;
    if (not defined $comp_instance_row) {
        throw Kanopya::Exception::Internal(error => "Component with component_instance_id '$args{component_instance_id}' not found on this cluster");
    }
    $log->debug("Comp name is " . $comp_instance_row->get_column('component_name'));
    $log->debug("Component instance found with " . ref($comp_instance_row));
    my $comp_category = $comp_instance_row->get_column('component_category');
    my $comp_instance_id = $comp_instance_row->get_column('component_instance_id');
    my $comp_name = $comp_instance_row->get_column('component_name');
    my $comp_version = $comp_instance_row->get_column('component_version');
    my $class= "Entity::Component::" . $comp_name . $comp_version;
    my $loc = General::getLocFromClass(entityclass=>$class);
    eval { require $loc; };
    return "$class"->get(id =>$comp_instance_id);
}

=head2 getSystemImage

    Desc : This function return the cluster's system image.
    args:
        administrator : Administrator : Administrator object to instanciate all components
    return : a system image instance

=cut

sub getSystemImage {
    my $self = shift;
    my $systemimage_id = $self->getAttr(name => 'systemimage_id');
    if($systemimage_id) {
        return Entity::Systemimage->get(id => $systemimage_id);
    } else {
        # only admin cluster has no systemimage ?
        return;
    }
}

sub getMasterNodeIp {
    my $self = shift;
    my $adm = Administrator->new();
    my $node_instance_rs = $self->{_dbix}->search_related("nodes", { master_node => 1 })->single;
    if(defined $node_instance_rs) {
         my $host_ipv4_internal_id = $node_instance_rs->host->get_column('host_ipv4_internal_id');
         my $node_ip = $adm->{manager}->{network}->getInternalIP(ipv4_internal_id => $host_ipv4_internal_id)->{ipv4_internal_address};
        $log->debug("Master node found and its ip is $node_ip");
        return $node_ip;
    } else {
        $log->debug("No Master node found for this cluster");
        return;
    }
}

sub getMasterNodeId {
    my $self = shift;
    my $node_instance_rs = $self->{_dbix}->search_related("nodes", { master_node => 1 })->single;
    if(defined $node_instance_rs) {
        my $id = $node_instance_rs->host->get_column('host_id');
        return $id;
    } else {
        return;
    }
}

=head2 addComponent

create a new component instance
this is the first step of cluster setting

=cut

sub addComponent {
    my $self = shift;
    my %args = @_;
    my $noconf;

    General::checkParams(args => \%args, required => ['component_id']);

    if(defined $args{noconf}){
        $noconf = $args{noconf};
        delete $args{noconf};
    }
    my $componentinstance = Entity::Component->new(%args, cluster_id => $self->getAttr(name => "cluster_id"));
    my $component_instance_id = $componentinstance->save();

    my $internal_cluster = Entity::Cluster->getCluster(hash => {cluster_name => 'adm'});
    $log->info('internal cluster;'.Dumper($internal_cluster));
    # Insert default configuration in db
    # Remark: we must get concrete instance here because the component->new (above) return an Entity::Component and not a concrete child component
    #          There must be a way to do this more properly (component management).
    my $concrete_component = Entity::Component->getInstance(id => $component_instance_id);
    if (! $noconf) {
        $concrete_component->insertDefaultConfiguration(internal_cluster => $internal_cluster);}
    return $component_instance_id;
}

=head2 removeComponent

remove a component instance and all its configuration
from this cluster

=cut

sub removeComponent {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['component_instance_id']);

    my $component_instance = Entity::Component->get(id => $args{component_instance_id});
    $component_instance->delete;

}

=head2 getHosts

    Desc : This function get hosts executing the cluster.
    args:
        administrator : Administrator : Administrator object to instanciate all components
    return : a hashref of host, it is indexed on host_id

=cut

sub getHosts {
    my $self = shift;

    my $host_rs = $self->{_dbix}->nodes;
    my %hosts;
    while ( my $node_row = $host_rs->next ) {
        my $host_row = $node_row->host;
        $log->debug("Nodes found");
        my $host_id = $host_row->get_column('host_id');
        eval { $hosts{$host_id} = Entity::Host->get (
                        id => $host_id,
                        type => "Host") };
    }
    return \%hosts;
}

=head2 getCurrentNodesCount

    class : public
    desc : return the current nodes count of the cluster

=cut

sub getCurrentNodesCount {
    my $self = shift;
    my $nodes = $self->{_dbix}->nodes;
    if ($nodes) {
    return $nodes->count;}
    else {
        return 0;
    }
}



sub getPublicIps {
    my $self = shift;

    my $publicip_rs = $self->{_dbix}->ipv4_publics;
    my $i =0;
    my @pub_ip =();
    while ( my $publicip_row = $publicip_rs->next ) {
        my $publicip = {publicip_id => $publicip_row->get_column('ipv4_public_id'),
                        address => $publicip_row->get_column('ipv4_public_address'),
                        netmask => $publicip_row->get_column('ipv4_public_mask'),
                        gateway => $publicip_row->get_column('ipv4_public_default_gw'),
                        name     => "eth0:$i",
                        cluster_id => $self->{_dbix}->get_column('cluster_id'),
        };
        $i++;
        push @pub_ip, $publicip;
    }
    return \@pub_ip;
}

=head2 getQoSConstraints

    Class : Public

    Desc :

=cut

sub getQoSConstraints {
    my $self = shift;
    my %args = @_;

    # TODO retrieve from db (it's currently done by RulesManager, move here)
    return { max_latency => 22, max_abort_rate => 0.3 } ;
}

=head2 addNode

=cut

sub addNode {
    my $self = shift;

    my $adm = Administrator->new();
    # addNode method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'addNode');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to add a node to this cluster");
       }
    my %params = (
        cluster_id => $self->getAttr(name =>"cluster_id"),
    );
    $log->debug("New Operation PreStartNode with attrs : " . %params);

    Operation->enqueue(
        priority => 200,
        type     => 'PreStartNode',
        params   => \%params,
    );
}

=head2 removeNode

=cut

sub removeNode {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['host_id']);

    my $adm = Administrator->new();
    # removeNode method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'removeNode');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to remove a node from this cluster");
       }
    my %params = (
        cluster_id => $self->getAttr(name =>"cluster_id"),
        host_id => $args{host_id},
    );
    $log->debug("New Operation AddHostInCluster with attrs : " . %params);

    Operation->enqueue(
        priority => 200,
        type     => 'PreStopNode',
        params   => \%params,
    );
}

=head2 start

=cut

sub start {
    my $self = shift;

    my $adm = Administrator->new();
    # start method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'start');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to start this cluster");
       }

    $log->debug("New Operation StartCluster with cluster_id : " . $self->getAttr(name=>'cluster_id'));
    Operation->enqueue(
        priority => 200,
        type     => 'StartCluster',
        params   => { cluster_id => $self->getAttr(name =>"cluster_id") },
    );
}

=head2 stop

=cut

sub stop {
    my $self = shift;

    my $adm = Administrator->new();
    # stop method concerns an existing entity so we use his entity_id
       my $granted = $adm->{_rightchecker}->checkPerm(entity_id => $self->{_entity_id}, method => 'stop');
       if(not $granted) {
           throw Kanopya::Exception::Permission::Denied(error => "Permission denied to stop this cluster");
       }

    $log->debug("New Operation StopCluster with cluster_id : " . $self->getAttr(name=>'cluster_id'));
    Operation->enqueue(
        priority => 200,
        type     => 'StopCluster',
        params   => { cluster_id => $self->getAttr(name =>"cluster_id") },
    );
}



=head2 getState

=cut

sub getState {
    my $self = shift;
    my $state = $self->{_dbix}->get_column('cluster_state');
    return wantarray ? split(/:/, $state) : $state;
}

=head2 setState

=cut

sub setState {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => ['state']);
    my $new_state = $args{state};
    my $current_state = $self->getState();
    $self->{_dbix}->update({'cluster_prev_state' => $current_state,
                            'cluster_state' => $new_state.":".time})->discard_changes();;
}
 #*******************************************************************************************************
 sub getBestNodeNumber{
  my $self = shift;
 my $count_node=$self->getCurrentNodesCount();
 $log->info("currentnode $count_node");
 if ($count_node==1)
 { 
 return ("1");
 }
 else
 {
  my $nodes =$self->getHosts();
  my @nodenumber_list;
 BOUCLE1:foreach my $node (keys %$nodes) 
   { 
	 my $tmp=$node->getNodeNumber();
	 push(@nodenumber_list,$tmp);
   }
    my $max_node= $self->getAttr(name =>"cluster_max_node");
    $log->debug("max_node = $max_node");
    my $i;
    my $node_num;
      for ($i=1;$i<=$max_node;$i++)
         {
          foreach $node_num(@nodenumber_list)
            {
		     if ($i!=$node_num)
		     {next;}
		     return("$i");
			 last BOUCLE1;
	        }
         }
}
}
 
 sub generateHostname{
	 my $self = shift;
	 my $bestNode_number=$self->getBestNodeNumber();
	 my $base_hostname = $self->getAttr(name=>'cluster_basehostname');
     $log->info("basehostname $base_hostname");
     return("$base_hostname"."$bestNode_number");
      $log->info("Hostname generated : $base_hostname.$bestNode_number");
	 
 }


1;
