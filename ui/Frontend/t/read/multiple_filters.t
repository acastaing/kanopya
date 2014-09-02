#!/usr/bin/perl

use Test::More 'no_plan';
use strict;
use warnings;

# the order is important
use Dancer::Test;
use Frontend;
use REST::api;
use APITestLib;

use Data::Dumper;
$DB::deep = 500;

use Log::Log4perl;
Log::Log4perl->easy_init({level=>'DEBUG', file=>'api.t.log', layout=>'%d [ %H - %P ] %p -> %M - %m%n'});

# Firstly login to the api
APITestLib::login();

my $netconf_vms = dancer_response GET => '/api/netconfrole', { params => { netconf_role_name => 'vms' } };
is $netconf_vms->{status}, 200, "response from GET /api/netconfrole is 200";
my $role = Dancer::from_json($netconf_vms->{content});

my $netconfs = dancer_response GET => '/api/netconf',
               { params => { 
                     netconf_role_id => "=,$role->[0]->{netconf_role_id}",
                     netconf_id      => ">,200",
               } };
my $netconfs_content = Dancer::from_json($netconfs->{content});

foreach my $netconf (@$netconfs_content) {
    is $netconf->{netconf_role_id},
       $role->[0]->{netconf_role_id},
       "netconf has good netconf role $role->[0]->{netconf_role_id} from filter";

    cmp_ok $netconf->{netconf_id}, '>', 200,
           "netconf has good id $netconf->{netconf_id} > 200";
}
