#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2007 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use lib "../../lib";
use strict;
use Getopt::Long;
use WebGUI::Session;
use WebGUI::Workflow;

my $toVersion = "7.4.0"; # make this match what version you're going to
my $quiet; # this line required


my $session = start(); # this line required

addRealtimeWorkflow($session);
addGroupingsIndexOnUserId($session);
fixProfileDataWithoutFields($session);
buildNewUserProfileTable($session);
addAttachmentsToEvents($session);
addMetaDataPostsToCS($session);
addUserInvitations($session);
addPrivateMessaging($session);
addNewsletter($session);
addHttpProxyUrlPatternFilter($session);

finish($session); # this line required

#-------------------------------------------------
sub addNewsletter {
	my $session = shift;
	print "\tAdding a newsletter management system.\n" unless ($quiet);
    $session->config->addToArray("assets","WebGUI::Asset::Wobject::Collaboration::Newsletter");
    my $db = $session->db;
    $db->write("create table Newsletter (
        assetId varchar(22) binary not null,
        revisionDate bigint not null,
        newsletterTemplateId varchar(22) binary not null default 'newsletter000000000001',
        mySubscriptionsTemplateId varchar(22) binary not null default 'newslettersubscrip0001',
        newsletterHeader mediumtext,
        newsletterFooter mediumtext,
        newsletterCategories text,
        primary key (assetId, revisionDate)
        )");
    $db->write("create table Newsletter_subscriptions (
        assetId varchar(22) binary not null, 
        userId varchar(22) binary not null, 
        subscriptions text,
        lastTimeSent bigint not null default 0,
        primary key (assetId, userId)
        )");
    $db->write("alter table Newsletter_subscriptions add index lastTimeSent_assetId_userId
        (lastTimeSent,assetId,userId)");
    my $workflow = WebGUI::Workflow->new($session, "pbworkflow000000000002");
    my $activity = $workflow->addActivity("WebGUI::Workflow::Activity::SendNewsletters","newslettersendactivity");
    $activity->set("title","Send Newsletters For Newsletter Assets");
}

#-------------------------------------------------
sub addRealtimeWorkflow {
	my $session = shift;
	print "\tAdding realtime workflow option.\n" unless ($quiet);
    my $db = $session->db;
    $db->write("alter table Workflow add column mode varchar(20) not null default 'parallel'");
    my $sth = $db->read("select workflowId, isSerial from Workflow where isSerial=1 or isSingleton=1");
    while (my ($id, $serial) = $sth->array) {
        my $mode = "singleton";
        $mode = "serial" if ($serial);
        $db->write("update Workflow set mode=? where workflowId=?",[$mode, $id]);
    }
    $db->write("alter table Workflow drop column isSingleton");
    $db->write("alter table Workflow drop column isSerial");
    my $workflow = WebGUI::Workflow->create($session, {
        enabled     => 1,
        title       => "Commit Content Immediately",
        description => "Will commit the content as soon as save is pressed rather than waiting for Spectre to pick it up and run it in the background.",
        mode        => "realtime",
        type        => "WebGUI::VersionTag",
        },"realtimeworkflow-00001");
    my $activity = $workflow->addActivity("WebGUI::Workflow::Activity::CommitVersionTag", "pb-commitimmediately01");
    $activity->set("title", "Commit Version Tag"); 
    $session->setting->add("autoRequestCommit",0);
    $session->setting->add("skipCommitComments",0);
}

#----------------------------------------------------------------------------

sub addGroupingsIndexOnUserId {
    my $session     = shift;
    my $db          = $session->db;
    print qq{\tAdding index on `userId` column in `groupings` table for performance... } unless $quiet;

    # See if we even NEED to add this index, if we don't it just takes up
    # disk/memory space.
    my %createTable 
        = $db->quickHash(
            "SHOW CREATE TABLE `groupings`"
        );

    if ($createTable{'Create Table'} =~ /KEY\s+`[^`]+`\s+[(]`userId`[)]/) {
        print   " Skipped!\n",
                "\t\tAn index already exists on the `userId` column in the `groupings` table\n"
                    unless $quiet;
    }
    else {
        print   "\n\t\tThis may take a while... " unless $quiet;
        $db->write("ALTER TABLE `groupings` ADD INDEX `userId` (`userId`)");
        print   "DONE!\n" unless $quiet;
    }
}

#----------------------------------------------------------------------------

sub fixProfileDataWithoutFields {
    my $session     = shift;
    my $db          = $session->db;
    
    use WebGUI::ProfileField;

    print "\tFixing profile data without entries in userProfileField table..." unless $quiet;
    
    for my $fieldName (qw{ firstDayOfWeek language timeZone uiLevel }) {
        next if WebGUI::ProfileField->new($session, $fieldName);
        $db->write(
            q{INSERT INTO userProfileField (fieldName, label, visible, fieldType, protected, editable) 
            VALUES (?,?,0,"ReadOnly",1,0)},
            [$fieldName, $fieldName]
        );
    }

    print "OK!\n" unless $quiet;
}


#----------------------------------------------------------------------------

sub addMetaDataPostsToCS {
    my $session     = shift;
    my $db          = $session->db;
    
    print "\tAdding feature to CS to enable meta data in posts... " unless $quiet;
    $db->write("alter table Collaboration add column enablePostMetaData int(11) not null default 0");
    print "OK!\n" unless $quiet;
}


#----------------------------------------------------------------------------

sub addUserInvitations {
    my $session     = shift;
    my $db          = $session->db;
    
    print "\tAdding the ability for users's to invite others to the site... " unless $quiet;
    ##Add settings
    $session->setting->add('userInvitationsEnabled', 0);
    $session->setting->add('userInvitationsEmailExists', 'This email address exists in our system.  This means that your friend is already a member of the site.  The invitation will not be sent.');
    $session->setting->add('userInvitationsEmailTemplateId', 'PBtmpl0userInviteEmail');

    ##Create table for tracking invitations
    $session->db->write(<<EOSQL);

CREATE TABLE userInvitations (
    inviteId    VARCHAR(22) BINARY NOT NULL,
    userId      VARCHAR(22) BINARY NOT NULL,
    dateSent    DATE,
    email       VARCHAR(255) NOT NULL,
    newUserId   VARCHAR(22) BINARY,
    dateCreated DATE,
    PRIMARY KEY (inviteId)

)
EOSQL
    print "OK!\n" unless $quiet;
}


#----------------------------------------------------------------------------

sub buildNewUserProfileTable {
    my $session     = shift;
    my $db          = $session->db;
    print "\tBuilding new user profile table. This may take a while...\n" unless $quiet; 
    
    use WebGUI::ProfileField;
    use List::Util qw( first );

    print "\t\tCreating structure..." unless $quiet;
    # Create a new temporary table
    $db->write(q{
        CREATE TABLE tmp_userProfileData (
            userId VARCHAR(22) BINARY NOT NULL,
            PRIMARY KEY (userId)
        )
    });

    # Loop through the current fields and add them to the new table
    my @profileFields;
    my $sth = $db->read(q{SELECT fieldName, fieldType FROM userProfileField});
    while (my %fieldData = $sth->hash) {
        push @profileFields, $fieldData{fieldName};
        my $fieldType   = 'WebGUI::Form::'.ucfirst $fieldData{fieldType};
        my $fieldName   = $db->dbh->quote_identifier($fieldData{fieldName});
        eval "use $fieldType;";
        my $dataType = $fieldType->new($session)->get("dbDataType");

        $db->write(
            "ALTER TABLE tmp_userProfileData ADD COLUMN ($fieldName $dataType)"
        );
    }
    print " OK!\n" unless $quiet;

    # Find fields that were not in the userProfileField database.
    print "\t\tLooking for profile fields not defined in User Profiling... \n" unless $quiet;
    my @dataFields  = $db->buildArray("SELECT fieldName FROM userProfileData GROUP BY fieldName");
    for my $dataField (@dataFields) {
        if (!first { $_ eq $dataField } @profileFields) {
            print "\t\t\tCreating invisible, read-only profile field '$dataField'\n" unless $quiet;

            my $fieldType   = 'WebGUI::Form::ReadOnly';
            my $fieldName   = $db->dbh->quote_identifier($dataField);
            eval "use $fieldType;";
            my $dataType = $fieldType->new($session)->get("dbDataType");

            $db->write(
                "ALTER TABLE tmp_userProfileData ADD COLUMN ($fieldName $dataType)"
            );  

            # Create the profile field 
            WebGUI::ProfileField->create($session, $dataField, {
                label       => $dataField,
                fieldType   => "ReadOnly",
                visible     => 0,
                protected   => 1,
            });
        }
    }
    print "\t\t... Done!\n";
   
    print "\t\tMigrating data to temporary table... " unless $quiet;
    # Loop over the old table and put them in the new table
    $sth    = $db->read(q{SELECT userId FROM users});
    while (my $user = $sth->hashRef) {
        # Get all of this user's profile data
        my %profile 
            = $db->buildHash(
                "SELECT fieldName, fieldData FROM userProfileData WHERE userId=?",
                [$user->{userId}]
            );

        # Write to the temp table
        my $sql 
            = q{INSERT INTO tmp_userProfileData } 
            . q{(userId,} . join(",", map { $db->dbh->quote_identifier($_) } keys %profile) . q{)} 
            . q{VALUES (?,} . join(",",("?")x values %profile) . q{)}
            ;
        $db->write($sql, [$user->{userId},values %profile]);
    }
    $sth->finish;
    print "OK!\n" unless $quiet;

    # Delete the old table
    print "\t\tExchanging old data with new... ";
    $db->write("drop table userProfileData");

    # Rename the new table
    $db->write("rename table tmp_userProfileData to userProfileData");
    print "OK!\n" unless $quiet;

    print "\t\t... Done!\n" unless $quiet;
}



#----------------------------------------------------------------------------

sub addAttachmentsToEvents {
    my $session     = shift;
    print "\tAdding an storageId column to the Event table..." unless $quiet; 
    $session->db->write(
        "ALTER TABLE Event ADD COLUMN storageId VARCHAR(22) not null"
    );
    print "OK!\n" unless $quiet;
}

#-------------------------------------------------
sub addPrivateMessaging {
	my $session = shift;
	print "\tAdding private messaging...." unless ($quiet); 
    $session->setting->add("viewInboxTemplateId","PBtmpl0000000000000206");
    $session->setting->add("viewInboxMessageTemplateId","PBtmpl0000000000000205");
    $session->setting->add("sendPrivateMessageTemplateId","PBtmplPrivateMessage01");
    $session->db->write("alter table inbox add sentBy varchar(22) not null default 3");
    
    my %data = (
		label=>q|WebGUI::International::get("allow private messages label","WebGUI")|,
		editable=>1,
		visible=>1,
		required=>0,
		showAtRegistration=>0,
		requiredForPasswordRecovery=>0,
		fieldType=>"yesNo",
		protected=>1,
		);
	WebGUI::ProfileField->create($session,"allowPrivateMessages", \%data, 4);
    #Allow private messages for everyone initially
    $session->db->write("update userProfileData set allowPrivateMessages=1");
    print "OK!\n" unless $quiet;
}

#-------------------------------------------------
sub addHttpProxyUrlPatternFilter {
    my $session = shift;
    print "\tAdding HttpProxy Url Pattern Filter..." unless ($quiet);
    $session->db->write("alter table HttpProxy add urlPatternFilter mediumtext default NULL");
    print "OK!\n" unless ($quiet);
}



# ---- DO NOT EDIT BELOW THIS LINE ----

#-------------------------------------------------
sub start {
	my $configFile;
	$|=1; #disable output buffering
	GetOptions(
    		'configFile=s'=>\$configFile,
        	'quiet'=>\$quiet
	);
	my $session = WebGUI::Session->open("../..",$configFile);
	$session->user({userId=>3});
	my $versionTag = WebGUI::VersionTag->getWorking($session);
	$versionTag->set({name=>"Upgrade to ".$toVersion});
	$session->db->write("insert into webguiVersion values (".$session->db->quote($toVersion).",'upgrade',".$session->datetime->time().")");
	updateTemplates($session);
	return $session;
}

#-------------------------------------------------
sub finish {
	my $session = shift;
	my $versionTag = WebGUI::VersionTag->getWorking($session);
	$versionTag->commit;
	$session->close();
}

#-------------------------------------------------
sub updateTemplates {
	my $session = shift;
	return undef unless (-d "templates-".$toVersion);
        print "\tUpdating templates.\n" unless ($quiet);
	opendir(DIR,"templates-".$toVersion);
	my @files = readdir(DIR);
	closedir(DIR);
	my $importNode = WebGUI::Asset->getImportNode($session);
	my $newFolder = undef;
	foreach my $file (@files) {
		next unless ($file =~ /\.tmpl$/);
		open(FILE,"<templates-".$toVersion."/".$file);
		my $first = 1;
		my $create = 0;
		my $head = 0;
		my %properties = (className=>"WebGUI::Asset::Template");
		while (my $line = <FILE>) {
			if ($first) {
				$line =~ m/^\#(.*)$/;
				$properties{id} = $1;
				$first = 0;
			} elsif ($line =~ m/^\#create$/) {
				$create = 1;
			} elsif ($line =~ m/^\#(.*):(.*)$/) {
				$properties{$1} = $2;
			} elsif ($line =~ m/^~~~$/) {
				$head = 1;
			} elsif ($head) {
				$properties{headBlock} .= $line;
			} else {
				$properties{template} .= $line;	
			}
		}
		close(FILE);
		if ($create) {
			$newFolder = createNewTemplatesFolder($importNode) unless (defined $newFolder);
			my $template = $newFolder->addChild(\%properties, $properties{id});
		} else {
			my $template = WebGUI::Asset->new($session,$properties{id}, "WebGUI::Asset::Template");
			if (defined $template) {
				my $newRevision = $template->addRevision(\%properties);
			}
		}
	}
}

#-------------------------------------------------
sub createNewTemplatesFolder {
	my $importNode = shift;
	my $newFolder = $importNode->addChild({
		className=>"WebGUI::Asset::Wobject::Folder",
		title => $toVersion." New Templates",
		menuTitle => $toVersion." New Templates",
		url=> $toVersion."_new_templates",
		groupIdView=>"12"
		});
	return $newFolder;
}



