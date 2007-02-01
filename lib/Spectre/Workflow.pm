package Spectre::Workflow;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2006 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use HTTP::Request::Common;
use HTTP::Cookies;
use POE qw(Component::Client::HTTP);
use POE::Queue::Array;

#-------------------------------------------------------------------

=head2 _start ( )

Initializes the workflow manager.

=cut

sub _start {
        my ( $kernel, $self, $publicEvents) = @_[ KERNEL, OBJECT, ARG0 ];
	$self->debug("Starting workflow manager.");
        my $serviceName = "workflow";
        $kernel->alias_set($serviceName);
        $kernel->call( IKC => publish => $serviceName, $publicEvents );
        $kernel->yield("checkInstances");
}

#-------------------------------------------------------------------

=head2 _stop ( )

Gracefully shuts down the workflow manager.

=cut

sub _stop {
	my ($kernel, $self) = @_[KERNEL, OBJECT];	
	$self->debug("Stopping workflow manager.");
	undef $self;
}

#-------------------------------------------------------------------

=head2 addInstance ( params )

Adds a workflow instance to the workflow processing queue.

=head3 params

A hash reference containing important information about the workflow instance to add to the queue.

=head4 sitename

The host and domain of the site this instance belongs to.

=head4 instanceId

The unqiue id for this workflow instance.

=head4 priority

The priority (1,2, or 3) that this instance should be run at.

=cut

sub addInstance {
	my ($self, $instance) = @_[OBJECT, ARG0];
	my $priority = ($instance->{priority} -1) * 10;
	$self->debug("Adding workflow instance ".$instance->{instanceId}." from ".$instance->{sitename}." to queue at priority ".$priority.".");
	$self->getWaitingQueue->enqueue($priority, $instance);
}

#-------------------------------------------------------------------

=head2 checkInstances ( )

Checks to see if there are any open instance slots available, and if there are assigns a new instance to be run to fill it.

=cut

sub checkInstances {
	my ($kernel, $self) = @_[KERNEL, OBJECT];
	$self->debug("Checking to see if we can run anymore instances right now.");
	if ($self->countRunningInstances < $self->config->get("maxWorkers")) {
		$self->debug("Total workflows waiting to run: ".$self->getWaitingQueue->get_item_count);
		my $instance = $self->getNextInstance;
		if (defined $instance) {
			$kernel->yield("runWorker",$instance);
		}
	}	
	$kernel->delay_set("checkInstances",$self->config->get("timeBetweenRunningWorkflows"));
}

#-------------------------------------------------------------------

=head2 config ( )

Returns a reference to the config object.

=cut 

sub config {
	my $self = shift;
	return $self->{_config};
}

#-------------------------------------------------------------------

=head2 countRunningInstances ( )

Returns an integer representing the number of running instances.

=cut

sub countRunningInstances {
	my $self = shift;
	my $instanceCount = $self->getRunningQueue->get_item_count;
	$self->debug("There are $instanceCount running instances.");
	return $instanceCount;
}

#-------------------------------------------------------------------

=head2 debug ( output )

Prints out debug information if debug is enabled.

=head3 output

The debug message to be printed if debug is enabled.

=cut 

sub debug {
	my $self = shift;
	my $output = shift;
	if ($self->{_debug}) {
		print "WORKFLOW: ".$output."\n";
	}
	$self->getLogger->debug("WORKFLOW: ".$output);
}

#-------------------------------------------------------------------

=head2 deleteInstance ( instanceId ) 

Removes a workflow instance from the processing queue.

=cut

sub deleteInstance {
	my ($self, $instanceId,$kernel, $session ) = @_[OBJECT, ARG0, KERNEL, SESSION];
	$self->debug("Deleting workflow instance $instanceId from queue.");
	$self->getWaitingQueue->remove_items(
		sub {
			my $instance = shift; 
			return 1 if ($instance->{instanceId} eq $instanceId);
			return 0;
		}
	);
	$self->removeInstanceFromRunningQueue($instanceId);
}

#-------------------------------------------------------------------

=head2 error ( output )

Prints out error information if debug is enabled.

=head3 output

The error message to be printed if debug is enabled.

=cut 

sub error {
	my $self = shift;
	my $output = shift;
	if ($self->{_debug}) {
		print "WORKFLOW: [Error] ".$output."\n";
	}
	$self->getLogger->error("WORKFLOW: ".$output);
}

#-------------------------------------------------------------------

=head2 getLogger ( )

Returns a reference to the logger.

=cut

sub getLogger {
	my $self = shift;
	return $self->{_logger};
}

#-------------------------------------------------------------------

=head2 getRunningQueue ( )

Returns a reference to the queue of workflow instances that are running now.

=cut

sub getRunningQueue {
	my $self = shift;
	return $self->{_runningQueue};
}

#-------------------------------------------------------------------

=head2 getWaitingQueue ( )

Returns a reference to the queue of workflow instances waiting to run.

=cut

sub getWaitingQueue {
	my $self = shift;
	return $self->{_waitingQueue};
}


#-------------------------------------------------------------------

=head2 getNextInstance ( )

Returns the next available instance.

=cut

sub getNextInstance {
	my $self = shift;
	$self->debug("Looking for a workflow instance to run.");
	my $waiting = $self->getWaitingQueue;
	if ($waiting->get_item_count > 0) {
		my ($priority, $id, $instance) = $waiting->dequeue_next;
		$instance->{workingPriority} = $priority;
		$self->getRunningQueue->enqueue($priority, $instance);
		$self->debug("Looks like ".$instance->{instanceId}." at priority $priority would be a good workflow instance to run.");
		return $instance;
	}
	$self->debug("Didn't see any workflow instances to run.");
	return undef;
}

#-------------------------------------------------------------------

=head2 new ( config, logger, [ , debug ] )

Constructor. Loads all active workflows from each WebGUI site and begins executing them.

=head3 config

The config object for spectre.

=head3 logger

A reference to the logger object.

=head3 debug

A boolean indicating Spectre should spew forth debug as it runs.

=cut

sub new {
	my $class = shift;
	my $config = shift;
	my $logger = shift;
	my $debug = shift;
	my $self = {_debug=>$debug, _config=>$config, _logger=>$logger};
	bless $self, $class;
	my @publicEvents = qw(addInstance deleteInstance);
	POE::Session->create(
		object_states => [ $self => [qw(_start _stop returnInstanceToRunnableState addInstance checkInstances deleteInstance suspendInstance runWorker workerResponse), @publicEvents] ],
		args=>[\@publicEvents]
        	);
	my $cookies = HTTP::Cookies->new(file => '/tmp/cookies');
	POE::Component::Client::HTTP->spawn(
		Agent => 'Spectre',
		Alias => 'workflow-ua',
		CookieJar => $cookies
  		);
	$self->{_runningQueue} = POE::Queue::Array->new;
	$self->{_waitingQueue} = POE::Queue::Array->new;
}


#-------------------------------------------------------------------

=head2 removeInstanceFromRunningQueue ( )

Removes a workflow instance from the queue that tracks what's running and returns a reference to it.

=cut

sub removeInstanceFromRunningQueue {
	my $self = shift;
	my $instanceId = shift;
	my @items = $self->getRunningQueue->remove_items(
		sub {
			my $payload = shift; 
			return 1 if ($payload->{instanceId} eq $instanceId);
			return 0;
		}
	);
	my $instance = $items[0][2];
	return $instance;
}

#-------------------------------------------------------------------

=head2 returnInstanceToRunnableState ( )

Returns a workflow instance back to runnable queue.

=cut

sub returnInstanceToRunnableState {
	my ($self, $instance) = @_[OBJECT, ARG0];
	$self->debug("Returning ".$instance->{instanceId}." to runnable state.");
	$self->getWaitingQueue->enqueue($instance->{workingPriority}+1, $instance);
}

#-------------------------------------------------------------------

=head2 runWorker ( )

Calls a worker to execute a workflow activity.

=cut

sub runWorker {
	my ($kernel, $self, $instance, $session) = @_[KERNEL, OBJECT, ARG0, SESSION];
	$self->debug("Preparing to run workflow instance ".$instance->{instanceId}.".");
	my $url = "http://".$instance->{sitename}.':'.$self->config->get("webguiPort").$instance->{gateway};
	my $request = POST $url, [op=>"runWorkflow", instanceId=>$instance->{instanceId}];
	my $cookie = $self->{_cookies}{$instance->{sitename}};
	$request->header("Cookie",$instance->{cookieName}."=".$cookie) if (defined $cookie);
	$request->header("X-instanceId",$instance->{instanceId});
	$request->header("User-Agent","Spectre");
	$self->debug("Posting workflow instance ".$instance->{instanceId}." to $url.");
	$kernel->post('workflow-ua','request', 'workerResponse', $request);
	$self->debug("Workflow instance ".$instance->{instanceId}." posted.");
}

#-------------------------------------------------------------------

=head2 suspendInstance ( ) 

Suspends a workflow instance for a number of seconds defined in the config file, and then returns it to the runnable queue.

=cut

sub suspendInstance {
	my ($self, $instance, $kernel) = @_[OBJECT, ARG0, KERNEL];
	$self->debug("Suspending workflow instance ".$instance->{instanceId}." for ".$self->config->get("suspensionDelay")." seconds.");
	$kernel->delay_set("returnInstanceToRunnableState",$self->config->get("suspensionDelay"), $instance);
}

#-------------------------------------------------------------------

=head2 workerResponse ( )

This method is called when the response from the runWorker() method is received.

=cut

sub workerResponse {
	my ($self, $kernel, $requestPacket, $responsePacket) = @_[OBJECT, KERNEL, ARG0, ARG1];
	$self->debug("Retrieving response from workflow instance.");
 	my $request  = $requestPacket->[0];
    	my $response = $responsePacket->[0];
	my $instanceId = $request->header("X-instanceId");	# got to figure out how to get this from the request, cuz the response may die
	$self->debug("Response retrieved is for $instanceId.");
	my $instance = $self->removeInstanceFromRunningQueue($instanceId);
	if ($response->is_success) {
		$self->debug("Response for $instanceId retrieved successfully.");
		if ($response->header("Set-Cookie") ne "") {
			$self->debug("Storing cookie for $instanceId for later use.");
			my $cookie = $response->header("Set-Cookie");
			my $pattern = $instance->{cookieName}."=([a-zA-Z0-9\_\-]{22}).*";
			$cookie =~ s/$pattern/$1/;
			$self->{_cookies}{$instance->{sitename}} = $cookie;
		}
		my $state = $response->content; 
		if ($state eq "waiting") {
			$self->debug("Was told to wait on $instanceId because we're still waiting on some external event.");
			$kernel->yield("suspendInstance",$instance);
		} elsif ($state eq "complete") {
			$self->debug("Workflow instance $instanceId ran one of it's activities successfully.");
			$kernel->yield("returnInstanceToRunnableState",$instance);
		} elsif ($state eq "disabled") {
			$self->debug("Workflow instance $instanceId is disabled.");
			$kernel->yield("suspendInstance",$instance);			
		} elsif ($state eq "done") {
			$self->debug("Workflow instance $instanceId is now complete.");
			$kernel->yield("deleteInstance",$instanceId);			
		} elsif ($state eq "error") {
			$self->debug("Got an error response for $instanceId.");
			$kernel->yield("suspendInstance",$instance);
		} else {
			$self->error("Something bad happened on the return of $instanceId. ".$response->error_as_HTML);
			$kernel->yield("suspendInstance",$instance);
		}
	} elsif ($response->is_redirect) {
		$self->error("Response for $instanceId was redirected. This should never happen if configured properly!!!");
	} elsif ($response->is_error) {	
		$self->error("Response for $instanceId had a communications error. ".$response->error_as_HTML);
		$kernel->yield("suspendInstance",$instance)
	}
}


1;
