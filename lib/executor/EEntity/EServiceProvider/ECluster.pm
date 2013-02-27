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

# Maintained by Dev Team of Hedera Technology <dev@hederatech.com>.

package EEntity::EServiceProvider::ECluster;
use base 'EEntity';

use strict;
use warnings;

use Entity;
use Entity::ServiceProvider::Cluster;
use General;
use Kanopya::Config;
use EFactory;
use EEntity;
use Entity::NetconfRole;

use Template;
use String::Random;
use IO::Socket;
use Net::Ping;

use Log::Log4perl "get_logger";

my $log = get_logger("");
my $errmsg;

sub create {
    my $self = shift;
    my %args = @_;

    General::checkParams(args     => \%args,
                         required => [ 'managers' ],
                         optional => { 'interfaces' => {}, 'components' => {} });

    my $config = Kanopya::Config::get('executor');

    # Create cluster directory
    my $dir = "$config->{clusters}->{directory}/" . $self->cluster_name;
    my $command = "mkdir -p $dir";
    $self->getExecutorEContext->execute(command => $command);
    $log->debug("Execution : mkdir -p $dir");

    # set initial state to down
    $self->setAttr(name => 'cluster_state', value => 'down:'.time);

    # Add all the components provided by the master image
    if ($self->masterimage) {
        foreach my $component ($self->masterimage->components_provided) {
            $args{components}->{$component->component_type->component_name} = {
                component_type => $component->component_type_id
            };
        }

        if ($self->masterimage->masterimage_defaultkernel && ! $self->kernel) {
            $self->setAttr(name  => "kernel_id",
                           value => $self->masterimage->masterimage_defaultkernel->id);
        }
    }

    # Save the new cluster in db
    $log->debug("trying to update the new cluster previouly created");
    $self->save();

    # Set default permissions on this cluster for the related customer
    for my $method (keys %{ $self->getMethods }) {
        $self->addPerm(consumer => $self->user, method => $method);
    }

    # Use the method for policy applying to configure manager, components, and interfaces.
    $self->applyPolicies(
        presets => {
            components      => $args{components},
            interfaces      => $args{interfaces},
            managers        => $args{managers},
            billing_limits  => $args{billing_limits},
            orchestration   => $args{orchestration},
        }
    );

    # Automatically add the admin interface if it does not exists
    my $adminrole = Entity::NetconfRole->find(hash => { netconf_role_name => 'admin' });
    eval {
        Entity::Interface->find(hash => {
            service_provider_id => $self->id,
            'netconf_interfaces.netconf.netconf_role.netconf_role_id' => $adminrole->id
        });
    };
    if ($@) {
        $log->debug("Automatically add the admin interface as it is not defined.");

        my $kanopya   = Entity::ServiceProvider::Cluster->find(hash => { cluster_name => 'Kanopya' });
        my $interface = Entity::Interface->find(hash => {
                            service_provider_id => $kanopya->id,
                            'netconf_interfaces.netconf.netconf_role.netconf_role_id' => $adminrole->id
                        });

        my @netconfs = $interface->netconfs;
        $self->addNetworkInterface(netconfs => \@netconfs);
    }
}

sub addNode {
    my $self = shift;
    my %args = @_;

    my $host_manager = $self->getManager(manager_type => 'HostManager');
    my $host_manager_params = $self->getManagerParameters(manager_type => 'HostManager');
   
    my @interfaces = $self->interfaces;
    $host_manager_params->{interfaces} = \@interfaces;

    my $ehost_manager = EEntity->new(entity => $host_manager);

    my $host = $ehost_manager->getFreeHost(%$host_manager_params);

    $log->debug("Host manager <" . $host_manager->id . "> returned free host <$host>");

    return $host;
}

sub generateResolvConf {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => ['host', 'mount_point' ]);

    my $rand = new String::Random;
    my $tmpfile = $rand->randpattern("cccccccc");

    my @nameservers = ();

    for my $attr ('cluster_nameserver1','cluster_nameserver2') {
        push @nameservers, {
            ipaddress => $self->getAttr(name => $attr)
        };
    }

    my $data = {
        domainname => $self->getAttr(name => 'cluster_domainname'),
        nameservers => \@nameservers,
    };

    my $file = $self->generateNodeFile(
        cluster       => $self->_getEntity,
        host          => $args{host},
        file          => '/etc/resolv.conf',
        template_dir  => '/templates/internal',
        template_file => 'resolv.conf.tt',
        data          => $data
    );

    $self->getExecutorEContext->send(
        src  => $file,
        dest => $args{mount_point}.'/etc/resolv.conf'
    );
}

sub checkComponents {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    my @components = $self->getComponents(category => "all");
    foreach my $component (@components) {
        my $component_name = $component->component_type->component_name;
        $log->debug("Browsing component: " . $component_name);

        my $ecomponent = EEntity->new(entity => $component);

        if (not $ecomponent->isUp(host => $args{host}, cluster => $self)) {
            $log->info("Component <$component_name> not yet operational on host <" . $args{host}->id .  ">");
            return 0;
        }
    }
    return 1;
}

sub postStartNode {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    my @components = $self->getComponents(category => "all", order_by => "priority");

    $log->info('Processing cluster components configuration for this node');
    foreach my $component (@components) {
        EEntity->new(entity => $component)->postStartNode(
            cluster   => $self,
            host      => $args{host},
            erollback => $args{erollback}
        );
    }
}

sub stopNode {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    my @components = $self->getComponents(category => "all");
    $log->info('Processing cluster components configuration for this node');

    foreach my $component (@components) {
        EFactory::newEEntity(data => $component)->stopNode(
            host    => $args{host},
            cluster => $self
        );
    }
}

sub readyNodeRemoving {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    # Ask to all cluster component if they are ready for node addition.
    my @components = $self->getComponents(category => "all");
    foreach my $component (@components) {
        if (not $component->readyNodeRemoving(host_id => $args{host}->id)) {
            return 0;
        }
    }
    return 1;
}

sub postStopNode {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'host' ]);

    my @components = $self->getComponents(category => "all");

    # Ask to all cluster component if they are ready for node addition.
    foreach my $component (@components) {
        EFactory::newEEntity(data => $component)->postStopNode(
            host    => $args{host},
            cluster => $self
        );
    }
}

sub getEContext {
    my $self = shift;

    return EFactory::newEContext(ip_source      => $self->{_executor}->getMasterNodeIp(),
                                 ip_destination => $self->getMasterNodeIp());
}

sub reconfigure {
    my $self = shift;

    my $agent = $self->getComponent(category => "Configurationagent");
    my $eagent = EFactory::newEEntity(data => $agent);
    $eagent->applyConfiguration(cluster => $self);
}

1;