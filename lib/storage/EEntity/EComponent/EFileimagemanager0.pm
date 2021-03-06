#    Copyright © 2011 Hedera Technology SAS
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


=pod
=begin classdoc

TODO

=end classdoc
=cut

package EEntity::EComponent::EFileimagemanager0;
use base "EEntity::EComponent";
use base 'EManager::EExportManager';
use base "EManager::EDiskManager";

use strict;
use warnings;

use General;
use EEntity;
use Kanopya::Exceptions;
use Entity::ContainerAccess;
use Entity::Container::FileContainer;
use Entity::ContainerAccess::FileContainerAccess;

use Data::Dumper;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;


sub createDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "name", "size", "filesystem", "container_access_id" ],
                         optional => { image_type => "raw" });

    my $container_access = Entity::ContainerAccess->get(id => $args{container_access_id});

    $self->fileCreate(container_access => $container_access,
                      file_name        => $args{name},
                      file_size        => $args{size},
                      file_type        => $args{image_type});

    my $entity = Entity::Container::FileContainer->new(
                     disk_manager_id      => $self->id,
                     container_access_id  => $args{container_access_id},
                     container_name       => $args{name},
                     container_size       => $args{size},
                     container_filesystem => $args{filesystem},
                     container_freespace  => 0,
                     container_device     => $args{name} . '.'. $args{image_type},
                );
    my $container = EEntity->new(data => $entity);

    if (not $args{"noformat"}) {
        # Create a temporary export and connect to the access to get a device
        my $access = $self->createExport(container => $container);
        my $device = $access->tryConnect(econtext  => $self->getEContext,
                                         erollback => $args{erollback});

        $self->mkfs(device => $device, fstype => $args{filesystem});

        # Disconnect from access and remove the export
        $access->tryDisconnect(econtext  => $self->getEContext,
                               erollback => $args{erollback});
        $self->removeExport(container_access => $access);
    }

    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('removeDisk'),
            parameters => [ $self, "container", $container ]
        );
     }

    return $container;
}


sub removeDisk{
    my $self = shift;
    my %args = @_;

    General::checkParams(args=>\%args, required => [ "container" ]);

    if (! $args{container}->isa("EEntity::EContainer::EFileContainer")) {
        throw Kanopya::Exception::Internal::WrongType(
                  error => "Container must be a EEntity::EContainer::EFileContainer, not " . 
                           ref($args{container})
              );
    }

    # Check if the disk is removable
    $self->SUPER::removeDisk(%args);

    $self->fileRemove(container => $args{container});

    $args{container}->delete();

    #TODO: insert erollback ?
}


sub createExport {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'container' ]);

    # Check if the disk is not already exported
    $self->SUPER::createExport(%args);

    # TODO: Check if the given container is provided by the same
    #       storage provider than the nfsd storage provider.

    # Container is FileContainer.
    my $underlying = Entity::ContainerAccess->get(
                         id => $args{container}->getAttr(name => 'container_access_id')
                     );

    my $export_name = $underlying->getAttr(name => 'container_access_export') .
                      '/' . $args{container}->getAttr(name => 'container_device');

    my $entity = Entity::ContainerAccess::FileContainerAccess->new(
                     container_id            => $args{container}->getAttr(name => 'container_id'),
                     export_manager_id       => $self->_entity->getAttr(name => 'entity_id'),
                     container_access_export => $export_name,
                     container_access_ip     => $underlying->getAttr(name => 'container_access_ip'),
                     container_access_port   => $underlying->getAttr(name => 'container_access_port'),
                 );
    my $container_access = EEntity->new(data => $entity);

    $log->info("Added Export for file <$export_name>");

    if (exists $args{erollback} and defined $args{erollback}) {
        $args{erollback}->add(
            function   => $self->can('removeExport'),
            parameters => [ $self, "container_access", $container_access ]
        );
    }

    return $container_access;
}

sub removeExport {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ 'container_access' ]);

    if (! $args{container_access}->isa("EEntity::EContainerAccess::EFileContainerAccess")) {
        throw Kanopya::Exception::Execution(
                  error => "ContainerAccess must be a EEntity::EContainerAccess::EFileContainerAccess, not " .
                           ref($args{container_access})
              );
    }

    $args{container_access}->delete();
}


=pod
=begin classdoc

Create an empty file that will be of the type managed by the component

=end classdoc
=cut

sub fileCreate {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ 'container_access', 'file_name',
                                       'file_size', 'file_type' ]);

    # Firstly mount the container access on the executor.
    my $mountpoint = $args{container_access}->getMountPoint . "_filecreate_" . $args{file_name};
    my $econtainer_access = EEntity->new(data => $args{container_access});
    
    $econtainer_access->mount(mountpoint => $mountpoint,
                              econtext   => $self->getEContext);

    my $file_image_path = "$mountpoint/$args{file_name}.$args{file_type}";
    my ($command, $result);

    $log->debug("Container access mounted, trying to create $file_image_path, size $args{file_size}.");

    eval {
        $command = 'qemu-img create -f ' . $args{file_type} . ' ' .
                   $file_image_path . ' ' . $args{file_size};

        $result  = $self->getEContext->execute(command => $command);

        if ($result->{stderr} and ($result->{exitcode} != 0)) {
            throw Kanopya::Exception::Execution(error => $result->{stderr});
        }

        $command = "sync";
        $self->getEContext->execute(command => $command);

        $command = "chmod 777 $file_image_path";
        $self->getEContext->execute(command => $command);
    };
    if ($@) {
        $econtainer_access->umount(mountpoint => $mountpoint,
                                   econtext   => $self->getEContext);

        throw Kanopya::Exception::Execution(
            error => "Unable to create file <$file_image_path> with size <$args{file_size}>: $@"
        );
    }

    $econtainer_access->umount(mountpoint => $mountpoint,
                               econtext   => $self->getEContext);
}


sub fileRemove{
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "container" ]);

    # Firstly mount the container access on the executor.
    my $container_access = Entity::ContainerAccess->get(
                               id => $args{container}->container_access_id
                           );

    my $mountpoint = $container_access->getMountPoint . "_fileremove_" . $args{container}->container_device;

    my $econtainer_access = EEntity->new(data => $container_access);
    $econtainer_access->mount(mountpoint => $mountpoint, econtext => $self->getEContext);

    my $file_image_path = "$mountpoint/" . $args{container}->container_device;

    $log->debug("Container access mounted, trying to remove $file_image_path");

    my $fileremove_cmd = "rm -f $file_image_path";
    $log->debug($fileremove_cmd);
    my $ret = $self->getEContext->execute(command => $fileremove_cmd);

    if($ret->{'stderr'}){
        $errmsg = "Error with removing file " . $file_image_path .  ": " . $ret->{'stderr'};
        $log->error($errmsg);
        throw Kanopya::Exception::Execution(error => $errmsg);
    }

    $econtainer_access->umount(mountpoint => $mountpoint, econtext => $self->getEContext);
}

1;
