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

package EEntity::EComponent::EVmm;
use base 'EEntity::EComponent';

use strict;
use warnings;
use Data::Dumper;
use Log::Log4perl "get_logger";
use General;

my $log = get_logger("");
my $errmsg;

sub postStartNode {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'node' ]);

    $self->iaas->registerHypervisor(host => $args{node}->host);
}

sub stopNode {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    $self->iaas->unregisterHypervisor(host => $args{host});
}

sub iaas {
    my ($self, %args) = @_;

    return EEntity->new(data => $self->getAttr(name => "iaas", deep => 1));
}

1;
