# Copyright © 2013 Hedera Technology SAS
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

Kanopya executor runs workflows and operations

=end classdoc
=cut

package Entity::Component::KanopyaExecutor;
use base Entity::Component;
use base Manager::DaemonManager;

use strict;
use warnings;

use Entity::Workflow;
use Entity::Operation;

use Kanopya::Database;
use Kanopya::Exceptions;
use Kanopya::Config;

use Hash::Merge qw(merge);

use Log::Log4perl "get_logger";
my $log = get_logger("");

use constant ATTR_DEF => {
    control_queue => {
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 0,
        is_editable  => 1
    },
    time_step => {
        label        => 'Workflow pooling frequency',
        #type         => 'time',
        type         => 'integer',
        pattern      => '^\d+$',
        default      => 5,
        is_mandatory => 1,
        is_editable  => 1
    },
    masterimages_directory => {
        label        => 'Master images directory',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1
    },
    clusters_directory => {
        label        => 'Clusters data directory',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1
    },
    private_directory => {
        label        => 'Private data directory',
        type         => 'string',
        pattern      => '^.*$',
        is_mandatory => 1,
        is_editable  => 1
    },
};

sub getAttrDef { return ATTR_DEF; }

sub methods {
    return {
        run => {
            description => 'produce a workflow to run.',
            message_queuing => {
                queue => 'kanopya.executor.workflow'
            }
        },
        execute => {
            description => 'produce an operation to execute',
            message_queuing => {
                queue => 'kanopya.executor.operation'
            }
        },
        terminate => {
            description => 'produce an operation execution result.',
            message_queuing => {
                queue => 'kanopya.executor.operation_result'
            }
        },
    };
}


sub enqueue {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'type' ],
                         optional => { 'params'   => {},
                                       'priority' => 200,
                                       'workflow' => undef });

    # If workflow specified, insert the operation at the current rank of the running workflow
    my $workflow = delete $args{workflow};
    if (defined $workflow) {
        return $workflow->enqueueNow(operation => \%args);
    }

    my $operation = Entity::Operation->enqueue(%args);

    # Publish on the 'workflow' queue
    eval {
        MessageQueuing::RabbitMQ::Sender::run($self,
                                              workflow_id => $operation->workflow->id,
                                              %{ Kanopya::Database::_adm->{config}->{amqp} });
    };
    if ($@) {
        my $err = $@;
        $log->error("Unable to run workflow <" . $operation->workflow->id . ">, removing it: $err");
        $operation->workflow->remove();

        $err->rethrow();
    }
    return $operation;
}


sub execute {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'operation_id' ]);

    # Publish on the 'operation' queue
    MessageQueuing::RabbitMQ::Sender::execute($self,
                                              operation_id => $args{operation_id},
                                              %{ Kanopya::Database::_adm->{config}->{amqp} });
}


sub terminate {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'operation_id', 'status' ],
                         optional => { 'exception' => undef, 'time' => undef });

    # Publish on the 'operation_result' queue
    MessageQueuing::RabbitMQ::Sender::terminate($self,
                                                operation_id => $args{operation_id},
                                                status       => $args{status},
                                                exception    => $args{exception},
                                                time         => $args{time},
                                                %{ Kanopya::Database::_adm->{config}->{amqp} });
}


sub run {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'name' ],
                         optional => { 'params'     => undef,
                                       'related_id' => undef,
                                       'rule_id'    => undef,
                                       'workflow'   => undef });

    # If workflow specified, insert the embedded workflow
    # at the current rank of the running workflow
    my $workflow = delete $args{workflow};
    if (defined $workflow) {
        return $workflow->enqueueNow(workflow => \%args);
    }

    $workflow = Entity::Workflow->run(%args);

    # Publish on the 'workflow' queue
    eval {
        MessageQueuing::RabbitMQ::Sender::run($self,
                                              workflow_id => $workflow->id,
                                              %{ Kanopya::Database::_adm->{config}->{amqp} });
    };
    if ($@) {
        my $err = $@;
        $log->error("Unable to run workflow <" . $workflow->id . ">, removing it: $err");
        $workflow->remove();

        $err->rethrow();
    }
    return $workflow;
}


sub resume {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow_id' ]);

    my $workflow = Entity::Workflow->get(id => $args{workflow_id});

    # Publish on the 'workflow' queue
    eval {
        MessageQueuing::RabbitMQ::Sender::run($self,
                                              workflow_id => $args{workflow_id},
                                              %{ Kanopya::Database::_adm->{config}->{amqp} });
    };
    if ($@) {
        my $err = $@;
        $log->error("Unable to resume workflow <" . $workflow->id . ">: $err");
        $err->rethrow();
    }
    return $workflow;
}


=pod
=begin classdoc

Generic method for sending messages.
Should be not implemeted and the call handled by the AUTOLOAD in
MessageQueuing::RabbitMQ::Sender, but we need to fix a multi autoload confilct.

=end classdoc
=cut

sub send {
    my ($self, %args) = @_;

    MessageQueuing::RabbitMQ::Sender::send($self, %args);
}


sub getPuppetDefinition {
    my ($self, %args) = @_;

    my $config = Kanopya::Config::get("executor");
    my $dbconfig = Kanopya::Database::_adm->{config};
    my @executors = map { $_->fqdn } $self->nodes;

    return merge($self->SUPER::getPuppetDefinition(%args), {
        kanopyaexecutor => {
            classes => {
                'kanopya::common' => {
                    %{$dbconfig}
                },
                'kanopya::executor' => {
                    logdir       => $config->{logdir},
                    privatedir   => $self->private_directory,
                    user         => $config->{user}->{name},
                    password     => $config->{user}->{password},
                    amqpuser     => $config->{amqp}->{user},
                    amqppassword => $config->{amqp}->{password},
                },
            },
            params => {
                'kanopya::puppetmaster::sections' => [ {
                    name  => "kanopyaexecutor",
                    path  => $self->private_directory,
                    allow => \@executors
                }, {
                    name  => "kanopyafiles",
                    path  => $self->clusters_directory,
                    allow => [ "*" ]
                } ]
            },
            dependencies => [ $self->service_provider->getComponent(name => "Amqp"),
                              $self->service_provider->getComponent(name => "Mysql"),
                              $self->service_provider->getComponent(name => "Puppetmaster") ]
        }
    } );
}

1;
