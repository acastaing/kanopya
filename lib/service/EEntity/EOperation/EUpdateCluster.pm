#    Copyright © 2011-2013 Hedera Technology SAS
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

package EEntity::EOperation::EUpdateCluster;
use base "EEntity::EOperation";

use Kanopya::Exceptions;
use strict;
use warnings;
use EEntity;

use Log::Log4perl 'get_logger';

my $log = get_logger("");
my $errmsg;

sub execute {
    my ($self, %args) = @_;

    # check if this cluster has a puppet agent component
    my $puppetagent;
    eval {
        $puppetagent = $self->{context}->{cluster}->getComponent(category => 'Configurationagent');
    };
    if ($@) {
        my $errmsg = "UpdateCluster Operation cannot be used without a puppet " .
                     "agent component configured on the cluster : " . $@;
        $log->error($errmsg);
        throw Kanopya::Exception::Internal(error => $errmsg);
    } else {
        $self->{context}->{puppetagent} = EEntity->new(
            data => $puppetagent
        );

        my @nodes = map { $_->node } @{ $self->{context}->{cluster}->getHosts() };
        $self->{context}->{puppetagent}->applyConfiguration(nodes => \@nodes);
    }
}

sub postrequisites {
    my ($self, %args) = @_;
    my $delay = 10;

    my @hosts;
    if ($self->{context}->{host}) {
        $log->info("Checking component on host " . $self->{context}->{host} . " only");
        push @hosts, $self->{context}->{host};
    }
    else {
        @hosts = map { EEntity->new(entity => $_->host) } $self->{context}->{cluster}->nodes;
    }

    # Check if all host components are up.
    for my $host (@hosts) {
        if (not $host->node->checkComponents()) {
            throw Kanopya::Exception::Internal("Failed to update " . $host->node->label);
        }

        $self->{context}->{cluster}->postStartNode(host      => $host,
                                                   erollback => $self->{erollback});
    }
}

1;
