package WebGUI::Workflow::Activity::BucketPassiveAnalytics;


=head1 LEGAL

 -------------------------------------------------------------------
  Copyright 2001-2008 SDH Corporation
 -------------------------------------------------------------------

=cut

use strict;
use base 'WebGUI::Workflow::Activity';
use WebGUI::PassiveAnalytics::Rule;
use WebGUI::Inbox;

=head1 NAME

Package WebGUI::Workflow::Activity::BucketPassiveAnalytics

=head1 DESCRIPTION

Run through a set of rules to figure out how to classify log file entries.

=head1 SYNOPSIS

See WebGUI::Workflow::Activity for details on how to use any activity.

=head1 METHODS

These methods are available from this class:

=cut


#-------------------------------------------------------------------

=head2 definition ( session, definition )

See WebGUI::Workflow::Activity::defintion() for details.

=cut 

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my $i18n = WebGUI::International->new($session, "PassiveAnalytics");
	push( @{$definition}, {
		name=>$i18n->get("Bucket Passive Analytics"),
		properties=> {
            notifyUser => {
                fieldType => 'user',
                label     => $i18n->get('User'),
                hoverHelp => $i18n->get('User help'),
                defaultValue => $session->user->userId,
            },
        },
    });
	return $class->SUPER::definition($session,$definition);
}


#-------------------------------------------------------------------

=head2 execute ( [ object ] )

Analyze the deltaLog table, and generate the bucketLog table.

=head3 notes

=cut

sub execute {
	my ($self, undef, $instance) = @_;
    my $session = $self->session;
    sleep 45;
    my $endTime = time() + $self->getTTL;
    my $expired = 0;

    ##Load all the rules into an array
    my @rules = ();
    my $getARule = WebGUI::PassiveAnalytics::Rule->getAllIterator($session);
    while (my $rule = $getARule->()) {
        push @rules, $rule;
    }

    ##Get the index stored from the last invocation of the Activity.  If this is
    ##the first run, then clear out the table.
    my $logIndex = $instance->getScratch('lastPassiveLogIndex') || 0;
    if ($logIndex == 0) { 
        $session->db->write('delete from bucketLog');
    }

    ##Configure all the SQL
    my $deltaSql  = <<"EOSQL1";
select userId, assetId, url, delta, from_unixtime(timeStamp) as stamp
    from deltaLog order by timestamp limit $logIndex, 1234567890
EOSQL1
    my $deltaSth  = $session->db->read($deltaSql);
    my $bucketSth = $session->db->prepare('insert into bucketLog (userId, Bucket, duration, timeStamp) VALUES (?,?,?,?)');

    ##Walk through the log file entries, one by one.  Run each entry against
    ##all the rules until 1 matches.  If it doesn't match any rule, then bin it
    ##into the "Other" bucket.
    DELTA_ENTRY: while (my $entry = $deltaSth->hashRef()) {
        ++$logIndex;
        my $bucketFound = 0;
        RULE: foreach my $rule (@rules) {
           next RULE unless $rule->matchesBucket($entry); 
           
           # Into the bucket she goes..
           $bucketSth->execute([$entry->{userId}, $rule->get('bucketName'), $entry->{delta}, $entry->{stamp}]);
           $bucketFound = 1;
           last RULE;
        }
        if (!$bucketFound) {
           $bucketSth->execute([$entry->{userId}, 'Other', $entry->{delta}, $entry->{stamp}]);
        }
        if (time() > $endTime) {
            $expired = 1;
            last DELTA_ENTRY;
        }
    }

    if ($expired) {
        $instance->setScratch('logIndex', $logIndex);
        return $self->WAITING(1);
    }
    my $message = 'Passive analytics is done.';
    if ($session->setting->get('passiveAnalyticsDeleteDelta')) {
        $session->log->info('Clearing Passive Analytics delta log');
        $session->db->write('delete from deltaLog');
        $message .= '  The delta log has been cleaned up.';
    }
    my $inbox = WebGUI::Inbox->new($self->session);
    $inbox->addMessage({
        status  => 'unread',
        subject => 'Passive analytics is done',
        userId  => $self->get('userId'),
        message => $message,
    });
    $session->db->write('update passiveAnalyticsStatus set endDate=NOW(), running=0');

    return $self->COMPLETE;
}

1;

#vim:ft=perl
