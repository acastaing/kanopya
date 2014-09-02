#   TEST 4.a :
#
#       HOSTS :
#        _______________________________________________________________________________________________
#       |                               |                               |                               |
#       | Host 1 -                      | Host 2 -                      | Host 3 -                      |
#       |     CPU Core number = 2       |     CPU Core number = 2       |     CPU Core number = 2       |
#       |     RAM quantity    = 4096    |     RAM quantity    = 4096    |     RAM quantity    = 4096    |
#       |     Ifaces :                  |     Ifaces :                  |     Ifaces :                  |
#       |         iface 1 :             |         iface 1 :             |         iface 1 :             |
#       |             Bonds number = 0  |             Bonds number = 0  |             Bonds number = 0  |
#       |             NetIps       = [] |             NetIps       = [] |             NetIps       = [] |
#       |     Tags : [1,2,3,4,5,6]      |     Tags : [1,2]              |     Tags : [1,3,6]            |
#       |_______________________________|_______________________________|_______________________________|
#        _______________________________________________________________________________________________
#       |                               |                               |                               |
#       | Host 4 -                      | Host 5 -                      | Host 6 -                      |
#       |     CPU Core number = 2       |     CPU Core number = 2       |     CPU Core number = 2       |
#       |     RAM quantity    = 4096    |     RAM quantity    = 4096    |     RAM quantity    = 4096    |
#       |     Ifaces :                  |     Ifaces :                  |     Ifaces :                  |
#       |         iface 1 :             |         iface 1 :             |         iface 1 :             |
#       |             Bonds number = 0  |             Bonds number = 0  |             Bonds number = 0  |
#       |             NetIps       = [] |             NetIps       = [] |             NetIps       = [] |
#       |     Tags : [1,2,3,5]          |     Tags : [1,2,3,4]          |     Tags : [1,2,3,6,7]        |
#       |_______________________________|_______________________________|_______________________________|
#
#       CONSTRAINTS (Cluster) :
#
#       /---------------------------------\
#       /                                 \
#       /   Min CPU Core number = 1       \
#       /   Min RAM quantity    = 512     \
#       /   Interfaces :                  \
#       /       interface 1 :             \
#       /           Min Bonds number = 0  \
#       /           Min NetIps       = [] \
#       /   Min Tags : [1,2,3]            \
#       /   No  Tags : [4,5]            \
#       /---------------------------------\
#

use Entity::Tag;
use Kanopya::Test::TestUtils 'expectedException';
#use strict;
#use warnings;

sub test4a {
    ########################
    #### Create Tags    ####
    ########################

    my @tags= ();
    for my $i (0..6) {
        push @tags, Entity::Tag->findOrCreate(tag => "test_4a_".$i);
    }

    ########################
    #### Create Cluster ####
    ########################

    # Create NetConf
    my $netConf =  Entity::Netconf->findOrCreate(netconf_name => 'netconf');

    # Host Manager config
    my $host_manager_conf = {
        managers => {
            host_manager => {
                manager_params => {
                    core => 1,
                    ram  => 512*1024*1024,
                    tags => [$tags[0]->id, $tags[1]->id, $tags[2]->id],
                    no_tags => [$tags[3]->id, $tags[4]->id],
                },
            },
        }
    };

    # Create Cluster and add network interface to it
    my $cluster = Kanopya::Test::Create->createCluster(
                     cluster_conf => $host_manager_conf,
                  );

    Kanopya::Test::Execution->executeAll();

    for my $interface ($cluster->interfaces) {
        $interface->delete();
    }

    my $network_manager_params = {
        interfaces => {
            interface1 => {
                netconfs       => {$netConf->netconf_name => $netConf },
                bonds_number   => 0,
                interface_name => "eth0",
            },
        }
    };
    $cluster->configureInterfaces(%{ $network_manager_params });

    ######################
    #### Create Hosts ####
    ######################

    my @hosts = ();
    my $host;
    # Create Host 1
    $host = Kanopya::Test::Register->registerHost(
        board => {
            serial_number => 1,
            core          => 2,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => 'eth0',
                    pxe  => 0,
                },
            ],
        },
    );
    $host->_populateRelations(
        relations => {
            entity_tags => [$tags[0], $tags[1], $tags[2], $tags[3], $tags[4], $tags[5]],
        }
    );
    push @hosts, $host;

    # Create Host 2
    $host = Kanopya::Test::Register->registerHost(
        board => {
            serial_number => 2,
            core          => 2,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => 'eth0',
                    pxe  => 0,
                },
            ],
        },
    );
    $host->_populateRelations(
        relations => {
            entity_tags => [$tags[0], $tags[1]],
        }
    );
    push @hosts, $host;

    # Create Host 3
    $host = Kanopya::Test::Register->registerHost(
        board => {
            serial_number => 3,
            core          => 2,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => 'eth0',
                    pxe  => 0,
                },
            ],
        },
    );
    $host->_populateRelations(
        relations => {
            entity_tags => [$tags[0], $tags[2], $tags[5]],
        }
    );
    push @hosts, $host;

    # Create Host 4
    $host = Kanopya::Test::Register->registerHost(
        board => {
            serial_number => 6,
            core          => 2,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => 'eth0',
                    pxe  => 0,
                },
            ],
        },
    );
    $host->_populateRelations(
        relations => {
            entity_tags => [$tags[0], $tags[1], $tags[2], $tags[4]],
        }
    );
    push @hosts, $host;

    # Create Host 5
    $host = Kanopya::Test::Register->registerHost(
        board => {
            serial_number => 5,
            core          => 2,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => 'eth0',
                    pxe  => 0,
                },
            ],
        },
    );
    $host->_populateRelations(
        relations => {
            entity_tags => [$tags[0], $tags[1], $tags[2], $tags[3]],
        }
    );
    push @hosts, $host;


    #########################################
    #### Perform the test without host 6 ####
    #########################################

    lives_ok {

        expectedException {
            my $selected_host = DecisionMaker::HostSelector->getHost(
                                    host_manager => Entity::Component::Physicalhoster0->find(),
                                    %{ $network_manager_params },
                                    %{ $host_manager_conf->{managers}->{host_manager}->{manager_params} },
                                );

        } 'Kanopya::Exception', 'Test 4.a : Wrong host selected expected no host';

        # Create Host 6
        $host = Kanopya::Test::Register->registerHost(
            board => {
                serial_number => 4,
                core          => 2,
                ram           => 4096*1024*1024,
                ifaces        => [
                    {
                        name => 'eth0',
                        pxe  => 0,
                    },
                ],
            },
        );
        $host->_populateRelations(
            relations => {
                entity_tags => [$tags[0], $tags[1], $tags[2], $tags[5], $tags[6]],
            }
        );
        push @hosts, $host;

        my $selected_host = DecisionMaker::HostSelector->getHost(
                                host_manager => Entity::Component::Physicalhoster0->find(),
                                %{ $network_manager_params },
                                %{ $host_manager_conf->{managers}->{host_manager}->{manager_params} },
                            );


        # The selected host must be the last one.
        if ($selected_host->id != $hosts[-1]->id) {
            die ('Test 4.a : Wrong host <'.($selected_host->id).'> selected, expected <'.($hosts[3]->id).'>');
        }

    } "Test 4.a : Choosing the host with no tags";

    for my $host (@hosts) {
        $host->delete();
    }

    $cluster->delete();

    for my $tag (@tags) {
        $tag->delete();
    }

}

1;
