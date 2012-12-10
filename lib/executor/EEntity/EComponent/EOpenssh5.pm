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
package EEntity::EComponent::EOpenssh5;

use strict;
use Template;
use String::Random;

use base "EEntity::EComponent";
use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

=pod

=begin classdoc

Check if host is up

=end classdoc

=end

=cut

sub isUp {
    my ($self,%args) = @_;

    General::checkParams(args => \%args, required => [ "host" ]);

    my $host = $args{host};

    eval {
        $host->getEContext->execute(command => "uptime");
    };
    if ($@) {
        $log->info('isUp() check for host <' . $host->adminIp . '>, host not sshable');
        return 0;
    }
}

1;
