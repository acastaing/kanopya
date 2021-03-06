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
package EEntity::EComponent::EPhp5;
use base 'EEntity::EComponent';

use strict;
use warnings;
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

# generate configuration files on node
sub configureNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'host','mount_point' ]);

    # Generation of php.ini
    my $conf = $self->getConf();
    my $data = { session_handler => $conf->{php5_session_handler},
                 session_path    => $conf->{php5_session_path} };

    # This handler needs specific configuration (depending on master node)
    if ( $data->{session_handler} eq "memcache" ) {
        # current node is the master node
        my $masternodeip = $self->getMasterNode ? $self->getMasterNode->adminIp : $args{host}->adminIp;

        # default port of memcached TODO: retrieve memcached port using component
        my $port = '11211';
        $data->{session_path} = "tcp://$masternodeip:$port";
    }
    
    my $file = $self->generateNodeFile(
        host          => $args{host},
        file          => '/etc/php5/apache2/php.ini',
        template_dir  => 'components/php5',
        template_file => 'php.ini.tt',
        data          => $data,
        mount_point   => $args{mount_point}
    );
}


1;
