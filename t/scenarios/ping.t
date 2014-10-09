#!/usr/bin/perl -w

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;

use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level=>'DEBUG',
    file=>'Bonding.t.log',
    layout=>'%d [ %H - %P ] %p -> %M - %m%n'
});


use Kanopya::Database;
use Entity::ServiceProvider::Cluster;
use Net::Ping;
use Ip;
use Entity::Iface;
use Kanopya::Test::Retrieve;

eval {
    Kanopya::Database::authenticate( login =>'admin', password => 'K4n0pY4' );

    $cluster = Kanopya::Test::Retrieve->retrieveCluster(criteria => {cluster_name => 'Bondage'});

    lives_ok {
        my @bonded_ifaces;
        foreach my $host ($cluster->getHosts()) {
            my @ifaces = grep { scalar @{ $_->slaves} > 0 } Entity::Iface->find(hash => {host_id => $host->id});
            push @bonded_ifaces, @ifaces;
        }

        my $ip;
        my $ping;
        my $pingable;
        foreach my $iface (@bonded_ifaces) {
            $ip = Ip->find(hash => {iface_id => $iface->id});
        	$ping = Net::Ping->new('icmp');
	        $pingable = $ping->ping($ip->ip_addr, 10);
	        $pingable ? $pingable : 0;
        }
    } 'ping bonded interface';

};
if($@) {
    my $error = $@;
    print $error."\n";
};
