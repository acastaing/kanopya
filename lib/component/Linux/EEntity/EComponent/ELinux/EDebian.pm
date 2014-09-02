#    Copyright © 2012 Hedera Technology SAS
#
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

package EEntity::EComponent::ELinux::EDebian;
use base 'EEntity::EComponent::ELinux';

use strict;
use warnings;

use Kanopya::Config;

use Log::Log4perl 'get_logger';
use Data::Dumper;

my $log = get_logger("");
my $errmsg;

# generate configuration files on node
sub configureNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'host', 'mount_point' ]);

    $self->SUPER::configureNode(%args);

    my $econtext = $self->_host->getEContext;
    my $grep_result = $econtext->execute(
                         command => "grep \"NETDOWN=no\" $args{mount_point}/etc/default/halt"
                      );

    if (not $grep_result->{stdout}) {
        $econtext->execute(
            command => "echo \"NETDOWN=no\" >> $args{mount_point}/etc/default/halt"
        );
    }

    # adjust some requirements on the image
    my $data = $self->_entity->getConf();
    my $automountnfs = 0;
    for my $mountdef (@{$data->{linuxes_mount}}) {
        my $mountpoint = $mountdef->{linux_mount_point};
        $econtext->execute(command => "mkdir -p $args{mount_point}/$mountpoint");
        
        if ($mountdef->{linux_mount_filesystem} eq 'nfs') {
            $automountnfs = 1;
        }
    }

    if ($automountnfs) {
        my $grep_result = $econtext->execute(
                              command => "grep \"ASYNCMOUNTNFS=no\" $args{mount_point}/etc/default/rcS"
                          );

        if (not $grep_result->{stdout}) {
            $econtext->execute(
                command => "echo \"ASYNCMOUNTNFS=no\" >> $args{mount_point}/etc/default/rcS"
            );
        }
    }

    # Disable network deconfiguration during halt
    unlink "$args{mount_point}/etc/rc0.d/S35networking";
}

sub _shell {
    return "/bin/bash";
}

sub _writeNetConf {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'host', 'mount_point', 'ifaces' ]);

    my $cluster = $args{host}->node->service_provider;

    #we ignore the slave interfaces in the case of bonding
    my @ifaces = @{ $args{ifaces} };
    my $host_params = $cluster->getManagerParameters(manager_type => 'HostManager');

    my $file = $self->generateNodeFile(
        host          => $args{host},
        file          => '/etc/network/interfaces',
        template_dir  => 'internal',
        template_file => 'network_interfaces.tt',
        data          => {
            deploy_on_disk => $host_params->{deploy_on_disk},
            interfaces     => \@ifaces,
            boot_policy    => $cluster->cluster_boot_policy
        },
        mount_point   => $args{mount_point}
    );
}

sub service {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'services', 'mount_point' ]);

    for my $service (@{$args{services}}) {
        if (defined ($args{command})) {
            system("chroot $args{mount_point} invoke-rc.d " . $service . " " . $args{command});
        }
        if (defined ($args{state})) {
            # TODO : specialize EDebian class into EUbuntu and overwrite `service` sub
            if (not system("[ -f $args{mount_point}/sbin/insserv ]")) {
                system("chroot $args{mount_point} /sbin/insserv -d $service");
            }
            else {
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc0.d/K20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc1.d/K20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc2.d/S20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc3.d/S20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc4.d/S20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc5.d/S20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rc6.d/K20" . $service);
                system("cp " . $args{mount_point} . "/etc/init.d/" . $service . " " . $args{mount_point} . "/etc/rcS.d/K20" . $service);
            }
        }
    }
}

sub customizeInitramfs {
    my ($self, %args) = @_;

    General::checkParams(args     =>\%args,
                         required => [ 'initrd_dir', 'host' ]);

    $self->SUPER::customizeInitramfs(%args);

    my $kanopya_dir = Kanopya::Config::getKanopyaDir();
    my $cmd = "cp -R $kanopya_dir/tools/deployment/system/initramfs-tools/scripts/* " . $args{initrd_dir} . "/scripts";
    $self->_host->getEContext->execute(command => $cmd);
}
            
1;
