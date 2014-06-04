# TimeDataDB.pm - Object class of Monitor

#    Copyright  © 2011 Hedera Technology SAS
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
# Created 03/02/2012

package TimeData;

use strict;
use warnings;
use General;
use TimeData::RRDTimeData;

sub new {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, required => [ 'store' ]);

    if ($args{store} eq 'rrd') {
        return TimeData::RRDTimeData->new();
    }

    throw Kanopya::Exception::Internal::WrongValue(
              error => 'Unknown value <' . $args{store} . '> stored in param preset'
          );
}

sub createTimeDataStore;
sub deleteTimeDataStore;
sub fetchTimeDataStore;
sub updateTimeDataStore;
sub getLastUpdatedValue;
1;
