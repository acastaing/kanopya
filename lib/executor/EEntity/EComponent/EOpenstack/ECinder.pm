#    Copyright © 2013 Hedera Technology SAS
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

package EEntity::EComponent::EOpenstack::ECinder;
use base "EEntity::EComponent";
use base "EManager::EDiskManager";

use strict;
use warnings;

use EEntity;
use Entity::ContainerAccess::IscsiContainerAccess;

=head

=begin classdoc
Instruct a cinder instance to create a volume, then trigger the Cinder entity to register
it into Kanopya

@param name the volume name
@param size the volume size

@return a container object

=end classdoc

=cut

sub createDisk {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ "name", "size" ]); 

    my $e_controller = EEntity->new(entity => $self->nova_controller);
    my $api = $e_controller->api;

    my $req = $api->volume->volumes->post(
                  content => {
                      "volume" => {
                          "name"         => $args{name},
                          "size"         => $args{size} / 1024 / 1024 / 1024,
                          "display_name" => $args{name},
                      }
                  }
              );

    my $container = $self->lvcreate(
                        volume_id    => $req->{volume}->{id},
                        lvm2_lv_name => $args{name},
                        lvm2_lv_size => $args{size},
                    );

    return EEntity->new(entity => $container);
}

=head 2

=begin classdoc
Register a new iscsi container access into Kanopya

=end classdoc

=cut

sub createExport {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ "container" ] );

    my $id = join('-', (split('--', $args{container}->container_device))[-5..-1]);

    my $export = Entity::ContainerAccess::IscsiContainerAccess->new(
        container_id            => $args{container}->id,
        container_access_export => "iqn.2010-10.org.openstack:volume-" . $id,
        container_access_port   => 3260,
        container_access_ip     => $self->getMasterNode->adminIp,
        export_manager_id       => $self->id,
        typeio                  => "fileio",
        iomode                  => "wb",
        lun_name                => ""
    );

    return EEntity->new(entity => $export);
}

sub removeExport {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ "container_access" ] );

    $args{container_access}->remove();
}

sub addExportClient {
}

sub getLunId {
    return 1;
}

sub postStartNode {
    my ($self , %args) = @_;

    General::checkParams(args => \%args, required => [ 'cluster', 'host' ]);

    $DB::single = 1;
    my $e_controller = EEntity->new(entity => $self->nova_controller);
    my $api = $e_controller->api;

    my $req = $api->volume->types->post(
                  content => {
                      "volume_type" => {
                          "name" => "nfs",
                      }
                  }
              );

    my $type = $req->{volume_type}->{id};
    $api->volume->extra_specs->post(
        content => {
            "extra_specs" => {
                "volume_backend_name" => "Generic_NFS"
            }
        }
    );
}

1;
