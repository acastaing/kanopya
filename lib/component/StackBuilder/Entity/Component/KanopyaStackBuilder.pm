# Copyright © 2014 Hedera Technology SAS
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

Kanopya stack builder build many clusters that represent a stack
from a json infrastructure definition. 

=end classdoc
=cut

package Entity::Component::KanopyaStackBuilder;
use base Entity::Component;

use strict;
use warnings;

use Entity::User;
use Kanopya::Exceptions;
use NotificationSubscription;
use Entity::Operationtype;

use Data::Dumper;
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
    }
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        buildStack => {
            description => 'build a stack in function of the json infrastrucutre definition.',
        },
        endStack => {
            description => 'shutdown and disable a stack.',
        },
    };
}

my $service_templates = [
    {
        "service_name" => "PMS HA Controller",
        "components"   => [
            'Keystone',
            'Neutron',
            'Glance',
            'Apache',
            'NovaController',
            'Cinder',
            'Lvm',
            'Amqp',
            'Mysql',
            'Haproxy',
            'Keepalived'
        ],
    },
    {
        "service_name" => "PMS AllInOne Controller",
        "components"   => [
            'Keystone',
            'Neutron',
            'Glance',
            'Apache',
            'NovaController',
            'Cinder',
            'Lvm',
            'Amqp',
            'Mysql'
        ],
    },
    {
        "service_name" => "PMS Distributed Controller",
        "components"   => [
            'Keystone',
            'Neutron',
            'Glance',
            'Apache',
            'NovaController',
            'Cinder',
            'Lvm'
        ],
    },
    {
        "service_name" => "PMS DB and Messaging",
        "components"   => [ 'Amqp', 'Mysql' ],
    },
    {
        "service_name" => "PMS Hypervisor",
        "components"   => [ 'NovaCompute' ],
    },
];


sub buildStack {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'stack' ],
                         optional => { 'owner_id' => Kanopya::Database::currentUser,
                                       # Set default timeout to 4 hours
                                       'timeout'  => 4 * 60 * 60 });

    # TODO: Check existance of PimpMyStack policies
    my @templates = Entity::ServiceTemplate->search(hash => { service_name => { 'LIKE' => 'PMS%' } });
    if (! scalar(@templates)) {
        throw Kanopya::Exception::Internal(
                  error => 'Unable to find services and policies required for building stasks, ' .
                           'perhaps you forgot to load pimpmystack.json policies and servces.')

    }

    # The stack args must fit the following formalism:
    # {
    #     services => [
    #         # Service "PMS Distributed Controller"
    #         {
    #             cpu        => 4,
    #             ram        => 8282906624,
    #             components => [
    #                 {
    #                     component_type => 'Keystone',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Neutron',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Glance',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Apache',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'NovaController',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Cinder',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Lvm',
    #                     conf => {}
    #                 },
    #             ],
    #         },
    #         # Service "PMS Hypervisor"
    #         {
    #             cpu        => 8,
    #             ram        => 33131626496,
    #             components => [
    #                 {
    #                     component_type => 'NovaCompute',
    #                     conf => {}
    #                 },
    #             ],
    #         },
    #         # Service "PMS DB and Messaging"
    #         {
    #             cpu        => 4,
    #             ram        => 8282906624,
    #             components => [
    #                 {
    #                     component_type => 'Amqp',
    #                     conf => {}
    #                 },
    #                 {
    #                     component_type => 'Mysql',
    #                     conf => {}
    #                 },
    #             ],
    #         },
    #     ],
    #     iprange  => "10.0.0.0/24'
    # }

    General::checkParams(args => $args{stack}, required => [ 'stack_id', 'services', 'iprange' ]);

    # Browse the service defintion list to find the service templates which correspond to.
    my @services;

    SERVICE:
    for my $service (@{ $args{stack}->{services} }) {
        my @components = map { $_->{component_type} } @{ $service->{components} };

        # Search a template that contains components of the service
        TEMPLATE:
        for my $template (@{ $service_templates }) {
            for my $template_component (@{ $template->{components} }) {
                if (scalar(grep { $_ eq $template_component } @components) <= 0) {
                    next TEMPLATE;
                }
            }

            # All components of the template found in the service definition
            # So get the service template id from name
            my $service_template = Entity::ServiceTemplate->find(hash => {
                                       service_name => $template->{service_name}
                                   });

            # If some components are defined with configuration, add them to the service defintion to create
            my @configuredComponents;
            for my $configured (grep { defined $_->{conf} } @{ $service->{components} }) {
                my $component_type = ClassType::ComponentType->find(hash => {
                                         component_name => $configured->{component_type}
                                     });

                push @configuredComponents, {
                    component_type                => $component_type->id,
                    component_configuration       => $configured->{conf},
                    component_extra_configuration => delete $configured->{conf}->{extra},
                }
            }

            # And push the service defintion filled with template id in the service list.
            delete $service->{components};
            push @services, {
                service_template_id => $service_template->id,
                components          => \@configuredComponents,
                %{ $service }
            };
            next SERVICE;
        }

        # No template found for this service.
        throw Kanopya::Exception::Internal::Inconsistency(
                 error => "Unable to find a service template corresponding to servide defintion:\n" .
                          Dumper($service)
              )
    }

    # Set the notification subscription for the owner of the stack
    $self->subscribeSupportNotifications();
    $self->subscribeOwnerNotifications(owner_id => $args{owner_id});

    # Run the workflow BuildStack
    my $workflow = $self->executor_component->run(
        name       => 'BuildStack',
        timeout    => $args{timeout},
        params     => {
            services   => \@services,
            stack_id   => $args{stack}->{stack_id},
            iprange    => $args{stack}->{iprange},
            context    => {
                stack_builder => $self,
                user          => Entity::User->get(id => $args{owner_id}),
            },
        },
    );

    $workflow->addPerm(consumer => $workflow->owner, method => 'get');
    $workflow->addPerm(consumer => $workflow->owner, method => 'cancel');

    return $workflow;
}


sub endStack {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'stack_id' ],
                         optional => { 'owner_id' => Kanopya::Database::currentUser
                                       # Set default timeout to 1 hour
                                       'timeout'  => 1 * 60 * 60 });

    # Run the workflow EndStack
    my $workflow = $self->executor_component->run(
        name       => 'EndStack',
        timeout    => $args{timeout},
        params     => {
            stack_id => $args{stack_id},
            context  => {
                stack_builder => $self,
                user          => Entity::User->get(id => $args{owner_id}),
            },
        }
    );

    $workflow->addPerm(consumer => $workflow->owner, method => 'get');
    $workflow->addPerm(consumer => $workflow->owner, method => 'cancel');

    return $workflow;
}


sub subscribeSupportNotifications {
    my ($self, %args) = @_;

    # Try to get the support user from configuration
    my $support = defined $self->support_user
                      ? $self->support_user
                      : Entity::User->find(hash => { user_login => 'admin' } );

    # TODO: If some notifcations exists, and the subcripber is defferent from
    #       support, remove them.

    # The support will be notified when the buildStack workflow start
    my $build_stack = Entity::Operationtype->find(hash => { operationtype_name => "buildStack" });
    $build_stack->subscribe(subscriber_id   => $support->id,
                            entity_id       => $self->id,
                            operation_state => "processing");
    # The support will be notified when the buildStack workflow fail
    $build_stack->subscribe(subscriber_id   => $support->id,
                            entity_id       => $self->id,
                            operation_state => "cancelled");

    # The support will be notified when the buildStack workflow succeed
    my $conf_stack = Entity::Operationtype->find(hash => { operationtype_name => "configureStack" });
    $conf_stack->subscribe(subscriber_id   => $support->id,
                           entity_id       => $self->id,
                           operation_state => "succeeded");
    # The support will be notified when the configureStack operation is interrupted
    $conf_stack->subscribe(subscriber_id   => $support->id,
                           entity_id       => $self->id,
                           operation_state => "interrupted");

    # The support will be notified when the endStack workflow start
    Entity::Operationtype->find(hash => { operationtype_name => "stopStack" })->subscribe(
        subscriber_id   => $support->id,
        entity_id       => $self->id,
        operation_state => "processing"
    );

    # The support will be notified when the endStack workflow succeed
    Entity::Operationtype->find(hash => { operationtype_name => "endStack" })->subscribe(
        subscriber_id   => $support->id,
        entity_id       => $self->id,
        operation_state => "succeeded"
    );

    # The support will be notified when a StopNode workflow fail
    Entity::Operationtype->find(hash => { operationtype_name => "PreStopNode" })->subscribe(
        subscriber_id   => $support->id,
        entity_id       => $self->id,
        operation_state => "failed"
    );

    # The support will be notified when the endStack workflow fail
    Entity::Operationtype->find(hash => { operationtype_name => "unconfigureStack" })->subscribe(
        subscriber_id   => $support->id,
        entity_id       => $self->id,
        operation_state => "cancelled"
    );

    # The support will be notified on every timeouted operation
    Entity::Operationtype->subscribe(subscriber_id   => $support->id,
                                     operation_state => "timeouted",
                                     entity_id       => $self->id,);
}

sub subscribeOwnerNotifications {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'owner_id' ]);

    # The owner will be notified when the buildStack workflow succeed
    Entity::Operationtype->find(hash => { operationtype_name => "configureStack" })->subscribe(
        subscriber_id   => $args{owner_id},
        entity_id       => $args{owner_id},
        operation_state => "succeeded"
    );
}

sub unsubscribeOwnerNotifications {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'owner_id' ]);

    for my $subscription (NotificationSubscription->search(hash => { subscriber_id => $args{owner_id} })) {
        Entity::Operationtype->unsubscribe(notification_subscription_id => $subscription->id);
    }
}

1;
