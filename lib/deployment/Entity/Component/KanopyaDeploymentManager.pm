#    Copyright © 2014 Hedera Technology SAS
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


=pod
=begin classdoc

KanopyaDeploymentManager is the native deployment component of Kanopya.
It implement the deployment interface by using other any given export and disk drivers,
and other Kanopya components like dchpd and tfptd to achieve deploymement of nodes.
It deploy diskless or on local disk nodes, install and configure the requested components. 

@since    2014-Apr-9
@instance hash
@self     $self

=end classdoc
=cut

package Entity::Component::KanopyaDeploymentManager;
use parent Entity::Component;
use parent Manager::DeploymentManager;
use parent Manager::BootManager;

use strict;
use warnings;

use TryCatch;
use Log::Log4perl "get_logger";
my $log = get_logger("");


use constant ATTR_DEF => {
    executor_component_id => {
        label        => 'Workflow manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
    dhcp_component_id => {
        label        => 'Dhcp manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
    tftp_component_id => {
        label        => 'Tftp manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
    system_component_id => {
        label        => 'Operating system manager',
        type         => 'relation',
        relation     => 'single',
        pattern      => '^[0-9\.]*$',
        is_mandatory => 1,
        is_editable  => 0,
    },
};

sub getAttrDef { return ATTR_DEF; }


=pod
=begin classdoc

@constructor

Override the parent contructor to check the category of the component parameters

=end classdoc
=cut

sub new {
    my ($class, %args) = @_;

    General::checkParams(args => \%args,
                         required => [ 'executor_component', 'dhcp_component',
                                       'tftp_component', 'system_component' ]);

    my @wrongs;
    if (scalar(grep { $_->category_name eq 'Dhcpserver' }
               $args{dhcp_component}->component_type->component_categories) <= 0) {
        push @wrongs, $args{dhcp_component};
    }
    if (scalar(grep { $_->category_name eq 'Tftpserver' }
               $args{tftp_component}->component_type->component_categories) <= 0) {
        push @wrongs, $args{tftp_component};
    }
    if (scalar(grep { $_->category_name eq 'System' }
               $args{system_component}->component_type->component_categories) <= 0) {
        push @wrongs, $args{system_component};
    }
    if (scalar(@wrongs)) {
        throw Kanopya::Exception::Internal::WrongType(
              error => "Wrong category for component(s): " .
                       join(',', map { $_->component_type_component_name } @wrongs)
          )
    }

    return $class->SUPER::new(%args);
}


=pod
=begin classdoc

Use the executor to run the operation AddCluster.

@param node the node to deploy
@param systemimage the systemiage to use to deploy the node
@param boot_policy, the boot policy for the deplyoment

@optional hypervisor the hypervisor to use for virtuals nodes
@optional kernel_id force the kernel to use
@optional workflow in which to embed the deployment operation
@optional deploy_on_disk activate the on disk deployment

@see <package>Manager::DeploymentManager</package>

=end classdoc
=cut

sub deployNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'node', 'systemimage', 'boot_policy',
                                       'boot_manager', 'network_manager' ],
                         optional => { 'hypervisor' => undef, 'kernel_id' => undef,
                                       'deploy_on_disk' => 0, 'workflow' => undef });

    $args{context}->{deployment_manager} = $self;
    return $self->executor_component->run(
               name     => 'DeployNode',
               workflow => delete $args{workflow},
               params => {
                   context => {
                       deployment_manager => $self,
                       boot_manager       => delete $args{boot_manager},
                       network_manager    => delete $args{network_manager},
                       node               => delete $args{node},
                       systemimage        => delete $args{systemimage},
                   },
                   %args,
               }
           );
}


=pod
=begin classdoc

Use the executor to run the operation ReleaseNode.

@param node the node to deploy

@optional workflow in which to embed the deployment operation

@see <package>Manager::DeploymentManager</package>

=end classdoc
=cut

sub releaseNode {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'node', 'boot_manager' ],
                         optional => { 'workflow' => undef });

    $args{context}->{deployment_manager} = $self;
    return $self->executor_component->run(
               name     => 'ReleaseNode',
               workflow => delete $args{workflow},
               params   => {
                   context => {
                       deployment_manager => $self,
                       boot_manager       => delete $args{boot_manager},
                       node               => delete $args{node},
                   },
               },
               %args,
           );
}


=pod
=begin classdoc

Do the required configuration/actions to provides the boot mechanism for the node.

@see <package>Manager::BootManager</package>

=end classdoc
=cut

sub configureBoot {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ "node", "systemimage", "boot_policy", "boot_manager" ]);

    throw Kanopya::Exception::NotImplemented();
}


=pod
=begin classdoc

Workaround for the native HCM boot manager that requires the configuration
of the boot made in 2 steps.

Apply the boot configuration set at configureBoot

@see <package>Manager::BootManager</package>

=end classdoc
=cut

sub applyBootConfiguration {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ "node", "systemimage", "boot_policy", "boot_manager" ]);

    throw Kanopya::Exception::NotImplemented();
}

1;
