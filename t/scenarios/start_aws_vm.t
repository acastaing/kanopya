#!/usr/bin/perl -w

=head1 SCOPE

Create and stop a VM on AWS.

=head1 PRE-REQUISITE

An AWS account. Export the credentials into the environment
variables AWS_ACCESS_KEY and AWS_SECRET_KEY for use in this test.

=cut

use Test::More 'no_plan';
use Test::Exception;
# use Test::Pod;
use Kanopya::Exceptions;
# use ClassType::ComponentType;

use TryCatch;
use File::Basename;
use Log::Log4perl qw(:easy get_logger);
Log::Log4perl->easy_init({
    level  => 'DEBUG',
    file   => basename(__FILE__) . '.log',
    layout => '%d [ %H - %P ] %p -> %M - %m%n'
});

use Kanopya::Database;

use Kanopya::Test::Execution;
use Kanopya::Test::Register;
#use Kanopya::Test::Retrieve;
#use Kanopya::Test::Create;

#use Entity::Component::KanopyaDeploymentManager;
#use Entity::Masterimage::GlanceMasterimage;

use AWS::API;
use AWS::EC2;
use Entity::Component::Virtualization::AwsAccount;


my $testing = 1;

main();

sub main {
    Kanopya::Database::global_user_check(value => 0);

    if ($testing == 1) {
        Kanopya::Database::beginTransaction;
    }

    diag('Register/get the AWS component');
    my $aws;
    try {
        $aws = Entity::Component::Virtualization::AwsAccount->find();
    }
    catch {
        my $localhostname = `hostname`;
        chomp($localhostname);

        $aws = Kanopya::Test::Register->registerComponentOnNode(
                   componenttype => "AwsAccount",
                   hostname      => $localhostname,
                   component_params => {
                       api_access_key => $ENV{AWS_ACCESS_KEY},
                       api_secret_key => $ENV{AWS_SECRET_KEY} 
                   }
               );
    
#    my $api = AWS::API->new(aws_account => $aws);
#    my $ec2 = AWS::EC2->new(api => $api);
#    
#    $ec2->getImages(); 
                
#        foreach my $image (@$aws_images) {
#            diag("Found image: $image");
#        }

        lives_ok {
            Kanopya::Test::Execution->executeOne(entity => $aws->synchronize());
        } 'Synchronize the existing infrastructure';
    }
    
    

#    diag('Create and configure the openstack vm cluster');
#    my $cluster;
#    my $masterimage = Entity::Masterimage::GlanceMasterimage->find(
#                          hash => { masterimage_name => "trusty-server-cloudimg" }
#                      );
#
#    lives_ok {
#        my $clustername = "openstack_vm_cluster_test_" . time();
#        my $create = Entity::ServiceProvider::Cluster->create(
#                        active                => 1,
#                        cluster_name          => $clustername,
#                        cluster_min_node      => 1,
#                        cluster_max_node      => 3,
#                        cluster_priority      => "100",
#                        cluster_si_persistent => 1,
#                        cluster_domainname    => 'my.domain',
#                        cluster_nameserver1   => '208.67.222.222',
#                        cluster_nameserver2   => '127.0.0.1',
#                        owner_id              => Entity::User->find(hash => { user_login => 'admin' })->id,
#                        masterimage_id        => $masterimage->id,
#                        managers => {
#                            host_manager => {
#                                manager_id     => $openstack->id,
#                                manager_type   => "HostManager",
#                                manager_params => {
#                                    flavor => "m1.tiny",
#                                    availability_zone => "nova",
#                                    tenant => "Doc",
#                                },
#                            },
#                            storage_manager => {
#                                manager_id     => $openstack->id,
#                                manager_type   => "StorageManager",
#                                manager_params => {
#                                    volume_type => "dummy",
#                                    systemimage_size => $masterimage->masterimage_size + (1024 * 1024 * 1024),
#                                },
#                            },
#                            deployment_manager => {
#                                manager_id     => Entity::Component::KanopyaDeploymentManager->find()->id,
#                                manager_type   => "DeploymentManager",
#                                manager_params => {
#                                    boot_manager_id => $openstack->id,
#                                    boot_policy     => 'Boot from Glance Image',
#                                    components => {},
#                                },
#                            },
#                            network_manager => {
#                                manager_id     => $openstack->id,
#                                manager_type   => "NetworkManager",
#                                manager_params => {
#                                    subnets => [ "10.0.0.0/24 (DocNetwork)" ]
#                                },
#                            },
#                        },
#                     );
#
#        Kanopya::Test::Execution->executeOne(entity => $create);
#
#        $cluster = Kanopya::Test::Retrieve->retrieveCluster(criteria => { cluster_name => $clustername });
#    } 'Create OpenStack VM cluster';
#
#    diag('Start OpenStack VM cluster');
#    lives_ok {
#        Kanopya::Test::Execution->startCluster(cluster => $cluster);
#    } 'Start cluster';
#
#    diag('Stopping OpenStack VM cluster');
#    lives_ok {
#        my ($state, $timestamp) = $cluster->reload->getState();
#        if ($state ne 'up') {
#            die "Cluster should be up, not $state";
#        }
#        Kanopya::Test::Execution->executeOne(entity => $cluster->stop());
#    } 'Stopping OpenStack VM cluster';
#
#    diag('Remove OpenStack VM cluster');
#    lives_ok {
#        Kanopya::Test::Execution->executeOne(entity => $cluster->deactivate());
#        Kanopya::Test::Execution->executeOne(entity => $cluster->remove());
#    } 'Removing OpenStack VM cluster';
#
#    my @systemimages = Entity::Systemimage->search();
#    diag('Check if systemimage have been deleted');
#    ok(scalar(@systemimages) == 0);

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
    
    Kanopya::Database::global_user_check(value => 1);
}

1;
