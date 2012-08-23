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

package EEntity::EConnector::ENetappVolumeManager;
use base "EEntity::EConnector";

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

=head2 createDisk

createDisk ( name, size, filesystem )
    desc: This function creates a new volume on NetApp.
    args:
        name : string : new volume name
        size : String : disk size finishing by unit (M : Mega, K : kilo, G : Giga)
        filesystem : String : filesystem type
    return:
        1 if an error occurred, 0 otherwise
    
=cut

sub createDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "name", "size", "filesystem", "aggregate_id" ]);

    my $aggregate = Entity->get(id => $args{aggregate_id});
    my $api = $self->_getEntity();
    $api->volume_create("containing-aggr-name" => $aggregate->getAttr(name => 'name'),
                        volume => "/" . $args{name},
                        size   => $args{size});

    delete $args{noformat};

    my $entity = Entity::Container::NetappVolume->new(
                     disk_manager_id      => $self->_getEntity->getAttr(name => 'entity_id'),
                     container_name       => $args{name},
                     container_size       => $args{size},
                     container_filesystem => $args{filesystem},
                     container_freespace  => $args{size},
                     container_device     => $args{name},
                     aggregate_id         => $args{aggregate_id}
                 );
    my $container = EFactory::newEEntity(data => $entity);

    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('removeDisk'),
            parameters => [ $self, "container", $container ]
        );
    }

    return $container;
}

=head2 removeDisk

=cut

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

    my $container_name = $args{container}->getAttr(name => 'container_name');

    $self->_getEntity()->volume_offline(name => $container_name);
    $self->_getEntity()->volume_destroy(name  => $container_name,
                                        force => "true");

    $args{container}->delete();

    #TODO: insert erollback ?
}

=head2 createExport

    Desc : This method allow to create a new export in 1 call

=cut

sub createExport {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args     => \%args,
                         required => [ 'container', 'export_name' ],
                         optional => { 'client_options' => 'rw,sync,no_root_squash' });

    my $manager_ip = $self->_getEntity->getServiceProvider->getMasterNodeIp;
    my $entity = Entity::ContainerAccess::NfsContainerAccess->new(
                     container_id            => $args{container}->getAttr(name => 'container_id'),
                     export_manager_id       => $self->_getEntity->getAttr(name => 'entity_id'),
                     container_access_export => $manager_ip . ':/vol/' . $args{export_name},
                     container_access_ip     => $manager_ip,
                     container_access_port   => 2049,
                     options                 => $args{client_options},
                 );
    my $container_access = EFactory::newEEntity(data => $entity);

    $log->info("Added NFS export for volume " . $args{container}->getAttr(name => "container_name"));

    if (exists $args{erollback}) {
        $args{erollback}->add(
            function   => $self->can('removeExport'),
            parameters => [ $self, "container_access", $container_access ]
        );
    }

    return $container_access;
}

=head2 removeExport

    Desc : This method allow to remove an export in 1 call

=cut

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

=head2 addExportClient

    Desc : Autorize client to access an export
    args:
        export : export to give access to
        host : host to authorize

=cut

sub addExportClient {
    my $self = shift;
    my %args = @_;

    my $host = $args{host};
    my $volume = $args{export}->getContainer;

    eval {
        $self->_getEntity()->nfs_exportfs_append_rules(
            persistent => [ "true" ],
            rules => {
                "exports-rule-info" => [ {
                    "pathname" => $volume->volumePath,
                    "nosuid" => "true",
                    "read-write" => {
                        "exports-hostname-info" => [ {
                            "name" => $host->getAdminIp
                        } ]
                    },
                    "root" => {
                        "exports-hostname-info" => [ {
                            "name" => $host->getAdminIp
                        } ]
                    }
                } ]
            }
        );
    }
}

1;
