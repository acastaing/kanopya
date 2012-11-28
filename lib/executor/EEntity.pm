# EEntity.pm - Entity is the highest general execution object

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
# Created 14 july 2010

=head1 NAME

EEntity - EEntity is the highest general execution object

=head1 SYNOPSIS



=head1 DESCRIPTION

EEntity is the highest general execution object

=head1 METHODS

=cut
package EEntity;

use strict;
use warnings;

use Entity;
use Kanopya::Exceptions;
use Kanopya::Config;
use File::Basename;
use Template;
use vars qw ( $AUTOLOAD );

use Log::Log4perl "get_logger";
use vars qw(@ISA $VERSION);

my $log = get_logger("");
my $errmsg;

$VERSION = do { my @r = (q$Revision: 0.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };


my $mocks_classes = {};

sub new {
    my ($class, %args) = @_;

    $args{entity} = $args{entity} || $args{data};

    General::checkParams(args => \%args, required => ['entity']);

    if ($args{entity}->isa('Entity') && !$args{entity}->isa('Entity::Operation')) {
        my $entityclass = ref($args{entity});
        $entityclass =~s/\:\:/\:\:E/g;
        $class = "E".$entityclass;
        
        # Use a possibly defined mock for this execution class
        $class = $mocks_classes->{$class} ? $class . '::' . $mocks_classes->{$class} : $class;

        while ($class ne "EEntity") {
            my $location = General::getLocFromClass(entityclass => $class);

            eval {
                require $location;
            };
            if ($@){
                # Try to use the parent package
                $class =~ s/\:\:[a-zA-Z0-9]+$//g;
            }
            else {
                last;
            }
        }
    }

    my $config = Kanopya::Config::get('executor');

    my $self = {
        _entity   => $args{entity},
        _executor => Entity->get(id => $config->{cluster}->{executor}),
        config    => $config
    };

    bless $self, $class;
    return $self;
}

sub _getEntity{
    my $self = shift;
    return $self->{_entity};
}

sub getEContext {
    my $self = shift;

    throw Kanopya::Exception::NotImplemented();
}

sub getExecutorEContext {
    my $self = shift;

    return EFactory::newEContext(ip_source      => $self->{_executor}->getMasterNodeIp(),
                                 ip_destination => $self->{_executor}->getMasterNodeIp());
}

sub generateNodeFile {
    my ($self, %args) = @_;
    General::checkParams(
        args     => \%args,
        required => ['cluster','host','file','template_dir','template_file','data']
    );
    
    my $config = Kanopya::Config::get('executor');
    my $econtext = $self->getExecutorEContext();
    my $path = $config->{clusters}->{directory};
    $path .= '/' . $args{cluster}->cluster_name;
    $path .= '/' . $args{host}->host_hostname;
    $path .= '/' . $args{file};
    my ($filename, $directories, $prefix) = fileparse($path);
    $econtext->execute(command => "mkdir -p $directories");
    
    my $template_conf = {
        INCLUDE_PATH => $args{template_dir},
        INTERPOLATE  => 0,               # expand "$var" in plain text
        POST_CHOMP   => 0,               # cleanup whitespace
        EVAL_PERL    => 1,               # evaluate Perl code blocks
        RELATIVE     => 1,               # desactive par defaut
    };

    my $template = Template->new($template_conf);
    eval {
        $template->process($args{template_file}, $args{data}, $path);
    };
    if($@) {
        $errmsg = "error during generation from '$args{template}':" .  $template->error;
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    }
    return $path;
}

sub setMock {
    my ($self, %args) = @_;
    my $class = ref($self) || $self;

    General::checkParams(args => \%args, optional => { 'mock' => undef });

    $mocks_classes->{$class} = $args{mock};
}

sub AUTOLOAD {
    my $self = shift;
    my %args = @_;

    my @autoload = split(/::/, $AUTOLOAD);
    my $method = $autoload[-1];

    return $self->_getEntity->$method(%args);
}

sub DESTROY {
    my $self = shift;
    my %args = @_;
}

1;
