# copyright © 2013 hedera technology sas
#
# this program is free software: you can redistribute it and/or modify
# it under the terms of the gnu affero general public license as
# published by the free software foundation, either version 3 of the
# license, or (at your option) any later version.
#
# this program is distributed in the hope that it will be useful,
# but without any warranty; without even the implied warranty of
# merchantability or fitness for a particular purpose.  see the
# gnu affero general public license for more details.
#
# you should have received a copy of the gnu affero general public license
# along with this program.  if not, see <http://www.gnu.org/licenses/>.

package Entity::ServiceProvider::Hpc7000;
use base 'Entity::ServiceProvider';

use Entity::ServiceProvider::Cluster;

use strict;
use warnings;

use constant ATTR_DEF => {
};

sub methods {
    return {
        synchronize => {
            description => 'synchronize Kanopya with the HP C7000 device.'
        }
    };
}

sub getAttrDef { return ATTR_DEF; }

sub synchronize {
    my $self = shift;

    my $kanopya = Entity::ServiceProvider::Cluster->getKanopyaCluster();

    $kanopya->service_provider->getManager(manager_type => 'ExecutionManager')->run(
        name   => 'Synchronize',
        params => {
            context => {
                entity => $self
            }
        }
    );
}

1;
