# EDeployMasterimage.pm - Operation class implementing master image deployment 

#    Copyright 2011 Hedera Technology SAS
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
# Created 14 july 2010

=head1 NAME

EOperation::EDeployMasterimage - Operation class implementing master image deployment

=head1 SYNOPSIS


=head1 DESCRIPTION

parameters:
    file_path

=cut
package EEntity::EOperation::EDeployMasterimage;
use base "EEntity::EOperation";

use strict;
use warnings;

use Data::Dumper;
use XML::Simple;
use File::Temp qw/ tempdir /;
use File::Copy qw/ move /;
use File::Path qw/ mkpath /;
use Kanopya::Config;
use Kanopya::Exceptions;
use Entity::Masterimage;
use Entity::ServiceProvider::Inside::Cluster;
use Entity::Gp;
use EFactory;

use Log::Log4perl "get_logger";
my $log = get_logger("");

my $errmsg;
our $VERSION = '1.00';

=head2 prepare

=cut

sub prepare {
    my $self = shift;
    my %args = @_;
    $self->SUPER::prepare();

    General::checkParams(args => $self->{params}, required => [ "file_path" ]);

    # check file_path set
    my $file_path = $self->{params}->{file_path};

    if (not defined $file_path) {
        $errmsg = "Invalid operation argument ; $file_path not defined !";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }
    
    # check tarball existence
    if (! -e $file_path) {
        $errmsg = "Invalid operation argument ; $file_path not found !";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }

    # check tarball format
    if (`file $file_path` !~ /(bzip2|gzip) compressed data/) {
        $errmsg = "Invalid operation argument ; $file_path must be a gzip or bzip2 compressed file !";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }
    else {
        $self->{params}->{compress_type} = $1;
        $self->{params}->{file} = $file_path;
    }
}

sub execute {
    my $self = shift;
    my ($cmd, $cmd_res);

    # Untar master image archive in a temporary folder
    my $tmpdir = tempdir(CLEANUP => 1);
    $log->debug("Unpack archive files from archive '$self->{params}->{file}' into $tmpdir");
    my $compress = $self->{params}->{compress_type} eq 'bzip2' ? 'j' : 'z';
    $cmd = "tar -x -$compress -f $self->{params}->{file} -C $tmpdir"; 
    $cmd_res = $self->getEContext->execute(command => $cmd);

    # check metadata file exists
    my $metadatafile = "$tmpdir/img-metadata.xml";
    if(! -e $metadatafile) {
        $errmsg = "File missing in archive ; $metadatafile";
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }
    
    # parse and validate metadata file
    # TODO check metadata format and values
    my $metadata = XMLin($metadatafile, ForceArray => [ "kernel", "component" ]); # , ForceArray => 'name');
    my $imagefile = $metadata->{file};
    
    # retrieve master images directory
    $log->debug(Dumper $metadata);
    my $directory = $self->{config}->{masterimages}->{directory};
    $directory =~ s/\/$//g;
    
    # get the image size
    $cmd = "du -s --bytes $tmpdir/$imagefile | awk '{print \$1}'";
    $cmd_res = $self->getEContext->execute(command => $cmd);
    my $image_size = $cmd_res->{stdout};  
    
    # create the directory for the image
    mkpath("$directory/$imagefile");
    
    # move image and metadata to the directory
    move("$tmpdir/$imagefile", "$directory/$imagefile");

    # register the available kernels
    my $defaultkernel;
    if (defined $metadata->{kernel}) {
        while (my ($name, $infos) = each(%{$metadata->{kernel}})) {
            my $kernel;
            eval {
                $kernel = Entity::Kernel->find(hash => { kernel_name => $name });
            };
            if ($@) {
                # move image and metadata to the directory
                my $tftpdir = Kanopya::Config::get('executor')->{tftp}->{directory};
                move("$tmpdir/" . $infos->{file}, $tftpdir);

                $kernel = Entity::Kernel->new(
                    kernel_name    => $name,
                    kernel_version => $infos->{version},
                    kernel_desc    => $infos->{description}
                );
            }

            if ($infos->{default}) {
                $defaultkernel = $kernel->id;
            }
        }
    }

    # delete uploaded archive
    if (! $self->{params}->{keep_file}) {
        unlink $self->{params}->{file};
    }

    my $args = {
        masterimage_name => $metadata->{name},
        masterimage_file => "$directory/$imagefile/$imagefile",
        masterimage_desc => $metadata->{description},
        masterimage_os   => $metadata->{os},
        masterimage_size => $image_size,
        masterimage_defaultkernel_id => $defaultkernel
    };
    
    my $masterimage = Entity::Masterimage->new(%$args);
    
    # set components
    foreach my $name (keys %{$metadata->{component}}) {
        my $vers = $metadata->{component}->{$name}->{version};
        $log->debug("component to set : $name, $vers");
        $masterimage->setProvidedComponent(
            component_name    => $name,
            component_version => $vers
        );
    }
}        

=head1 DIAGNOSTICS

Exceptions are thrown when mandatory arguments are missing.
Exception : Kanopya::Exception::Internal::IncorrectParam

=head1 CONFIGURATION AND ENVIRONMENT

This module need to be used into Kanopya environment. (see Kanopya presentation)
This module is a part of Administrator package so refers to Administrator configuration

=head1 DEPENDENCIES

This module depends of 

=over

=item KanopyaException module used to throw exceptions managed by handling programs

=item Entity::Component module which is its mother class implementing global component method

=back

=head1 INCOMPATIBILITIES

None

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to <Maintainer name(s)> (<contact address>)

Patches are welcome.

=head1 AUTHOR

<HederaTech Dev Team> (<dev@hederatech.com>)

=head1 LICENCE AND COPYRIGHT

Kanopya Copyright (C) 2009, 2010, 2011, 2012, 2013 Hedera Technology.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; see the file COPYING.  If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301 USA.

=cut

1;
