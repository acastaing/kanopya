#    Copyright © 2011 Hedera Technology SAS
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


=pod
=begin classdoc

TODO

=end classdoc
=cut

package EEntity::EComponent::EVmm::EKvm;
use base "EEntity::EComponent::EVmm";

use strict;
use warnings;

use Entity;
use Entity::ContainerAccess;
use EEntity;
use General;
use XML::Simple;
use Log::Log4perl "get_logger";
use Data::Dumper;
use NetAddr::IP;
use File::Copy;
use Hash::Merge qw(merge);

my $log = get_logger("");
my $errmsg;

my $resources_keys = { ram => { name => 'currentMemory/0/content', factor => 1024 },
                       cpu => { name => 'vcpu/0/content', factor => 1 } };

sub configureNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'host', 'mount_point' ]);

    $log->debug('generate /lib/udev/rules.d/60-qemu-kvm.rules');
    $self->_generateQemuKvmUdev(%args);

    $self->addInitScripts(
        mountpoint => $args{mount_point},
        scriptname => 'libvirt-bin',
    );

    $self->addInitScripts(
        mountpoint => $args{mount_point},
        scriptname => 'qemu-kvm',
    );

    # create directories for registered datastores
    for my $repo (@{ $self->iaas->getConf()->{opennebula3_repositories} }) {
        if (defined $repo->{datastore_id}) {
            my $dir = $args{mount_point} . '/var/lib/one/datastores/' . $repo->{datastore_id};
            my $cmd = "mkdir -p $dir";
            $self->_host->getEContext->execute(command => $cmd);
        }
    }
}

sub isUp {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'node' ]);

    return 1;
}

sub _generateQemuKvmUdev {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host', 'mount_point' ]);

    my $command = "echo 'KERNEL==\"kvm\", OWNER==\"oneadmin\", GROUP==\"kvm\", " .
                  "MODE==\"0660\"' > $args{mount_point}/lib/udev/rules.d/60-qemu-kvm.rules";
    $self->_host->getEContext->execute(command => $command);
}

=pod
=begin classdoc

Return the available memory amount by interrogating virsh

@param host Target Host instance

@return hash ref {mem_effectively_available   => value, mem_theoretically_available => value}

=end classdoc
=cut

sub getAvailableMemory {
    my ($self, %args) = @_;

    General::checkParams(
        args     => \%args,
        required => [ "host" ],
    );

    my $host = $args{host};
    my $mem = 0;
    my @vms = $host->virtual_machines;

    if (@vms) {
        my $command = '';
        my $onevm_id;
        for my $vm (@vms) {
            $onevm_id = $vm->opennebula3_vm->onevm_id;
            $command .= "virsh dumpxml one-$onevm_id | grep currentMemory; "
        }

        my $result = $host->getEContext->execute(command => $command);
        my $parser = XML::Simple->new();
        my $stdout = '<root>' . $result->{stdout} . '</root>';
        my $res_array = $parser->XMLin($stdout, ForceArray => 'currentMemory')->{currentMemory};
        for my $res (@$res_array) {
            $mem += $res->{content} * 1024;
        }
    }

    return {
        mem_effectively_available   => $host->getSystemComponent->getAvailableMemory(host => $host)->{mem_effectively_available},
        mem_theoretically_available => $host->host_ram * $self->iaas->overcommitment_memory_factor - $mem,
    }
}


=pod
=begin classdoc

Return virtual machine resources. If no resource type(s)
is specified in parameters, return all known resources.

@param host Target Hypervisor instance

@optional vm  If no vm specified, get resssources for all hypervisor vms.

@optional resources array of resources name to retrieve ('ram' and/or 'cpu')

=end classdoc
=cut

sub getVmResources {
    my ($self, %args) = @_;

    General::checkParams(
        args     => \%args,
        required => [ 'host' ],
        optional => { vm => undef, resources => [ 'ram', 'cpu' ] }
    );

    # If no vm specified, get resssources for all hypervisor vms.
    my @vms;
    if (not defined $args{vm}) {
        @vms = $args{host}->getVms;
    } else {
        push @vms, $args{vm};
    }

    my $vms_resources = {};
    for my $vm (@vms) {
        # Get the vm configuration in xml
        my $result = $args{host}->getEContext->execute(command => 'virsh dumpxml one-' . $vm->onevm_id);
        if ($result->{exitcode} != 0) {
            throw Kanopya::Exception::Execution(error => $result->{stdout});
        }

        my $parser = XML::Simple->new();
        my $hxml = $parser->XMLin($result->{stdout}, ForceArray => 1);

        # Build the resssources hash according to required resources
        my $vm_resources = {};
        for my $resource (@{ $args{resources} }) {
            my $value = $hxml;
            for my $selector (split('/', $resources_keys->{$resource}->{name})) {
                if (ref($value) eq "ARRAY") {
                    $value = $value->[$selector];
                } else {
                    $value = $value->{$selector};
                }
            }
            $vm_resources->{$vm->id}->{$resource} = $value * $resources_keys->{$resource}->{factor};

            if ($resource eq "cpu") {
                my $pins = $hxml->{cputune}->[0]->{vcpupin};
                for my $pinning (@{$pins}) {
                    if ($pinning->{cpuset} eq '0') {
                        $vm_resources->{$vm->id}->{$resource} -= 1;
                    }
                }
            }
        }

        $vms_resources = merge($vms_resources, $vm_resources);
    }

    return $vms_resources;
};


=pod
=begin classdoc

Update the CPU pinning for an hypervisor

@param host Hypervisor instance
@param vm VirtualMachine instance
@optional cpus

=end classdoc
=cut

sub updatePinning {
    my $self    = shift;
    my %args    = @_;

    General::checkParams(args => \%args, required => [ 'host', 'vm' ], optional => { cpus => -1 });

    if ($args{cpus} == -1) {
        $args{cpus} = $args{vm}->host_core;
    }

    my $i   = 0;
    my $cmd = "";
    while ($i < $args{vm}->opennebula3_kvm_vm_cores) {
        if ($i < $args{cpus}) {
            $cmd    .= "virsh vcpupin one-" . $args{vm}->onevm_id
                . " " . $i . " 0-" . ($args{host}->host_core - 1) . " ; ";
        }
        else {
            $cmd    .= "virsh vcpupin one-" . $args{vm}->onevm_id
                . " " . $i . " 0 ; ";
        }
        ++$i;
    }
    $args{host}->getEContext->execute(command => "$cmd");
}

sub getMinEffectiveRamVm {
    my ($self,%args) = @_;

    General::checkParams(
        args        => \%args,
        required    => [ 'host' ]
    );

    my @virtual_machines = map { EEntity->new(entity => $_); } $args{host}->virtual_machines;

    my $min_vm  = EEntity->new(entity => shift @virtual_machines);
    my $min_ram = $self->getRamUsedByVm(host => $min_vm)->{total};

    for my $virtual_machine (@virtual_machines) {
        my $ram = $self->getRamUsedByVm(host => $virtual_machine)->{total};
        if ($ram < $min_ram) {
            $min_ram = $ram;
            $min_vm  = $virtual_machine;
        }
    }

    return {
        vm  => $min_vm,
        ram => $min_ram,
    }
}

sub getRamUsedByVm {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    my $vm = $args{host};
    my $e_hypervisor = EEntity->new(entity => $vm->hypervisor);

    # This command get the pid of the kvm process then get the RAM used and SWAP used by this process
    my $cmd = 'cat /proc/$(cat /var/run/libvirt/qemu/one-' . ($vm->onevm_id) . '.pid)/status | grep "VmRSS\|VmSwap"';

    my $mem;
    my $stdout = $e_hypervisor->getEContext->execute(command => "$cmd")->{stdout};
    my @lines = split('\n', $stdout);

    for my $line (@lines) {
        my @line_split = split('\s+', $line);
        $mem->{$line_split[0]} = $line_split[1] * 1024; # Convert kB to bytes
    }

    return {
        mem_ram  => $mem->{'VmRSS:'},
        mem_swap => $mem->{'VmSwap:'},
        total    => $mem->{'VmRSS:'} + $mem->{'VmSwap:'},
    }
}

1;
