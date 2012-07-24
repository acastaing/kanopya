# EHost.pm - Abstract class of EHosts object

#    Copyright © 2011-2012 Hedera Technology SAS
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
# Created 14 july 2010

=head1 NAME

EHost - execution class of host entities

=head1 SYNOPSIS



=head1 DESCRIPTION

EHost is the execution class of host entities

=head1 METHODS

=cut
package EEntity::EHost;
use base "EEntity";

use strict;
use warnings;

use Entity;
use EFactory;
use Entity::Powersupplycard;

use String::Random;
use Template;
use IO::Socket;
use Net::Ping;

use Log::Log4perl "get_logger";

my $log = get_logger("executor");
my $errmsg;

sub new {
    my $class = shift;
    my %args = @_;

    my $self = $class->SUPER::new(%args);

    $self->{host_manager} = EFactory::newEEntity(data => $self->getHostManager);

    return $self;
}

sub start {
    my $self = shift;
    my %args = @_;

    $self->{host_manager}->startHost(host => $self, hypervisor => $args{hypervisor});

    $self->setState(state => 'starting');

    # Sommetimes a host can be promoted to another object type
    # So reload the object to be sure to have the good type.
    return EFactory::newEEntity(data => Entity->get(id => $self->id));
}

sub halt {
    my $self = shift;
    my %args = @_;

    my $result = $self->getEContext->execute(command => 'halt');
    $self->setState(state => 'stopping');
}

sub stop {
    my $self = shift;
    my %args = @_;

    $self->{host_manager}->stopHost(host => $self);
}

sub postStart {
    my $self = shift;
    my %args = @_;

    $self->{host_manager}->postStart(host => $self);
}

sub ping {
    my ($self) = @_;
    my $ip = $self->getAdminIp;
    my $ping = Net::Ping->new();
    my $pingable = $ping->ping($ip, 2);
    $ping->close();
    return $pingable ? $pingable : 0;
}

sub checkUp {
    my $self = shift;
    my %args = @_;

    my $ip = $self->getAdminIp;
    my $ping = Net::Ping->new();
    my $pingable = $ping->ping($ip);
    $ping->close();

    if ($pingable) {
        eval {
            $self->getEContext;

            $log->debug("In checkUP test if host <$ip> is pingable <$pingable>\n");
        };
        if ($@) {
            $log->info("Ehost->checkUp for host <$ip>, host pingable but not sshable");
            return 0;
        }
    }

    return $pingable ? $pingable : 0;
}

sub getEContext {
    my $self = shift;

    return EFactory::newEContext(ip_source      => $self->{_executor}->getMasterNodeIp,
                                 ip_destination => $self->getAdminIp);
}


sub timeOuted {
    my $self = shift;
    $self->setState(state => 'broken');
}
1;

__END__

=head1 AUTHOR

Copyright (c) 2011-2012 by Hedera Technology Dev Team (dev@hederatech.com). All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
