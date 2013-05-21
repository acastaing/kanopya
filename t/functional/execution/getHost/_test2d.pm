#   TEST 2.D :
#
#     HOSTS :
#        _______________________________________________________________________________________________
#       |                               |                               |                               |
#       | Host 1 -                      | Host 2 -                      | Host 3 -                      |
#       |     CPU Core number = 1       |     CPU Core number = 2       |     CPU Core number = 4       |
#       |     RAM quantity    = 4096    |     RAM quantity    = 8192    |     RAM quantity    = 4096    |
#       |     Ifaces :                  |     Ifaces :                  |     Ifaces :                  |
#       |         iface 1 :             |         iface 1 :             |         iface 1 :             |
#       |             Bonds number = 0  |             Bonds number = 2  |             Bonds number = 2  |
#       |             NetIps       = [] |             NetIps       = [] |             NetIps       = [] |
#       |         iface 2 :             |                               |         iface 2 :             |
#       |             Bonds number = 0  |                               |             Bonds number = 0  |
#       |             NetIps       = [] |                               |             NetIps       = [] |
#       |         iface 3 :             |                               |                               |
#       |             Bonds number = 1  |                               |                               |
#       |             NetIps       = [] |                               |                               |
#       |_______________________________|_______________________________|_______________________________|
#
#     CONSTRAINTS (Cluster) :
#
#       /---------------------------------\
#       /                                 \
#       /   Min CPU Core number = 1       \
#       /   Min RAM quantity    = 4096    \
#       /   Interfaces :                  \
#       /       interface 1 :             \
#       /           Min Bonds number = 1  \
#       /           Min NetIps       = [] \
#       /       interface 2 :             \
#       /           Min Bonds number = 2  \
#       /           Min NetIps       = [] \
#       /                                 \
#       /---------------------------------\
#
sub test2d {
    ########################
    #### Create Cluster ####
    ########################
    
    # Create NetConf
    my $netConf =  Entity::Netconf->create(
        netconf_name => 'Being a netconf is cool',
    );
    # Host Manager config
    my $host_manager_conf = {
        managers              => {
            host_manager => {
                manager_params => {
                    core => 1,
                    ram  => 4096*1024*1024,
                },
            },
        }
    };
    # Create Cluster and add network interfaces to it
    my $cluster = Kanopya::Tools::Create->createCluster(
        cluster_conf => $host_manager_conf,
    );
    for my $interface ($cluster->interfaces) {
        $interface->delete();
    }
    $cluster->configureInterfaces(
        interfaces => {
            interface1 => {
                interface_netconfs => {$netConf->netconf_name => $netConf },
                bonds_number        => 1,
            },
            interface2 => {
                interface_netconfs => {$netConf->netconf_name => $netConf },
                bonds_number        => 2,
            },
        }
    );

    ######################
    #### Create Hosts ####
    ######################

    # Create Host 1
    my $master_iface_name1 = 'Nothing to say';
    my $host1 = Kanopya::Tools::Register->registerHost(
        board => {
            serial_number => 1,
            core          => 1,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => '...',
                    pxe  => 0,
                },
                {
                    name => '777',
                    pxe  => 0,
                },
                {
                    name => $master_iface_name1,
                    pxe  => 0,
                },
                    {
                        name   => 'Slaveman',
                        pxe    => 0,
                        master => $master_iface_name1,
                    },
            ],
        },
    );
    # Create Host 2
    my $master_iface_name2 = 'Masterman';
    my $host2 = Kanopya::Tools::Register->registerHost(
        board => {
            serial_number => 2,
            core          => 2,
            ram           => 8192*1024*1024,
            ifaces        => [
                {
                    name => $master_iface_name2,
                    pxe  => 0,
                },
                    {
                        name   => 'Slavedude',
                        pxe    => 0,
                        master => $master_iface_name2,
                    },
                    {
                        name   => 'Se me va la olla',
                        pxe    => 0,
                        master => $master_iface_name2,
                    },
            ],
        },
    );
    # Create Host 3
    my $master_iface_name3 = 'En el Raval';
    my $host3 = Kanopya::Tools::Register->registerHost(
        board => {
            serial_number => 3,
            core          => 4,
            ram           => 4096*1024*1024,
            ifaces        => [
                {
                    name => $master_iface_name3,
                    pxe  => 0,
                },
                    {
                        name   => 'myname1',
                        pxe    => 0,
                        master => $master_iface_name3,
                    },
                    {
                        name   => 'myname2',
                        pxe    => 0,
                        master => $master_iface_name3,
                    },
                {
                    name => '...',
                    pxe  => 0,
                },
            ],
        },
    );

    ##########################
    #### Perform the test ####
    ##########################

    throws_ok {
        my $selected_host_index = DecisionMaker::HostSelector->getHost(cluster => $cluster);
        my $host_manager        = $cluster->getManager(manager_type => "HostManager");
        my @free_hosts          = $host_manager->getFreeHosts();
        my $selected_host       = $free_hosts[$selected_host_index];

    } 'Kanopya::Exception',
      'Test 2.d : None of the hosts match the minimum bonds number constraint';
}

1;