package REST::api;

use Dancer ':syntax';
use Dancer::Plugin::REST;

prefix undef;

use General;
use Entity;

prepare_serializer_for_format;

my %resources = ( "host"           => "Entity::Host",
                  "cluster"        => "Entity::ServiceProvider::Inside::Cluster",
                  "user"           => "Entity::User",
                  "masterimage"    => "Entity::Masterimage",
                  "systemimage"    => "Entity::Systemimage",
                  "processormodel" => "Entity::Processormodel",
                  "hostmodel"      => "Entity::Hostmodel",
                  "permission"     => "Permissions",
                  "operation"      => "Operation",
                  "message"        => "Message",
                  "vlan"           => "Entity::Network::Vlan" );

sub setupREST {

    foreach my $resource (keys %resources) {
        resource "api/$resource" =>
            get    => sub {
                content_type 'application/json';
                return to_json( Entity->get(id => params->{id})->toJSON );
            },

            create => sub {
                my $class = $resources{$resource};
                my $hash = { };
                my $params = params;
                for my $attr (keys %$params) {
                    $hash->{$attr} = params->{$attr};
                }
                eval {
                    my $location = "EOperation::EAdd" . ucfirst($resource) . ".pm";
                    $location =~ s/\:\:/\//g;
                    require $location;
                    Operation->enqueue(
                        priority => 200,
                        type     => 'Add' . ucfirst($resource),
                        params   => $hash
                    );
                };
                if ($@) {
                    eval {
                         $class->new(params);
                    };
                    if ($@) {
                        my $exception = $@;
                        if (Kanopya::Exception::Permission::Denied->caught()) {
                           redirect '/permission_denied';
                        }
                        else {
                            $exception->rethrow();
                        }
                    }
                }
            },

            delete => sub {
                 Entity->get(id => params->{id})->remove();
            },

            update => sub {
                my $obj = Entity->get(id => params->{id});
                my $params = params;
                for my $attr (keys %$params) {
                    if ($attr ne "id") {
                        $obj->setAttr(name  => $attr,
                                      value => params->{$attr});
                    }
                }
                $obj->save();
            };

        get '/api/' . $resource => sub {
            my $objs = [];
            my $class = $resources{$resource};
            my %query = params('query');
            my %params = (
                hash => \%query,
            );
            if (defined params->{page}) {
                $params{page} = params->{page};
                delete $params{hash}->{page};
            }
            if (defined params->{rows}) {
                $params{rows} = params->{rows};
                delete $params{hash}->{rows};
            }
            if (defined params->{order_by}) {
                $params{order_by} = params->{order_by};
                delete $params{hash}->{order_by};
            }
            require( General::getLocFromClass(entityclass => $class) );
            for my $obj ($class->search(%params)) {
                push @$objs, $obj->toJSON();
            }
            content_type 'application/json';
            return to_json($objs);
        }
    }
}

get '/api/attributes/:resource' => sub {
    my $class = $resources{host};
    content_type 'application/json';
    return to_json($class->toJSON(model => 1));
};

setupREST;

true;