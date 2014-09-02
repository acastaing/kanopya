=head1 TEST SUITE

Post all resources

=head1 USAGE

You can pass a resource name to this test as script parameter in order to test only this resource

=head1 DESCRIPTION

For each available resources:
1. GET attributes of the resource
2. Generate value for each mandatory attribute:
    a. If attribute is a relationship then GET related resources and keep the first
        - if no resource available, POST one. These temp resources will be deleted at the end (7.)
    b. Else generate a valid value according to the pattern
3. POST the resource with only mandatory attributes
4. Test the response status of the POST request
5. DELETE the resource
6. Test the response status of the DELETE request
7. Delete the related resources possibly created (2.a)

If a test fail, see the log file for more details (failing request response)

You can run this test for a specific resource by giving the name of the resource (command line parameter)

=head1 REQUIREMENTS

Message queuing server must be running (since some POST lead to an operation enqueuing).

=head1 INFO

=head2 Expected status

Expected response status is 200 by default.
However, some POST requests status are 405 ("must implement _delegatee").
The hash %POST_expected_status lists resources with a post status different than 200.
POST test will pass if status correspond to defined status in this hash, otherwise test will fail.
So 405 is considered as correct response, since we don't know if it's a wanted behavior or not.

TODO Implement _delegatee for resources that need it, and remove them from %POST_expected_status.

=head2 Resource delete

Resource are deleted only if the POST request was ok and do not lead to an operation enqueueing.

TODO Handle DELETE for resource created after operation execution

=head2 Skipped resources

Some resources are skipped in this tests suite.
Reasons are:
 - Nonsense to create through API (base class, kanopya internal resources)
 - Hard to generically automatize. TODO Specific tests suite
 - Produce strange error. TODO Study and fix

All skipped resources are in the array @skip_resources

=head2 Fixed value

Some attribute values can not be correctly generated from the pattern.
These values are fixed in %attribute_fixed_value

=cut

use Test::More 'no_plan';

use Test::Exception;
use strict;
use warnings;

# the order is important
use Frontend;
use Dancer::Test;
use REST::api;
use APITestLib;

use String::Random 'random_regex';
use Data::Dumper;

require 't/APITestLogger.pm';
use Log::Log4perl 'get_logger';
my $log = get_logger("");

# default : 200
# 405 :  Non entity class <xxx> must implement _delegatee method for permissions check.
my %POST_expected_status = (
    'netconfiface' => 405,
    'netconfpoolip'=> 405,
    'userprofile' => 405,
    'profile' => 405,
    'quota'   => 405,
    'datamodeltype' => 405,
    'entitytimeperiod' => 405,
    'message' => 405,
    'indicatorset' => 405,
    'entitycomment' => 405,
    'ip' => 405,
    'alert'=> 405,
    'netconfinterface' => 405,
    'iscsiportal' => 405,
    'lvm2vg' => 405,
    'apache2virtualhost' => 405,
    'entityright' => 405,
    'parampreset' => 405,
    'linuxmount' => 405,
    'keepalived1vrrpinstance' => 405,
    'haproxy1listen' => 405,
    'componenttypecategory' => 405,
    'managercategory' => 405,

);

my %DELETE_expected_status = (
    'systemimage' => 404, # No container access found
);

my @skip_resources = (

    # Nonsense to create through API
    'entity',
    'classtype',
    'datamodel',
    'component',
    'componenttype',
    'scope',
    'scopeparameter',
    'serviceprovidertype',
    'masterimage',
    'operation',
    'oldoperation',
    'operationtype',

    # Pb : valid formula generation (valid IDs)
    # Need specific tests suite for monitoring and rule
    'rule', #cant instanciate abstract class

    # Repository : foreign key 'virtualization_id' failed
    # Need specific tests suite
    'repository',
    'openstackrepository',
    'opennebula3repository',
    'vsphere5repository',

    # Container and container access (need to be linked to valid container and export manager)
    'container',
    'lvmcontainer', # ??
    'containeraccess',
    'nfscontaineraccess',
    'filecontaineraccess',
    'iscsicontaineraccess',
    'nfscontaineraccessclient',

    # Misc, to study
    'notificationsubscription', # Why 'entity_id' is mandatory ?
    'ucsmanager',
    'cluster', # owner_id mandatory set not mandatory
    'netapplunmanager',
    'netappvolumemanager',
    'hpc7000', # need HpcManager
    'netapp',
    'netappaggregate',
    'netapplun',
    'netappvolume',
    'unifiedcomputingsystem'
);

# Some regexp can not be correctly parsed and bad value are generated, so we fix it
my %attribute_fixed_value = (
    'nodemetriccondition' => {
        'nodemetric_condition_comparator' => '>'
    },
    'aggregatecondition' => {
        'comparator' => '>='
    },
    'user' => {
        'user_email' => 'foo@bar.fr'
    },
    'customer' => {
        'user_email' => 'foo@bar.fr'
    },
    'stackbuildercustomer' => {
        'user_email' => 'foo@bar.fr'
    },
    'poolip' => {
        'poolip_first_addr' => '10.0.0.1'
    },
    'kanopyamailnotifier' => {
        'smtp_server' => '0.0.0.0'
    },
    'clustermetric' => {
        'clustermetric_statistics_function_name' => 'mean'
    },
);

# Filled at runtime
my %common_fixed_value = (
    domainname    => 'my.domain',
    node_hostname => 'hostname'
);

my %_skip_resources;


sub fillMissingFixedAttr {
    # host_manager_ids
    my $resp = dancer_response(GET => "/api/physicalhoster0", {});
    my $ph0 = Dancer::from_json($resp->{content});
    $resp = dancer_response(GET => "/api/opennebula3", {});
    my $on3 = Dancer::from_json($resp->{content});
    $resp = dancer_response(GET => "/api/novacontroller", {});
    my $nova = Dancer::from_json($resp->{content});

    $attribute_fixed_value{host}{host_manager_id} = $ph0->[0]->{pk};
    $attribute_fixed_value{hypervisor}{host_manager_id} = $ph0->[0]->{pk};
    $attribute_fixed_value{virtualmachine}{host_manager_id} = $on3->[0]->{pk};
    $attribute_fixed_value{opennebula3hypervisor}{host_manager_id} = $ph0->[0]->{pk};
    $attribute_fixed_value{openstackhypervisor}{host_manager_id} = $ph0->[0]->{pk};
    $attribute_fixed_value{openstackvm}{host_manager_id} = $nova->[0]->{pk};
    $attribute_fixed_value{opennebula3vm}{host_manager_id} = $on3->[0]->{pk};

    # serviceprovidermanager
    $attribute_fixed_value{serviceprovidermanager}{manager_id} = $ph0->[0]->{pk};
    my $component_type_id = $ph0->[0]->{component_type_id};
    $resp = dancer_response GET => '/api/componenttypecategory',
                                   { params => { component_type_id => $component_type_id } };
    my $json = Dancer::from_json($resp->{content});

    $attribute_fixed_value{serviceprovidermanager}{manager_category_id} = $json->[0]->{component_category_id};

    # formulas
    # nodemetricrule
    $resp = dancer_response(GET => "/api/nodemetriccondition", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{rule}{formula} = 'id'.$json->[0]->{pk};
    $attribute_fixed_value{nodemetricrule}{formula} = 'id'.$json->[0]->{pk};

    # aggregaterule
    $resp = dancer_response(GET => "/api/aggregatecondition", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{aggregaterule}{formula} = 'id'.$json->[0]->{pk};

    # aggregatecombination
    $resp = dancer_response(GET => "/api/clustermetric", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{aggregatecombination}{aggregate_combination_formula} = 'id'.$json->[0]->{pk};

    #nodemetriccombination
    $resp = dancer_response(GET => "/api/collectorindicator", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{nodemetriccombination}{nodemetric_combination_formula} = 'id'.$json->[0]->{pk};

    # cluster for node
    $resp = dancer_response(GET => "/api/cluster", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{node}{service_provider_id} = $json->[0]->{pk};

    #related metric
    $resp = dancer_response(GET => "/api/clustermetric", {});
    $json = Dancer::from_json($resp->{content});
    $attribute_fixed_value{anomaly}{related_metric_id} = $json->[0]->{pk};

    # Retrieve an executor
    $resp = dancer_response(GET => "/api/kanopyaexecutor", {});
    my $executor = Dancer::from_json($resp->{content})->[0];
    $common_fixed_value{executor_component_id} = $executor->{pk};

    # Do not understand why the executor_component_id is NON mandatory in attributes
    # Force to add this param.
    $attribute_fixed_value{fileimagemanager0}{executor_component_id} = $executor->{pk};
}


sub run {
    my $resource = shift;

    # Firstly login to the api
    APITestLib::login();

    # Check Kanopya DB consistance
    my $rq  = dancer_response GET => '/api/entity';
    if ($rq->{status} ne 200) {
        die 'First Kanopya DB consistance check. Wrong status GET /api/entity'
    }

    %_skip_resources = map { $_ => 1 } @skip_resources;

    # Firtly manage resource required for others
    manage_resource("opennebula3", 1);
    manage_resource("novacontroller", 1);

    $_skip_resources{opennebula3} = 1;
    $_skip_resources{novacontroller} = 1;

    # Fix params for specific resources
    fillMissingFixedAttr();

    my @api_resources = $resource ? ($resource) : keys %REST::api::resources;
    #@api_resources = @api_resources[0 .. 20];
    #@api_resources = ('operation', 'netapp');

    RESOURCE:
    for my $resource_name (@api_resources) {
        manage_resource($resource_name);
    }
}


# POST a resource and test response status
# Attributes values are generated
sub manage_resource {
    my ($resource_name, $persitent) = @_;

    lives_ok {
        if (exists $_skip_resources{$resource_name}) {
            SKIP: {
                skip "POST '$resource_name' not managed in this test", 1;
            }
            next RESOURCE;
        }
        post_resource($resource_name, $persitent);

        # Check if resource deletion has not corrupted Kanopya DB
        # (e.g. with unmanaged delete on cascade)

        my $rq  = dancer_response GET => '/api/entity';
        if ($rq->{status} ne 200) {
            die 'Wrong status GET /api/entity got <' . $rq->{status}
                . '> instead of <200> after managing resource < ' . $resource_name . '>'
                . ', ' . $rq->{content};
        }
    } 'Manage '. $resource_name;
}

# Generate values for (mandatory) attributes of a resource
sub _generate_values {
    my ($resource_name) = @_;

    my $resource_info_resp = dancer_response(GET => "/api/attributes/$resource_name", {});
    my $resource_info = Dancer::from_json($resource_info_resp->{content});

    my %params;
    while (my ($attr_name, $attr_def) = each %{$resource_info->{attributes}}) {
        if ($attr_def->{is_mandatory}) {
            my $value = '';
            if (exists $common_fixed_value{$attr_name}) {
                $value = $common_fixed_value{$attr_name};
            }
            elsif (exists $attribute_fixed_value{$resource_name}{$attr_name}) {
                # value can not be generated
                $value = $attribute_fixed_value{$resource_name}{$attr_name};
            }
            elsif ($attr_def->{'relation'} || $attr_name =~ /.*_id$/) {
                # Relation
                (my $relation = $attr_name) =~ s/_id$//;
                my $related_resource = $resource_info->{relations}{$relation}{resource};
                if (not defined $related_resource) {($related_resource = $relation) =~ s/_//g;}
                $value = get_resource($related_resource, $resource_name);
            }
            else {
                # Generate value using pattern
                my $pattern = $attr_def->{pattern} || '^.*$';

                my @pattern_split = split '', $attr_def->{pattern};
                $pattern_split[0]  = '' if $pattern_split[0] eq '^';
                $pattern_split[-1] = '' if $pattern_split[-1] eq '$';
                $pattern = join '', @pattern_split;

                if ($pattern =~ m/^\((\w+\|)+\w+\)$/) {
                    $pattern =~ s/^.//;
                    $pattern =~ s/.$//;
                    my @split = split '\|', $pattern;
                    $value = $split[0];
                }
                else {
                    eval {
                        $value = random_regex($pattern);
                    };
                    if ($@) {
                        $log->error("Can not generate a string for pattern '$pattern'");
                    }
                }
            }
            $params{$attr_name} = $value;
        }
        elsif (exists $attribute_fixed_value{$resource_name}{$attr_name}) {
            # value can not be generated
            $params{$attr_name} = $attribute_fixed_value{$resource_name}{$attr_name};
        }
    }
    return \%params;
}

my $temp_resources = {};

# POST a resource and test response status
# Attributes values are generated
sub post_resource {
    my ($resource_name, $persistent, $related_resource_name) = @_;

    $log->debug("POST $resource_name");

    my $params = _generate_values($resource_name);
    $log->debug("POST '$resource_name' with attributes : " . (Dumper $params));

    my $new_resp = dancer_response(POST => "/api/$resource_name", { params => $params});

    my $expect_status = $POST_expected_status{$resource_name} || 200;
    if (!$persistent) {
        if ($new_resp->{status} ne $expect_status) {
           die 'POST <' . $resource_name . '> with only mandatory attributes got <'
               . $new_resp->{status} . '> expected <' . $expect_status . '>, ' . $new_resp->{content};
       }
    }

    # If POST succeed
    if ($new_resp->{status} == 200) {
        my $new_resource = Dancer::from_json($new_resp->{content});
        if ($persistent) {
            if (! defined $temp_resources->{$resource_name}) {
                $temp_resources->{$resource_name} = ();
            }
            push @{ $temp_resources->{$related_resource_name} }, $new_resource->{pk};
            return $new_resource->{pk};
        }
        else {
            # If resource created (i.e do not need operation execution) then we delete it
            if (!$new_resource->{operation_id}) {
                delete_resource($resource_name, $new_resource->{pk});
            }
            # Delete related resources created before (persistent)
            foreach (@{ $temp_resources->{$resource_name} }) {
                delete_resource('entity', $_, 1)
            };
            $temp_resources->{$resource_name} = ();
        }
    } else {
       $log->error(Dumper $new_resp) if ($new_resp->{status} != $expect_status);
    }
}

sub delete_resource {
    my ($resource_name, $resource_id, $notest) = @_;

    $log->debug("DELETE $resource_name/$resource_id");
    my $delete_resp = dancer_response(DELETE => "/api/$resource_name/$resource_id", {});

    if (!$notest) {
        if ($delete_resp->{status} ne ($DELETE_expected_status{$resource_name} || 200)) {
            die "DELETE $resource_name got status <" . $delete_resp->{status} . '> exepected <'
                . ($DELETE_expected_status{$resource_name} || 200) . '>';
        }
    }
    $log->error(Dumper $delete_resp) if ($delete_resp->{status} != 200);
}

# Get or create if empty
sub get_resource {
    my ($resource_name, $related_resource_name) = @_;

    $log->debug("GET $resource_name");
    my $resource_resp = dancer_response(GET => "/api/$resource_name", {});

    $log->error(Dumper $resource_resp) if ($resource_resp->{status} != 200);

    my $resource;
    eval {
        $resource = Dancer::from_json($resource_resp->{content});
    };
    if ($@) {
        my $error = $@;
        if ($error =~ 'malformed') {
            $log->error(
                "Can not parse response for GET '$resource_name' due to special characters in some attributes value."
                . " Considered as empty."
            );
        } else {
            $log->error($error);
        }
    }

    if ((ref $resource) eq 'ARRAY' && $resource->[0]) {
        return $resource->[0]{pk};
    }
    else {
        $log->info("No resource of type '$resource_name', we will create it");
        return post_resource($resource_name, 1, $related_resource_name);
    }
}

run($ARGV[0]);
