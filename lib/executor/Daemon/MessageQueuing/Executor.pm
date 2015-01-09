#    Copyright © 2011-2014 Hedera Technology SAS
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

The execution daemon, fetch jobs from the following messages queues:
 - 'operation'        : Execute a single operation and push the result on the queue 'operation_result',
 - 'operation_result' : Handle an operation result, continue, finish or cancel workflows according to
                        the last operation result and the state of the workflow,
 - 'workflow'         : Run a specified workflow., push the first operation.

@since    2013-May-14
@instance hash
@self     $self

=end classdoc
=cut

package Daemon::MessageQueuing::Executor;
use base Daemon::MessageQueuing;

use strict;
use warnings;

use General;
use Message;
use Kanopya::Exceptions;
use Kanopya::Database;

use Entity::Workflow;
use Entity::Operation;
use EEntity::EOperation;

use TryCatch;
use Switch;
use XML::Simple;
use Data::Dumper;

use Log::Log4perl "get_logger";
use Log::Log4perl::Layout;
use Log::Log4perl::Appender;

my $log = get_logger("");


use constant CALLBACKS => {
    execute_operation => {
        callback  => \&executeOperation,
        type      => 'queue',
        queue     => 'kanopya.executor.operation',
        instances => 2,
        duration  => 30,
    },
    handle_result => {
        callback  => \&handleResult,
        type      => 'queue',
        queue     => 'kanopya.executor.operation_result',
        instances => 1,
        duration  => 30,
    },
    run_workflow => {
        callback  => \&runWorkflow,
        type      => 'queue',
        queue     => 'kanopya.executor.workflow',
        instances => 1,
        duration  => 30,
    },
};

sub getCallbacks { return CALLBACKS; }


=pod
=begin classdoc

@constructor

Instanciate an execution daemon.

@optional duration force the duration while awaiting messages.

@return the executor instance

=end classdoc
=cut

sub new {
    my ($class, %args) = @_;

    General::checkParams(args => \%args, optional => { "duration" => undef });

    return $class->SUPER::new(confkey => 'executor', %args);
}


=pod
=begin classdoc

Wait messages on the channel 'workflow', set the workflow as running
and push the first operation on the channel 'operation'.

@param workflow_id the id of the workflow to run.

=end classdoc
=cut

sub runWorkflow {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'workflow_id' ],
                         optional => { 'ack_cb' => undef });

    my $workflow = Entity::Workflow->get(id => $args{workflow_id});

    # Log in the proper file
    $self->setLogAppender(workflow => $workflow);

    $log->info("---- [ Workflow " . $workflow->id . " ] ----");

    # Check the state
    if ($workflow->state ne 'pending' && $workflow->state ne 'interrupted') {
        throw Kanopya::Exception::Execution(
                  error => "Can not run workflow with state <" . $workflow->state . ">"
              );
    }

    # Set the workflow as running
    $workflow->setState(state => 'running');

    # Pop the first operation
    my $first;
    try {
        $first = EEntity::EOperation->new(operation => $workflow->getNextOperation());

        $log->info("Running " . $workflow->workflow_name . " workflow <" . $workflow->id . "> ");
        $log->info("Executing " . $workflow->workflow_name . " first operation <" . $first->id . ">");

        # Set the operation as ready
        $first->setState(state => 'ready');

        # Push the first operation on the execution channel
        $self->_component->execute(operation_id => $first->id);
    }
    catch ($err) {
        $log->warn("$err");
        $workflow->cancel();
    }

    # Acknowledge the message
    return 1;
}


=pod
=begin classdoc

Wait messages on the channel 'operation', execute the operation
and push the result on the queue 'operation_result'.

@param operation_id the id of the operation to execute.

=end classdoc
=cut

sub executeOperation {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ "operation_id" ],
                         optional => { 'ack_cb' => undef });

    my $operation = $self->instantiateOperation(id     => $args{operation_id},
                                                ack_cb => $args{ack_cb});

    # Log in the proper file
    $self->setLogAppender(workflow => $operation->workflow);

    $self->logWorkflowState(operation => $operation);
    Message->send(from    => "Executor",
                  level   => "info",
                  content => "Operation Processing [$operation]...");

    # Check parameters
    try {
        $log->info("Step <check>");
        $operation->check();
    }
    catch ($err) {
        return $self->terminateOperation(operation => $operation,
                                         status    => 'cancelled',
                                         exception => $err);
    }

    # Skip the proccessing steps if postreported
    my $delay;
    if ($operation->state ne 'postreported') {
        if ($operation->state ne 'prereported') {
            # Set the operation as proccessing
            # NOTE: when operation go to processing, the update of the state could require validation,
            #       in this case the operation is reported and will be executed at validation.
            try {
                $operation->setState(state => 'processing')
            }
            catch (Kanopya::Exception::Execution::OperationRequireValidation $err) {
                # Terminate if the operation require validation
                return $self->terminateOperation(operation => $operation,
                                                 status    => 'waiting_validation');
            }
            catch (Kanopya::Exception $err) {
                $err->rethrow();
            }
            catch ($err) {
                throw Kanopya::Exception::Execution(error => $err);
            }

            # Check the required state of the context objects, and update its
            try {
                # Firstly lock the context objects
                $self->lockOperationContext(operation => $operation);

                # Check/Update the state of the context objects atomically
                $log->info("Step <prepare>");
                Kanopya::Database::beginTransaction;

                $operation->prepare();
            }
            catch ($err) {
                Kanopya::Database::rollbackTransaction;
                $operation->unlockContext();

                if ($err->isa('Kanopya::Exception::Execution::InvalidState') or
                    $err->isa('Kanopya::Exception::Execution::OperationReported')) {
                    # TODO: Do not report the operation, implement a mechanism
                    #       that re-trigger operation that received InvalidState
                    #       when the coresponding state change...
                    return $self->terminateOperation(operation => $operation,
                                                     status    => 'statereported',
                                                     time      => time + 10,
                                                     exception => $err);
                }
                return $self->terminateOperation(operation => $operation,
                                                 status    => 'cancelled',
                                                 exception => $err);
            }

            Kanopya::Database::commitTransaction;

            # Unlock the context objects
            $operation->unlockContext();

        }

        # Check preconditions for processing
        try {
            $log->info("Step <prerequisites>");
            $delay = $operation->prerequisites();
        }
        catch ($err) {
            return $self->terminateOperation(operation => $operation,
                                             status    => 'cancelled',
                                             exception => $err);
        }
        # Report the operation if delay is set
        if ($delay) {
            return $self->terminateOperation(operation => $operation,
                                             status    => 'prereported',
                                             time      => $delay > 0 ? time + $delay : undef);
        }

        # Process the operation
        try {
            Kanopya::Database::beginTransaction;

            $log->info("Step <process>");
            $operation->execute();
        }
        catch (Kanopya::Exception::Execution::OperationInterrupted $err) {
            Kanopya::Database::rollbackTransaction;

            return $self->terminateOperation(operation => $operation,
                                             status    => 'interrupted',
                                             exception => $err);
        }
        catch ($err) {
            Kanopya::Database::rollbackTransaction;

            return $self->terminateOperation(operation => $operation,
                                             status    => 'cancelled',
                                             exception => $err);
        }

        Kanopya::Database::commitTransaction;
    }

    $log->info("Step <postrequisites>");
    try {
         $delay = $operation->postrequisites();
    }
    catch ($err) {
        return $self->terminateOperation(operation => $operation,
                                         status    => 'cancelled',
                                         exception => $err);
    }
    # Report the operation if delay is set
    if ($delay) {
        return $self->terminateOperation(operation => $operation,
                                         status    => 'postreported',
                                         time      => $delay > 0 ? time + $delay : undef);
    }

    # Update the state of the context objects if required
    try {
        # Lock/Unlock the context with option 'skip_not_found',
        # as some context entities could be deleted by the operation
        $self->lockOperationContext(operation      => $operation,
                                    skip_not_found => 1);

        # Update the state of the context objects atomically
        $log->info("Step <finish>");
        $operation->finish();
    }
    catch ($err) {
        $operation->unlockContext(skip_not_found => 1);

        if ($err->isa('Kanopya::Exception::Execution::OperationReported')) {
            return $self->terminateOperation(operation => $operation,
                                             status    => 'prereported',
                                             time      => time + 10,
                                             exception => $err);
        }
        return $self->terminateOperation(operation => $operation,
                                         status    => 'cancelled',
                                         exception => $err);
    }

    # Unlock the context objects
    $operation->unlockContext(skip_not_found => 1);

    # Terminate the operation with success
    return $self->terminateOperation(operation => $operation,
                                     status    => 'succeeded');
}


=pod
=begin classdoc

Push a result on the channel 'operation_result'. Also serialize
the terminated operation parameters.

@param operation the terminated operation.
@param status the state of the execution of the operation.

=end classdoc
=cut

sub terminateOperation {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'operation', 'status' ]);

    my $operation = delete $args{operation};

    $log->info("Operation terminated with status <$args{status}>");
    if (defined $args{exception} and ref($args{exception})) {
        $args{exception} = "$args{exception}";
        $log->error($args{exception});
    }

    # Handle failed operations
    if ($args{status} eq 'cancelled') {
        # If interupt on error mode activated (usefull for debug)
        # set the workflow as interrupted
        if ($self->{config}->{onerror} eq 'interrupt') {
            $args{status} = "interrupted";
        }
        else {
            # If the operation is harmless, swith the state to 'failed'
            # to avoid the cancel of the workflow
            if ($operation->harmless) {
                $args{status} = "failed";
            }
            # If some rollback defined, undo them
            if (defined $operation->{erollback}) {
                $log->debug("Undo rollbacks");
                $operation->{erollback}->undo();
            }
        }
    }

    # Serialize the parameters as its could be modified during
    # the operation executions steps.
    my $params = delete $operation->{params};
    $params->{context} = delete $operation->{context};
    if (defined $args{exception}) {
        $params->{exception} = $args{exception};
    }
    $operation->serializeParams(params => $params);

    # Produce a result on the operation_result channel
    $self->_component->terminate(operation_id => $operation->id, %args);

    # Acknowledge the message
    return 1;
}


=pod
=begin classdoc

Wait messages on the channel 'operation_result', and trigger the correponding job:
 - operation succeeded : continue or finish the workflow,
 - operation reported  : trigger a timer that will re-push the operation at the proper time,
 - operation cancelled : cancel the workflow.

@param operation_id the id of the terminated operation.
@param status the state of the execution of the operation.

=end classdoc
=cut

sub handleResult {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'operation_id', 'status' ],
                         optional => { 'exception' => undef, 'time' => undef, 'ack_cb' => undef });

    my $operation = $self->instantiateOperation(id     => $args{operation_id},
                                                ack_cb => $args{ack_cb});

    # Log in the proper file
    $self->setLogAppender(workflow => $operation->workflow);

    # Force the execution status if the workflow has been manually cancelled or interupted.
    if ($operation->workflow->state =~ m/^(cancelled|interrupted)$/) {
        $args{status} = $operation->workflow->state;
    }
    # If the timeout exceeded, swith the workflow state to "timeouted"
    elsif ($operation->workflow->state ne 'timeouted' &&
        defined $operation->workflow->timeout &&
        $operation->workflow->timeout < time) {
        $operation->workflow->timeouted();

        # Set the state on the operation for notification purpose only,
        # The real state of the operation wil be set at the following statement.
        $operation->setState(state => "timeouted");
    }

    # TODO: Check the current state / new state consitency

    # Set the operation state
    $operation->setState(state => $args{status});

    # Operation succeeded
    switch ($args{status}) {
        case 'succeeded' {
            # Operation succeeded, let's continue/finish the workflow

            $self->logWorkflowState(operation => $operation, state => 'SUCCEED');

            Message->send(from    => "Executor",
                          level   => "info",
                          content => "[$operation] Execution Success");

            # Continue the workflow
        }
        case /(prereported|postreported|statereported)/ {
            # Operation reported, do not ack the message to re-insert the opeartion in queue,
            # the operation will be re-triggered at next re-connection.
            # If the delay expired, execute the operation.

            General::checkParams(args => \%args, optional => { 'time' => undef });

            # If the workflow has been interrupted
            if ($operation->workflow->state eq 'interrupted') {
                # Stop the workflow
                return 1;
            }

            # The operation execution is reported at $args{time}
            if (defined $args{time}) {
                # Compute the delay
                my $delay = $args{time} - time;

                $self->logWorkflowState(operation => $operation, state => "REPORTED while $delay s");
                if (defined $args{exception}) {
                    $log->info("Report reason: " . $args{exception});
                }

                # If the hoped execution time is in the future, report the operation
                if ($delay > 0) {
                    # Update the hoped excution time of the operation
                    $operation->report(duration => $delay);

                    # Re-trigger the operation at proper time
                    my $report_cb = sub {
                        # Re-execute the operation
                        $self->_component->execute(operation_id => $operation->id);

                        # Acknowledge the message as the operation result is finally handled
                        $args{ack_cb}->();
                    };
                    # TODO: Excecute the previous callback in $delay s.

                    # Do not acknowledge the message as it will be done by the timer.
                    # If the current proccess die while some timers still active,
                    # the operation result will be automatically re-enqueued.
                    return 0;
                }
                else {
                    # Re-trigger the operation now
                    $self->_component->execute(operation_id => $operation->id);

                    # Stop the workflow for now
                    return 1;
                }
            }
            # The operation is indefinitely reported, execution is delegated to the workflow
            else {
                # $operation->setState(state => 'pending');
                # Continue the workflow
            }
        }
        case 'waiting_validation' {
            # Operation require validation, simply do not continue the workflow

            $self->logWorkflowState(operation => $operation, state => 'WAITING VALIDATION');

            # TODO: Probably better to send notification for validation here,
            #       instead of at validation time (cf. executeOperation)

            # Stop the workflow
            return 1;
        }
        case 'validated' {
            # Operation has been validated, execute it.

            $self->logWorkflowState(operation => $operation, state => 'VALIDATED');

            # Re-trigger the operation now
            $self->_component->execute(operation_id => $operation->id);

            # Stop the workflow
            return 1;
        }
        case 'interrupted' {
            # Operation has been interrupted, change the state of the workflow and do not continue it.

            $self->logWorkflowState(operation => $operation, state => 'INTERRUPTED');

            # Change the state of the workflow
            $operation->workflow->interrupt();

            # Stop the workflow
            return 1;
        }
        case 'failed' {
            # Operation failed, log the error, continue the workflow

            General::checkParams(args => \%args, optional => { 'exception' => undef });

            Message->send(from    => "Executor",
                          level   => "error",
                          content => "[$operation] Execution Aborted : $args{exception}");

            $self->logWorkflowState(operation => $operation, state => 'FAILED');
            $log->error($args{exception});

            $log->info("Operation " . $operation->type . " <" . $operation->id .
                       "> failed, but is harmless, continue the workflow.");

            my @tofail;
            if (defined $operation->operation_group) {
                @tofail = $operation->operation_group->search(related  => 'operations',
                                                              order_by => 'execution_rank DESC');
            }
            else {
                @tofail = ($operation);
            }

            # Cancel all the operations of the group of the operation that failed
            for my $tofail (map { EEntity::EOperation->new(operation => $_, skip_not_found => 1) } @tofail) {
                if ($tofail->state ne 'pending') {
                    try {
                        $log->info("Cancelling operation " . $tofail->type . " <" . $tofail->id . ">");
                        $tofail->cancel();
                    }
                    catch ($err){
                        $log->error("Error during operation cancel :\n$err");
                    }
                }
                # Set operations of the group as failed, to avoid the workflow execute them
                $tofail->setState(state => "failed", reason => $args{exception});
            }

            # Continue the workflow
        }
        case 'cancelled' {
            # Operation cancelled, rollbacking failled operation, cancelling succeeded ones

            General::checkParams(args => \%args, optional => { 'exception' => undef });

            $self->logWorkflowState(operation => $operation, state => 'FAILED');
            $log->error($args{exception});

            Message->send(from    => "Executor",
                          level   => "error",
                          content => "[$operation] Execution Aborted : $args{exception}");

            # Try to cancel all workflow operations, and delete them.
            $log->info("Cancelling workflow \"" . $operation->workflow->workflow_name .
                       "\"  <" . $operation->workflow->id . ">");

            # Restore context object states updated at 'prepare' step.
            try {
                # Firstly lock the context objects
                $self->lockOperationContext(operation => $operation, skip_not_found => 1);

                my $workflow = $operation->workflow;
                my @tocancel = map { EEntity::EOperation->new(operation => $_, skip_not_found => 1) }
                                   $workflow->search(related  => 'operations',
                                                     order_by => 'execution_rank DESC');

                # Call cancel on all operation executed operations
                for my $tocancel (@tocancel) {
                    if ($tocancel->state ne 'pending') {
                        try {
                            $log->info("Cancelling operation " . $tocancel->type .
                                       " <" . $tocancel->id . ">");
                            $tocancel->cancel();
                        }
                        catch ($err){
                            $log->error("Error during operation cancel :\n$err");
                        }
                    }
                    $tocancel->setState(state => 'cancelled', reason => $args{exception});
                    $tocancel->remove();
                }
                $workflow->cancel();
            }
            catch ($err) {
                $operation->unlockContext(skip_not_found => 1);

                if ($err->isa('Kanopya::Exception::Execution::OperationReported')) {
                    # Could not get the locks, do not ack the message
                    return 0;
                }
                else { $err->rethrow(); }
            }

            # Unlock the context objects
            $operation->unlockContext(skip_not_found => 1);

            # Stop the workflow
            return 1;
        }
        else {
            throw Kanopya::Exception::Execution(
                      error => "Unknown operation operation result status <$args{status}>"
                  );
        }
    }

    # Compute the workflow status, push the next op if there is remaining one(s),
    # finish the workflow instead.
    my $next;
    try {
        $next = EEntity::EOperation->new(
                    operation => $operation->workflow->prepareNextOperation(current => $operation)
                );

        $log->info("Executing " . $operation->workflow->workflow_name .
                   " workflow next operation " . $next->type . " <" . $next->id . ">");

        if ($next->state eq 'pending') {
            # Set the operation as ready
            $next->setState(state => 'ready');
        }

        # Push the next operation on the execution channel
        $self->_component->execute(operation_id => $next->id);
    }
    catch (Kanopya::Exception::Internal::NotFound $err) {
        # No remaning operation
        $log->info("Finishing " . $operation->workflow->workflow_name .
                   " workflow <" . $operation->workflow->id . ">");
        $operation->workflow->finish();
    }
    catch ($err) {
        $err->rethrow();
    }

    # Acknowledge the message
    return 1;
}


=pod
=begin classdoc

Set the log appender to log in the workflow specific log file.

@param workflow the workflow to identify the log file

=end classdoc
=cut

sub setLogAppender {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'workflow' ]);

    if (exists Log::Log4perl->appenders()->{'workflow'}) {
        $log->eradicate_appender('workflow');
    }

    my $appender = Log::Log4perl::Appender->new("Log::Dispatch::File",
                       name      => "workflow",
                       filename  => $self->{config}->{logdir} . "/workflows/" . $args{workflow}->id . ".log"
                   );

    $appender->layout(Log::Log4perl::Layout::PatternLayout->new("%d %c %p> %M - %m%n"));
    $log->add_appender($appender);
}


=pod
=begin classdoc

Log the workflow state.

@param operation the just terminated operation of the workflow
@param state the state of the workflow

=end classdoc
=cut

sub logWorkflowState {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'operation' ],
                         optional => { 'state' => '' });

    my $msg = $args{operation}->type . " <" . $args{operation}->id . "> (workflow " .
              $args{operation}->workflow->id . ") " . $args{state};
    $log->info("---- [ Operation " . $msg . " ] ----");
}


=pod
=begin classdoc

Try to lock the entities of the operation context. Context entities should not
be locked by an operation while more than few millisecond, so retry to lock every second.
If could not get the locks until the timeout exeedeed, report the operation.

@param operation the operation thaht want lock the context
@param state the state of the workflow

=end classdoc
=cut

sub lockOperationContext {
    my ($self, %args) = @_;

    General::checkParams(args     => \%args,
                         required => [ 'operation' ],
                         optional => { 'skip_not_found' => 0 });

    my $timeout = 10;
    while ($timeout >= 0) {
        try {
            $args{operation}->lockContext(skip_not_found => $args{skip_not_found});

            # Operation context successfully unlocked
            return;
        }
        catch (Kanopya::Exception::Execution::Locked $err) {
            $log->info("Operation <" . $args{operation}->id .
                       ">, unable to get the context locks, $timeout second(s) left...");
            sleep 1;
        }
        catch ($err) {
            $err->rethrow();
        }
        $timeout--;
    }
    throw Kanopya::Exception::Execution::OperationReported(
              error => "Unable to get the context locks until timeout exeedeed."
          );
}


=pod
=begin classdoc

@param operation the operation to instantiate

@return the operation instance

=end classdoc
=cut

sub instantiateOperation {
    my ($self, %args) = @_;

    General::checkParams(args => \%args, required => [ 'id' ]);

    my $operation;
    try {
        $operation = EEntity::EOperation->new(
                         operation => Entity::Operation->get(id => $args{id})
                     );
    }
    catch (Kanopya::Exception::Internal::NotFound $err) {
        # The operation does not exists, probably due to a workflow cancel
        $log->warn("Operation <$args{id}> does not exists, skipping.");

        # Acknowledge the message as the operation result is finally handled
        if (defined $args{ack_cb}) {
            $args{ack_cb}->();
        }
        $err->rethrow();
    }
    catch (Kanopya::Exception $err) {
        $err->rethrow();
    }
    catch ($err) {
        throw Kanopya::Exception::Execution(error => $err);
    }

    return $operation;
}

1;
