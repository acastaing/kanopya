#!/usr/bin/perl -w

=head1 SCOPE

TODO

=head1 PRE-REQUISITE

TODO

=cut

use Test::More 'no_plan';
use Test::Exception;
use Test::Pod;
use Kanopya::Exceptions;

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
use Kanopya::Test::Retrieve;
use Kanopya::Test::Create;

use Entity::Systemimage;
use Entity::Node;
use Entity::Component::KanopyaExecutor;
use Entity::Component::Lvm2;
use Entity::Component::Iscsi::Iscsitarget1;
use Entity::Component::Linux::Debian;
use Entity::Component::Openssh5;
use Entity::Component::HCMNetworkManager;
use Entity::Component::HCMStorageManager;
use IscsiPortal;

my $testing = 0;

main();

sub main {

    if ($testing == 1) {
        Kanopya::Database::beginTransaction;

        Kanopya::Test::Register->registerHost(board => {
            ram  => 1073741824,
            core => 4,
            serial_number => 0,
            ifaces => [ { name => 'eth0', pxe => 1, mac => '00:00:00:00:00:00' } ]
        });
    }

    diag('Register master image');
    my $masterimage;
    lives_ok {
        $masterimage = Kanopya::Test::Execution::registerMasterImage();
    } 'Register master image';

    diag('Get any executor');
    my $executor;
    lives_ok {
        $executor = Entity::Component::KanopyaExecutor->find();
    } 'Get any executor';

    diag('Create the node');
    my ($node, $host);
    lives_ok {
        # Firstly get any one available host
        $host = Entity::Host->find(hash => { host_state =>  { 'LIKE' =>  'down:%' } });
        $node = Entity::Node->new(
                    host             => $host,
                    # Generate the hostname ourself as we are deploying the node ourself
                    node_hostname  => "deploy_node_test_" . time(),
                );
    } 'Create the node';

    diag('Configure node iface with admin network');
    my $adminnetconf;
    lives_ok {
        $adminnetconf = Entity::Netconf->find(hash => { netconf_name => "Kanopya admin" });
    } 'Configure node iface with admin network';

    diag('Add Lvm, Iscsi  and Debian components on the node');
    lives_ok {
        Entity::Component::Lvm2->new(executor_component => $executor)->registerNode(node => $node, master_node => 1);
        # Isci seems to do nto respond on the deployed node
        # Entity::Component::Iscsi::Iscsitarget1->new(executor_component => $executor)->registerNode(node => $node, master_node => 1);

        # Add the required system and ssh components
        # TODO: find the proper system component type frm the registred masterimage
        my $system = Entity::Component::Linux::Debian->new(
                         nameserver1        => '208.67.222.222',
                         nameserver2        => '127.0.0.1',
                         domainname         => 'my.domain',
                         default_gateway_id => ($adminnetconf->poolips)[0]->network->id,
                     );

        $system->registerNode(node => $node, master_node => 1);
        Entity::Component::Openssh5->new()->registerNode(node => $node, master_node => 1);
    } 'Add component to the node';

    diag('Create the system image for the node to deploy');
    my $systemimage;
    lives_ok {
        my $lvm = Entity::Component::Lvm2->find();
        my $iscsi = Entity::Component::Iscsi::Iscsitarget1->find();

        my $hcmstorage = EEntity->new(entity => Entity::Component::HCMStorageManager->find());
        $systemimage = $hcmstorage->createSystemImage(systemimage_name  => "deploy_node_test_" . time(),
                                                      systemimage_size  => 1024 * 1024 * 1024 * 4,
                                                      disk_manager_id   => $lvm->id,
                                                      export_manager_id => $iscsi->id,
                                                      masterimage       => $masterimage,
                                                      iscsi_portal      => IscsiPortal->find()->id);

    } 'Create the system image for the node to deploy';

    diag('Deploy the node via the KanopyaDeploymentManager');
    lives_ok {
        my $deployment_mamager = Entity::Component::KanopyaDeploymentManager->find();
        my $operation = $deployment_mamager->deployNode(
                            node            => $node,
                            systemimage     => $systemimage,
                            kernel_id       => $masterimage->masterimage_defaultkernel_id,
                            boot_policy     => 'PXE Boot via ISCSI',
                            boot_manager_id => $deployment_mamager->id,
                            network_manager => Entity::Component::HCMNetworkManager->find(),
                            interfaces      => {
                                admin => {
                                    interface_name => "eth0",
                                    netconfs       => {
                                        admin_netconf => $adminnetconf->id
                                    }
                                }
                            }
                        );
        Kanopya::Test::Execution->executeOne(entity => $operation);
    } 'Deploy the node via the KanopyaDeploymentManager';

    if ($testing == 1) {
        Kanopya::Database::rollbackTransaction;
    }
}

1;
