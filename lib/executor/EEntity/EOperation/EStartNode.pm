#    Copyright © 2009-2012 Hedera Technology SAS
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package EEntity::EOperation::EStartNode;
use base "EEntity::EOperation";

use strict;
use warnings;

use String::Random;
use Date::Simple (':all');

use Kanopya::Exceptions;
use EFactory;
use Entity::ServiceProvider;
use Entity::ServiceProvider::Inside::Cluster;
use Entity::Host;
use Entity::Kernel;
use Template;
use General;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");
my $errmsg;
our $VERSION = '1.00';

my $config = General::getTemplateConfiguration();


sub check {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => $self->{context}, required => [ "cluster", "host" ]);
}

sub prerequisites {
    my $self  = shift;
    my %args  = @_;
    my $delay = 10;

    my $cluster_id = $self->{context}->{cluster}->getAttr(name => 'entity_id');
    my $host_id    = $self->{context}->{host}->getAttr(name => 'entity_id');

    # Ask to all cluster component if they are ready for node addition.
    my $components = $self->{context}->{cluster}->getComponents(category => "all");
    foreach my $key (keys %$components) {
        my $ready = $components->{$key}->readyNodeAddition(host_id => $host_id);
        if (not $ready) {
            my $component_class = ref($components->{$key});
            $log->info("Component $component_class not ready for node addition");
            return $delay;
        }
    }

    $log->info("Cluster <$cluster_id> ready for node addition");
    return 0;
}

sub prepare {
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    # Instanciate the bootserver Cluster
    $self->{context}->{bootserver}
        = EFactory::newEEntity(
              data => Entity->get(id => $self->{config}->{cluster}->{bootserver})
          );

    # Instanciate dhcpd
    my $dhcpd = $self->{context}->{bootserver}->getComponent(name => "Dhcpd", version => 3);
    $self->{context}->{dhcpd_component} = EFactory::newEEntity(data => $dhcpd);

    # Instanciate puppetmaster
    my $puppetmaster = $self->{context}->{bootserver}->getComponent(name => 'Puppetmaster', version => 2);
    $self->{context}->{component_puppetmaster} = EFactory::newEEntity(data => $puppetmaster);

    # Get container of the system image, get the container access of the container
    my $container = $self->{context}->{host}->getNodeSystemimage->getDevice;
    $self->{context}->{container} = EFactory::newEEntity(data => $container);

    # Warning:
    # 1. Systeme image should be activated, so at least one container access exists
    # 2. As systemimages always dedicated for instance, a system image container has
    #    onlky one container access.
    my $container_access = pop @{ $self->{context}->{container}->getAccesses };
    $self->{context}->{container_access} = EFactory::newEEntity(data => $container_access);

    $self->{context}->{export_manager}
        = EFactory::newEEntity(data => $self->{context}->{container_access}->getExportManager);

    $self->{params}->{kanopya_domainname} = $self->{context}->{bootserver}->getAttr(name => 'cluster_domainname');

    $self->{cluster_components} = $self->{context}->{cluster}->getComponents(category => "all");

}

sub execute {
    my $self = shift;

    # Firstly compute the node configuration
    
    if ((exists $self->{context}->{powersupplycard} and defined $self->{context}->{powersupplycard}) and
        (exists $self->{params}->{powersupplyport_number} and defined $self->{params}->{powersupplyport_number})) {
        my $powersupply_id = $self->{context}->{powersupplycard}->addPowerSupplyPort(
                                 powersupplyport_number => $self->{params}->{powersupplyport_number}
                             );

        $self->{context}->{host}->setAttr(name  => 'host_powersupply_id',
                                          value => $powersupply_id);
    }

    my $mount_options = $self->{context}->{cluster}->getAttr(name => 'cluster_si_shared')
                      ? "ro,noatime,nodiratime" : "defaults";

    # Mount the containers on the executor.
    my $mountpoint = $self->{context}->{container}->getMountPoint;

    $log->debug('Mounting the container <' . $mountpoint . '>');
    $self->{context}->{container_access}->mount(mountpoint => $mountpoint,
                                                econtext   => $self->getEContext,
                                                erollback  => $self->{erollback});

    $log->info("Operate Network Configuration");
    $self->_generateNetConf(mount_point => $mountpoint);

    $log->debug("Generate ntpdate Conf");
    $self->_generateNtpdateConf(mount_point => $mountpoint);

    $log->info("Operate Boot Configuration");
    $self->_generateBootConf(mount_point => $mountpoint,
                             filesystem => $self->{context}->{container}->getAttr(
                                               name => 'container_filesystem'
                                           ),
                             options    => $mount_options);

    my $components = $self->{cluster_components};
    my $puppet_definitions = "";
    
    $log->info("Operate components configuration");
    foreach my $i (keys %$components) {
        my $ecomponent = EFactory::newEEntity(data => $components->{$i});
        $log->debug("component is " . ref($ecomponent));
        $ecomponent->addNode(host        => $self->{context}->{host},
                             mount_point => $mountpoint,
                             cluster     => $self->{context}->{cluster},
                             erollback   => $self->{erollback});

        # retrieve puppet definition to create manifest
        $puppet_definitions .= $ecomponent->getPuppetDefinition(
            host    => $self->{context}->{host},
            cluster => $self->{context}->{cluster},
        );
    }

    # check if this cluster must be managed by puppet and kanopya puppetmaster
    my $puppetagent = eval {
        $self->{context}->{cluster}->getComponent(name    => 'Puppetagent',
                                                  version => 2
        );
    };
    if($puppetagent) {
        my $conf = $puppetagent->getConf();
        if($conf->{puppetagent2_mode} eq 'kanopya') {

            # create, sign and push a puppet certificate on the image
            $log->info('Puppent agent component configured with kanopya puppet master');
            my $fqdn = $self->{context}->{host}->getAttr(name => 'host_hostname');
            $fqdn .= '.' . $self->{params}->{kanopya_domainname};
            $self->{context}->{component_puppetmaster}->createHostCertificate(
                mount_point => $mountpoint,
                host_fqdn   => $fqdn
            );

            $self->{context}->{component_puppetmaster}->createHostManifest(
                host_fqdn          => $fqdn,
                puppet_definitions => $puppet_definitions
            );

        }
    }

    # Umount system image container
    $self->{context}->{container_access}->umount(mountpoint => $mountpoint,
                                                 econtext   => $self->getEContext,
                                                 erollback  => $self->{erollback});

    # Create node instance
    $self->{context}->{host}->setNodeState(state => "goingin");
    $self->{context}->{host}->save();

    # Finally we start the node
    $self->{context}->{host} = $self->{context}->{host}->start(
        erollback  => $self->{erollback},
        hypervisor => $self->{context}->{hypervisor}, #only need for vm add
    );
}

sub _cancel {
    my $self = shift;

    $log->info("Cancel start node, we will try to remove node link for <" .
               $self->{context}->{host}->getAttr(name => "entity_id") . ">");

    $self->{context}->{host}->stopToBeNode();

    my $hosts = $self->{context}->{cluster}->getHosts();
    if (! scalar keys %$hosts) {
        $self->{context}->{cluster}->setState(state => "down");
    }

    # Try to umount the container.
    eval {
        my $mountpoint = $self->{context}->{container}->getMountPoint;
        $self->{context}->{container_access}->umount(mountpoint => $mountpoint,
                                                     econtext   => $self->getEContext);
    };
}

sub finish {
    my $self = shift;

    # No need to lock the bootserver
    delete $self->{context}->{bootserver};
    delete $self->{context}->{dhcpd_component};
    delete $self->{context}->{component_puppetmaster};
    delete $self->{context}->{container};
    delete $self->{context}->{container_access};
    delete $self->{context}->{export_manager};
    delete $self->{context}->{systemimage};
}

sub _generateNetConf {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'mount_point' ]);

    # search for an potential 'loadbalanced' component
    my $components = $self->{cluster_components};
    my $is_loadbalanced = 0;
    foreach my $component (values %$components) {
        my $clusterization_type = $component->getClusterizationType();
        if ($clusterization_type && ($clusterization_type eq 'loadbalanced')) {
            $is_loadbalanced = 1;
            last;
        }
    }

    my $is_masternode;
    if($self->{context}->{cluster}->getCurrentNodesCount > 1) { 
        $is_masternode = 0;
    } else {
        $is_masternode = 1;
    }

    # Pop an IP adress for all host iface,
    my @net_ifaces;
    INTERFACES:
    foreach my $interface (@{$self->{context}->{cluster}->getNetworkInterfaces}) {
        
        # public network on loadbalanced cluster must be configured only
        # on the master node
        my $interface_role_name = $interface->getRole->getAttr(name => 'interface_role_name');
        if(( $interface_role_name eq 'public') and $is_loadbalanced
            and not $is_masternode) {
            next INTERFACES;
        }
        
        my $iface = $interface->getAssociatedIface(host => $self->{context}->{host});

        # Assign ip from the associated interface poolip
        $iface->assignIp();

        # Only add non pxe iface to /etc/network/interfaces
        if (not $iface->getAttr(name => 'iface_pxe')) {
            my ($gateway, $netmask, $ip, $method);

            if ($iface->hasIp) {
                my $pool = $iface->getPoolip;
                $netmask = $pool->poolip_netmask;
                $ip = $iface->getIPAddr;
                $gateway = $interface->hasDefaultGateway() ? $pool->poolip_gateway : undef;
                $method = "static";
                if ($is_loadbalanced and not $is_masternode) {
                    $gateway = $self->{context}->{cluster}->getMasterNodeIp
                }
            }
            else {
                $method = "manual";
            }

            push @net_ifaces, { method  => $method,
                                name    => $iface->iface_name,
                                address => $ip,
                                netmask => $netmask,
                                gateway => $gateway,
                                role    => $interface_role_name };

            $log->info("Iface " .$iface->iface_name . " configured via static file");
        }

        # Apply VLAN's
        for my $network ($interface->getNetworks) {
            if ($network->isa("Entity::Network::Vlan")) {
                $log->info("Apply VLAN on " . $iface->getAttr(name => 'iface_name'));
                my $ehost_manager = EFactory::newEEntity(data => $self->{context}->{host}->getHostManager);
                $ehost_manager->applyVLAN(
                    iface => $iface,
                    vlan  => $network
                );
            }
        }
    }

    #~ if (not $self->{context}->{cluster}->getMasterNodeId()) {
        #~ my $i = 1;
        #~ my $tiers = $self->{context}->{cluster}->getTiers();
        #~ if ($tiers) {
            #~ foreach my $tier_key (keys %$tiers){
                #~ my $dmz_ips = $tiers->{$tier_key}->getDmzIps();
                #~ foreach my $dmz_ip (@$dmz_ips){
                    #~ my $tmp_iface = {
                        #~ name    => "eth0:$i",
                        #~ address => $dmz_ip->{address},
                        #~ netmask => $dmz_ip->{netmask}
                    #~ };
                    #~ push (@net_ifaces, $tmp_iface);
                    #~ $i++;
                #~ }
            #~ }
        #~ }
        #~ @net_ifaces = (@net_ifaces, @{$self->{context}->{cluster}->getPublicIps()});
    #~ }

     my $file = $self->{context}->{cluster}->generateNodeFile(
        cluster       => $self->{context}->{cluster},
        host          => $self->{context}->{host},
        file          => '/etc/network/interfaces',
        template_dir  => '/templates/internal',
        template_file => 'network_interfaces.tt',
        data          => { interfaces => \@net_ifaces }
    );

    $self->getEContext->send(
        src  => $file,
        dest => $args{mount_point}.'/etc/network'
    );

    # Disable network deconfiguration during halt
    unlink "$args{mount_point}/etc/rc0.d/S35networking";

    # Update kanopya etc hosts
    my @data = ();
    for my $host (Entity::Host->getHosts(hash => {})) {
        my $hostname = $host->getAttr(name => 'host_hostname');
        next if (not $hostname or $hostname eq '');
        push @data, {
            ip         => $host->getAdminIp,
            hostname   => $hostname,
            domainname => $self->{params}->{kanopya_domainname},
        };
    }

    my $template = Template->new( {
        INCLUDE_PATH => '/templates/components/linux',
        INTERPOLATE  => 0,
        POST_CHOMP   => 0,
        EVAL_PERL    => 1,
        RELATIVE     => 1,
    } );

    $template->process('hosts.tt', { hosts => \@data }, '/etc/hosts');
}

sub _generateBootConf {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     =>\%args,
                         required => [ 'mount_point', 'filesystem', 'options' ]);

    # Firstly create pxe config file if needed
    my $boot_policy = $self->{context}->{cluster}->getAttr(name => 'cluster_boot_policy');

    if ($boot_policy =~ m/PXE/) {
        $self->_generatePXEConf(cluster     => $self->{context}->{cluster},
                                host        => $self->{context}->{host},
                                mount_point => $args{mount_point});

        if ($boot_policy =~ m/ISCSI/) {
            my $targetname = $self->{context}->{container_access}->getAttr(name => 'container_access_export');

            $self->getEContext->execute(
                command => "touch $args{mount_point}/etc/iscsi.initramfs"
            );

            $log->debug("Generate Initiator Conf");

            my $initiatorname = $self->{context}->{host}->host_initiatorname;
            my $lun_number = $self->{context}->{container_access}->getLunId(host => $self->{context}->{host});

            $self->getEContext->execute(
                command => "echo \"InitiatorName=$initiatorname\" > " .
                           "$args{mount_point}/etc/initiatorname.iscsi"
            );

            my $rand = new String::Random;
            my $tmpfile = $rand->randpattern("cccccccc");

            # create Template object
            my $template = Template->new($config);
            my $input = "bootconf.tt";

            my $vars = {
                filesystem    => $self->{context}->{container}->getAttr(name => 'container_filesystem'),
                initiatorname => $initiatorname,
                target        => $targetname,
                ip            => $self->{context}->{container_access}->getAttr(name => 'container_access_ip'),
                port          => $self->{context}->{container_access}->getAttr(name => 'container_access_port'),
                lun           => "lun-" . $lun_number,
                mount_opts    => $args{options},
                mounts_iscsi  => [],
                additional_devices => "",
            };

            my $components = $self->{cluster_components};
            foreach my $i (keys %$components) {
                if ($components->{$i}->isa("Entity::Component")) {
                    if ($components->{$i}->isa("Entity::Component::Openiscsi2")){
                        my $iscsi_export = $components->{$i};
                        $vars->{mounts_iscsi} = $iscsi_export->getExports();
                        my $tmp = $vars->{mounts_iscsi};
                        foreach my $j (@$tmp){
                            $vars->{additional_devices} .= " ". $j->{name};
                        }
                    }
                }
            }

            $template->process($input, $vars, "/tmp/$tmpfile")
                or throw Kanopya::Exception::Internal(
                             error => "Error when processing template $input."
                         );

            my $tftp_conf = $self->{config}->{tftp}->{directory};
            my $dest = $tftp_conf . '/' . $self->{context}->{host}->getAttr(name => "host_hostname") . ".conf";

            $self->getEContext->send(src => "/tmp/$tmpfile", dest => "$dest");
            unlink "/tmp/$tmpfile";
        }

        my $grep_result = $self->getEContext->execute(
                              command => "grep \"NETDOWN=no\" $args{mount_point}/etc/default/halt"
                          );

        if (not $grep_result->{stdout}) {
            $self->getEContext->execute(
                command => "echo \"NETDOWN=no\" >> $args{mount_point}/etc/default/halt"
            );
        }
    }

    # Set up fastboot
    $self->getEContext->execute(
        command => "touch $args{mount_point}/fastboot"
    );
}

sub _generatePXEConf {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     =>\%args,
                         required => ['cluster', 'host', 'mount_point']);

    my $cluster_kernel_id = $args{cluster}->getAttr(name => "kernel_id");
    my $kernel_id = $cluster_kernel_id ? $cluster_kernel_id : $args{host}->getAttr(name => "kernel_id");

    my $clustername = $args{cluster}->getAttr(name => 'cluster_name');
    my $hostname = $args{host}->getAttr(name => 'host_hostname');

    my $kernel_version = Entity::Kernel->get(id => $kernel_id)->getAttr(name => 'kernel_version');
    my $boot_policy    = $args{cluster}->getAttr(name => 'cluster_boot_policy');

    my $tftpdir = $self->{config}->{tftp}->{directory};

    my $nfsexport = "";
    if ($boot_policy =~ m/NFS/) {
        $nfsexport = $self->{context}->{container_access}->getAttr(name => 'container_access_export');
    }

    ## Here we create a dedicated initramfs for the node
    # we create a temporary working directory for the initrd

    $log->info('Build dedicated initramfs');
    my $initrddir = "/tmp/$clustername-$hostname";
    my $cmd = "mkdir -p $initrddir";
    $self->getEContext->execute(command => $cmd);

    # check and retrieve compression type
    my $initrd = "$tftpdir/initrd_$kernel_version";
    $cmd = "file $initrd | grep -o -E '(gzip|bzip2)'";
    my $result = $self->getEContext->execute(command => $cmd);
    my $decompress;
    chomp($result->{stdout});
    if($result->{stdout} eq 'gzip') {
        $decompress = 'zcat';
    } elsif($result->{stdout} eq 'bzip2') {
        $decompress = 'bzcat';
    } else {
        throw Kanopya::Exception::Internal(
            error => "Invalid compress type for $initrd ; must be gzip or bzip2"
        );
    }

    # we decompress and extract the original initrd to this directory
    $cmd = "(cd $initrddir && $decompress $initrd | cpio -i)";
    $self->getEContext->execute(command => $cmd);

    # append files to the archive directory
    my $sourcefile = $args{mount_point}.'/etc/udev/rules.d/70-persistent-net.rules';
    $cmd = "(cd $initrddir && mkdir -p etc/udev/rules.d && cp $sourcefile etc/udev/rules.d)";
    $self->getEContext->execute(command => $cmd);

    # create the final storing directory
    my $path = "$tftpdir/$clustername/$hostname";
    $cmd = "mkdir -p $path";
    $self->getEContext->execute(command => $cmd);

    # rebuild and compress the new initrd
    my $newinitrd = $path."/initrd_$kernel_version";
    $cmd = "(cd $initrddir && find . | cpio -H newc -o | bzip2 > $newinitrd)";
    $self->getEContext->execute(command => $cmd);

    # finaly we remove the temporary directory
    $cmd = "rm -r $initrddir";
    $self->getEContext->execute(command => $cmd);

    my $pxeiface = $args{host}->getPXEIface;
    my $interface = $pxeiface->getInterface;
    my $gateway = undef;
    if ($interface->hasDefaultGateway) {
        $gateway = $pxeiface->getPoolip()->getAttr(name => 'poolip_gateway');
    }

    # Add host in the dhcp
    my $subnet = $self->{context}->{dhcpd_component}->getInternalSubNetId();

    # Set Hostname
    my $host_hostname = $self->{context}->{host}->getAttr(name => "host_hostname");

    # Configure DHCP Component
    my $tmp_kernel_id = $self->{context}->{cluster}->getAttr(name => "kernel_id");
    my $host_kernel_id = $tmp_kernel_id ? $tmp_kernel_id : $self->{context}->{host}->getAttr(name => "kernel_id");

    $self->{context}->{dhcpd_component}->addHost(
        dhcpd3_subnet_id                => $subnet,
        dhcpd3_hosts_ipaddr             => $pxeiface->getIPAddr,
        dhcpd3_hosts_mac_address        => $pxeiface->getAttr(name => 'iface_mac_addr'),
        dhcpd3_hosts_hostname           => $host_hostname,
        dhcpd3_hosts_ntp_server         => $self->{context}->{bootserver}->getMasterNodeIp(),
        dhcpd3_hosts_domain_name        => $self->{context}->{cluster}->getAttr(name => "cluster_domainname"),
        dhcpd3_hosts_domain_name_server => $self->{context}->{cluster}->getAttr(name => "cluster_nameserver1"),
        dhcpd3_hosts_gateway            => $gateway,
        kernel_id                       => $host_kernel_id,
        erollback                       => $self->{erollback}
    );

    my $eroll_add_dhcp_host = $self->{erollback}->getLastInserted();
    $self->{erollback}->insertNextErollBefore(erollback => $eroll_add_dhcp_host);

    # Generate new configuration file
    $self->{context}->{dhcpd_component}->generate(erollback => $self->{erollback});

    my $eroll_dhcp_generate = $self->{erollback}->getLastInserted();
    $self->{erollback}->insertNextErollBefore(erollback=>$eroll_dhcp_generate);

    # Generate new configuration file
    $self->{context}->{dhcpd_component}->reload(erollback => $self->{erollback});
    $log->info('Kanopya dhcp server reconfigured');

    # Here we generate pxelinux.cfg for the host
    my $rand    = new String::Random;
    my $tmpfile = $rand->randpattern("cccccccc");

    # create Template object
    my $template = Template->new($config);
    my $input    = "node-syslinux.cfg.tt";

    my $vars = {
        nfsroot    => ($boot_policy =~ m/NFS/) ? 1 : 0,
        iscsiroot  => ($boot_policy =~ m/ISCSI/) ? 1 : 0,
        xenkernel  => ($kernel_version =~ m/xen/) ? 1 : 0,
        kernelfile => "vmlinuz-$kernel_version",
        initrdfile => "$clustername/$hostname/initrd_$kernel_version",
        nfsexport  => $nfsexport,
    };

    $template->process($input, $vars, "/tmp/$tmpfile")
        or throw Kanopya::Exception::Internal(
                     error => "Error when processing template $input."
                 );

    my $node_mac_addr = $pxeiface->getAttr(name => 'iface_mac_addr');
    $node_mac_addr =~ s/:/-/g;
    my $dest = $tftpdir . '/pxelinux.cfg/01-' . lc $node_mac_addr ;

    $self->getEContext->send(src => "/tmp/$tmpfile", dest => "$dest");
    unlink "/tmp/$tmpfile";

    # Update Host internal ip
    $log->debug("Get subnet <$subnet> and have host ip <$pxeiface->getIPAddr>");
    my %subnet_hash = $self->{context}->{dhcpd_component}->getSubNet(dhcpd3_subnet_id => $subnet);
}

sub _generateKanopyaHalt {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "etc_path", "targetname" ]);

    my $rand = new String::Random;
    my $template = Template->new($config);
    my $tmpfile = $rand->randpattern("cccccccc");
    my $tmpfile2 = $rand->randpattern("cccccccc");
    my $input = "KanopyaHalt.tt";
    my $omitted_file = "Kanopya_omitted_iscsid";

    #TODO: mettre en parametre le port du iscsi du nas!!
    my $vars = {
        target   => $args{targetname},
        nas_ip   => $self->{context}->{container_access}->getAttr(name => 'container_access_ip'),
        nas_port => $self->{context}->{container_access}->getAttr(name => 'container_access_port'),
    };

    my $components = $self->{context}->{cluster}->getComponents(category => "all");
    foreach my $i (keys %$components) {
        # TODO: Check if it is an ExportClient and call generic method
        if ($components->{$i}->isa("Entity::Component")) {
            if ($components->{$i}->isa("Entity::Component::Openiscsi2")) {
                $log->debug("The cluster component is an Openiscsi2");

                my $iscsi_export = $components->{$i};
                $vars->{data_exports} = $iscsi_export->getExports();
            }
        }
    }

    $log->debug("Generate Kanopya Halt with :" . Dumper($vars));
    $template->process($input, $vars, "/tmp/" . $tmpfile) or die $template->error(), "\n";

    $self->getEContext->send(src  => "/tmp/$tmpfile",
                             dest => "$args{etc_path}/init.d/Kanopya_halt");
    unlink "/tmp/$tmpfile";

    $self->getEContext->execute(
        command => "chmod 755 $args{etc_path}/init.d/Kanopya_halt"
    );
    #$self->getEContext->execute(
    #    command => "ln -sf ../init.d/Kanopya_halt $args{etc_path}/rc0.d/S89Kanopya_halt"
    #);

    $log->debug("Generate omitted file <$omitted_file>");
    $self->getEContext->execute(
        command => "cp /templates/internal/$omitted_file /tmp/"
    );
    $self->getEContext->send(
        src  => "/tmp/$omitted_file",
        dest => "$args{etc_path}/init.d/Kanopya_omitted_iscsid"
    );
    unlink "/tmp/$omitted_file";

    $self->getEContext->execute(
        command => "chmod 755 $args{etc_path}/init.d/Kanopya_omitted_iscsid"
    );
    #$self->getEContext->execute(
    #    command => "ln -sf ../init.d/Kanopya_omitted_iscsid " .
    #               "$args{etc_path}/rc0.d/S19Kanopya_omitted_iscsid"
    #);
}

sub _generateNtpdateConf {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ 'mount_point' ]);

    my $rand = new String::Random;
    my $tmpfile = $rand->randpattern("cccccccc");
    my $template = Template->new($config);
    my $input = "ntpdate.tt";
    my $data = {
        ntpservers => $self->{context}->{bootserver}->getMasterNodeIp(),
    };

    $template->process($input, $data, "/tmp/$tmpfile")
        or throw Kanopya::Exception::Internal::IncorrectParam(
                     error => "Error while generating ntpdate configuration ". $template->error() . "\n"
                 );

    $self->getEContext->send(
        src  => "/tmp/$tmpfile",
        dest => "$args{mount_point}/etc/default/ntpdate"
    );

    unlink "/tmp/$tmpfile";

    # send ntpdate init script
    $tmpfile = $rand->randpattern("cccccccc");
    $input = "ntpdate";
    $data = {};

    $template->process($input, $data, "/tmp/$tmpfile")
        or throw Kanopya::Exception::Internal::IncorrectParam(
                     error => "Error while generating ntpdate init script ". $template->error() . "\n"
                 );

    $self->getEContext->send(
        src  => "/tmp/$tmpfile",
        dest => "$args{mount_point}/etc/init.d/ntpdate"
    );

    $self->getEContext->execute(command => "chmod +x $args{mount_point}/etc/init.d/ntpdate");
    $self->getEContext->execute(command => "chroot $args{mount_point} /sbin/insserv -d ntpdate");
}

1;

__END__

=pod

=head1 NAME

EOperation::EStartNode - Operation class implementing Node starting operation

=head1 SYNOPSIS

This Object represent an operation.
It allows to implement Node starting operation

=head1 DESCRIPTION

This operation is the second in node addition in cluster process.
Cluster was prepare during PreStartNode, this operation :
- create the node configuration
- create export if node is diskless
- configure dhcp and node network configuration
- generate information used during node booting process (in the initramfs)
- finally start the node (etherwake, psu or other)

=head1 METHODS

=head2 new

my $op = EOperation::EStartNode->new();

Operation::EStartNode->new creates a new AddMotheboardInCluster operation.
return : EOperation::EStartNode : Operation add host in a cluster

=head2 _init

    $op->_init();
    This private method is used to define some hash in Operation

=head2 _cancel

    Class : Private

    Desc : This private method is used to rollback the operation

=head2 prepare

    Class : Private

    Desc : This private method is used to prepare the operation execution

=head2 _generateNodeConf

    Class : Private

    Desc : This is the method which call node configuration methods (udev, net...)

    Args : root_dev : Hash ref : This value come from
                                 $cluster->getSystemImage()->getDevices()->{root},
                                 It represents information on root device of cluster's
                                 system image
           etc_targetname   : String : This is the targetname of etc export
           mount_point      : String : This is the node etc disk mount point

=head2 _generateHostnameConf

    Class : Private

    Desc : This file generate file /etc/hostname which contains node host name

    Args : mount_point  : String : path to the directory where is mounted etc of node
           hostname : String : it is the node host name

=head2 _generateInitiatorConf

    Class : Private

    Desc : This file generate file /etc/iscsi/initiatorname.iscsi which contains node initiatorname

    Args : mount_point  : String : path to the directory where is mounted etc of node
           initatorname : String : it is the node initiator name

=head2 _generateUdevConf

    Class : Private

    Desc : This method generates and copies /etc/udev/rules.d/70-persistent-net.rules
           This file defines name of the network interface name with their MAC address

    Args : mount_point  : String : path to the directory where is mounted etc of node

=head2 _generateKanopyaHalt

    Class : Private

    Desc : This script generate and copy KanopyaHalt and iscsi_omitted script on /etc/init.d of node and add them into rc0.d

    Args : mount_point      : String : path to the directory where is mounted etc of node
           etc_targetname   : String : the tagetname of the etc device

=head2 _generateHosts

    Class : Private

    Desc : This method generate and copy hosts file in /etc disk of the node

    Args : mount_point      : String : path to the directory where is mounted etc of node

=head2 _generateNetConf

    Class : Private

    Desc : This method generate and copy network configuration file
           (man /etc/network/interface) file in /etc disk of the node
           It disables iscsi unmount at halt time through deleting rc0.d/S35networking

    Args : mount_point      : String : path to the directory where is mounted etc of node

=head2 _generateBootConf

    Class : Private

    Desc : This method generate the boot configuration file.
           This file contains disk connection specification and system image access method

    Args : root_dev : Hash ref : This value come from
                             $cluster->getSystemImage()->getDevices()->{root},
                             It represents information on root device of cluster's system image
       etc_targetname   : String : This is the targetname of etc export
       initiatorname    : String : This is the node initiator name

=head2 _generateResolvConf

    Class : Private

    Desc : This method generate the file /etc/resolv.conf which is the linux file to define dns server name.

    Args : mount_point  : String : path to the directory where is mounted etc of node

=head2 _generateNtpdateConf

    Class : Private

    Desc : This method generate the file /etc/default/ntpdate which is the config file of ntpdate.
           It allows to synchronize host with time server.

Args : mount_point  : String : path to the directory where is mounted etc of node


=head2 finish

    Class : Public

    Desc : This method is the last execution operation method called.
    It is used to clean and finalize operation execution

    Args :
        None

    Return : Nothing

    Throw

=head1 DIAGNOSTICS

Exceptions are thrown when mandatory arguments are missing.
Exception : Kanopya::Exception::Internal::IncorrectParam

=head1 CONFIGURATION AND ENVIRONMENT

This module need to be used into Kanopya environment. (see Kanopya presentation)
This module is a part of Administrator package so refers to Administrator configuration

=head1 DEPENDENCIES

This module depends of

=over

=item KanopyaException module used to throw exceptions managed by handling programs

=item Entity::Component module which is its mother class implementing global component method

=back

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to <Maintainer name(s)> (<contact address>)

Patches are welcome.

=head1 AUTHOR

<HederaTech Dev Team> (<dev@hederatech.com>)

=head1 LICENCE AND COPYRIGHT

Copyright 2011 Hedera Technology SAS
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

