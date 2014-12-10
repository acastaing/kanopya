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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package Entity::Component::Apache2;
use base "Entity::Component";

use strict;
use warnings;

use Kanopya::Exceptions;
use Apache2Virtualhost;

use Hash::Merge qw(merge);
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

use constant ATTR_DEF => {
    apache2_loglevel => { 
        label        => 'Log level',
        type         => 'enum',
        options      => ['debug','info','notice','warn','error','crit',
                         'alert','emerg'], 
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
        description  => 'It is log level of your apache server.'.
                        ' It could be debug, info, notive, warn, error, critical, alert or emergency',
    },
    apache2_serverroot => { 
        label        => 'Server root',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
        description  => 'it is the root directory of the web server',
    },
    apache2_ports => { 
        label        => 'HTTP Port',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1,
        description  => 'It is the HTTP port used by apache. It will be used by'.
                        ' the load balancer to dispatch request between the different nodes',
    },
    apache2_sslports => { 
        label        => 'SSL Port',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 0,
        is_editable  => 1,
        description  => 'It is the https port used by apache. It will be used by the load '.
                        'balancer to dispatch request between the different nodes',
    },
    apache2_virtualhosts => {
        label       => 'Virtual hosts',
        type        => 'relation',
        relation    => 'single_multi',
        is_editable => 1,
        description  => 'It is the list of virtualhost managed by this web server',
    },
};

sub getAttrDef { return ATTR_DEF; }

sub priority {
    return 40;
}

sub getBaseConfiguration {
    return {
        apache2_loglevel   => 'debug',
        apache2_serverroot => '/srv',
        apache2_ports      => 80,
        apache2_sslports   => 443,
    };
}

sub insertDefaultExtendedConfiguration {
    my $self = shift;

    Apache2Virtualhost->new(
        apache2_id                       => $self->id,
        apache2_virtualhost_servername   => 'www.yourservername.com',
        apache2_virtualhost_sslenable    => 'no',
        apache2_virtualhost_serveradmin  => 'admin@mycluster.com',
        apache2_virtualhost_documentroot => '/srv',
        apache2_virtualhost_log          => 'vhost_access.log',
        apache2_virtualhost_errorlog     => 'vhost_error.log',
    );
}

sub getNetConf {
    my $self = shift;

    my $http_port = $self->apache2_ports;
    my $https_port = $self->apache2_sslports;

    my $net_conf = {
        http => {
            port => $http_port,
            protocols => ['tcp']
        }
    };

    # manage ssl
    my @virtualhosts = $self->apache2_virtualhosts;
    my $ssl_enable
        = grep { defined($_->{apache2_virtualhost_sslenable}) && $_->{apache2_virtualhost_sslenable} == 1 }
              @virtualhosts;

    $net_conf->{https} = {
        port => $https_port,
        protocols => ['tcp', 'ssl']
    } if ($ssl_enable);

    return $net_conf;
}

sub getPuppetDefinition {
    my ($self, %args) = @_;

    my $vhosts = {};
    for my $vhost ($self->apache2_virtualhosts) {
        $vhosts->{$vhost->apache2_virtualhost_servername} = {
            vhost_name => $vhost->apache2_virtualhost_servername,
            docroot => $vhost->apache2_virtualhost_documentroot,
            serveradmin => $vhost->apache2_virtualhost_serveradmin,
            access_log_file => $vhost->apache2_virtualhost_log,
            error_log_file => $vhost->apache2_virtualhost_errorlog
        };
    }

    return merge($self->SUPER::getPuppetDefinition(%args), {
        apache => {
            classes => {
                'kanopya::apache' => {
                    vhosts => $vhosts
                }
            }
        }
    } );
}

1;
