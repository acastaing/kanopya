#    Copyright © 2014 Hedera Technology SAS
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

=pod
=begin classdoc

Implement Openstack API Compute operations related to servers (virtual machines)
http://docs.openstack.org/api/openstack-compute/2/content/compute_servers.html

=end classdoc
=cut

package OpenStack::Volume;

use strict;
use warnings;

use General;
use OpenStack::Flavor;

=pod
=begin classdoc

Lists all available volumes (i.e. vms)

=end classdoc
=cut

sub list {
    my ($class, %args) = @_;
    General::checkParams(args => \%args, required => [ 'api' ], optional => {all_tenants => 0});

    if ($args{all_tenants} eq 1) {
        my $option = 'volumes?all_tenants=True';
        return $args{api}->volume->$option->get->{volumes};
    }

    return $args{api}->volume->volumes->detail->get->{volumes};
}

sub detail {
    my ($class, %args) = @_;
    General::checkParams(args => \%args, required => [ 'api' , 'id' ]);

    return $args{api}->volume->volumes(id => $args{id})->get->{volume};
}

sub create {
    my ($class, %args) = @_;

    General::checkParams(args => \%args,
                         required => [ 'api', 'image_id' ],
                         optional => { size => 5, display_name => undef, volume_type => undef } );

    my $params = {
        volume => {
            imageRef => $args{image_id},
            size => $args{size},
            display_name => $args{display_name},
            # availability_zone => undef,
            # display_description => undef,
            # snapshot_id => undef,
        }
    };

    if (defined $args{volume_type}) {
        $params->{volume}->{volume_type} = $args{volume_type};
    }

    return $args{api}->volume->volumes->post(content => $params);
}


sub delete {
    my ($class, %args) = @_;
    General::checkParams(args => \%args, required => [ 'api' , 'id' ]);

    return $args{api}->volume->volumes(id => $args{id})->delete;
}
1;