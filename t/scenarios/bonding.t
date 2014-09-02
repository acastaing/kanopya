#!/usr/bin/perl -w

=head1 SCOPE

Setup a cluster with a bonded interface, and provide it an host with the matching bonded ifaces
Deactivate one of the slave, ping the bonded iface, then reactivate the iface and deactivate the
other slave, and ping again the master.

=head1 PRE-REQUISITE

=cut

use Test::More 'no_plan';
use Test::Exception;

use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level=>'DEBUG',
    file=>'Bonding.t.log',
    layout=>'%F %L %p %m%n'
});

use Kanopya::Database;
use Entity::Host;
use Entity::Iface;
use Net::Ping;
use Ip;

use Kanopya::Test::Execution;
use Kanopya::Test::Register;
use Kanopya::Test::Retrieve;
use Kanopya::Test::Create;

my $testing = 0;

my $NB_HYPERVISORS = 1;

main();

sub main {
    Kanopya::Database::authenticate( login =>'admin', password => 'K4n0pY4' );

    if ($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    my $host = Entity::Host->find(hash => { 
	           -or => [ host_serial_number => 'Desperado', host_serial_number => 'Heineken', host_serial_number => 'Swinkels' ] 
	       });
    
    my $eth3 = Entity::Iface->find(hash => {
                   iface_name => 'eth3',
                   host_id    => $host->id,
               });
    $eth3->setAttr(name => 'iface_name', value => 'bond0');
    $eth3->save();

    my $eth1 = Entity::Iface->find(hash => {
	           iface_name => 'eth1',
		   host_id    => $host->id,
	       });

    $eth1->setAttr(name => 'master', value => 'bond0');
    $eth1->save();

     my $eth2 = Entity::Iface->find(hash => {
	           iface_name => 'eth2',
		   host_id    => $host->id,
	       });

    $eth2->setAttr(name => 'master', value => 'bond0');
    $eth2->save();
    
    diag('register masterimage');
    my $masterimage = Kanopya::Test::Execution::registerMasterImage();

    diag('retrieve admin netconf');
    my $adminnetconf = Kanopya::Test::Retrieve->retrieveNetconf(criteria => { netconf_name => 'Kanopya admin' });

    diag('Create and configure cluster');
    my $bondage = Kanopya::Test::Create->createCluster(
                      cluster_conf => {
                          cluster_name         => 'Bondage',
                          cluster_basehostname => 'bondage',
                          masterimage_id       => $masterimage->id,
                      },
                      interfaces => {
                          public => {
                              interface_name => 'eth0',
                              netconfs       => { $adminnetconf->id => $adminnetconf->id },
                              bonds_number   => 2
                          },
                      }
                  );

    diag('Start host with bonded interfaces');
    Kanopya::Test::Execution->startCluster(cluster => $bondage);

    diag('deactivate slave n°1');
    _deactivate_iface(iface => 'eth1', cluster => $bondage);

    diag('ping iface bond0');
    _ping_ifaces();

    diag('deactivate slave n°2');
    _deactivate_iface(iface => 'eth2', cluster => $bondage);

    diag('ping iface bond0');
    _ping_ifaces();

    if($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}

sub _deactivate_iface {
    my %args = @_;

    General::checkParams(args => \%args, required => ['iface','cluster']);

    my @hosts = $args{cluster}->getHosts();
    my $host = pop @hosts;
    my $ehost = EEntity->new(entity => $host);
    $ehost->getEContext->execute(command => 'ifconfig ' . $args{iface} . ' down');
}


sub _ping_ifaces {
    lives_ok {
        diag('retrieve Cluster via name');
        my $cluster = Kanopya::Test::Retrieve->retrieveCluster(criteria => {cluster_name => 'Bondage'});

        my @bonded_ifaces;
        foreach my $host ($cluster->getHosts()) {
            my @ifaces = grep { scalar @{ $_->slaves} > 0 } Entity::Iface->find(hash => {host_id => $host->id});
            push @bonded_ifaces, @ifaces;
        }

        my $ip;
        my $ping;
        my $pingable = 0;
        foreach my $iface (@bonded_ifaces) {
            $ping = Net::Ping->new('icmp');
            $pingable |= $ping->ping($iface->getIPAddr, 10);
        }
    } 'ping cluster\'s hosts bonded ifaces';
}

1;
