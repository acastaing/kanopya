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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.


=pod
=begin classdoc

Execution class for iscsi container access entities.

=end classdoc
=cut

package EEntity::EContainerAccess::EIscsiContainerAccess;
use base "EEntity::EContainerAccess";

use strict;
use warnings;

use Log::Log4perl "get_logger";

my $log = get_logger("");


=pod
=begin classdoc

Creating open-iscsi node, and wait for the device appeared.

=end classdoc
=cut

sub connect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $target = $self->getAttr(name => 'container_access_export');
    my $ip     = $self->getAttr(name => 'container_access_ip');
    my $port   = $self->getAttr(name => 'container_access_port');
    my $lun    = $self->getLunId();

    $log->debug("Creating open iscsi node <$target> from <$ip:$port>.");

    my $result;
    my $create_node_cmd = "iscsiadm -m node -T $target -p $ip:$port -o new";
    $result = $args{econtext}->execute(command => $create_node_cmd);

    if ($result->{exitcode} != 0) {
        my $logger = get_logger("command");
        $logger->error($result->{stderr});
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }

    $log->debug("Logging in node <$target> (<$ip:$port>).");

    my $login_node_cmd = "iscsiadm -m node -T $target -p $ip:$port -l";
    $result = $args{econtext}->execute(command => $login_node_cmd);

     if($result->{exitcode} != 0) {
        my $logger = get_logger("command");
        $logger->error($result->{stderr});
        throw Kanopya::Exception::Execution(error => $result->{stderr});
    }

    my $device = '/dev/disk/by-path/ip-' . $ip . ':' . $port . '-iscsi-' . $target . '-lun-' . $lun;

    my $retry = 20;
    do {
        $result = $args{econtext}->execute(command => "file $device");

        if ($result->{exitcode} != 0) {
            if ($retry <= 0) {
                my $errmsg = "IsciContainer->mount: unable to find waited device<$device>";
                $log->error($errmsg);

                throw Kanopya::Exception::Execution($errmsg);
            }
            $retry -= 1;

            $log->debug("Device not found yet (<$device>), sleeping 1s and retry.");
            sleep 1;
        }
    } while ($result->{exitcode} != 0);

    $log->debug("Device found (<$device>).");
    $self->setAttr(name => 'device_connected', value => $device);
    $self->save();

    if (exists $args{erollback} and defined $args{erollback}){
        $args{erollback}->add(
            function   => $self->can('disconnect'),
            parameters => [ $self, "econtext", $args{econtext} ]
        );
    }

    return $device;
}

=pod
=begin classdoc

Deleting open-iscsi node.

=end classdoc
=cut

sub disconnect {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => [ 'econtext' ]);

    my $target = $self->getAttr(name => 'container_access_export');
    my $ip     = $self->getAttr(name => 'container_access_ip');
    my $port   = $self->getAttr(name => 'container_access_port');

    $log->debug("Logout from node <$target>");

    my $logout_cmd = "iscsiadm -m node -U manual";
    $args{econtext}->execute(command => $logout_cmd);

    $log->debug("Deleting node <$target> (<$ip:$port>).");

    my $delete_node_cmd = "iscsiadm -m node -T $target -p $ip:$port -o delete";
    $args{econtext}->execute(command => $delete_node_cmd);

    $self->setAttr(name  => 'device_connected',
                   value => '');
    $self->save();

    # TODO: insert an eroolback with mount method ?
}


=pod
=begin classdoc

Get the LUN id for a host

=end classdoc
=cut

sub getLunId {
    my $self = shift;
    my %args = @_;

    General::checkParams(args => \%args, required => []);

    return EEntity->new(data => $self->export_manager)->getLunId(lun => $self);
}

1;
