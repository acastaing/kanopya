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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

=head1 NAME

ENfsContainerAccess - execution class of iscsi container access entities.

=head1 SYNOPSIS


=head1 DESCRIPTION

EContainerAccess::ENfsContainerAccess is the execution class for iscsi container access entities.

=head1 METHODS

=cut

package EEntity::EContainerAccess::EFileContainerAccess;
use base "EEntity::EContainerAccess";

use strict;
use warnings;

use Operation;
use EFactory;
use Entity::ContainerAccess;

use Log::Log4perl "get_logger";
my $log = get_logger("");

sub connect {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $underlying_access_id = $self->getContainer->getAttr(
                                   name => 'container_access_id'
                               );

    my $eunderlying_access = EFactory::newEEntity(
                                 data => Entity::ContainerAccess->get(id => $underlying_access_id)
                             );

    my $mountpoint = $self->buildMountpoint(eunderlying_access => $eunderlying_access);
    $eunderlying_access->mount(mountpoint => $mountpoint,
                               econtext   => $args{econtext});

    # Get a free loop device
    $command = "losetup -f";
    $result = $args{econtext}->execute(command => $command);
    if ($result->{exitcode} != 0) {
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }
    chomp($result->{stdout});
    my $loop = $result->{stdout};

    my $file = $mountpoint . '/' . $self->getContainer->getAttr(
                                       name => 'container_device'
                                   );

    $command = "losetup $loop $file";
    $result = $args{econtext}->execute(command => $command);
    if ($result->{exitcode} != 0) {
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }

    $self->setAttr(name  => 'device_connected',
                   value => $loop);
    $self->save();
    
    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('disconnect'),
            parameters => [ $self, "econtext", $args{econtext} ]
        );
    }
    return $loop;
}

sub disconnect {
    my $self = shift;
    my %args = @_;
    my ($command, $result);

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $device = $self->getAttr(name => 'device_connected');

    my $counter = 5;
    while($counter != 0) {
        $command = "losetup -d $device";
        $result  = $args{econtext}->execute(command => $command);
        if($result->{exitcode} == 0) {
            last;
        }
        $counter--;
        sleep(1);
    }

    if ($result->{exitcode} != 0) {
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }

    my $underlying_access_id = $self->getContainer->getAttr(
                                   name => 'container_access_id'
                               );

    my $eunderlying_access = EFactory::newEEntity(
                                 data => Entity::ContainerAccess->get(id => $underlying_access_id)
                             );

    my $mountpoint = $self->buildMountpoint(eunderlying_access => $eunderlying_access);
    $eunderlying_access->umount(mountpoint => $mountpoint,
                                econtext   => $args{econtext});

    $self->setAttr(name  => 'device_connected',
                   value => '');
    $self->save();
}

sub buildMountpoint {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'eunderlying_access' ]);

    my $underlying = $args{eunderlying_access}->_getEntity->getContainer->getAttr(name => 'container_id');
    my $file_mountpoint = $self->_getEntity->getContainer->getMountPoint;

    return $file_mountpoint . "_on_" . $underlying;
}

sub getPreferredBlockSize {
    my $self = shift;
    my %args = @_;

    # bs=1M raise an operating system freeze when output device is
    # a loopback of a file on a nfs mount point.
    return '1k';
}

1;
