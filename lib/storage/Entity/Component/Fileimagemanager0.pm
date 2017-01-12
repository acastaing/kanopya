# Copyright © 2012-2013 Hedera Technology SAS
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

=pod
=begin classdoc

TODO

=end classdoc
=cut

package Entity::Component::Fileimagemanager0;
use base "Entity::Component";
use base "Manager::ExportManager";
use base "Manager::DiskManager";

use strict;
use warnings;

use Entity::Container::FileContainer;
use Entity::ContainerAccess::FileContainerAccess;
use Entity::ContainerAccess::NfsContainerAccess;
use Entity::ContainerAccess;

use Manager::HostManager;
use Kanopya::Exceptions;

use Hash::Merge qw(merge);
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    executor_component_id => {
        label        => 'Workflow manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
    image_type => {
        pattern      => '^img|vmdk|qcow2$',
        is_mandatory => 0,
        is_extended  => 0,
        description  => 'The image type. It could be img (raw), vmdk or qcow2.',
    },
    disk_type => {
        is_virtual => 1
    },
    export_type => {
        is_virtual => 1
    }
};

sub getAttrDef { return ATTR_DEF; }

sub exportType {
    return "NFS repository";
}

sub diskType {
    return "Virtual machine disk";
}

=pod
=begin classdoc

@return the manager params definition.

=end classdoc
=cut

sub getManagerParamsDef {
    my ($self, %args) = @_;

    return {
        # TODO: call super on all Manager supers
        %{ $self->SUPER::getManagerParamsDef },
        container_access_id => {
            label        => 'NFS repository to use',
            type         => 'enum',
            is_mandatory => 1,
            description  => 'Images will be kept in this NFS repository.',
        },
        image_type => {
            label        => 'Disk image format',
            type         => 'enum',
            is_mandatory => 1,
            options      => [ "raw", "qcow2", "vmdk" ],
            description  => 'The image type. It could be img (raw), vmdk or qcow2.',
        },
    };
}


sub checkDiskManagerParams {
    my $self = shift;
    my %args = @_;
    
    General::checkParams(args => \%args, required => [ "container_access_id", "systemimage_size", "image_type" ]);
}


=pod
=begin classdoc

@return the managers parameters as an attribute definition. 

=end classdoc
=cut

sub getDiskManagerParams {
    my $self = shift;
    my %args  = @_;

    my $definition = $self->getManagerParamsDef();
    $definition->{container_access_id}->{options} = {};

    my @nfs = Entity::ContainerAccess::NfsContainerAccess->search();
    for my $access (@nfs) {
        $definition->{container_access_id}->{options}->{$access->id} = $access->container_access_export;
    }

    return {
        container_access_id => $definition->{container_access_id},
        image_type          => $definition->{image_type}
    };
}

sub getExportManagerFromBootPolicy {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "boot_policy" ]);

    if ($args{boot_policy} eq Manager::HostManager->BOOT_POLICIES->{virtual_disk}) {
        return $self;
    }

    throw Kanopya::Exception::Internal::UnknownCategory(
              error => "Unsupported boot policy: $args{boot_policy}"
          );
}

sub getBootPolicyFromExportManager {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "export_manager" ]);

    if ($args{export_manager}->id == $self->id) {
        return Manager::HostManager->BOOT_POLICIES->{virtual_disk};
    }

    throw Kanopya::Exception::Internal::UnknownCategory(
              error => "Unsupported export manager:" . $args{export_manager}
          );
}

sub getExportManagers {
    my $self = shift;
    my %args = @_;

    return [ $self ];
}

sub getReadOnlyParameter {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'readonly' ]);
    
    return undef;
}

sub createDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "container_access", "name", "size", "filesystem" ]);

    $log->debug("New Operation CreateDisk with attrs : " . %args);
    $self->executor_component->enqueue(
        type     => 'CreateDisk',
        params   => {
            name                => $args{name},
            size                => $args{size},
            filesystem          => $args{filesystem},
            vg_id               => $args{vg_id},
            container_access_id => $args{container_access}->id,
            context             => {
                disk_manager => $self,
            }
        },
    );
}

sub getFreeSpace {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "container_access_id" ]);

    my $container_access = Entity::ContainerAccess->get(id => $args{container_access_id});

    return $container_access->getContainer->getAttr(name => 'container_freespace');
}

sub createExport {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "container", "export_name" ]);

    $log->debug("New Operation CreateExport with attrs : " . %args);
    $self->executor_component->enqueue(
        type     => 'CreateExport',
        params   => {
            context => {
                export_manager => $self,
                container      => $args{container},
            },
            manager_params => {
                export_name    => $args{export_name},
            },
        },
    );
}

sub getPuppetDefinition {
    my ($self, %args) = @_;

    return merge($self->SUPER::getPuppetDefinition(%args), {
        fileimagemanager => {
            classes => {
                'kanopya::fileimagemanager' => { }
            }
        }
    } );
}

1;
