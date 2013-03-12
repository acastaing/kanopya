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
package EEntity::EComponent::EPuppetmaster2;
use base 'EEntity::EComponent';

use strict;
use warnings;

use Template;
use File::Path qw/ mkpath /;
use File::Temp qw/ tempdir /;
use Log::Log4perl 'get_logger';

my $log = get_logger("");
my $errmsg;

# generate configuration files on node

sub configureNode {
    my ($self, %args) = @_;
    my $data;

    my $conf = $self->_getEntity()->getConf();

    # Generation of /etc/default/puppetmaster
    $data = { 
        puppetmaster2_options   => $conf->{puppetmaster2_options},
    };
    
    $self->generateFile( 
        mount_point  => $args{mount_point},
        template_dir => "/templates/components/puppetmaster",
        input_file   => "default_puppetmaster.tt", 
        output       => "/default/puppetmaster", 
        data         => $data
    );
}

sub addNode {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'mount_point', 'host' ]);
  
    $self->configureNode(
        mount_point => $args{mount_point}.'/etc',
        host        => $args{host}
    );

    $self->addInitScripts(    
        mountpoint => $args{mount_point}, 
        scriptname => 'puppet', 
    );
    
}

sub updateSite {
    my ($self) = @_;
    my $command = 'touch /etc/puppet/manifests/site.pp';
    $self->getEContext->execute(command => $command);
}

sub createHostCertificate {
    my ($self, %args) = @_;
 
    General::checkParams(args => \%args, required => [ 'mount_point', 'host_fqdn' ]);
    
    my $certificate = $args{host_fqdn} . '.pem';

    # check if new certificate is required
    my $command = "find /etc/puppet/ssl/certs -name $certificate";
    my $result = $self->getEContext->execute(command => $command);

    if (! $result->{stdout}) {
        # generate a certificate for the host
        $command = "puppetca --generate $args{host_fqdn}";
        my $result = $self->getEContext->execute(command => $command);
        # TODO check for error in command execution
    }

    # clean existing certificates information
    $command = 'rm -rf ' . $args{mount_point} . '/var/lib/puppet/ssl/*';
    $self->getEContext->execute(command => $command);    

    my $tmpdir = tempdir(CLEANUP => 1);
    mkpath($tmpdir . "/ssl/certs");
    mkpath($tmpdir . "/ssl/private_keys");

    # We do not use 'mkdir' because of a strange guestmount bug that forbids us
    # to create a folder in the puppet folder if it's owner by the 'puppet' user
    $self->getEContext->send(
        src  => $tmpdir . "/ssl",
        dest => $args{mount_point} . '/var/lib/puppet/'
    );

    # copy master certificate to the image
    $self->getEContext->send(
        src  => '/var/lib/puppet/ssl/certs/ca.pem',
        dest => $args{mount_point} . '/var/lib/puppet/ssl/certs/ca.pem'
    );
    
    # copy host certificate to the image
    $self->getEContext->send(
        src  => '/var/lib/puppet/ssl/certs/' . $certificate,
        dest => $args{mount_point} . '/var/lib/puppet/ssl/certs/' . $certificate
    );
    
    # copy host private key to the image
    $self->getEContext->send(
        src  => '/var/lib/puppet/ssl/private_keys/' . $certificate,
        dest => $args{mount_point} . '/var/lib/puppet/ssl/private_keys/' . $certificate
    );

    $self->updateSite;
}

sub createHostManifest {
    my ($self, %args) = @_;
    General::checkParams(args => \%args, required => [ 'puppet_definitions', 'host_fqdn' ]);

    my $config = {
        INCLUDE_PATH => '/templates/components/puppetmaster',
        INTERPOLATE  => 0,               # expand "$var" in plain text
        POST_CHOMP   => 0,               # cleanup whitespace
        EVAL_PERL    => 1,               # evaluate Perl code blocks
        RELATIVE => 1,                   # desactive par defaut
    };

    my $input = 'host_manifest.pp.tt';
    my $output = '/etc/puppet/manifests/nodes/';
    $output .= $args{host_fqdn}.'.pp';

    my $data = {
        host_fqdn          => $args{host_fqdn},
        puppet_definitions => $args{puppet_definitions}
    };

    my $template = Template->new($config);
    $template->process($input, $data, $output) || do {
        $errmsg = "error during generation from '$input':" .  $template->error;
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    };
    
    $self->updateSite;
}

1;
