#    Copyright © 2012 Hedera Technology SAS
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

package EEntity::EComponent::ENetappVolumeManager;
use base EEntity::EComponent;

use warnings;
use strict;

use General;
use Kanopya::Exceptions;
use Entity::Container::NetappVolume;
use Entity::ContainerAccess::NfsContainerAccess;

use Data::Dumper;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

sub createDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "name", "size", "filesystem", "aggregate_id" ]);

    my $aggregate = Entity->get(id => $args{aggregate_id});
    my $api = $self->_entity;
    $api->volume_create("containing-aggr-name" => $aggregate->getAttr(name => 'name'),
                        volume => "/" . $args{name},
                        size   => $args{size});

    delete $args{noformat};

    my $entity = Entity::Container::NetappVolume->new(
                     disk_manager_id      => $self->_entity->getAttr(name => 'entity_id'),
                     container_name       => $args{name},
                     container_size       => $args{size},
                     container_filesystem => $args{filesystem},
                     container_freespace  => $args{size},
                     container_device     => $args{name},
                     aggregate_id         => $args{aggregate_id}
                 );
    my $container = EEntity->new(data => $entity);

    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('removeDisk'),
            parameters => [ $self, "container", $container ]
        );
    }

    return $container;
}


sub removeDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "container" ]);

    if (! $args{container}->isa("EEntity::EContainer::ENetappVolume")) {
        throw Kanopya::Exception::Execution(
                  error => "Container must be a EEntity::EContainer::ENetappVolume, not " . 
                           ref($args{container})
              );
    }

    # Check if the disk is removable
    $self->SUPER::removeDisk(%args);

    my $container_name = $args{container}->getAttr(name => 'container_name');

    $self->_entity->volume_offline(name => $container_name);
    $self->_entity->volume_destroy(name  => $container_name,
                                        force => "true");

    $args{container}->delete();

    #TODO: insert erollback ?
}


sub createExport {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args     => \%args,
                         required => [ 'container', 'export_name' ],
                         optional => { 'client_options' => 'rw,sync,no_root_squash' });

    # Check if the disk is not already exported
    $self->SUPER::createExport(%args);

    my $manager_ip = $self->getMasterNode->adminIp;
    my $container_access = EEntity->new(entity => Entity::ContainerAccess::NfsContainerAccess->new(
                               container_id            => $args{container}->getAttr(name => 'container_id'),
                               export_manager_id       => $self->_entity->getAttr(name => 'entity_id'),
                               container_access_export => $manager_ip . ':/vol/' . $args{export_name},
                               container_access_ip     => $manager_ip,
                               container_access_port   => 2049,
                               options                 => $args{client_options},
                           ));

    $log->info("Added NFS export for volume " . $args{container}->getAttr(name => "container_name"));

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
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'container_access' ]);

    if (! $args{container_access}->isa("EEntity::EContainerAccess::ENfsContainerAccess")) {
        throw Kanopya::Exception::Internal::WrongType(
                  error => "ContainerAccess must be a EEntity::EContainerAccess::ENfsContainerAccess, not " . 
                           ref($args{container_access})
              );
    }

    $args{container_access}->delete();
}


sub addExportClient {
    my $self = shift;
    my %args = @_;

    my $host = $args{host};
    my $volume = $args{export}->getContainer;

    eval {
        $self->_entity->nfs_exportfs_append_rules(
            persistent => [ "true" ],
            rules => {
                "exports-rule-info" => [ {
                    "pathname" => $volume->volumePath,
                    "nosuid" => "true",
                    "read-write" => {
                        "exports-hostname-info" => [ {
                            "name" => $host->adminIp
                        } ]
                    },
                    "root" => {
                        "exports-hostname-info" => [ {
                            "name" => $host->adminIp
                        } ]
                    }
                } ]
            }
        );
    }
}

1;
