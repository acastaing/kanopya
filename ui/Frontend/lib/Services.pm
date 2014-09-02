package Services;

use Dancer ':syntax';
use Dancer::Plugin::Ajax;

use Log::Log4perl "get_logger";

use Entity::Node;

my $log = get_logger("");

prefix undef;

sub processOrderBy {
    my $orderby = shift;
    my $column  = 'node_hostname';
    my $order   = 'ASC';

    if (defined($orderby)) {
        if (index($orderby, ' ') > -1) {
            my @orderby = split ' ', $orderby;
            $column = $orderby[0];
            $order  = $orderby[1];
        } else {
            $column = $orderby;
        }
    }

    return ($column, $order);
}

post '/service/:servicename/component/:componenttype/:rpc' => sub {
    content_type 'application/json';

    my %params = params;

    # Extract rpc method name from params
    my $method = delete $params{rpc};

    # Find the service provider from service name
    my $service = Entity::ServiceProvider::Cluster->find(hash => {
                      cluster_name => delete $params{servicename}
                  });

    # Find the component on the service from component type
    my $component = $service->getComponent(name => delete $params{componenttype});

    $log->info("Calling RPC method '$method' on component $component with id <" . $component->id . ">");

    # Finally forward to the RPC call on the usaual api
    return forward '/api/component/' . $component->id . '/' . $method;
};


get '/nodes' => sub {
    content_type 'application/json';

    my %params   = params;
    my @order_by = processOrderBy($params{order_by});
    my $result   = { };

    if ($order_by[0] eq 'rulestate') {
        my @expand = (defined($params{expand})) ? split ',', $params{expand} : [];
        my $page   = (defined($params{page}))   ? $params{page}              : 1;
        my $rows   = (defined($params{rows}))   ? $params{rows}              : 25;
        my $first  = ($page - 1) * $rows;

        my $hash   =
            (defined($params{service_provider_id}))
                ? { service_provider_id => $params{service_provider_id} }
                : { };
        my @nodes        = Entity::Node->search(hash => $hash, prefetch => [ 'verified_noderules' ]);
        $result->{page}  = $page;
        $result->{total} = scalar(@nodes);
        $result->{pages} = $result->{total} / $rows;

        @nodes = sort { $a->rulestate <=> $b->rulestate } @nodes;
        if (uc($order_by[1]) eq 'DESC') {
            @nodes = reverse @nodes;
        }

        my @jsons          = map { REST::api::jsonify($_, expand => \@expand) } @nodes[$first..($first + $rows - 1)];
        $result->{rows}    = \@jsons;
        $result->{records} = scalar(@jsons);
    } else {
        $result = REST::api::getResources(resource => 'node', query => \%params);
    }

    return to_json $result;
};

1;
