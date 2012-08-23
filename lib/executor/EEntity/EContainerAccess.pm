# Copyright 2012 Hedera Technology SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package EEntity::EContainerAccess;
use base "EEntity";

use strict;
use warnings;

use General;
use EFactory;

use Data::Dumper;

use Kanopya::Exceptions;

use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

our $VERSION = '1.00';

=head2 copy

    desc: Copy content of a source container access to dest.
          Try to copy at the device level, mount the both container and copy
          files instead.

=cut

sub copy {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'dest', 'econtext' ]);

    my $source_access = $self;
    my $dest_access   = $args{dest};

    $log->debug('Try to connect to the source container...');
    my $source_device = $source_access->tryConnect(econtext  => $args{econtext},
                                                   erollback => $args{erollback});
    $log->debug('Try to connect to the destination container...');
    my $dest_device = $dest_access->tryConnect(econtext  => $args{econtext},
                                               erollback => $args{erollback});

    # If devices exists, copy contents with 'dd'
    if (defined $source_device and defined $dest_device) {
        my $blocksize = $dest_access->getPreferredBlockSize;

        $command = "dd conv=notrunc if=$source_device of=$dest_device bs=$blocksize";
        $result  = $args{econtext}->execute(command => $command);

        if ($result->{stderr} and ($result->{exitcode} != 0)) {
            $errmsg = "Error with copy of $source_device to $dest_device: " .
                      $result->{stderr};
            throw Kanopya::Exception::Execution(error => $errmsg);
        }

        $command = "sync";
        $args{econtext}->execute(command => $command);

        my $source_size = $source_access->getContainer->getAttr(name => 'container_size');
        my $dest_size   = $dest_access->getContainer->getAttr(name => 'container_size');

        # Check if the destination container is higher thant the source one,
        # resize it to maximum.
        if ($dest_access->getPartitionCount(econtext => $args{econtext}) == 1 and $dest_size > $source_size) {
            my $part_start = $dest_access->getPartitionStart(econtext => $args{econtext});
            if ($part_start and $part_start > 0) {
                $command = "parted -s $dest_device rm 1";
                $result  = $args{econtext}->execute(command => $command);

                $command = "parted -s -- $dest_device mkpart primary " . $part_start . "B -1s";
                $result  = $args{econtext}->execute(command => $command);
            }

            my $part_device = $dest_access->tryConnectPartition(econtext  => $args{econtext},
                                                                erollback => $args{erollback});

            # Finally resize2fs the partition
            $command = "e2fsck -y -f $part_device";
            $args{econtext}->execute(command => $command);
            $command = "resize2fs -F $part_device";
            $args{econtext}->execute(command => $command);

            $dest_access->tryDisconnectPartition(econtext  => $args{econtext},
                                                 erollback => $args{erollback});
        }

        # Disconnect the containers.
        $log->debug('Try to disconnect from the source container...');
        $source_access->tryDisconnect(econtext  => $args{econtext},
                                      erollback => $args{erollback});

        $log->debug('Try to disconnect from the destination container...');
        $dest_access->tryDisconnect(econtext  => $args{econtext},
                                    erollback => $args{erollback});
    }
    # One or both container access do not support device level (e.g. Nfs)
    else {
        # Mount the containers on the executor.
        my $source_mountpoint = $source_access->getContainer->getMountPoint;
        my $dest_mountpoint   = $dest_access->getContainer->getMountPoint;

        $log->debug('Mounting source container <' . $source_mountpoint . '>');
        $source_access->mount(mountpoint => $source_mountpoint,
                              econtext   => $args{econtext},
                              erollback  => $args{erollback});

        $log->debug('Mounting destination container <' . $dest_mountpoint . '>');
        $dest_access->mount(mountpoint => $dest_mountpoint,
                            econtext   => $args{econtext},
                            erollback  => $args{erollback});

        # Copy the filesystem.
        $command = "cp -R --preserve=all $source_mountpoint/. $dest_mountpoint/";
        $result  = $args{econtext}->execute(command => $command);

        if ($result->{stderr}) {
            $errmsg = "Error with copy of $source_mountpoint to $dest_mountpoint: " .
                      $result->{stderr};
            $log->error($errmsg);
            throw Kanopya::Exception::Execution(error => $errmsg);
        }

        # Unmount the containers.
        
        $source_access->umount(mountpoint => $source_mountpoint,
                               econtext   => $args{econtext},
                               erollback  => $args{erollback});
        $dest_access->umount(mountpoint => $dest_mountpoint,
                             econtext   => $args{econtext},
                             erollback  => $args{erollback});
    }
}

=head2 mount

    desc: Generic mount method. Connect to the container_access,
          and mount the corresponding device on givven mountpoint.

=cut

sub mount {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'mountpoint', 'econtext' ]);

    # Connecting to the container access.
    my $device = $self->tryConnectPartition(econtext  => $args{econtext},
                                            erollback => $args{erollback});

    $command = "mkdir -p $args{mountpoint}";
    $args{econtext}->execute(command => $command);

    $log->debug("Mounting <$device> on <$args{mountpoint}>.");

    $command = "mount $device $args{mountpoint}";
    $result  = $args{econtext}->execute(command => $command);
    if($result->{stderr}){
        throw Kanopya::Exception::Execution(
                  error => "Unable to mount $device on $args{mountpoint}: " .
                           $result->{stderr}
              );
    }

    $log->debug("Device <$device> mounted on <$args{mountpoint}>.");
    
    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('umount'),
            parameters => [ $self, "mountpoint", $args{mountpoint}, "econtext", $args{econtext} ]
        );
    }
}

=head2 umount

    desc: Generic umount method. Umount, disconnect from the container access,
          and remove the mountpoint.

=cut

sub umount {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'mountpoint', 'econtext' ]);

    $log->debug("Unmonting (<$args{mountpoint}>)");

    $command = "sync";
    $args{econtext}->execute(command => $command);

    my $counter = 5;
    while($counter != 0) {
        $command = "umount $args{mountpoint}";
        $result  = $args{econtext}->execute(command => $command);
        if($result->{exitcode} == 0) {
            last;
        }
        $counter--;
        sleep(1);
    }
    
    if ($result->{exitcode} != 0 ) {
        throw Kanopya::Exception::Execution(
                  error => "Unable to umount $args{mountpoint}: " .
                           $result->{stderr}
              );
    }

    # Disconnecting from container access.
    $self->tryDisconnectPartition(econtext  => $args{econtext},
                                  erollback => $args{erollback});
    $self->tryDisconnect(econtext  => $args{econtext},
                         erollback => $args{erollback});

    $command = "rm -R $args{mountpoint}";
    $args{econtext}->execute(command => $command);

    # TODO: insert an eroolback with mount method ?
}

=head2 connect

    desc: Abstract method.

=cut

sub connect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    throw Kanopya::Exception::NotImplemented();
}

=head2 disconnect

    desc: Abstract method.

=cut

sub disconnect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    throw Kanopya::Exception::NotImplemented();
}

sub getPartitionStart {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->getAttr(name => 'device_connected');
    if (! $device) {
        my $msg = "A container access must be connected before getting partition start.";
        throw Kanopya::Exception::Execution(error => $msg);
    }

    $command = "parted -m -s $device u B print";
    $result = $args{econtext}->execute(command => $command);

    # Parse the parted output to get partition start.
    my $part_start = $result->{stdout};
    $part_start =~ s/\n//g;
    $part_start =~ s/.*1://g;
    $part_start =~ s/B.*//g;
    chomp($part_start);

    return $part_start;
}

sub getPartitionCount {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->getAttr(name => 'device_connected');
    if (! $device) {
        my $msg = "A container access must be connected before getting partition start.";
        throw Kanopya::Exception::Execution(error => $msg);
    }

    $command = "parted -m -s $device u B print";
    $result = $args{econtext}->execute(command => $command);

    my @lines = split('\n', $result->{stdout});
    return (scalar @lines) - 2;
}

sub connectPartition {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->tryConnect(econtext  => $args{econtext},
                                   erollback => $args{erollback});
    my $part_start = $self->getPartitionStart(econtext  => $args{econtext},
                                              erollback => $args{erollback});

    if ($part_start and $part_start > 0) {
        # Get a free loop device
        $command = "losetup -f";
        $result  = $args{econtext}->execute(command => $command);
        if ($result->{exitcode} != 0) {
            throw Kanopya::Exception::Execution(error => $result->{stderr});
        }
        chomp($result->{stdout});
        my $loop = $result->{stdout};

        $command = "losetup $loop $device -o $part_start";
        $result  = $args{econtext}->execute(command => $command);
        if ($result->{exitcode} != 0) {
            throw Kanopya::Exception::Execution(error => $result->{stderr});
        }

        $self->setAttr(name  => 'partition_connected',
                       value => $loop);
        $self->save();

        if (exists $args{erollback} and defined $args{erollback}){
            $args{erollback}->add(
                function   => $self->can('disconnectPartition'),
                parameters => [ $self, "econtext", $args{econtext} ]
            );
        }
        return $loop;
    }
    else {
        return $device;
    }
}

sub disconnectPartition {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $partition = $self->getAttr(name => 'partition_connected');

    $command = "sync";
    $args{econtext}->execute(command => $command);

    $command = "losetup -d $partition";
    $result = $args{econtext}->execute(command => $command);
    if ($result->{exitcode} != 0) {
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }

    $self->setAttr(name  => 'partition_connected',
                   value => '');
    $self->save();
}

sub tryConnect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->getAttr(name => 'device_connected');
    if ($device) {
        $log->debug("Device already connected <$device>.");
        return $device;
    }
    return $self->connect(%args);
}

sub tryDisconnect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->getAttr(name => 'device_connected');
    if (! $device) {
        $log->debug('Device seems to be not connected, doing nothing.');
        return;
    }
    $self->disconnect(%args);
}

sub tryConnectPartition {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $partition = $self->getAttr(name => 'partition_connected');
    if ($partition) {
        $log->debug("Partition already connected <$partition>.");
        return $partition;
    }
    return $self->connectPartition(%args);
}

sub tryDisconnectPartition {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $partition = $self->getAttr(name => 'partition_connected');
    if (! $partition) {
        $log->debug('Partition seems to be not connected, doing nothing.');
        return;
    }
    $self->disconnectPartition(%args);
}

sub getPreferredBlockSize {
    my $self = shift;
    my %args = @_;

    return '1M';
}

1;

__END__

=head1 AUTHOR

Copyright (c) 2012 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
