# Copyright © 2011-2012 Hedera Technology SAS
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

=pod
=begin classdoc

EHost is the execution class of host entities

=end classdoc
=cut

package EEntity::EHost;
use base "EEntity";

use strict;
use warnings;

use Entity;

use String::Random;
use Template;
use IO::Socket;

use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

sub getHostManager {
    my $self = shift;

    return EEntity->new(data => $self->SUPER::getHostManager);
}

sub start {
    my $self = shift;
    my %args = @_;

    # Do not known the list of params, it dpends of the type of host manager
    $self->getHostManager->startHost(host => $self, %args);

    $self->setState(state => 'starting');

    # Sommetimes a host can be promoted to another object type
    # So reload the object to be sure to have the good type.
    return $self->reload;
}

sub halt {
    my $self = shift;
    my %args = @_;

    $self->getHostManager->haltHost(host => $self);

    $self->setState(state => 'stopping');
}

sub stop {
    my $self = shift;
    my %args = @_;

    $self->getHostManager->stopHost(host => $self);
}

sub release {
    my $self = shift;
    my %args = @_;

    $self->getHostManager->releaseHost(host => $self);
}

sub postStart {
    my $self = shift;
    my %args = @_;

    $self->getHostManager->postStart(host => $self);
}

sub checkUp {
    my ($self, %args) = @_;

    return $self->getHostManager->checkUp(host => $self);
}

sub timeOuted {
    my $self = shift;

    $self->setState(state => 'broken');
}


=pod
=begin classdoc

Return the component to interrogate to get system informations

=end classdoc
=cut

sub getSystemComponent {
    my $self = shift;

    return EEntity->new(entity => $self->node->getComponent(category => "System"));
}


=pod
=begin classdoc

    Return the available memory amount.

=end classdoc
=cut

sub getAvailableMemory {
    my $self = shift;

    return $self->getSystemComponent->getAvailableMemory(host => $self);
}


=pod
=begin classdoc

    Return the total memory amount.

=end classdoc
=cut

sub getTotalMemory {
    my ($self, %args) = @_;

    return $self->getAvailableMemory()->{mem_total};
}


=pod
=begin classdoc

    Return the total cpu count.

=end classdoc
=cut

sub getTotalCpu {
    my $self = shift;

    return $self->getSystemComponent->getTotalCpu(host => $self);
}

sub getEContext {
    my $self = shift;

    return $self->SUPER::getEContext(dst_ip => $self->adminIp);
}

1;
