#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

TODO

=cut

use Test::More 'no_plan';
use Test::Exception;

use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level=>'DEBUG',
    file=>'openstack.t.log',
    layout=>'%F %L %p %m%n'
});

use BaseDB;
use NetconfVlan;
use Entity::Vlan;

use Kanopya::Tools::Execution;
use Kanopya::Tools::Register;
use Kanopya::Tools::Retrieve;
use Kanopya::Tools::Create;
use Kanopya::Tools::TestUtils 'expectedException';

my $testing = 0;

main();

sub main {
    BaseDB->authenticate( login =>'admin', password => 'K4n0pY4' );

    if ($testing == 1) {
        BaseDB->beginTransaction;
    }

    diag('Register master image');
    my $masterimage;
    lives_ok {
        #$masterimage = Kanopya::Tools::Register::registerMasterImage();
	use Entity::Masterimage;
	$masterimage = Entity::Masterimage->find;
    } 'Register master image';

    diag('Create and configure MySQL and RabbitMQ cluster');
    my $cloud;
    lives_ok {
        $cloud = Kanopya::Tools::Create->createCluster(
                        cluster_conf => {
                            cluster_name         => 'CloudController',
                            cluster_basehostname => 'cloud'
                        },
                        components => {
                            'mysql' => {
                            },
                            'amqp'  => {
                            },
                            'keystone' => {
                            },
                            'novacontroller' => {
                                overcommitment_cpu_factor    => 1,
                                overcommitment_memory_factor => 1
                            },
                            'glance' => {
                            },
                            'quantum' => {
                            },
                            'fileimagemanager' => {
                            }
                        }
                    );
    } 'Create MySQL and RabbitMQ cluster';

    my $sql = $cloud->getComponent(name => 'Mysql');
    my $amqp = $cloud->getComponent(name => 'Amqp');
    my $keystone = $cloud->getComponent(name => 'Keystone');
    my $nova_controller = $cloud->getComponent(name => "NovaController");
    my $glance = $cloud->getComponent(name => "Glance");
    my $quantum = $cloud->getComponent(name => "Quantum");

    $keystone->setConf(conf => {
        mysql5_id   => $sql->id,
    });

    $nova_controller->setConf(conf => {
        mysql5_id   => $sql->id,
        keystone_id => $keystone->id,
        amqp_id     => $amqp->id
    });

    $glance->setConf(conf => {
        mysql5_id          => $sql->id,
        nova_controller_id => $nova_controller->id
    });

    $quantum->setConf(conf => {
        mysql5_id          => $sql->id,
        nova_controller_id => $nova_controller->id
    });

    diag('Create and configure Nova compute cluster');
    my $compute;
    lives_ok {
        $compute = Kanopya::Tools::Create->createCluster(
                       cluster_conf => {
                           cluster_name         => 'Compute',
                           cluster_basehostname => 'compute' 
                       },
                       components => {
                           'novacompute'  => {
                               nova_controller_id => $nova_controller->id,
                               iaas_id            => $nova_controller->id,
                               mysql5_id          => $sql->id
                           },
                       }
                   );
    } 'Create Nova Compute cluster';

    lives_ok {
        Kanopya::Tools::Execution->startCluster(cluster => $cloud);
    } 'Start Cloud controller cluster';

    lives_ok {
        Kanopya::Tools::Execution->startCluster(cluster => $compute);
    } 'Start Nova Compute cluster';

    lives_ok {
        my $vm_cluster = Kanopya::Tools::Create->createVmCluster(
                             iaas => $iaas,
                             cluster_conf => {
                                 cluster_name         => 'VmCluster',
                                 cluster_basehostname => 'vmcluster',
                                 masterimage_id       => $masterimage->id,
                             }
                         );
        
    } 'Create VM cluster';

    if ($testing == 1) {
        BaseDB->rollbackTransaction;
    }
}