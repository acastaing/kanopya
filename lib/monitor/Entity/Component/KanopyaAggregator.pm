# Copyright © 2013 Hedera Technology SAS
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

package Entity::Component::KanopyaAggregator;
use base Entity::Component;
use base MessageQueuing::RabbitMQ::Sender;

use strict;
use warnings;

use Kanopya::Exceptions;

use Log::Log4perl "get_logger";
use Data::Dumper;

my $log = get_logger("");

use constant ATTR_DEF => {
    control_queue => {
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 0,
        is_editable  => 1
    },
    time_step => {
        label        => 'Aggregation frequency',
        #type         => 'time',
        type         => 'integer',
        pattern      => '^\d+$',
        default      => 300,
        is_mandatory => 1,
        is_editable  => 1
    },
    storage_duration => {
        label        => 'Data storage duration',
        #type         => 'time',
        type         => 'integer',
        pattern      => '^\d+$',
        default      => 604800,
        is_mandatory => 1,
        is_editable  => 1
    },
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        addNodeMetric => {
            description => 'Produce a node metric.',
            message_queuing => {
                queue => 'kanopya.aggregator.node_metric'
            }
        },
        addClusterMetric => {
            description => 'Produce a node metric.',
            message_queuing => {
                queue => 'kanopya.aggregator.cluster_metric'
            }
        },
    };
}

1;
