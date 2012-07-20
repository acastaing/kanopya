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

package Manager::HostManager;
use base "Manager";

use strict;
use warnings;

use Kanopya::Exceptions;
use Log::Log4perl "get_logger";
use Data::Dumper;

use Entity::Powersupplycard;
use Entity::Processormodel;
use Entity::Hostmodel;
use Entity::Kernel;

my $log = get_logger("administrator");
my $errmsg;

use constant BOOT_POLICIES => {
    pxe_nfs      => 'PXE Boot via NFS',
    pxe_iscsi    => 'PXE Boot via ISCSI',
    virtual_disk => 'BootOnVirtualDisk',
    boot_on_san  => 'BootOnSan',
};

sub methods {
    return {
        'getHostType'   => {
            'description'   => 'Return the type of managed hosts.',
            'perm_holder'   => 'entity'
        },
        'scaleHost'     => {
            'description'   => "scale host's cpu / memory",
            'perm_holder'   => 'entity'
        },
        'migrate'       => {
            'description'   => "migrate a host",
            'perm_holrder'  => "entity"
        }
    };
}

=head2 checkHostManagerParams

=cut

sub checkHostManagerParams {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args => \%args, required => [ "cpu", "ram" ]);
}

=head2 addHost

=cut

sub addHost {
    my $self = shift;
    my %args  = @_;

    General::checkParams(args     => \%args,
                         required => [ "host_core", "kernel_id", "host_serial_number", "host_ram" ]);

    my $host_manager_id = $self->getAttr(name => 'entity_id');

    # Instanciate new Host Entity
    my $host;
    eval {
        $host = Entity::Host->new(
                    host_manager_id => $host_manager_id,
                    %args
                );
    };
    if($@) {
        my $errmsg = "Wrong host attributes detected\n" . $@;
        throw Kanopya::Exception::Internal::WrongValue(error => $errmsg);
    }

    # Add power supply card if required
    eval {
        General::checkParams(args => \%args, required => [ "powersupplycard_id",
                                                           "powersupplyport_number" ]);

        my $powersupplycard = Entity::Powersupplycard->get(id => $args{powersupplycard_id});
        my $powersupply_id  = $powersupplycard->addPowerSupplyPort(
                                  powersupplyport_number => $args{powersupplyport_number}
                              );

        $host->setAttr(name  => 'host_powersupply_id', value => $powersupply_id);
    };
    if($@) {
        $log->info("No power supply card provided for host <" . $host->getAttr(name => 'host_id') . ">")
    }

    # Set initial state to down
    $host->setAttr(name => 'host_state', value => 'down:' . time);

    # Save the Entity in DB
    $host->save();

    return $host;
}

=head2 delHost

=cut

sub delHost {
    my $self = shift;
    my %args  = @_;
    my ($powersupplycard, $powersupplyid);

    General::checkParams(args => \%args, required => [ "host" ]);

    my $powersupplycard_id = $args{host}->getPowerSupplyCardId();
    if ($powersupplycard_id) {
        $powersupplycard = Entity::Powersupplycard->get(id => $powersupplycard_id);
        $powersupplyid   = $args{host}->getAttr(name => 'host_powersupply_id');
    }

    # Delete the host from db
    $args{host}->delete();

    if ($powersupplycard_id){
        $log->debug("Deleting powersupply with id <$powersupplyid> on the card : <$powersupplycard>");
        $powersupplycard->delPowerSupply(powersupply_id => $powersupplyid);
    }
}

=head2 createHost

    Desc : Implement createHost from HostManager interface.
           This function enqueue a EAddHost operation.
    args :

=cut

sub createHost {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ "host_core", "kernel_id", "host_serial_number", "host_ram" ]);

    $log->debug("New Operation AddHost with attrs : " . Dumper(%args));
    Operation->enqueue(
        priority => 200,
        type     => 'AddHost',
        params   => {
            context  => {
                host_manager => $self,
            },
            %args
        }
    );
}

sub removeHost {
    my $self = shift;
    my %args = @_;

    General::checkParams(args  => \%args, required => [ "host" ]);

    $log->debug("New Operation RemoveHost with host_id : <" .
                $args{host}->getAttr(name => "host_id") . ">");

    Operation->enqueue(
        priority => 200,
        type     => 'RemoveHost',
        params   => {
            context  => {
                host => $args{host},
            },
        },
    );
}

=head2 getFreeHosts

    Desc: return a list containing available hosts for this hosts manager

=cut

sub getFreeHosts {
    my ($self) = @_;

    my $where = {
        active          => 1, 
        host_state      => {-like => 'down:%'},
        host_manager_id => $self->getAttr(name => 'entity_id')      
    };

    my @hosts = Entity::Host->getHosts(hash => $where);
    my @free;
    foreach my $m (@hosts) {
        if(not $m->node) {
            push @free, $m;
        }
    }
    return @free;
}

=head2 getBootPolicies

    Desc: return a list containing boot policies available
        on hosts manager ; MUST BE IMPLEMENTED IN CHILD CLASSES

=cut

sub getBootPolicies {
    throw Kanopya::Exception::NotImplemented();
}

=head2 getHostType

    Desc: return the name of the host managed by this host manager

=cut

sub getHostType {
    return "Host";
}

=head2 getRemoteSessionURL

    Desc: return an URL to a remote session to the host

=cut

sub getRemoteSessionURL {
    throw Kanopya::Exception::NotImplemented();
}

=head2 scaleHost

=cut

sub scaleHost {
    throw Kanopya::Exception::NotImplemented();
}

=head2 migrate

=cut

sub migrate {
    throw Kanopya::Exception::NotImplemented();
}

1;
