package REST::api;

use Dancer ':syntax';
use Dancer::Plugin::REST;
use POSIX qw(ceil);

prefix undef;

use General;
use Entity;
use Entity::Operation;
use Workflow;
use Kanopya::Exceptions;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

my $API_VERSION = "0.1";

prepare_serializer_for_format;

my %resources = (
    "activedirectory"          => "Entity::Connector::ActiveDirectory",
    "aggregator"               => "Aggregator",
    "atftpd0"                  => "Entity::Component::Atftpd0",
    "aggregatecombination"     => "AggregateCombination",
    "aggregatecondition"       => "AggregateCondition",
    "aggregaterule"            => "AggregateRule",
    "apache2"                  => "Entity::Component::Apache2",
    "apache2virtualhost"       => "Apache2Virtualhost",
    "billinglimit"             => "Entity::Billinglimit",
    "cluster"                  => "Entity::ServiceProvider::Inside::Cluster",
    "clustermetric"            => "Clustermetric",
    "component"                => "Entity::Component",
    "componenttype"            => "ComponentType",
    "connector"                => "Entity::Connector",
    "connectortype"            => "ConnectorType",
    "container"                => "Entity::Container",
    "containeraccess"          => "Entity::ContainerAccess",
    "dashboard"                => "Dashboard",
    "entity"                   => "Entity",
    "entitycomment"            => "EntityComment",
    "externalcluster"          => "Entity::ServiceProvider::Outside::Externalcluster",
    "externalnode"             => "Externalnode",
    "filecontaineraccess"      => "Entity::ContainerAccess::FileContainerAccess",
    "fileimagemanager0"        => "Entity::Component::Fileimagemanager0",
    "gp"                       => "Entity::Gp",
    "haproxy1"                 => "Entity::Component::HAProxy1",
    "host"                     => "Entity::Host",
    "hostmodel"                => "Entity::Hostmodel",
    "iface"                    => "Entity::Iface",
    "indicator"                => "Indicator",
    "indicatorset"             => "Indicatorset",
    "infrastructure"           => "Entity::Infrastructure",
    "interface"                => "Entity::Interface",
    "interfacerole"            => "Entity::InterfaceRole",
    "inside"                   => "Entity::ServiceProvider::Inside",
    "ip"                       => "Ip",
    "iptables1"                => "Entity::Component::Iptables1",
    "iscsicontaineraccess"     => "Entity::ContainerAccess::IscsiContainerAccess",
    "iscsitarget1"             => "Entity::Component::Iscsitarget1",
    "kanopyacollector1"        => "Entity::Component::Kanopyacollector1",
    "keepalived1"              => "Entity::Component::Keepalived1",
    "kernel"                   => "Entity::Kernel",
    "lvm2"                     => "Entity::Component::Lvm2",
    "lvmcontainer"             => "Entity::Container::LvmContainer",
    "managerparam"             => "Entity::ManagerParameter",
    "masterimage"              => "Entity::Masterimage",
    "memcached1"               => "Entity::Component::Memcached1",
    "message"                  => "Message",
    "mockmonitor"              => "Entity::Connector::MockMonitor",
    "mounttable1"              => "Entity::Component::Mounttable1",
    "mysql5"                   => "Entity::Component::Mysql5",
    "netapp"                   => "Entity::ServiceProvider::Outside::Netapp",
    "netappaggregate"          => "Entity::NetappAggregate",
    "netapplun"                => "Entity::Container::NetappLun",
    "netapplunmanager"         => "Entity::Connector::NetappLunManager",
    "netappvolume"             => "Entity::Container::NetappVolume",
    "netappvolumemanager"      => "Entity::Connector::NetappVolumeManager",
    "network"                  => "Entity::Network",
    "nfscontaineraccessclient" => "Entity::NfsContainerAccessClient",
    "nfscontaineraccess"       => "Entity::ContainerAccess::NfsContainerAccess",
    "nfsd3"                    => "Entity::Component::Nfsd3",
    "nodemetriccombination"    => "NodemetricCombination",
    "nodemetriccondition"      => "NodemetricCondition",
    "nodemetricrule"           => "NodemetricRule",
    "node"                     => "Externalnode::Node",
    "notificationsubscription" => "NotificationSubscription",
    "openiscsi2"               => "Entity::Component::Openiscsi2",
    "opennebula3"              => "Entity::Component::Opennebula3",
    "parampreset"              => "ParamPreset",
    "permission"               => "Permissions",
    "php5"                     => "Entity::Component::Php5",
    "physicalhoster0"          => "Entity::Component::Physicalhoster0",
    "pleskpanel10"             => "Entity::ParallelsProduct::Pleskpanel10",
    "policy"                   => "Entity::Policy",
    "poolip"                   => "Entity::Poolip",
    "powersupplycard"          => "Entity::Powersupplycard",
    "powersupplycardmodel"     => "Entity::Powersupplycardmodel",
    "processormodel"           => "Entity::Processormodel",
    "profile"                  => "Profile",
    "puppetagent2"             => "Entity::Component::Puppetagent2",
    "puppetmaster2"            => "Entity::Component::Puppetmaster2",
    "openldap1"                => "Entity::Component::Openldap1",
    "openssh5"                 => "Entity::Component::Openssh5",
    "operation"                => "Entity::Operation",
    "operationtype"            => "Operationtype",
    "orchestrator"             => "Orchestrator",
    "outside"                  => "Entity::ServiceProvider::Outside",
    "sco"                      => "Entity::Connector::Sco",
    "scom"                     => "Entity::Connector::Scom",
    "scomindicator"            => "ScomIndicator",
    "scope"                    => "Scope",
    "scopeparameter"           => "ScopeParameter",
    "snmpd5"                   => "Entity::Component::Snmpd5",
    "serviceprovider"          => "Entity::ServiceProvider",
    "serviceprovidermanager"   => "ServiceProviderManager",
    "servicetemplate"          => "Entity::ServiceTemplate",
    "syslogng3"                => "Entity::Component::Syslogng3",
    "systemimage"              => "Entity::Systemimage",
    "tier"                     => "Entity::Tier",
    "ucsmanager"               => "Entity::Connector::UcsManager",
    "unifiedcomputingsystem"   => "Entity::ServiceProvider::Outside::UnifiedComputingSystem",
    "user"                     => "Entity::User",
    "userextension"            => "UserExtension",
    "userprofile"              => "UserProfile",
    "vlan"                     => "Entity::Network::Vlan",
    "workflow"                 => "Workflow",
    "workflowdef"              => "WorkflowDef",
    "alert"                    => "Alert",
    "mailnotifier0"            => "Entity::Component::Mailnotifier0",
    "linux0"                   => "Entity::Component::Linux0",
    "linux0mount"              => "Linux0Mount",
    "opennebula3repository"    => "Opennebula3Repository",
    "opennebula3hypervisor"    => "Opennebula3Hypervisor",
    "lvm2vg"                   => "Lvm2Vg",
);

sub db_to_json {
    my $obj = shift;
    my $expand = shift || [];

    my $basedb;
    my $json;
    if ($obj->isa("BaseDB")) {
        $basedb = $obj;
        $json = $obj->toJSON;
    }
    else {
        $basedb = bless { _dbix => $obj }, "BaseDB";
        $json = $basedb->toJSON;
        my %columns = $obj->get_columns;
        for my $key (keys %columns) {
            if (defined $columns{$key}) {
                $json->{$key} = $columns{$key};
            }
        }
    }

    # Usefull for including relation object contents
    if (defined ($expand) and $expand) {
        my $expands     = [];
        my $subexp  = {};

        for my $key (@$expand) {
            my @key     = split('\.', $key);
            my $size    = @key;
            if ($size == 1) {
                push(@$expands, $key);
            }
            else {
                if (not exists($subexp->{$key[0]})) {
                    $subexp->{$key[0]}  = [];
                }
                push(@{$subexp->{$key[0]}}, ($#key == 1) ? $key[1] : join('.', @key[1..$#key]));
            }
        }

        for my $key (@$expands) {
            # Search for $key in relations, possibly in upper classes
            my $is_relation;
            my $dbix = $basedb->{_dbix};
            while ($dbix) {
                if ($dbix->result_source->has_relationship($key)) {
                    $is_relation = $dbix->result_source->relationship_info($key)->{attrs}->{accessor};
                    last;
                }
                $dbix = $dbix->result_source->has_relationship('parent') ? $dbix->parent : undef;
            }

            if ($is_relation) {
                my $nextexpand  = $subexp->{$key} || [];
                if ($is_relation eq 'multi') {
                    my $children = [];
                    for my $item ($dbix->$key) {
                        push @$children, db_to_json($item, $nextexpand);
                    }
                    $json->{$key} = $children;
                }
                else {
                    $json->{$key} = db_to_json($basedb->getAttr(name => $key), $nextexpand);
                }
            }
            else {
                $json->{$key} = jsonify($basedb->getAttr(name => $key));
            }
        }
    }
    return $json;
}

sub handle_null_param {
    my $param = shift;
    if (! defined $param || !length($param)) {
        return undef;
    }
    elsif (($param eq "''") or ($param eq "\"\"")) {
        return '';
    }
    else {
        return $param;
    }
}

sub format_results {
    my %args = @_;

    my $objs = [];
    my $class = $args{class};
    my $dataType = $args{dataType} || "";
    my $expand = $args{expand} || [];
    my $table;
    my $result;
    my %params = ();

    delete $args{class};
    delete $args{dataType};
    delete $args{expand};

    $params{page} = $args{page};
    delete $args{page};

    if (defined $args{rows}) {
        $params{rows} = $args{rows};
        delete $args{rows};
    }

    if (defined $args{order_by}) {
        $params{order_by} = $args{order_by};
        delete $args{order_by};
    }

    foreach my $attr (keys %args) {
        my @filter = split(',', $args{$attr}, -1);
        if (scalar (@filter) > 1) {
            $filter[1] = handle_null_param($filter[1]);
            my %filter = @filter;
            $args{$attr} = \%filter;
        }
        else {
            $args{$attr} = handle_null_param($args{$attr});
        }
    }

    if ($class->isa("DBIx::Class::ResultSet")) {
        my $results = $class->search_rs(\%args, \%params);
        while (my $obj = $results->next) {
            push @$objs, db_to_json($obj, $expand);
        }

        my $total = (defined ($params{page}) or defined ($params{rows})) ?
                        $results->pager->total_entries : $results->count;

        $result = {
            page    => $params{page} || 1,
            pages   => $params{rows} ? ceil($total / $params{rows}) : 1,
            records => scalar @$objs,
            rows    => $objs,
            total   => $total,
        };
    }
    else {
        eval {
            require (General::getLocFromClass(entityclass => $class));
        };

        $result = $class->search(hash => \%args, dataType => "hash", %params);

        for my $obj (@{$result->{rows}}) {
            push @$objs, $obj->toJSON();
        }

        $result->{rows} = $objs;
    }

    if ($dataType ne "jqGrid") {
        return $result->{rows};
    } else {
        return $result;
    }
}

sub jsonify {
    my $var = shift;

    # Jsonify the non scalar only
    if (ref($var) and ref($var) ne "HASH") {
        if ($var->can("toJSON")) {
            if ($var->isa("Entity::Operation")) {
                return Entity::Operation->get(id => $var->getId)->toJSON;
            }
            elsif ($var->isa("Workflow")) {
                return Workflow->get(id => $var->getId)->toJSON;
            } else {
                return $var->toJSON;
            }
        }
    }
    return $var;
}

sub setupREST {

    foreach my $resource (keys %resources) {
        my $class = $resources{$resource};

        resource "api/$resource" =>
            get    => sub {
                content_type 'application/json';
                require (General::getLocFromClass(entityclass => $class));

                my @expand = defined params->{expand} ? split(',', params->{expand}) : ();
                return to_json( db_to_json($class->get(id => params->{id}),
                                           \@expand) );
            },

            create => sub {
                content_type 'application/json';
                require (General::getLocFromClass(entityclass => $class));
                my $obj = {};
                my $hash = {};
                my %params = params;
                if (request->content_type && (split(/;/, request->content_type))[0] eq "application/json") {
                    %params = %{from_json(request->body)};
                } else {
                    %params = params;
                }

                if ($class->can('create')) {
                    $obj = jsonify($class->methodCall(method => 'create', params => \%params));
                }
                else {
                    # We probably do not want to directly enqueue operations,
                    # as permissions are checked from methods calls.

#                    eval {
#                        my $location = "EOperation::EAdd" . ucfirst($resource) . ".pm";
#                        $location =~ s/\:\:/\//g;
#                        require $location;
#                        $obj = Entity::Operation->enqueue(
#                            priority => 200,
#                            type     => 'Add' . ucfirst($resource),
#                            params   => $hash
#                        );
#                        $obj = Entity::Operation->get(id => $obj->getId)->toJSON;
#                    };
#
#                    if ($@) {
#                        $obj = $class->new(params)->toJSON();
#                    };

                     $obj = $class->new(%params)->toJSON();
                }
                return to_json($obj);
            },

            delete => sub {
                content_type 'application/json';
                require (General::getLocFromClass(entityclass => $class));

                my $obj = $class->get(id => params->{id});
                $obj->can("remove") ? $obj->methodCall(method => 'remove') : $obj->delete();

                return to_json( { status => "success" } );
            },

            update => sub {
                content_type 'application/json';
                require (General::getLocFromClass(entityclass => $class));

                my %params = params;
                my $obj = $class->get(id => params->{id});
                if (request->content_type && (split(/;/, request->content_type))[0] eq "application/json") {
                    %params = %{from_json(request->body)};
                } else {
                    %params = params;
                }

                $obj->methodCall(method => 'update', params => \%params);

                return to_json( { status => "success" } );
            };

        get qr{ /api/$resource/([^/]+)/?(.*) }x => sub {
            content_type 'application/json';
            require (General::getLocFromClass(entityclass => $class));

            my ($id, $filters) = splat;
            my $obj = $class->get(id => $id);

            my @filters = split("/", $filters);
            my @objs;
            my $result;

            my %query = params('query');
            my $hash = \%query;

            for my $filter (@filters) {
                my $parent = $obj->{_dbix};

                RELATION:
                while (1) {
                    if ($parent->result_source->has_relationship($filter)) {
                        # TODO: prefetch filter so that we can just bless it
                        # $obj = bless { _dbix => $parent->$filter }, "Entity";

                        if ($parent->result_source->relationship_info($filter)->{attrs}->{accessor} eq "multi") {
                            my @rs = $parent->$filter->search_rs( { } );

                            my $json = format_results(class     => $parent->$filter->search_rs(),
                                                      dataType  => params->{dataType},
                                                      %$hash);

                            return to_json($json);
                        }
                        elsif (defined $parent->$filter) {
                            my $dbix = $parent->$filter;

                            $obj = $dbix->has_relationship("class_type") ?
                                       Entity->get(
                                           id => $dbix->get_column(($dbix->result_source->primary_columns)[0])
                                       ) :
                                       $dbix; 

                            my @expand = defined params->{expand} ? split(',', params->{expand}) : ();
                            return to_json(db_to_json($obj, \@expand));
                        }
                        else {
                            return "null";
                        }

                        last RELATION;
                    }

                    last if (not $parent->can('parent'));
                    $parent = $parent->parent;
                }
            }
 
            return to_json($obj->toJSON);
        };

        post qr{ /api/$resource/(.*) }x => sub {
            content_type 'application/json';
            require (General::getLocFromClass(entityclass => $class));

            my ($id, $obj, $method);
            my @query = split('/', (splat)[0]);

            if (scalar @query > 1) {
                ($id, $method) =  @query;
                $obj = $class->get(id => $id);
            }
            else {
                $method = $query[0];
                $obj = $class;
            }

            my $methods = $obj->getMethods();

            if (not defined $methods->{$method}) {
                throw Kanopya::Exception::NotImplemented(error => "Method not implemented");
            }

            my %params;
            if (request->content_type && (split(/;/, request->content_type))[0] eq "application/json") {
                %params = %{from_json(request->body)};
            } else {
                %params = params;
            }

            my $ret = $obj->methodCall(method => $method, params => \%params);

            if (ref($ret) eq "ARRAY") {
                my @jsons;
                for my $elem (@{$ret}) {
                    push @jsons, jsonify($elem);
                }
                $ret = \@jsons;
            } elsif ($ret) {
                $ret = jsonify($ret);
            } else {
                $ret = jsonify({});
            }

            return to_json($ret, { allow_nonref => 1, convert_blessed => 1, allow_blessed => 1 });
        };

        get '/api/' . $resource . '/?' => sub {
            content_type 'application/json';
            require (General::getLocFromClass(entityclass => $class));

            my $objs = [];
            my $class = $resources{$resource};
            my %query = params('query');
            my %params = (
                hash => \%query,
            );

            my $json = format_results(class     => $class,
                                      dataType  => params->{dataType},
                                      %query);

            my @expand = defined params->{expand} ? split(',', params->{expand}) : ();
            return to_json($json);
        }
    }
}

get '/api/attributes/:resource' => sub {
    content_type 'application/json';

    my $class = $resources{params->{resource}};

    require (General::getLocFromClass(entityclass => $class));

    return to_json($class->toJSON(  model => 1,
                                    no_relations => params->{no_relations}));
};

get '/api' => sub {
    content_type 'application/json';

    my @resources = keys %resources;

    return to_json({
        version   => $API_VERSION,
        resources => \@resources
    });
};

setupREST;

true;

