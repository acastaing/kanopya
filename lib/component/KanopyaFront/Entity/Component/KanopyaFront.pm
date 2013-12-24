# Copyright © 2012 Hedera Technology SAS
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package Entity::Component::KanopyaFront;
use base "Entity::Component";

use strict;
use warnings;

use Kanopya::Database;
use Kanopya::Exceptions;

use Hash::Merge qw(merge);

use Log::Log4perl "get_logger";
my $log = get_logger("");

use constant ATTR_DEF => {};

sub getAttrDef { return ATTR_DEF; }

sub methods {}

sub getNetConf {
    return {
        kanopyafront => {
            port => 5000,
            protocols => ['tcp']
        }
    };
}

sub getPuppetDefinition {
    my ($self, %args) = @_;

    my $config = Kanopya::Config::get('libkanopya');
    my $dbconfig = Kanopya::Database::_adm->{config};

    return merge($self->SUPER::getPuppetDefinition(%args), {
        kanopyafront => {
            classes => {
                "kanopya::common" => {
                    %{$dbconfig}
                },
                "kanopya::front" => {
                    amqpuser => $config->{amqp}->{user},
                    amqppassword => $config->{amqp}->{password},
                    logdir => $config->{logdir}
                }
            },
            dependencies => [ $self->service_provider->getComponent(name => "Amqp"),
                              $self->service_provider->getComponent(name => "Mysql") ]
        }
    } );
}

1;
