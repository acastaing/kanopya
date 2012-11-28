#    NetappManager.pm - NetApp connector
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

package Entity::Connector::NetappLunManager;
use base 'Entity::Connector::NetappManager';
use base "Manager::ExportManager";
use base "Manager::DiskManager";

use warnings;
use strict;

use Manager::HostManager;
use Entity::Operation;
use Entity::Container::NetappLun;
use Entity::Container::NetappVolume;
use Entity::ContainerAccess::IscsiContainerAccess;

use General;
use Data::Dumper;
use Log::Log4perl "get_logger";

my $log = get_logger("");

use constant ATTR_DEF => {
    disk_type => {
        is_virtual => 1
    },
    export_type => {
        is_virtual => 1
    }
};

sub getAttrDef { return ATTR_DEF; }

sub exportType {
    return "ISCSI target";
}

sub diskType {
    return "NetApp lun";
}

=head2 checkDiskManagerParams

=cut

sub checkDiskManagerParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "volume_id", "systemimage_size" ]);
}

=head2 getPolicyParams

=cut

sub getPolicyParams {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'policy_type' ]);

    my $volumes = {};
    if ($args{policy_type} eq 'storage') {
        for my $aggr (@{ $self->getConf->{aggregates} }) {
            for my $volume (@{ $aggr->{aggregates_volumes} }) {
                $volumes->{$volume->{volume_id}} = '(' . $aggr->{aggregate_name} . ') ' . $volume->{volume_name};
            }
        }
        return [ { name => 'volume_id', label => 'Volume to use', values => $volumes } ];
    }
    return [];
}

sub getExportManagerFromBootPolicy {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ "boot_policy" ]);

    if ($args{boot_policy} eq Manager::HostManager->BOOT_POLICIES->{pxe_iscsi}) {
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

    my $cluster = Entity::ServiceProvider->get(id => $self->getAttr(name => 'service_provider_id'));

    if ($args{export_manager}->getId == $self->getId) {
        return Manager::HostManager->BOOT_POLICIES->{pxe_iscsi};
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
    
    my $value;
    if ($args{readonly}) { $value = 'ro'; }
    else                 { $value = 'wb'; }
    return { 
        name  => 'iomode',
        value => $value,
    }
}

=head2 createDisk

    Desc : Implement createDisk from DiskManager interface.
           This function enqueue a ECreateDisk operation.
    args :

=cut

sub createDisk {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "volume_id", "disk_name", "size", "filesystem" ]);

    $log->debug("New Operation CreateDisk with attrs : " . %args);
    Entity::Operation->enqueue(
        priority => 200,
        type     => 'CreateDisk',
        params   => {
            name       => $args{disk_name},
            size       => $args{size},
            filesystem => $args{filesystem},
            noformat   => defined $args{noformat} ? $args{noformat} : 0,
            volume_id  => $args{volume_id},
            context    => {
                disk_manager => $self,
            }
        },
    );
}

=head2 createExport

    Desc : Implement createExport from ExportManager interface.
           This function enqueue a ECreateExport operation.
    args : export_name, device, typeio, iomode

=cut

sub createExport {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "container", "export_name", "typeio", "iomode" ]);

    $log->debug("New Operation CreateExport with attrs : " . %args);
    Entity::Operation->enqueue(
        priority => 200,
        type     => 'CreateExport',
        params   => {
            context => {
                export_manager => $self,
                container      => $args{container},
            },
            manager_params => {
                export_name  => $args{export_name},
                typeio       => $args{typeio},
                iomode       => $args{iomode}
            },
        },
    );
}

=head2 synchronize 

    Desc: synchronize netapp lun information with kanopya database

=cut

sub synchronize {
    my $self = shift;
    my %args = @_;

    # Get list of luns exists on NetApp
    foreach my $lun ($self->luns) {
        my @array_lun_volume_name = split(/\//, $lun->path);
        my $lun_volume_name = $array_lun_volume_name[2];
        my $lun_name = $array_lun_volume_name[3];

        # Search in database if the volume is stored
        my $lun_volume_obj = Entity::Container->find( hash => { container_name => $lun_volume_name });
        my $lun_volume_id = $lun_volume_obj->getAttr(name => "volume_id");

        # Is the LUN already in database :
        my $existing_luns = Entity::Container->search(hash => { container_name => $lun->name });
        my $existing_lun = scalar($existing_luns);
        if ($existing_lun eq "0") {
            Entity::Container::NetappLun->new(
                disk_manager_id      => $self->getAttr(name => 'entity_id'),
                container_name       => $lun_name,
                container_size       => $lun->size_used,
                container_filesystem => "ext3",
                container_freespace  => 0,
                container_device     => $lun_name,
                volume_id            => $lun_volume_id,
            );
        }
    }
}


=head2 getConf 

    Desc: return hash structure containing luns
    
    Return: Scalar $config
    
    Info: ReWrited on April 20 2012 by jlevasseur

=cut

sub getConf {
    my ($self) = @_;
    my $config = {};
    $config->{aggregates} = [];
    $config->{volumes} = [];
    $config->{luns} = [];
    my @aggr_object = $self->aggregates;
    my @vol_object = $self->volumes;
    my @lun_object = $self->luns;
    my @luns = Entity::Container::NetappLun->search(hash => {});
    my $aggregates = [];
    my $volumes = [];
    my $lun = [];
    
    # run through each aggr on xml/rpc fill and get comment from db
    foreach my $aggr (@aggr_object) {
        # get the identical info shared by aggr object and database :
        my $aggr_key = $aggr->name;
        my $aggr_id = Entity::NetappAggregate->find( hash => { name => $aggr_key } )->getAttr(name => 'aggregate_id');
        my $entity_id = Entity->find( hash => { entity_id => $aggr_id })->getAttr(name => 'entity_comment_id');
        my $tmp = {
            aggregate_id        => $aggr_id,
            aggregate_name      => $aggr->name,
            aggregate_state     => $aggr->state,
            aggregate_totalsize => General::bytesToHuman(value => $aggr->size_total, precision => 5),
            aggregate_sizeused  => General::bytesToHuman(value => $aggr->size_used, precision => 5),
            aggregate_volumes   => [],
            entity_comment      => "",
        };
        # run through each vol on xml/rpc fill and get comment from db
        foreach my $volume (@vol_object) {
            my $vol_key = $volume->name;
            my $volume_id = Entity::Container->find( hash => { container_name => $vol_key } )->getAttr(name => 'container_id');
            my $entity_id = Entity->find( hash => { entity_id => $volume_id })->getAttr(name => 'entity_comment_id');
                my $tmp2 = {
                    volume_id       => $volume_id,
                    volume_name      => $vol_key,
                    volume_state     => $volume->state,
                    volume_totalsize => General::bytesToHuman(value => $volume->size_total, precision => 5),
                    volume_sizeused  => General::bytesToHuman(value => $volume->size_used, precision => 5),
                    volume_luns      => [],
                    entity_comment   => "",
                };
                foreach my $lun (@lun_object) {
                    my $name = $vol_key;
                    my $lun_id = Entity::Container->find( hash => { container_name => $name } )->getAttr(name => 'container_id');
                    my $entity_id = Entity->find( hash => { entity_id => $lun_id })->getAttr(name => 'entity_comment_id');
                    if($lun->path =~ /$name/) {
                        my $tmp3 = {
                            lun_id          => $lun_id,
                            lun_path        => $lun->path,
                            lun_state       => $lun->state,
                            lun_totalsize   => General::bytesToHuman(value => $lun->size, precision => 5),
                            lun_sizeused    => General::bytesToHuman(value => $lun->size_used, precision => 5),
                            entity_comment   => "",
                        };
                        push @{$tmp2->{volume_luns}}, $tmp3;
                    }
                }    
                push @{$tmp->{aggregates_volumes}}, $tmp2;
            #}    
        }
        push @$aggregates, $tmp;
    }
    # Must be remove :
    #$log->info(Dumper($aggregates));
    return {
            "aggregates"=>$aggregates,
    };
    return $config;
}

1;
