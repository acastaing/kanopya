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

=pod
=begin classdoc

TODO

=end classdoc
=cut

package EEntity::EHost::EHypervisor;
use base "EEntity::EHost";

use strict;
use warnings;

use EEntity;

use Log::Log4perl "get_logger";

my $log = get_logger("");

sub vmm {
    my $self = shift;

    return EEntity->new(entity => $self->node->getMasterNode->getComponent(category => "Hypervisor"));
}


=pod
=begin classdoc

Return the available memory amount.

@return available memory amount

=end classdoc
=cut

sub getAvailableMemory {
    my ($self, %args) = @_;

    return $self->vmm->getAvailableMemory(host => $self,
                                          %args);
}


=pod
=begin classdoc

Return virtual machines resources. If no resssource type(s)
specified in parameters, return all know ressouces.

@return resources

=end classdoc
=cut


sub getVmResources {
    my ($self, %args) = @_;
    return $self->vmm->getVmResources(host => $self, %args);
}

=pod
=begin classdoc

    Update the CPU pinning of the hypervisor

=end classdoc
=cut


sub updatePinning {
    my ($self, %args) = @_;

    return $self->vmm->updatePinning(host => $self,
                                     %args);
}

sub getMinEffectiveRamVm {
    my ($self, %args) = @_;

    return $self->vmm->getMinEffectiveRamVm(host => $self,
                                            %args);
}

=pod

=begin classdoc

prompt an Openstack host for ram used by a given vm

@param $host the desired vm

@return ram used by vm

=end classdoc

=cut

sub getRamUsedByVm {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    return $self->vmm->getRamUsedByVm(
        host       => $args{host},
        hypervisor => $self
    );
}
            
1;
