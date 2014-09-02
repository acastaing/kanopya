# This script is called during setup to insert some kanopya data in DB
# The other way to insert data during setup is Data.sql.tt (pb: id management)
#

use lib qw(/opt/kanopya/lib/common/
           /opt/kanopya/lib/administrator/
           /opt/kanopya/lib/deployment/
           /opt/kanopya/lib/service/
           /opt/kanopya/lib/executor/
           /opt/kanopya/lib/monitor/
           /opt/kanopya/lib/orchestrator/
           /opt/kanopya/lib/external
           /opt/kanopya/lib/mock
           /opt/kanopya/lib/tools);

use General;
use Kanopya::Database;
use Kanopya::Config;
use Entity::Component;
use Entity::Operationtype;
use EEntity;
use ClassType;
use ClassType::ComponentType;
use ClassType::ServiceProviderType;
use ClassType::ServiceProviderType::ClusterType;
use Profile;
use Entityright;
use UserProfile;
use ComponentTemplate;
use Indicatorset;
use Ip;
use ServiceProviderManager;
use Lvm2Vg;
use Lvm2Pv;
use Lvm2Lv;
use Scope;
use ScopeParameter;
use NetconfInterface;
use NetconfPoolip;
use NetconfIface;
use ComponentCategory;
use ComponentCategory::ManagerCategory;
use Manager::HostManager;
use Dhcpd3Subnet;

use POSIX;
use Date::Simple (':all');
use Class::ISA;

use TryCatch;

# Catch warnings to clean the setup output (this warnings are not kanopya code related)
$SIG{__WARN__} = sub {
    my $warn_msg = $_[0];
};

my @classes = (
    'Entity',
    'Entity::Gp',
    'Entity::Host',
    'Entity::Hostmodel',
    'Entity::Kernel',
    'Entity::Processormodel',
    'Entity::Systemimage',
    'Entity::User',
    'Entity::User::Customer',
    'Entity::User::Customer::StackBuilderCustomer',
    'Entity::ServiceProvider::Cluster',
    'Entity::ServiceProvider::Cluster::Ubuntu12',
    'Entity::ServiceProvider::Cluster::Centos6',
    'Entity::ServiceProvider::Cluster::Debian6',
    'Entity::ServiceProvider::Cluster::Sles6',
    'Entity::ServiceProvider::Cluster::Kanopya',
    'Entity::ServiceProvider::Netapp',
    'Entity::ServiceProvider::UnifiedComputingSystem',
    'Entity::ContainerAccess::IscsiContainerAccess',
    'Entity::ContainerAccess::NfsContainerAccess',
    'Entity::ContainerAccess::LocalContainerAccess',
    'Entity::ContainerAccess::FileContainerAccess',
    'Entity::Container::LvmContainer',
    'Entity::Container::LocalContainer',
    'Entity::Container::NetappLun',
    'Entity::Container::NetappVolume',
    'Entity::Container::FileContainer',
    'Entity::Component',
    'Entity::Component::KanopyaAnomalyDetector',
    'Entity::Component::KanopyaExecutor',
    'Entity::Component::KanopyaFront',
    'Entity::Component::KanopyaAggregator',
    'Entity::Component::KanopyaRulesEngine',
    'Entity::Component::KanopyaMailNotifier',
    'Entity::Component::KanopyaOpenstackSync',
    'Entity::Component::KanopyaStackBuilder',
    'Entity::Component::KanopyaDeploymentManager',
    'Entity::Component::KanopyaServiceManager',
    'Entity::Component::HCMStorageManager',
    'Entity::Component::HCMNetworkManager',
    'Entity::Component::UcsManager',
    'Entity::Component::Fileimagemanager0',
    'Entity::Component::NetappManager',
    'Entity::Component::NetappLunManager',
    'Entity::Component::NetappVolumeManager',
    'Entity::Component::Lvm2',
    'Entity::Component::Iscsi',
    'Entity::Component::Iscsi::Iscsitarget1',
    'Entity::Component::Apache2',
    'Entity::Component::Tftpd',
    'Entity::Component::Dhcpd3',
    'Entity::Component::Haproxy1',
    'Entity::Component::Keepalived1',
    'Entity::Component::Memcached1',
    'Entity::Component::Linux',
    'Entity::Component::Mysql5',
    'Entity::Component::Openiscsi2',
    'Entity::Component::Virtualization',
    'Entity::Component::Virtualization::Opennebula3',
    'Entity::Component::Openssh5',
    'Entity::Component::Php5',
    'Entity::Component::Snmpd5',
    'Entity::Component::Syslogng3',
    'Entity::Component::Nfsd3',
    'Entity::Component::Storage',
    'Entity::Component::ActiveDirectory',
    'Entity::Component::Scom',
    'Entity::Component::Amqp',
    'Entity::Component::Virtualization::NovaController',
    'Entity::Component::Vmm::NovaCompute',
    'Entity::Component::Cinder',
    'Entity::Component::Neutron',
    'Entity::Component::Keystone',
    'Entity::Component::Glance',
    'Entity::Component::Virtualization::OpenStack',
    'Entity::Component::SwiftProxy',
    'Entity::Component::SwiftStorage',
    'Entity::Repository::OpenstackRepository',
    'Entity::Repository::Opennebula3Repository',
    'Entity::Repository::Vsphere5Repository',
    'Entity::Component::Physicalhoster0',
    'Entity::Component::DummyHostManager',
    'Entity::Component::Vmm',
    'Entity::Component::Vmm::Kvm',
    'Entity::Component::Vmm::Xen',
    'Entity::Component::Puppetagent2',
    'Entity::Component::Puppetmaster2',
    'Entity::Component::Kanopyacollector1',
    'Entity::Component::Sco',
    'Entity::Component::MockMonitor',
    'Entity::Component::Kanopyaworkflow0',
    'Entity::Component::Linux::Debian',
    'Entity::Component::Linux::Suse',
    'Entity::Component::Linux::Redhat',
    'Entity::ServiceProvider::Externalcluster',
    'Entity::Poolip',
    'Entity::Vlan',
    'Entity::Masterimage',
    'Entity::NfsContainerAccessClient',
    'Entity::Network',
    'Entity::Netconf',
    'Entity::NetconfRole',
    'Entity::Interface',
    'Entity::Iface',
    'Entity::Repository',
    'Entity::NetappAggregate',
    'Entity::Billinglimit',
    'Entity::ServiceProvider',
    'Entity::Host::Hypervisor',
    'Entity::Host::VirtualMachine',
    'Entity::Host::Hypervisor::Opennebula3Hypervisor',
    'Entity::Host::VirtualMachine::Opennebula3Vm',
    'Entity::Host::Hypervisor::OpenstackHypervisor',
    'Entity::Host::VirtualMachine::OpenstackVm',
    'Entity::Host::VirtualMachine::Opennebula3Vm::Opennebula3KvmVm',
    'Entity::ServiceTemplate',
    'Entity::Operation',
    'Entity::Operationtype',
    'Entity::Policy',
    'Entity::Policy::HostingPolicy',
    'Entity::Policy::StoragePolicy',
    'Entity::Policy::NetworkPolicy',
    'Entity::Policy::SystemPolicy',
    'Entity::Policy::ScalabilityPolicy',
    'Entity::Policy::BillingPolicy',
    'Entity::Policy::OrchestrationPolicy',
    'Entity::Workflow',
    'Entity::Host::Hypervisor::Vsphere5Hypervisor',
    'Entity::Host::VirtualMachine::Vsphere5Vm',
    'Entity::Component::Virtualization::Vsphere5',
    'Entity::Indicator',
    'Entity::CollectorIndicator',
    'Entity::Metric',
    'Entity::Metric::Anomaly',
    'Entity::Metric::Clustermetric',
    'Entity::Metric::Combination',
    'Entity::Metric::Combination::NodemetricCombination',
    'Entity::Metric::Combination::ConstantCombination',
    'Entity::Metric::Combination::AggregateCombination',
    'Entity::Metric::Nodemetric',
    'Entity::AggregateCondition',
    'Entity::Rule::AggregateRule',
    'Entity::NodemetricCondition',
    'Entity::Rule::NodemetricRule',
    'Entity::WorkflowDef',
    'Entity::Rule',
    'Entity::TimePeriod',
    'Entity::Component::Ceph',
    'Entity::Component::Ceph::CephMon',
    'Entity::Component::Ceph::CephOsd',
    'Entity::Tag',
    'Entity::Component::HpcManager',
    'Entity::ServiceProvider::Hpc7000',
    'Entity::Node'
);

sub registerKernels {
    my @kernels = (
        [ 'deployment', '3.0.51-0.7.9-default', 'Kanopya deployment' ]
    );

    for my $kernel (@kernels) {
        Entity::Kernel->new(
            kernel_name    => $kernel->[0],
            kernel_version => $kernel->[1],
            kernel_desc    => $kernel->[2]
        );
    }
}

sub registerClassTypes {
    for my $class_type (@classes) {
        ClassType->findOrCreate(class_type => $class_type);
    }
}

sub registerUsers {
    my %args = @_;
    my $admin_group;

    my $groups = [
        { name    => 'Entity',
          type    => 'Entity',
          desc    => 'Entity master group containing all entities',
          system  => 1
        },
        { name    => 'Admin',
          type    => 'User',
          desc    => 'Privileged users for administration tasks',
          system  => 1,
          profile => [ 'Super Admin', 'God profile : full access to the user interface.' ]
        },
        { name    => 'Administrator',
          type    => 'User',
          desc    => 'Administrator group',
          system  => 0,
          profile => [ 'Administrator', 'administrator profile' ]
        },
        { name    => 'ServiceDeveloper',
          type    => 'User',
          desc    => 'Service developer group',
          system  => 0,
          profile => [ 'Services Developer', 'services dev profile' ]
        },
        { name    => 'Sales',
          type    => 'User',
          desc    => 'Sales group',
          system  => 0,
          profile => [ 'Sales', 'sale profile' ]
        },
        { name    => 'Customer',
          type    => 'User',
          desc    => 'Customer group',
          system  => 0,
          profile => [ 'Customer', 'customer profile' ],
          methods => {
              'Sales' => [ 'create', 'update', 'remove', 'get' ],
          }
        },
        { name    => 'Guest',
          type    => 'User',
          desc    => 'Guest group',
          system  => 0,
          profile => [ 'Guest', 'guest profile' ],
        },
        { name    => 'User',
          type    => 'User',
          desc    => 'User master group containing all users',
          system  => 1,
        },
        { name    => 'Processormodel',
          type    => 'Processormodel',
          desc    => 'Processormodel master group containing all processor models',
          system  => 1
        },
        { name    => 'Hostmodel',
          type    => 'Hostmodel',
          desc    => 'Hostmodel master group containing all host models',
          system  => 1
        },
        { name    => 'Host',
          type    => 'Host',
          desc    => 'Host master group containing all hosts',
          system  => 1
        },
        { name    => 'ServiceProvider',
          type    => 'ServiceProvider',
          desc    => 'ServiceProvider master group containing all service providers',
          system  => 1,
          methods => {
              'ServiceDeveloper' => [ 'addManager', 'create', 'remove' ],
          }
        },
        { name    => 'Cluster',
          type    => 'Cluster',
          desc    => 'Cluster master group containing all clusters',
          system  => 1,
          methods => {
              'Sales' => [ 'get', 'create' ],
          }
        },
        { name    => 'Kernel',
          type    => 'Kernel',
          desc    => 'Kernel master group containing all kernels',
          system  => 1
        },
        { name    => 'Systemimage',
          type    => 'Systemimage',
          desc    => 'Systemimage master group containing all system images',
          system  => 1
        },
        { name    => 'Operationtype',
          type    => 'Operationtype',
          desc    => 'Operationtype master group containing all operations',
          system  => 1,
          methods => {
              'Sales' => [ 'subscribe', 'unsubscribe' ],
              'Administrator' => [ 'subscribe', 'unsubscribe' ],
          }
        },
        { name    => 'Masterimage',
          type    => 'Masterimage',
          desc    => 'Masterimage master group containing all master images',
          system  => 1
        },
        { name    => 'Component',
          type    => 'Component',
          desc    => 'Component group containing all components',
          system  => 1,
          methods => {
              'ServiceDeveloper' => [ 'get' ],
              'Sales'            => [ 'get', 'getConf' ],
              'Guest'            => [ 'getManagerParamsDef' ]
          }
        },
        { name    => 'Policy',
          type    => 'Policy',
          desc    => 'Policy group containing all policies',
          system  => 1,
          methods => {
              'ServiceDeveloper' => [ 'create', 'remove', 'update', 'get' ],
              'Sales'            => [ 'get' ],
          }
        },
        { name    => 'ServiceTemplate',
          type    => 'ServiceTemplate',
          desc    => 'ServiceTemplate group containing all service templates',
          system  => 1,
          methods => {
              'ServiceDeveloper' => [ 'create', 'update', 'remove', 'get' ],
              'Sales'            => [ 'get' ]
          }
        },
        { name    => 'WorkflowDef',
          type    => 'WorkflowDef',
          desc    => 'WorkflowDef group containing all workflow definitions',
          system  => 1,
          # Required as service intance user need to get workflows definitions
          # when associating workflow to rules. Better architecture should remove
          # this requirement.
          methods => {
              'ServiceDeveloper' => [ 'get' ],
              'Sales'            => [ 'get' ],
              'Customer'         => [ 'get' ],
          }
        },
        { name    => 'Network',
          type    => 'Network',
          desc    => 'Network group containing all service templates',
          system  => 1
        },
        { name    => 'Gp',
          type    => 'Gp',
          desc    => 'Groups master group containing all groups',
          system  => 1
        },
        { name    => 'Workflow',
          type    => 'Workflow',
          desc    => 'Workflow master group containing all workflows',
          system  => 1,
          methods => {
              'Sales' => [ 'get', 'cancel' ],
          }
        },
        { name    => 'Operation',
          type    => 'Operation',
          desc    => 'Operation master group containing all operations',
          system  => 1,
          methods => {
              'Sales' => [ 'get' ],
          }
        },
        # Re-handle the Entity group here to set permissions on methods,
        # indeed, we need have user groups created before setting permissions,
        # but we need to have the Entity group created at first.
        { name    => 'Entity',
          type    => 'Entity',
          desc    => 'Entity master group containing all entities',
          system  => 1,
          methods => {
              'Administrator' => [ 'create', 'update', 'remove', 'get', 'addPerm', 'removePerm' ],
              'Guest'         => [ 'get' ]
          }
        },
    ];

    # Browse all class types to find api methods
    CLASSTYPE:
    for my $classtype (@classes) {
        try {
            General::requireClass($classtype);
        }
        catch ($err) {
            # For instance, only some service provider has a concrete type
            # without the coresponding class.
            if ($classtype !~ m/^Entity::ServiceProvider.*/) {
                $err->rethrow();
            }
            next CLASSTYPE;
        }

        my $hierarchy = $classtype;
        my ($parenttype) = Class::ISA::super_path($classtype);
        my $methods    = $classtype->_methodsDefinition;
        for my $parentmethod (keys %{ $parenttype->_methodsDefinition }) {
            delete $methods->{$parentmethod};
        }

        my @methodlist = keys %$methods;
        if (scalar (@methodlist)) {
            $classtype =~ s/.*\:\://g;
            push @{$groups}, {
                name      => $classtype,
                type      => $classtype,
                desc      => $classtype . " master group",
                hierarchy => $hierarchy,
                system    => 1,
                methods   => {
                    'Administrator' => \@methodlist
                }
            }
        }
    }

    my @adminprofiles;
    my $profilegroups = {};
    for my $group (@{$groups}) {
        my $gp = Entity::Gp->findOrCreate(gp_name => $group->{name},
                                          gp_type => $group->{type});
        $gp->gp_desc($group->{desc});

        if ($group->{hierarchy}) {
            $gp->appendToHierarchyGroups(hierarchy => $group->{hierarchy});
        }

        if (defined ($group->{methods})) {
            for my $gpname (keys %{ $group->{methods} }) {
                for my $method (@{ $group->{methods}->{$gpname} }) {
                    print "\t\t- Setting permissions for group " . $gpname .
                          ", on method " . $gp->gp_name . "->" . $method . "\n";

                    Entityright->findOrCreate(
                        entityright_consumed_id => $gp->id,
                        entityright_consumer_id => $profilegroups->{$gpname}->id,
                        entityright_method      => $method
                    );
                }
            }
        }

        if (defined ($group->{profile})) {
            my $prof;
            eval {
                $prof = Profile->new(profile_name => $group->{profile}->[0],
                                     profile_desc => $group->{profile}->[1]);

                $prof->{_dbix}->profile_gps->create({
                    profile_id => $prof->id,
                    gp_id      => $gp->id
                });
            };
            if ($@) {
                $prof = Profile->find(profile_name => $group->{profile}->[0]);
            }

            if ($group->{system} == 0) {
                push @adminprofiles, $prof;
                $profilegroups->{$group->{name}} = $gp;
            }
        }
    }

    eval {
        Entity::User->find(hash => { user_login => "admin" });
    };
    if ($@) {
        my $admin_user = Entity::User->create(
                             user_system       => 0,
                             user_login        => "admin",
                             user_password     => $args{admin_password},
                             user_firstname    => 'Kanopya',
                             user_lastname     => 'Administrator',
                             user_email        => 'dev@hederatech.com',
                             user_creationdate => today(),
                             user_desc         => 'God user for administrative tasks.'
                         );

        for my $profile (@adminprofiles) {
            UserProfile->new(
                user_id    => $admin_user->id,
                profile_id => $profile->id
            );
        }
    }

    eval {
        Entity::User->find(hash => { user_login => "executor" });
    };
    if ($@) {
        my $executor_user = Entity::User->create(
            user_system       => 1,
            user_login        => "executor",
            user_password     => $args{admin_password},
            user_firstname    => 'Kanopya',
            user_lastname     => 'Executor',
            user_email        => 'dev@hederatech.com',
            user_creationdate => today(),
            user_desc         => 'User used by executor'
        );
    }

    eval {
        Entity::User->find(hash => { user_login => "rulesengine" });
    };
    if ($@) {
        my $rulesengine_user = Entity::User->create(
            user_system       => 1,
            user_login        => "rulesengine",
            user_password     => $args{admin_password},
            user_firstname    => 'Kanopya',
            user_lastname     => 'Rules engine',
            user_email        => 'dev@hederatech.com',
            user_creationdate => today(),
            user_desc         => 'User used by the Kanopya rules engine'
        );
    }
}

sub registerProcessorModels {
    my %args = @_;

    my $models = [
        {
            processor  => [ 'Generic', 'Generic', 1, 1.0, 1, 1,1 , 1 ],
            hostmodels => [
                [ 'Generic', 'Generic', 'Generic', 1, 1, 20, 1, 1 ]
            ]
        },
        {
            processor  => [ 'Intel', 'Atom 330', 2, 1.6, 1, 8, 1, 0 ],
            hostmodels => [
                [ 'Intel', 'DG945GCLF2', '945GC', 1, 42, 1, 1, 2 ],
                [ 'Asus', 'AT3GC-I', '945GC', 1, 42, 1, 1, 2, ],
                [ 'Asus', 'AT3N7A-I', 'NVIDIA ION', 1, 40, 1, 2, 4 ],
                [ 'J&W', 'MINIX ATOM330', '945GC', 1, 46, 1, 1, 2 ],
            ]
        },
        {
            processor  => [ 'Intel', 'Atom D510', 2, 1.66, 1, 13, 1, 0 ],
            hostmodels => [
                [ 'Gigabyte', 'GA-D510UD', 'INTEL NM10', 1, 26, 1, 2, 4 ],
                [ 'Intel', 'D510MO', 'INTEL NM10', 1, 21, 1, 2, 4 ],
            ]
        },
        {
            processor  => [ 'VIA Nano', 'L2200', 2, 1.6, 1, 13, 1, 0 ],
            hostmodels => [
                [ 'Via', 'VB8001', 'VIA CN896', 1, 17, 1, 2, 4 ],
            ]
        },
        {
            processor  => [ 'Intel', 'i3-330', 2, 2.1, 3, 35, 1, 1 ]
        },
        {
            processor  => [ 'Intel', 'i5-430', 2, 2.4, 3, 35, 1, 1 ]
        },
        {
            processor  => [ 'Intel', 'i7-640M', 2, 2.8, 4, 35, 1, 1 ]
        },
        {
            processor  => [ 'Intel', 'i7-720QM', 4, 1.6, 6, 45, 1, 1 ]
        },
        {
            processor  => [ 'AMD', 'Ontario', 2, 1.6, 1, 9, 1, 1 ],
            hostmodels => [
                [ 'Jetway', 'JNF81', 'Hudson E1', 1, 17, 2, 2, 8 ]
            ]
        },
        {
            processor => [ 'AMD', 'G-T56N', 2, 1.6, 1, 18, 1, 1 ]
        },
        {
            hostmodels => [
                [ 'IEI', 'Kino HM551', 'Intel HM55', 1, 32, 2, 2, 8 ]
            ]
        }
    ];

    for $model (@{$models}) {
        my $processor;
        if (defined ($model->{processor})) {
            my @proc = @{$model->{processor}};
            $processor = Entity::Processormodel->new(
                             processormodel_brand       => $proc[0],
                             processormodel_name        => $proc[1],
                             processormodel_core_num    => $proc[2],
                             processormodel_clock_speed => $proc[3],
                             processormodel_l2_cache    => $proc[4],
                             processormodel_max_tdp     => $proc[5],
                             processormodel_64bits      => $proc[6],
                             processormodel_virtsupport => $proc[7]
                         );
        }

        if (defined ($model->{hostmodels})) {
            for my $hostmodel (@{$model->{hostmodels}}) {
                Entity::Hostmodel->new(
                    hostmodel_brand         => $hostmodel->[0],
                    hostmodel_name          => $hostmodel->[1],
                    hostmodel_chipset       => $hostmodel->[2],
                    hostmodel_processor_num => $hostmodel->[3],
                    hostmodel_consumption   => $hostmodel->[4],
                    hostmodel_iface_num     => $hostmodel->[5],
                    hostmodel_ram_slot_num  => $hostmodel->[6],
                    hostmodel_ram_max       => $hostmodel->[7],
                    processormodel_id       => defined ($processor) ? $processor->id : undef
                );
            }
        }
    }
}

sub registerOperations {
    my %args = @_;

    my $operations = [
        [ 'DummyOperation', 'Doing dummy job..."' ],
        [ 'AddCluster', 'Instanciating new service "[% cluster_params.cluster_name %]"' ],
        [ 'RemoveCluster', 'Removing service "[% cluster ? cluster : "n/a" %]"' ],
        [ 'ActivateCluster', 'Activating service "[% cluster ? cluster : "n/a" %]"' ],
        [ 'DeactivateCluster', 'Deactivating service "[% cluster ? cluster : "n/a" %]"' ],
        [ 'StopCluster', 'Stopping service "[% cluster ? cluster : "n/a" %]"' ],
        [ 'RemoveSystemimage', 'Removing system image "[% systemimage %]"' ],
        [ 'CreateDisk', 'Creating new disk "[% name %]"' ],
        [ 'CreateExport', 'Exporting disk "[% container %]"' ],
        [ 'ForceStopCluster', 'Force stopping instance "[% cluster %]"' ],
        [ 'MigrateHost', 'Migrating virtual machine "[% vm ? vm : "n/a" %]" to hypervisor "[% host ? host : "n/a" %]"' ],
        [ 'RemoveDisk', 'Removing disk "[% container ? container : "n/a" %]"' ],
        [ 'RemoveExport', 'Removing export "[% container_access ? container_access : "n/a" %]"' ],
        [ 'DeployMasterimage', 'Deploying master image' ],
        [ 'RemoveMasterimage', 'Removing master image "[% masterimage ? masterimage : "n/a" %]"' ],
        [ 'ScaleCpuHost', 'Scaling [% cpu_number ? cpu_number : "n/a" %] cpu on host "[% host ? host : "n/a" %]"' ],
        [ 'ScaleMemoryHost', 'Scaling [% memory ? memory : "n/a" %]o. of memory on host "[% host ? host : "n/a" %]"' ],
        [ 'LaunchSCOWorkflow' ],
        [ 'UpdateCluster', 'Reconfigure instance "[% cluster ? cluster : "n/a" %]"' ],
        [ 'LaunchScaleInWorkflow', 'Configuring scale in for node node "[% host ? host : "n/a" %]"' ],
        [ 'LaunchOptimiaasWorkflow' ],
        [ 'ProcessRule', 'Processing triggered rule "[% rule %]"' ],
        [ 'ResubmitNode', 'Resubmit virtual machine "[% host ? host : "n/a" %]"' ],
        [ 'RelieveHypervisor', 'Relieve hypervisor "[% host ? host : "n/a" %]"' ],
        [ 'Synchronize', 'Synchronize component "[% entity ? entity : "n/a" %]"' ],
        [ 'FlushHypervisor', 'Compute flush hypervisor plan for "[% flushed_hypervisor ? flushed_hypervisor : "n/a" %]"' ],
        [ 'ResubmitHypervisor', 'Resubmit virtual machines of hypervisor "[% host ? host : "n/a" %]"' ],
        [ 'SelectDataModel', 'Compute data model of combination "[% combination ? combination : "n/a" %]"' ],
        [ 'SynchronizeInfrastructure', 'Synchronize infrastructure' ],
        # Workflow AddNode
        [ 'AddNode', 'Preparing a new node for instance "[% cluster ? cluster : "n/a" %]"' ],
        [ 'PreStartNode', 'Configuring node "[% host ? host : "n/a" %]"' ],
        [ 'PostStartNode', 'Validating node "[% host ? host : "n/a" %]"' ],
        # Workflow StopNode
        [ 'PreStopNode', 'Configuring node removal for instance "[% cluster ? cluster : "n/a" %]"' ],
        [ 'PostStopNode', 'Finalizing removing node "[% host ? host : "n/a" %]"' ],
        # Workflow Deploy/ReleaseNode
        [ 'PrepareNode', 'Configuring node "[% node ? node : "n/a" %]"' ],
        [ 'UnconfigureNode', 'Unconfiguring node "[% node ? node : "n/a" %]"' ],
        [ 'DeployNode', 'Deploying node "[% node ? node : "n/a" %]"' ],
        [ 'ReleaseNode', 'Releasing node "[% node ? node : "n/a" %]"' ],
        # Workflow BuildStack
        [ 'BuildStack', 'Building stack' ],
        [ 'StartStack', 'Starting stack' ],
        [ 'ConfigureStack', 'Configuring stack' ],
        # Workflow EndStack
        [ 'UnconfigureStack', 'Unconfiguring stack' ],
        [ 'StopStack', 'Stopping stack' ],
        [ 'EndStack', 'Ending stack' ],
    ];

    for my $operation (@{$operations}) {
        Entity::Operationtype->new(
            operationtype_name  => $operation->[0],
            operationtype_label => $operation->[1] || ''
        );
    }
}

sub registerManagerCategories {
    my %args = @_;

    my $managers = [
        'HostManager',
        'VirtualMachineManager',
        'StorageManager',
        'DiskManager',
        'ExportManager',
        'DeploymentManager',
        'BootManager',
        'NetworkManager',
        'CollectorManager',
        'NotificationManager',
        'WorkflowManager',
        'DirectoryServiceManager',
    ];

    for my $manager (@{$managers}) {
        ComponentCategory::ManagerCategory->new(
            category_name  => $manager
        );
    }
}

sub registerTags {
    my %args = @_;

    my @tags = (
        'hypervisor',
        'storage',
        'high performance computing',
    );

    for my $tag (@tags) {
        Entity::Tag->new(tag => $tag);
    }
}

sub registerServiceProviders {
    my %args = @_;

    my $serviceproviders = [
        { service_provider_name => 'Externalcluster' },
        { service_provider_name => 'Netapp' },
        { service_provider_name => 'UnifiedComputingSystem' },
        { service_provider_name => 'Hpc7000' },
    ];

    my $clusters = [
        { service_provider_name => 'Ubuntu12' },
        { service_provider_name => 'Centos6' },
        { service_provider_name => 'Debian6' },
        { service_provider_name => 'Sles6' },
        { service_provider_name => 'Kanopya' },
    ];

    for my $serviceprovider_type (@{ $serviceproviders }) {
        my $class_type = ClassType->find(hash => {
                             class_type => {
                                 like => "Entity::ServiceProvider::%" . $serviceprovider_type->{service_provider_name}
                             }
                         });

        ClassType::ServiceProviderType->promote(
            promoted              => $class_type,
            service_provider_name => $serviceprovider_type->{service_provider_name},
        );
    }

    ClassType::ServiceProviderType::ClusterType->promote(
        promoted              => ClassType->find(hash => { class_type => 'Entity::ServiceProvider::Cluster' }),
        service_provider_name => 'Cluster',
    );

    for my $cluster_type (@{ $clusters }) {
        my $class_type = ClassType->find(hash => {
                             class_type => {
                                 like => "Entity::ServiceProvider::Cluster::%" . $cluster_type->{service_provider_name}
                             }
                         });

        ClassType::ServiceProviderType::ClusterType->promote(
            promoted              => $class_type,
            service_provider_name => $cluster_type->{service_provider_name},
        );
    }
}

sub registerComponents {
    my %args = @_;

    my $components = [
        {
            component_name         => 'Openssh',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'RemoteShell' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6', 'Kanopya' ],
        },
        {
            component_name         => 'Storage',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'DiskManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Lvm',
            component_version      => 2,
            deployable             => 1,
            component_categories   => [ 'DiskManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Apache',
            component_version      => 2,
            deployable             => 1,
            component_categories   => [ 'Webserver' ],
            component_template     => 'components/apache2',
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Iscsi',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'ExportManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Iscsitarget',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'ExportManager', 'BlockExportManager' ],
            component_template     => 'components/ietd',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Debian6' ],
        },
        {
            component_name         => 'Openiscsi',
            component_version      => 2,
            deployable             => 1,
            component_categories   => [ 'Exportclient' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Dhcpd',
            component_version      => 3,
            deployable             => 1,
            component_categories   => [ 'Dhcpserver' ],
            component_template     => 'components/dhcpd',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Tftpd',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'Tftpserver' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Debian6' ],
        },
        {
            component_name         => 'Snmpd',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'Monitoragent' ],
            component_template     => 'components/snmpd',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Nfsd',
            component_version      => 3,
            deployable             => 1,
            component_categories   => [ 'ExportManager' ],
            component_template     => 'components/nfsd3',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Linux',
            component_version      => 5,
            deployable             => 0,
            component_categories   => [ 'System' ],
            component_template     => 'components/linux',
            service_provider_types => [ 'Cluster' ],
        },
        {
            component_name         => 'Mysql',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'DBMS' ],
            component_template     => 'components/nfsd3',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Syslogng',
            component_version      => 3,
            deployable             => 1,
            component_categories   => [ 'Logger' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Opennebula',
            component_version      => 3,
            deployable             => 1,
            component_categories   => [ 'HostManager', 'VirtualMachineManager', 'NetworkManager' ],
            service_provider_types => [ 'Cluster', 'Centos6', 'Sles6' ],
        },
        {
            component_name         => 'Physicalhoster',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'Hostmanager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Fileimagemanager',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'DiskManager', 'ExportManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Puppetagent',
            component_version      => 2,
            deployable             => 1,
            component_categories   => [ 'Configurationagent' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Puppetmaster',
            component_version      => 2,
            deployable             => 1,
            component_categories   => [ 'Configurationserver' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Kanopyacollector',
            component_version      => 1,
            deployable             => 0,
            component_categories   => [ 'CollectorManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Keepalived',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'LoadBalancer' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Haproxy',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'LoadBalancer' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Kanopyaworkflow',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'WorkflowManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'KanopyaMailNotifier',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'NotificationManager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
        {
            component_name         => 'Memcached',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'Cache' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Php',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'Lib' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Vsphere',
            component_version      => 5,
            deployable             => 1,
            component_categories   => [ 'HostManager', 'VirtualMachineManager', 'Hypervisor' ],
            service_provider_types => [ 'Cluster' ],
        },
        {
            component_name         => 'Debian',
            component_version      => 6,
            deployable             => 0,
            component_categories   => [ 'System' ],
            component_template     => 'components/debian',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Debian6' ],
        },
        {
            component_name         => 'Redhat',
            component_version      => 6,
            deployable             => 0,
            component_categories   => [ 'System' ],
            component_template     => 'components/redhat',
            service_provider_types => [ 'Cluster', 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'Suse',
            component_version      => 11,
            deployable             => 0,
            component_categories   => [ 'System' ],
            component_template     => 'components/suse',
            service_provider_types => [ 'Cluster', 'Sles6' ],
        },
        {
            component_name         => 'Kvm',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'Hypervisor' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'Xen',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'Hypervisor' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6', 'Sles6' ],
        },
        {
            component_name         => 'ActiveDirectory',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'DirectoryServiceManager' ],
            service_provider_types => [ 'Externalcluster' ],
        },
        {
            component_name         => 'Scom',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'CollectorManager' ],
            service_provider_types => [ 'Externalcluster' ],
        },
        {
            component_name         => 'Sco',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'WorkflowManager' ],
            service_provider_types => [ 'Externalcluster' ],
        },
        {
            component_name         => 'MockMonitor',
            component_version      => 1,
            deployable             => 0,
            component_categories   => [ 'CollectorManager' ],
            service_provider_types => [ 'Cluster', 'Externalcluster' ],
        },
        {
            component_name         => 'UcsManager',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'HostManager', 'NetworkManager' ],
            service_provider_types => [ 'UnifiedComputingSystem' ],
        },
        {
            component_name         => 'NetappLunManager',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'DiskManager', 'ExportManager' ],
            service_provider_types => [ 'Netapp' ],
        },
        {
            component_name         => 'NetappVolumeManager',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ 'DiskManager', 'ExportManager' ],
            service_provider_types => [ 'Netapp' ],
        },
        {
            component_name         => 'Cinder',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ 'DiskManager', 'ExportManager', 'BlockExportManager' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'Glance',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'OpenStack',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ 'HostManager', 'VirtualMachineManager', 'StorageManager', 'NetworkManager', 'BootManager' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'Keystone',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'NovaCompute',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ 'Hypervisor' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'NovaController',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ 'HostManager', 'VirtualMachineManager', 'NetworkManager' ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'Neutron',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'Amqp',
            component_version      => 6,
            deployable             => 1,
            component_categories   => [ 'MessageQueuing' ],
            service_provider_types => [ 'Cluster', 'Kanopya', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'Virtualization',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ ],
        },
        {
            component_name         => 'KanopyaFront',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaExecutor',
            component_version      => 0,
            deployable             => 0,
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaDeploymentManager',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'DeploymentManager', 'BootManager' ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'HCMStorageManager',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'StorageManager' ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'HCMNetworkManager',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'NetworkManager' ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaServiceManager',
            component_version      => 0,
            deployable             => 0,
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaAggregator',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaAnomalyDetector',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaRulesEngine',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaOpenstackSync',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'KanopyaStackBuilder',
            component_version      => 0,
            deployable             => 0,
            component_template     => 'components/stackbuilder',
            component_categories   => [ ],
            service_provider_types => [ 'Kanopya', 'Centos6' ],
        },
        {
            component_name         => 'Ceph',
            component_version      => 0,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'CephMon',
            component_version      => 0,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'CephOsd',
            component_version      => 0,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6', 'Debian6' ],
        },
        {
            component_name         => 'HpcManager',
            component_version      => 0,
            deployable             => 1,
            component_categories   => [ 'HostManager' ],
            service_provider_types => [ 'Hpc7000' ],
        },
        {
            component_name         => 'SwiftProxy',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6' ],
        },
        {
            component_name         => 'SwiftStorage',
            component_version      => 1,
            deployable             => 1,
            component_categories   => [ ],
            service_provider_types => [ 'Cluster', 'Ubuntu12', 'Centos6' ],
        },
    ];

    # Include the mocks
    if ($args{include_mocks}) {
        push @{ $components }, {
            component_name         => 'DummyHostManager',
            component_version      => 0,
            deployable             => 0,
            component_categories   => [ 'Hostmanager' ],
            service_provider_types => [ 'Cluster', 'Kanopya' ],
        },
    }

    for my $component_type (@{ $components }) {
        my $class_type;
        eval {
            $class_type = ClassType->find(hash => {
                              class_type => {
                                  like => "Entity::Component::%" . $component_type->{component_name}
                              }
                          });
        };
        if ($@) {
            $class_type = ClassType->find(hash => {
                              class_type => {
                                  like => "Entity::Component::%" .
                                          $component_type->{component_name} .
                                          $component_type->{component_version}
                              }
                          });
        }

        my @categories;
        for my $category (@{ $component_type->{component_categories} }) {
            eval {
                push @categories, ComponentCategory->find(hash => { category_name => $category });
            };
            if ($@) {
                push @categories, ComponentCategory->new(category_name => $category);
            }
        }

        my @servicetypes;
        for my $servicetype (@{ $component_type->{service_provider_types} }) {
            push @servicetypes, ClassType::ServiceProviderType->find(hash => { service_provider_name => $servicetype });
        }

        my $type = ClassType::ComponentType->promote(
            promoted                              => $class_type,
            component_name                        => $component_type->{component_name},
            component_version                     => $component_type->{component_version},
            deployable                            => $component_type->{deployable},
            component_type_categories             => \@categories,
            service_provider_type_component_types => \@servicetypes,
        );

        if (defined $component_type->{component_template}) {
            ComponentTemplate->new(
                component_template_name      => lc($component_type->{component_name}),
                component_template_directory => $component_type->{component_template},
                component_type_id            => $type->id
            );
        }
    }
}

sub registerNetconfRoles {
    my %args = @_;

    my @roles = ( [ 'admin', 'Network used for system administration' ],
                  [ 'public', 'Network used for public access' ],
                  [ 'vms', 'Network used for virtual machines' ],
                  [ 'private', 'Private network' ] );

    for my $role (@roles) {
        Entity::NetconfRole->new(
            netconf_role_name => $role->[0]
        )->setComment(comment => $role->[1]);
    }
}

sub registerIndicators {
    my %args = @_;

    my $indicators = [
        {
            set => {
                name      => 'mem',
                provider  => 'SnmpProvider',
                type      => 'GAUGE',
                component => undef,
                max       => 'Total',
                tableoid  => undef,
                indexoid  => undef
            },
            indicators => [
                [ 'mem/Total', 'Total', '.1.3.6.1.4.1.2021.4.5.0', undef, undef, 'FFFF0066', 'KBytes', undef ],
                [ 'mem/Available', 'Avail', '.1.3.6.1.4.1.2021.4.6.0', undef, undef, '00FF0066', 'KBytes', undef ],
                [ 'mem/Buffered', 'Buffered', '.1.3.6.1.4.1.2021.4.14.0', undef, undef, '0000FF66', 'KBytes', undef ],
                [ 'mem/Cached', 'Cached', '.1.3.6.1.4.1.2021.4.15.0', undef, undef, 'FF000066', 'KBytes', undef ],
            ]
        },
        {
            set => {
                name      => 'cpu',
                provider  => 'SnmpProvider',
                type      => 'COUNTER',
                component => undef,
                max       => 'User+Idle+Wait+Nice+Syst+Kernel+Interrupt',
                tableoid  => undef,
                indexoid  => undef
            },
            indicators => [
                [ 'cpu/User', 'User', '.1.3.6.1.4.1.2021.11.50.0', undef, undef, '0000FF66', '%', undef ],
                [ 'cpu/Wait', 'Wait', '.1.3.6.1.4.1.2021.11.54.0', undef, undef, 'FF000066', '%', undef ],
                [ 'cpu/Nice', 'Nice', '.1.3.6.1.4.1.2021.11.51.0', undef, undef, 'FFFF0066', '%', undef ],
                [ 'cpu/System', 'Syst', '.1.3.6.1.4.1.2021.11.52.0', undef, undef, '00FFFF66', '%', undef ],
                [ 'cpu/Kernel', 'Kernel', '.1.3.6.1.4.1.2021.11.55.0', undef, undef, 'FF00FF66', '%', undef ],
                [ 'cpu/Interrupt', 'Interrupt', '.1.3.6.1.4.1.2021.11.56.0', undef, undef, '66666666', '%', undef ],
                [ 'cpu/Idle', 'Idle', '.1.3.6.1.4.1.2021.11.53.0', undef, undef, '00FF0066', '%', undef ],
            ]
        },
        {
            set => {
                name      => 'apache_stats',
                provider  => 'ApacheProvider',
                type      => 'DERIVE',
                component => 'Apache',
            },
            indicators => [
                [ 'apache/Req/Sec', 'ReqPerSec','Total Accesses', 0, undef, '0000FF99', undef, undef ],
            ]
        },
        {
            set => {
                name      => 'apache_workers',
                provider  => 'ApacheProvider',
                type      => 'GAUGE',
                component => 'Apache',
            },
            indicators => [
                [ 'apache/Idle Workers', 'IdleWorkers','IdleWorkers', undef, undef, '00FF0099', undef, undef ],
                [ 'apache/Busy Workers', 'BusyWorkers','BusyWorkers', undef, undef, 'FF000099', undef, undef ],
            ]
        },
        {
            set => {
                name      => 'scom',
                provider  => 'External',
                type      => 'GAUGE',
            },
            indicators => [
                [ 'RAM free', 'RAM free', 'Memory/Available MBytes', undef, undef, 'FF000099', 'MBytes', undef ],
                [ 'RAM pool paged', 'RAM pool paged', 'Memory/Pool Paged Bytes', undef, undef, 'FF000099', 'Bytes', undef ],
                [ 'RAM used', 'RAM used', 'Memory/PercentMemoryUsed', undef, undef, 'FF000099', '%', undef ],
                [ 'CPU used', 'CPU used', 'Processor/% Processor Time', undef, undef, 'FF000099', '%', undef ],
                [ 'CPU Queue Length', 'CPU Queue Length', 'System/Processor Queue Length', undef, undef, 'FF000099', 'process', undef ],
                [ 'Disk idle time', 'Disk idle time', 'LogicalDisk/% Idle Time', undef, undef, 'FF000099', '%', undef ],
                [ 'Disk free space', 'Disk free space', 'LogicalDisk/% Free Space', undef, undef, 'FF000099', '%', undef ],
                [ 'Network used', 'Network used', 'Network Adapter/PercentBandwidthUsedTotal', undef, undef, 'FF000099', '%', undef ],
                [ 'Active Sessions', 'Active Sessions', 'Terminal Services/Active Sessions', undef, undef, 'FF000099', 'sessions', undef ],
                [ 'RAM I/O', 'RAM I/O', 'Memory/Pages/sec', undef, undef, 'FF000099', 'pages/sec', undef ],
            ]
        },
        {
            set => {
                name      => 'billing',
                provider  => 'KanopyaDatabaseProvider',
                type      => 'GAUGE',
            },
            indicators => [
                [ 'billing/Cores', 'Cores', 'Number of charged cores', undef, undef, 'FF000099', 'Cores', undef ],
                [ 'billing/Memory', 'Memory', 'Charged memory', undef, undef, 'FF000099', 'Bytes', undef ],
            ]
        },
        {
            set => {
                name      => 'state',
                provider  => 'KanopyaDatabaseProvider',
                type      => 'GAUGE',
            },
            indicators => [
                [ 'state/Up', 'Up', 'Host is up', undef, undef, 'FF000099', '', undef ],
                [ 'state/Starting', 'Starting', 'Host is starting', undef, undef, 'FF000099', '', undef ],
                [ 'state/Stopping', 'Stopping', 'Host is stopping', undef, undef, 'FF000099', '', undef ],
                [ 'state/Broken', 'Broken', 'Host is broken', undef, undef, 'FF000099', '', undef ],
            ]
        },
        {
            set => {
                name      => 'virtualization',
                provider  => 'KanopyaDatabaseProvider',
                type      => 'GAUGE',
            },
            indicators => [
                [ 'VMs count', 'VMs', 'Number of VMs', undef, undef, 'FF000099', 'VMs', undef ],
            ]
        },
        {
            set => {
                name      => 'diskIOTable',
                provider  => 'SnmpProvider',
                type      => 'COUNTER',
                tableoid  =>  '1.3.6.1.4.1.2021.13.15.1',
                indexoid  => 2
            },
            indicators => [
                [ 'disk/bytes read', 'bytesRead', 3, undef, undef, 'FF000099', undef, undef ],
                [ 'disk/bytes written ', 'bytesWritten', 4, undef, undef, 'FF000099', undef, undef ],
            ]
        },
        {
            set => {
                name      => 'interfaces',
                provider  => 'SnmpProvider',
                type      => 'COUNTER',
                tableoid  =>  '1.3.6.1.2.1.2.2',
                indexoid  => 2
            },
            indicators => [
                [ 'network interface/In Octets', 'ifInOctets', 10, undef, undef, 'FF000099', 'Octets/sec', undef ],
                [ 'network interface/Out Octets', 'ifOutOctets', 16, undef, undef, 'FF000099', 'Octets/sec', undef ],
                [ 'network interface/Out Errors', 'ifOutErrors', 20, undef, undef, 'FF000099', 'Packets|TU/sec', undef ],
                [ 'network interface/In Errors', 'ifInErrors', 14, undef, undef, 'FF000099', 'Packets|TU/sec', undef ]
            ]
        },
        {
            set => {
                name     => 'vsphere_vm',
                provider => 'VsphereProvider',
                type     => 'GAUGE',
             },
            indicators => [
                [ 'vsphere vm/total cpu', 'vm_cpu_total', 'summary.config.numCpu', undef, undef, 'FF000099', 'Cores', undef ],
                [ 'vsphere vm/cpu usage', 'vm_cpu_usage', 'summary.quickStats.overallCpuUsage', undef, undef, 'FF000099', 'MHz', undef ],
                [ 'vsphere vm/total mem', 'vm_mem_total', 'summary.config.memorySizeMB', undef, undef, 'FF000099', 'MBytes', undef ],
                [ 'vsphere vm/mem usage', 'vm_mem_usage', 'summary.quickStats.hostMemoryUsage', undef, undef, 'FF000099', 'MBytes', undef ],
            ]
        },
        {
            set => {
                name     => 'vsphere_host',
                provider => 'VsphereProvider',
                type     => 'GAUGE',
             },
            indicators => [
                [ 'vsphere hv/total cpu', 'hv_cpu_total', 'summary.hardware.numCpuCores', undef, undef, 'FF000099', 'Cores', undef ],
                [ 'vsphere hv/cpu usage', 'hv_cpu_usage', 'summary.quickStats.overallCpuUsage', undef, undef, 'FF000099', 'MHz', undef ],
                [ 'vsphere hv/total mem', 'hv_mem_total', 'summary.hardware.memorySize', undef, undef, 'FF000099', 'Bytes', undef ],
                [ 'vsphere hv/mem usage', 'hv_mem_usage', 'summary.quickStats.overallMemoryUsage', undef, undef, 'FF000099', 'MBytes', undef ],
            ]
        }
    ];

    for my $set (@{$indicators}) {
        my %values = %{$set->{set}};
        my $indicatorset = Indicatorset->new(
            indicatorset_name      => $values{name},
            indicatorset_provider  => $values{provider},
            indicatorset_type      => $values{type},
            indicatorset_component => $values{component},
            indicatorset_max       => $values{max},
            indicatorset_tableoid  => $values{tableoid},
            indicatorset_indexoid  => $values{indexoid}
        );

        for my $indicator (@{$set->{indicators}}) {
            Entity::Indicator->new(
                indicator_label => $indicator->[0],
                indicator_name  => $indicator->[1],
                indicator_oid   => $indicator->[2],
                indicator_min   => $indicator->[3],
                indicator_max   => $indicator->[4],
                indicator_color => $indicator->[5],
                indicator_unit  => $indicator->[6],
                indicatorset_id => $indicatorset->id
            );
        }
    }
}

sub registerKanopyaMaster {
    my %args = @_;

    my $admin_network = Entity::Network->new(
                            network_name    => "admin",
                            network_addr    => $args{ipv4_internal_network_ip},
                            network_netmask => $args{poolip_netmask},
                            network_gateway => $args{poolip_gateway}
                        );

    my $admin = Entity::User->find(hash => { user_login => "admin" });

    my $admin_cluster = Entity::ServiceProvider::Cluster->new(
                            cluster_name          => 'Kanopya',
                            cluster_desc          => 'Main Cluster hosting Administrator, Executor, Boot server and NAS',
                            cluster_type          => 0,
                            cluster_min_node      => 1,
                            cluster_max_node      => 10,
                            cluster_priority      => 500,
                            cluster_si_persistent => 0,
                            cluster_domainname    => $args{admin_domainname},
                            cluster_nameserver1   => defined $args{kanopya_nameserver1} ? $args{kanopya_nameserver1} : '8.8.8.8',
                            cluster_nameserver2   => defined $args{kanopya_nameserver2} ? $args{kanopya_nameserver2} : '8.8.4.4',
                            cluster_state         => 'up:' . time(),
                            cluster_basehostname  => 'kanopyamaster',
                            default_gateway_id    => $admin_network->id,
                            active                => 1,
                            owner_id              => $admin->id,
                            service_provider_type_id => ClassType::ServiceProviderType->find(hash => { service_provider_name => "Kanopya" })->id
                        );


    my $hostname = `hostname`;
    chomp($hostname);

    my $distro;
    if (-e "/etc/debian_version") {
        $distro = "Debian";
    }
    elsif (-e "/etc/redhat-release") {
        $distro = "Redhat";
    } else {
        die "Unknown distribution";
    }

    my $components = {
        'KanopyaFront' => {},
        'KanopyaExecutor' => {
            conf    => {
                masterimages_directory => $args{masterimages_directory} || "/var/lib/kanopya/masterimages/",
                clusters_directory     => $args{clusters_directory} || "/var/lib/kanopya/clusters/",
                private_directory      => $args{private_directory} || "/var/lib/kanopya/private/"
            },
            require => {
                notifier_component => 'KanopyaMailNotifier',
            }
        },
        'KanopyaDeploymentManager' => {
            manager => 'DeploymentManager',
            require => {
                executor_component => 'KanopyaExecutor',
                dhcp_component   => 'Dhcpd',
                tftp_component   => 'Tftpd',
                system_component => $distro,
            }
        },
        'HCMStorageManager' => {
            manager => 'StorageManager',
            require => {
                executor_component => 'KanopyaExecutor',
            }
        },
        'HCMNetworkManager' => {
            manager => 'NetworkManager',
            require => {
                executor_component => 'KanopyaExecutor',
            }
        },
        'KanopyaAnomalyDetector' => {},
        'KanopyaRulesEngine' => {},
        'KanopyaServiceManager' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'KanopyaOpenstackSync' => {},
        'KanopyaStackBuilder' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'KanopyaAggregator' => {},
        'KanopyaRulesEngine' => {},
        'Lvm' => {
            require => { executor_component => 'KanopyaExecutor' },
            manager => 'DiskManager'
        },
        'Storage' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'Iscsitarget' =>  {
            require => { executor_component => 'KanopyaExecutor' },
            manager => 'ExportManager'
        },
        'Iscsi' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'Fileimagemanager' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'Dhcpd' => {
            conf => {
                dhcpd3_domain_name =>  "hedera-technology.com",
                dhcpd3_servername  => "node001"
            },
        },
        'Tftpd' => {
            conf => {
                tftpd_repository => defined $args{tftp_directory} ? $args{tftp_directory} : "/var/lib/kanopya/tftp/"
            }
        },
        'Snmpd' => {},
        'Nfsd' => {
            require => { executor_component => 'KanopyaExecutor' },
            conf => {
                nfsd3_need_gssd => 'no',
                nfsd3_rpcnfsdcount => 8,
                nfsd3_rpcnfsdpriority => 0,
                nfsd3_need_svcgssd => 'no'
            }
        },
        'Syslogng' => {},
        'Puppetmaster' => {
            conf => {
                puppetmaster2_options => ""
            }
        },
        'Puppetagent' => {
            conf => {
                puppetagent2_options    => '--no-client',
                puppetagent2_mode       => "kanopya",
                puppetagent2_masterfqdn => $hostname . '.' . $args{admin_domainname},
                puppetagent2_masterip   => $args{poolip_addr}
            },
            require => { puppet_master => 'Puppetmaster' }
        },
        'Mysql' => {},
        'Kanopyacollector' => {
            manager => 'CollectorManager'
        },
        'Kanopyaworkflow' => {
            require => { executor_component => 'KanopyaExecutor' },
        },
        'KanopyaMailNotifier' => {
            manager => "NotificationManager",
            conf => {
                smtp_server => "localhost"
            }
        },
        'Amqp' => {},
        'Physicalhoster' => {
            require => { executor_component => 'KanopyaExecutor' },
            manager => 'HostManager'
        },
        'Openssh' => {},
        $distro => {
            conf => {
                owner_id           => $admin->id,
                domainname         => $args{admin_domainname},
                nameserver1        => defined $args{kanopya_nameserver1} ? $args{kanopya_nameserver1} : '8.8.8.8',
                nameserver2        => defined $args{kanopya_nameserver2} ? $args{kanopya_nameserver2} : '8.8.4.4',
                default_gateway_id => $admin_network->id,
            }
        },
    };

    # include the mocks
    if ($args{include_mocks}) {
        $components->{DummyHostManager} = {}
    }

    # Create the host for the Kanopya master
    my ( $sysname, $nodename, $release, $version, $machine ) = POSIX::uname();
    my $domain = $args{admin_domainname};

    my $date = today();
    my $year = $date->year;
    my $month = $date->month;

    if (length ($month) == 1) {
        $month = '0' . $month;
    }

    my $kanopya_initiator = "iqn.$year-$month."
        . join('.', reverse split(/\./, $domain)) . ':' . time();

    my $poolip = Entity::Poolip->new(
                     poolip_name       => "kanopya_admin",
                     poolip_first_addr => $args{poolip_addr},
                     poolip_size       => $args{poolip_mask},
                     network_id        => $admin_network->id,
                 );

    my $admin_interface = Entity::Interface->new(
                              service_provider_id => $admin_cluster->id,
                              interface_name      => $args{admin_interface}
                          );

    my $admin_host = Entity::Host->new(
                         host_serial_number => "1",
                         host_desc          => "Admin host",
                         active             => 1,
                         host_initiatorname => $kanopya_initiator,
                         host_ram           => 0,
                         host_core          => 1,
                         host_state         => "up:" . time(),
                         host_prev_state    => ""
                     );

    my $admin_iface = Entity::Iface->new(
                          iface_name     => $args{admin_interface},
                          iface_mac_addr => $args{mb_hw_address},
                          iface_pxe      => 0,
                          host_id        => $admin_host->id,
                      );

    Ip->new(
        ip_addr   => $args{poolip_addr},
        poolip_id => $poolip->id,
        iface_id  => $admin_iface->id
    );

    my $admin_role = Entity::NetconfRole->find(hash => { netconf_role_name => "admin" });
    my $vmsrole = Entity::NetconfRole->find(hash => { netconf_role_name => "vms" });

    my $netconf = Entity::Netconf->create(netconf_name    => "Kanopya admin",
                                          netconf_role_id => $admin_role->id);

    my $vmsnetconf = Entity::Netconf->create(netconf_name    => "Virtual machines bridge",
                                             netconf_role_id => $vmsrole->id);

    NetconfInterface->new(netconf_id => $netconf->id, interface_id => $admin_interface->id);
    NetconfPoolip->new(netconf_id => $netconf->id, poolip_id => $poolip->id);
    NetconfIface->new(netconf_id => $netconf->id, iface_id => $admin_iface->id);

    # Finally register the new node in the admin cluster
    my $admin_node = $admin_cluster->registerNode(
                         hostname         => $hostname,
                         host             => $admin_host,
                         state            => "in",
                         number           => 1,
                         monitoring_state => 'disabled'
                     );

    # Install components
    # TODO: use recursivity to handle requirements, force priority for now
    for my $name ('KanopyaExecutor', (keys %{ $components })) {
        my $component = $components->{$name};
        if (exists $component->{instance}) {
            next;
        }

        my $conf = $component->{conf};
        if (defined $component->{require}) {
            for my $relation (keys $component->{require}) {
                my $required = $components->{$component->{require}->{$relation}};
                if (defined $required->{instance}) {
                    $conf->{$relation} = $required->{instance};
                }
                else  {
                    $conf->{$relation} = installComponent(cluster => $admin_cluster,
                                                          name    => $component->{require}->{$relation},
                                                          manager => $required->{manager},
                                                          conf    => $required->{conf},
                                                          extra   => $required->{extra});
                    $components->{$component->{require}->{$relation}}->{instance} = $conf->{$relation};
                }
                # WORKAROUND: PuppetAgent require PuppetMaster but do not take it in parameter
                # TODO: Link PuppetAgent with PuppetMaster in database.
                if ($name eq 'Puppetagent' && $relation eq 'puppet_master') {
                    delete $conf->{$relation};
                }
            }
        }
        $component->{instance} = installComponent(cluster => $admin_cluster,
                                                  name    => $name,
                                                  manager => $component->{manager},
                                                  conf    => $conf,
                                                  extra   => $component->{extra});
    }

    # Set the host manager for the admin host
    $admin_host->host_manager($admin_cluster->getComponent(name => 'Physicalhoster'));

    # Configure components on kanopya master
    my $kanopyacollector = $admin_cluster->getComponent(name => 'Kanopyacollector');
    my $dhcp = $admin_cluster->getComponent(name => 'Dhcpd');

    # Collect some indicators for admin cluster
    $kanopyacollector->collectSets(
        sets_name           => ['mem', 'cpu'],
        service_provider_id => $admin_cluster->id
    );

    Dhcpd3Subnet->new(
        dhcpd3_id  => $dhcp->id,
        network_id => $admin_network->id
    );

    my $lvm = $admin_cluster->getComponent(name => 'Lvm');
    my $vg = Lvm2Vg->new(
        lvm2_id           => $lvm->id,
        lvm2_vg_name      => $args{kanopya_vg_name},
        lvm2_vg_freespace => $args{kanopya_vg_free_space},
        lvm2_vg_size      => $args{kanopya_vg_size}
    );

    for my $pv (@{$args{kanopya_pvs}}) {
        Lvm2Pv->new(
            lvm2_vg_id   => $vg->id,
            lvm2_pv_name => $pv
        );
    }

    $admin_cluster->addManagerParameter(
        manager_type => "DiskManager",
        name => "vg_id",
        value => $vg->id
    );

    $admin_cluster->addManagerParameter(
        manager_type => "DiskManager",
        name => "systemimage_size",
        value => 8 * 1024 * 1024 * 1024
    );

    my $iscsitarget = $admin_cluster->getComponent(name => 'Iscsitarget');
    $iscsitarget->insertDefaultExtendedConfiguration();

    $admin_cluster->addManagerParameter(
        manager_type => "ExportManager",
        name => "iscsi_portals",
        value => [ ($iscsitarget->iscsi_portals)[0]->id ]
    );

    $admin_cluster->addManagerParameter(
        manager_type => "ExportManager",
        name => "iomode",
        value => "wb"
    );

    my $ehost = EEntity->new(entity => $admin_host);

    $admin_host->host_core($ehost->getTotalCpu);
    $admin_host->host_ram($ehost->getTotalMemory);

    # Set service manager to the kanopya service
    $admin_cluster->service_manager($components->{'KanopyaServiceManager'}->{instance});

    # Check component availability
    print "\t- Check availability of the registred components\n";
    my @components = sort { $a->priority <=> $b->priority } $admin_node->components;
    foreach my $component (map { EEntity->new(entity => $_) } @components) {
        print "\t\t- Checking component " . $component->label . "...\n";
        try {
            if ($component->isUp(node => EEntity->new(entity => $admin_node))) {
                print "\t\t\t=> up\n";
            }
            else {
                print "\t\t\t=> down\n";
            }
        }
        catch ($err) {
            print "\t\t\t=> down, $err\n";
        }
    }
    return $admin_cluster;
}

sub installComponent {
    my %args = @_;

    print "\t\t- Installing component $args{name}...\n";

    # Get the template if exists
    my $component_template;
    eval {
        $component_template = ComponentTemplate->find(hash => { component_template_name => lc $args{name} })->id;
    };

    # Get the component type
    my $component_type = ClassType::ComponentType->find(hash => {
                             component_name => $args{name}
                         });

    # Add the component
    my $comp = $args{cluster}->addComponent(component_type_id             => $component_type->id,
                                            component_template_id         => $component_template,
                                            component_configuration       => $args{conf},
                                            component_extra_configuration => $args{extra});

    if (defined $args{manager}) {
        # Add the manager
        $args{cluster}->addManager(manager_id => $comp->id,
                                   manager_type => $args{manager},
                                   manager_params => $args{params});
    }
    return $comp;
}

sub registerScopes {
    my %args = @_;

    my $scopes = [
        {
            name => "node",
            parameters => [
                ('ou_from', 'node_hostname')
            ]
        },
        {
            name => "service_provider",
            parameters => [
                ("service_provider_name", )
            ]
        },
    ];
    for my $scope (@{$scopes}) {
        my $sc = Scope->new(
            scope_name => $scope->{name}
        );
        for my $parameter (@{$scope->{parameters}}) {
            ScopeParameter->new(
                scope_parameter_name => $parameter,
                scope_id             => $sc->id
            );
        }
    }
}

sub populate_workflow_def {
    my %args = @_;

    my $wf_manager_component_type_id = ClassType::ComponentType->find(hash => { component_name => 'Kanopyaworkflow' })->id;

    my $kanopya_wf_manager = Entity::Component->find(hash => {
                                 component_type_id   => $wf_manager_component_type_id,
                                 service_provider_id => $args{kanopya_master}->id
                             });

    my $scale_op_id       = Entity::Operationtype->find( hash => { operationtype_name => 'LaunchScaleInWorkflow' })->id;
    my $scale_amount_desc = "Format:\n - '+value' to increase\n - '-value' to decrease\n - 'value' to set";

    my $delay_desc = 'Delay minimum between two workflow triggers';
    # ScaleIn cpu workflow def
    my $scale_cpu_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'ScaleInCPU',
        params => {
            specific => {
                scalein_value => { label => 'Nb core', description => $scale_amount_desc},
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            },
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { cloudmanager_comp => undef, host => undef },
                scalein_type => 'cpu',
            },
        },
        steps => [ $scale_op_id ],
        description => "Scale in [% scalein_type %] on node [% host %]"
    );

    # ScaleIn memory workflow def
    my $scale_mem_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'ScaleInMemory',
        params => {
            specific => {
                scalein_value => { label => 'Amount', unit => 'byte', description => $scale_amount_desc},
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            },
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { cloudmanager_comp => undef, host => undef },
                scalein_type => 'memory',
            },
        },
        steps => [ $scale_op_id ],
        description => "Scale in [% scalein_type %] on node \"[% host %]\""
    );

    # AddNode workflow def
    my $addnode_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'AddNode' })->id;
    my $prestart_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'PreStartNode' })->id;
    my $poststart_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'PostStartNode' })->id;
    my $addnode_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'AddNode',
        params => {
            automatic => {
                context => {
                    cluster => undef
                }
            },
            internal => { scope_id => 2 },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $addnode_op_id, $prestart_op_id, $poststart_op_id ],
        description => "Adding node to instance \"[% cluster %]\""
    );

    # StopNode workflow def
    my $prestop_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'PreStopNode' })->id;
    my $poststop_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'PostStopNode' })->id;
    my $stopnode_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'StopNode',
        params => {
            automatic => {
                context => {
                    cluster => undef
                }
            },
            internal => { scope_id => 2 },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $prestop_op_id, $poststop_op_id ],
        description => "Removing node \"[% host %]\" from service \"[% cluster %]\""
    );

    # DeployNode workflow def
    my $confnode_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'PrepareNode' })->id;
    my $deploynode_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'DeployNode' })->id;
    my $deploynode_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'DeployNode',
        steps => [ $confnode_op_id, $deploynode_op_id, ],
        description => "Deploying node \"[% node ? node : \"n/a\" %]\""
    );

    # ReleaseNode workflow def
    my $unconfnode_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'UnconfigureNode' })->id;
    my $releasenode_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'ReleaseNode' })->id;
    my $releasenode_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'ReleaseNode',
        steps => [ $unconfnode_op_id, $releasenode_op_id ],
        description => "Releasing node \"[% node ? node : \"n/a\" %]\""
    );

    # Optimiaas Workflow def
    my $optimiaas_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'LaunchOptimiaasWorkflow' })->id;
    my $optimiaas_wf = $kanopya_wf_manager->createWorkflowDef(
                           workflow_name => 'OptimiaasWorkflow',
                           step          => [ $optimiaas_op_id ],
                           description   => "Optimizing virtual machines placement for IAAS \"[% cloudmanager_comp %]\""
                       );

    # Migrate Workflow def
    my $migrate_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'MigrateHost' })->id;
    my $migrate_wf = $kanopya_wf_manager->createWorkflowDef(
                         workflow_name => 'MigrateWorkflow',
                         steps         => [ $migrate_op_id ],
                         description   => "Migrating virtual machine \"[% vm %]\" to hypervisor \"[% host %]\""
                     );

    # ResubmitNode  workflow def
    my $resubmit_node_op_id  = Entity::Operationtype->find( hash => { operationtype_name => 'ResubmitNode' })->id;
    my $scale_cpu_op_id  = Entity::Operationtype->find( hash => { operationtype_name => 'ScaleCpuHost' })->id;
    my $scale_mem_op_id  = Entity::Operationtype->find( hash => { operationtype_name => 'ScaleMemoryHost' })->id;
    my $resubmit_node_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'ResubmitNode',
        params => {
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { host => undef },
            },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $resubmit_node_op_id, $scale_cpu_op_id, $scale_mem_op_id ],
        description => "Resubmitting node \"[% host %]\""
    );

    # RelieveHypervisor workflow def
    my $relieve_hypervisor_op_id  = Entity::Operationtype->find( hash => { operationtype_name => 'RelieveHypervisor' })->id;
    my $relieve_hypervisor_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'RelieveHypervisor',
        params => {
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { host => undef },
            },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $relieve_hypervisor_op_id, $resubmit_node_op_id, $migrate_op_id ],
        description => "Relieving hypervisor \"[% host %]\""
    );

    # MaintenanceHypervisor workflow def
    my $flush_hypervisor_op_id = Entity::Operationtype->find( hash => { operationtype_name => 'FlushHypervisor' })->id;
    my $hypervisor_maintenance_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'HypervisorMaintenance',
        params => {
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { host => undef },
            },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $flush_hypervisor_op_id ],
        description => "Putting hypervisor \"[% flushed_hypervisor %]\" in maintenance."
    );

    # Hypervisor resubmit workflow def
    my $resubmit_hypervisor_op_id  = Entity::Operationtype->find( hash => { operationtype_name => 'ResubmitHypervisor' })->id;
    my $hypervisor_resubmit_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'ResubmitHypervisor',
        params => {
            internal => {
                scope_id => 1,
            },
            automatic => {
                context => { host => undef },
            },
            specific => {
                delay => { label => 'Delay', unit => 'seconds', description => $delay_desc},
            }
        },
        steps => [ $resubmit_hypervisor_op_id ],
        description => "Resubmitting hypervisor \"[% host %]\""
    );

    my $notify_wf_node = $kanopya_wf_manager->createWorkflowDef(
        workflow_name   => 'NotifyWorkflow node',
        params          => {
            internal   => {
                scope_id    => 1
            },
            automatic  => { },
            specific   => { }
        },
    );

    my $notify_wf_service   = $kanopya_wf_manager->createWorkflowDef(
        workflow_name   => 'NotifyWorkflow service_provider',
        params          => {
            internal   => {
                scope_id    => 2
            },
            automatic  => { },
            specific   => { }
        }
    );

    # Synchronize workflow def
    my $synchronize_wf = $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'Synchronize',
        params        => {
            internal  => { },
            automatic => { },
            specific  => {
                entity => { label => 'Entity' }
            }
        },
        steps => [ Entity::Operationtype->find(hash => { operationtype_name => 'Synchronize' })->id ],
        description => "Synchronizing component \"[% entity %]\""
    );

    # BuildStack workflow def
    $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'BuildStack',
        params => {},
        steps => [
            Entity::Operationtype->find( hash => { operationtype_name => 'BuildStack' })->id,
            Entity::Operationtype->find( hash => { operationtype_name => 'StartStack' })->id,
            Entity::Operationtype->find( hash => { operationtype_name => 'ConfigureStack' })->id,
        ],
        description => "Build stack"
    );

    $kanopya_wf_manager->createWorkflowDef(
        workflow_name => 'EndStack',
        params => {},
        steps => [
            Entity::Operationtype->find( hash => { operationtype_name => 'UnconfigureStack' })->id,
            Entity::Operationtype->find( hash => { operationtype_name => 'StopStack' })->id,
            Entity::Operationtype->find( hash => { operationtype_name => 'EndStack' })->id,
        ],
        description => "End stack"
    );
}

sub populate_policies {
    my %args = @_;

    # orchestration
    my $orch_policy_sp = configureDefaultOrchestrationPolicyService( admin_cluster => $args{kanopya_master} );
}


# Link to kanopya workflow and collector manager
# Add cpu and mem metrics and rules
sub configureDefaultOrchestrationPolicyService {
    my %args = @_;

    my $sp = Entity::ServiceProvider->new();

     # Add default workflow manager
    my $workflow_manager = $args{admin_cluster}->getComponent(name => "Kanopyaworkflow", version => "0");
    $sp->addManager(manager_id   => $workflow_manager->id,
                    manager_type =>"WorkflowManager");

    # Add default collector manager
    my $collector_manager = $args{admin_cluster}->getComponent(name => "Kanopyacollector", version => "1");
    $sp->addManager(manager_id   => $collector_manager->id,
                    manager_type =>"CollectorManager");

    my $noderule_conf = {
        'mem/Available' => {
             comparator       => '<',
             threshold        => 256*1024,
             cond_label       => 'Available memory < 256M',
             rule_label       => 'Available memory too low',
             rule_description => 'Available memory is too low for this node',
        },
    };

    my $clusterrule_conf = {
        'mem/Available' => {
             'mean' => {
                 comparator       => '<',
                 threshold        => 256*1024,
                 cond_label       => 'Mean available memory < 256M',
                 rule_label       => 'Mean available memory too low',
                 rule_description => 'Available memory is too low for this service',
             }
        },
    };

    # Get indicators
    my @indics = Entity::CollectorIndicator->search (
        hash => {
            collector_manager_id                        => $collector_manager->id,
            'indicator.indicatorset.indicatorset_name'  => ['cpu', 'mem']
        }
    );

    # Generic creation of node and service combinations and rules
    for my $indic (@indics) {
        my $indic_label = $indic->indicator->indicator_label;

        # Node level
        # Node metric combinations
        my $nmcomb = Entity::Metric::Combination::NodemetricCombination->new(
                         service_provider_id             => $sp->id,
                         nodemetric_combination_formula  => 'id' . $indic->id
                     );

        if (exists $noderule_conf->{$indic_label}) {
            # Node condition
            my $nmcond = Entity::NodemetricCondition->new(
                left_combination_id                 => $nmcomb->id,
                nodemetric_condition_label          => $noderule_conf->{$indic_label}->{cond_label},
                nodemetric_condition_comparator     => $noderule_conf->{$indic_label}->{comparator},
                nodemetric_condition_threshold      => $noderule_conf->{$indic_label}->{threshold},
                nodemetric_condition_service_provider_id => $sp->id,
            );
            # Node rule
            Entity::Rule::NodemetricRule->new(
                formula             => 'id'.$nmcond->id,
                rule_name           => $noderule_conf->{$indic_label}->{rule_label},
                description         => $noderule_conf->{$indic_label}->{rule_description},
                state               => 'enabled',
                service_provider_id => $sp->id,
            );
        }

        # Service level
        for my $func ('sum', 'mean') {
             # Cluster metrics and combinations
            my $cm = Entity::Metric::Clustermetric->new(
                         clustermetric_service_provider_id       => $sp->id,
                         clustermetric_indicator_id              => $indic->id,
                         clustermetric_statistics_function_name  => $func,
                         clustermetric_window_time               => '600',
                     );

            my $acomb = Entity::Metric::Combination::AggregateCombination->new(
                service_provider_id             => $sp->id,
                aggregate_combination_formula   => 'id'.$cm->id
            );

            if (exists $clusterrule_conf->{$indic_label}{$func}) {
                # Service condition
                my $acond = Entity::AggregateCondition->new(
                    left_combination_id                 => $acomb->id,
                    aggregate_condition_label           => $clusterrule_conf->{$indic_label}{$func}->{cond_label},
                    comparator                          => $clusterrule_conf->{$indic_label}{$func}->{comparator},
                    threshold                           => $clusterrule_conf->{$indic_label}{$func}->{threshold},
                    aggregate_condition_service_provider_id => $sp->id,
                );
                # Service rule
                Entity::Rule::AggregateRule->new(
                    formula             => 'id'.$acond->id,
                    rule_name           => $clusterrule_conf->{$indic_label}{$func}->{rule_label},
                    description         => $clusterrule_conf->{$indic_label}{$func}->{rule_description},
                    state               => 'enabled',
                    service_provider_id => $sp->id,
                );
            }
        }
    }

    # Nodes state monitoring (node level and count at service level)
    my @state_indics = Entity::CollectorIndicator->search (
        hash => {
            collector_manager_id                        => $collector_manager->id,
            'indicator.indicatorset.indicatorset_name'  => 'state',
        }
    );
    my @total_ids;
    for my $indic (@state_indics) {
        Entity::Metric::Combination::NodemetricCombination->new(
            service_provider_id             => $sp->id,
            nodemetric_combination_formula  => 'id'.$indic->id,
            nodemetric_combination_label    => 'is'.$indic->indicator->indicator_name,
        );
        my $cm = Entity::Metric::Clustermetric->new(
                     clustermetric_service_provider_id      => $sp->id,
                     clustermetric_indicator_id             => $indic->id,
                     clustermetric_statistics_function_name => 'sum',
                     clustermetric_window_time              => '600',
                 );
        Entity::Metric::Combination::AggregateCombination->new(
            service_provider_id             => $sp->id,
            aggregate_combination_formula   => 'id'.$cm->id,
            aggregate_combination_label     => $indic->indicator->indicator_name . ' nodes',
        );
        push @total_ids, $cm->id;
    }
    my @total_formula = join ' + ', map { 'id'.$_} @total_ids;

    Entity::Metric::Combination::AggregateCombination->new(
        service_provider_id             => $sp->id,
        aggregate_combination_formula   => @total_formula,
        aggregate_combination_label     => 'All nodes',
    );

    return $sp;
}


sub login {
    my $config = Kanopya::Database::_loadconfig;
    my $god_mode = $config->{dbconf}->{god_mode};

    # Activate god mode before the administrator loads it config
    $config->{dbconf}->{god_mode} = "1";
    Kanopya::Config::set(subsystem => "libkanopya", config => $config);

    Kanopya::Database::_connectdb(config => $config);

    # Restore the config to its original state, the administrator keeps its old one
    if (defined $god_mode) {
        $config->{dbconf}->{god_mode} = $god_mode;
    } else {
        delete $config->{dbconf}->{god_mode};
    }
    Kanopya::Config::set(subsystem => "libkanopya", config => $config);

    $ENV{EID} = 0;
}

sub populateDB {
    my %args = @_;

    login();

    $args{db} = Kanopya::Database::_adm->{schema};

    print "\t- Registering class types...\n";
    registerClassTypes(%args);

    print "\t- Registering kernels...\n";
    registerKernels(%args);

    print "\t- Registering component/manager categories...\n";
    registerManagerCategories(%args);

    print "\t- Registering users and groups...\n";
    registerUsers(%args);

    print "\t- Registering tags...\n";
    registerTags(%args);

    print "\t- Registering processors models ;)\n";
    registerProcessorModels(%args);

    print "\t- Registering operation types...\n";
    registerOperations(%args);

    print "\t- Registering service provider types...\n";
    registerServiceProviders(%args);

    print "\t- Registering component types...\n";
    registerComponents(%args);

    print "\t- Registering network configuration roles...\n";
    registerNetconfRoles(%args);

    print "\t- Registering monitoring indicators...\n";
    registerIndicators(%args);

    print "\t- Registering Kanopya master...\n";
    my $kanopya_master = registerKanopyaMaster(%args);

    registerScopes(%args);

    print "\t- Registering workflow definitions...\n";
    populate_workflow_def(kanopya_master => $kanopya_master);

    print "\t- Create default orchestration policy...\n";
    populate_policies(kanopya_master => $kanopya_master);

    print "\t- Populating DB done.\n";
}

1;
