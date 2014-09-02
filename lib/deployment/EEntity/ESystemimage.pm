#    Copyright © 2010-2012 Hedera Technology SAS
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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

=pod
=begin classdoc

Excecution class for Systemimage. Here are implemented methods related to
system image creation involving disks creation, disks copies and exports creation.

@since    2011-Oct-15
@instance hash
@self     $self

=end classdoc
=cut

package EEntity::ESystemimage;
use base "EEntity";

use strict;
use warnings;

use General;
use EEntity;
use Entity::Container::LocalContainer;

use TryCatch;
use Data::Dumper;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;


=pod
=begin classdoc

Export the system image with the export manager given in paramaters.

@param export_manager the export manager to use for exporting the system image container
@param manager_params the parameters to give to the export manager for disk export

@optional erollback the erollback object

=end classdoc
=cut

sub activate {
    my $self = shift;

    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "container_accesses" ],
                         optional => { "erollback" => undef });

    # TODO: Check if the container of each container accesses is the same.

    # Link the systemimage with its accesses
    $self->update(systemimage_container_accesses => $args{container_accesses});

    # Set system image active
    $self->active(1);

    $log->info("System image <" . $self->systemimage_name . "> is now active");
}


=pod
=begin classdoc

Remove all export of the system image container.

@optional erollback the erollback object

=end classdoc
=cut

sub deactivate {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, optional => { "erollback" => undef });

    # Get instances of container accesses from systemimages root container
    $log->info("Remove all container accesses");
    try {
        for my $container_access (map { EEntity->new(data => $_) } $self->container_accesses) {
            my $export_manager = EEntity->new(data => $container_access->export_manager);

            $export_manager->removeExport(container_access => $container_access,
                                          erollback        => $args{erollback});
        }
    }
    catch ($err) {
        throw Kanopya::Exception::Internal::WrongValue(error => $err);
    }

    # Set system image active in db
    $self->active(0);

    $log->info("System image <" . $self->systemimage_name . "> is now unactive");
}


=pod
=begin classdoc

Remove the system image, also deactivate it if active.

@optional erollback the erollback object

=end classdoc
=cut

sub remove {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, optional => { "erollback" => undef });

    # Get the container before removing the container_access
    my $container;
    try {
       $container = EEntity->new(data => $self->getContainer);
    }
    catch (Kanopya::Exception::Internal::NotFound $err) {
        # No export found for this system image
        # TODO: is a container for this system image still exists ?
    }
    catch ($err) {
        $err->rethrow();
    }

    if ($self->active) {
        $self->deactivate(erollback => $args{erollback});
    }

    if (defined $container) {
        try {
            # Remove system image container.
            $log->info("Systemimage container deletion");

            # Get the disk manager of the current container
            my $disk_manager = EEntity->new(data => $container->getDiskManager);
            $disk_manager->removeDisk(container => $container);
        }
        catch ($err) {
            $log->warn("Unable to remove container while removing system image:\n$err");
        }
    }

    $self->delete();
}

1;
