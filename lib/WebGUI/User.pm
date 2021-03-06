package WebGUI::User;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2008 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::Cache;
use WebGUI::Group;
use WebGUI::DatabaseLink;
use WebGUI::Exception;
use WebGUI::Utility;
use WebGUI::Operation::Shared;
use JSON;

=head1 NAME

Package WebGUI::User

=head1 DESCRIPTION

This package provides an object-oriented way of managing WebGUI users as well as getting/setting a users's profile data.

=head1 SYNOPSIS

 use WebGUI::User;
 $u = WebGUI::User->new($session,3);
 $u = WebGUI::User->new($session,"new");
 $u = WebGUI::User->newByEmail($session, $email);
 $u = WebGUI::User->newByUsername($session, $username);

 $authMethod =		$u->authMethod("WebGUI");
 $dateCreated = 	$u->dateCreated;
 $karma = 		    $u->karma;
 $lastUpdated = 	$u->lastUpdated;
 $languagePreference = 	$u->profileField("language",1);
 $referringAffiliate =	$u->referringAffiliate;
 $status =		$u->status("somestatus");
 $username =		$u->username("jonboy");
 $arrayRef =		$u->getGroups;
 $member =		$u->isInGroup($groupId);

 $u->addToGroups(\@arr);
 $u->deleteFromGroups(\@arr);
 $u->delete;

 WebGUI::User->validUserId($session, $userId);

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------
# TODO This stays like this until we can break API, just in case somebody
# doesn't realize that _ means private.
# After API unfreeze, put this in the WebGUI::User->create routine
sub _create {
    my $session = shift;
    my $userId = shift || $session->id->generate();
    $session->db->write("insert into users (userId,dateCreated) values (?,?)",[$userId, time()]);
    $session->db->write("INSERT INTO userProfileData (userId) VALUES (?)",[$userId]);
    WebGUI::Group->new($session,2)->addUsers([$userId]);
    WebGUI::Group->new($session,7)->addUsers([$userId]);
    return $userId;
}

#-------------------------------------------------------------------

=head2 addToGroups ( groups [, expireOffset ] )

Adds this user to the specified groups.

=head3 groups

An array reference containing a list of groups.

=head3 expireOffset

An override for the default offset of the grouping. Specified in seconds.

=cut

sub addToGroups {
	my $self = shift;
	my $groups = shift;
	my $expireOffset = shift;
	$self->uncache;
	foreach my $groupId (@{$groups}) {
		WebGUI::Group->new($self->session,$groupId)->addUsers([$self->userId],$expireOffset);
	}
	$self->session->stow->delete("gotGroupsForUser");
}

#-------------------------------------------------------------------

=head2 acceptsPrivateMessages ( userId )

Returns a boolean of whether or not the user can receive private messages from the user passed in

=head3 userId

userId to determine if the user accepts private messages from

=cut

sub acceptsPrivateMessages {
    my $self      = shift;
    my $userId    = shift;

    return 0 if ($self->isVisitor);  #Visitor can't get private messages
    return 0 if ($self->userId eq $userId);  #Can't send private messages to yourself

    my $pmSetting = $self->profileField('allowPrivateMessages');

    return 0 if ($pmSetting eq "none");
    return 1 if ($pmSetting eq "all");

    if($pmSetting eq "friends") {
        my $friendsGroup = $self->friends;
        my $sentBy       = WebGUI::User->new($self->session,$userId);
        #$self->session->errorHandler->warn($self->isInGroup($friendsGroup->getId));
        return $sentBy->isInGroup($friendsGroup->getId);
    }

    return 0;
}

#-------------------------------------------------------------------

=head2 acceptsFriendsRequests ( user )

Returns whether or this user will accept friends requests from the user passed in

=head3 user

WebGUI::User object to check to see if user will accept requests from.

=cut

sub acceptsFriendsRequests {
    my $self    = shift;
    my $session = $self->session;
    my $user    = shift;

    return 0 unless ($user && ref $user eq "WebGUI::User"); #Sanity checks
    return 0 if($self->isVisitor);  #Visitors can't have friends
    return 0 if($user->isVisitor);  #Visitor can't be your friend either
    return 0 if($self->userId eq $user->userId);  #Can't be your own friend (why would you want to be?)

    my $me     = WebGUI::Friends->new($session,$self);
    my $friend = WebGUI::Friends->new($session,$user);

    return 0 if ($me->isFriend($user->userId));  #Already a friend
    return 0 if ($me->isInvited($user->userId) || $friend->isInvited($self->userId)); #Invitation sent by one or the other

    return $self->profileField('ableToBeFriend'); #Return profile setting
}

#-------------------------------------------------------------------

=head2 authMethod ( [ value ] )

Returns the authentication method for this user.

=head3 value

If specified, the authMethod is set to this value. The only valid values are "WebGUI" and "LDAP". When a new account is created, authMethod is defaulted to "WebGUI".

=cut

sub authMethod {
        my ($self, $value);
        $self = shift;
        $value = shift;
        if (defined $value) {
		$self->uncache;
                $self->{_user}{"authMethod"} = $value;
                $self->{_user}{"lastUpdated"} =$self->session->datetime->time();
                $self->session->db->write("update users set authMethod=".$self->session->db->quote($value).",
			lastUpdated=".$self->session->datetime->time()." where userId=".$self->session->db->quote($self->{_userId}));
        }
        return $self->{_user}{"authMethod"};
}

#-------------------------------------------------------------------

=head2 create ( session, [userId] )

Create a new user. C<userId> is an option user ID to give the new user.
Returns the newly created WebGUI::User object.

=cut

sub create {
    my $class   = shift;
    my $session = shift;
    my $userId  = shift;

    if ( !ref $session || !$session->isa( 'WebGUI::Session' ) ) {
        WebGUI::Error::InvalidObject->throw(
            expected => "WebGUI::Session",
            got      => (ref $session),
            error    => q{Must provide a session variable},
        );
    }

    return WebGUI::User->new( $session, "new", $userId );
}

#-------------------------------------------------------------------

=head2 cache ( )

Saves the user object into the cache.

=cut

sub cache {
    my $self = shift;
    my $cache = WebGUI::Cache->new($self->session,["user",$self->userId]);
    # copy user object
    my %userData;
    for my $k (qw(_userId _user _profile)) {
        $userData{$k} = $self->{$k};
    }
    $cache->set(\%userData, 60*60*24);
}

#-------------------------------------------------------------------

=head2 canUseAdminMode ( )

Returns a boolean indicating whether the user has the basic privileges needed to turn on admin mode and use basic admin functions. Note this isn't checking for any special privileges like whether the user can create new users, etc.

=cut

sub canUseAdminMode {
        my $self = shift;
	my $pass = 1;
	my $subnets = $self->session->config->get("adminModeSubnets") || [];
	if (scalar(@$subnets)) {
		$pass = WebGUI::Utility::isInSubnet($self->session->env->getIp, $subnets);
	}

	return $pass && $self->isInGroup(12)
}

#-------------------------------------------------------------------

=head2 canViewField ( field, user)

Returns whether or not the user passed in can view the field value for the user.
This will only check the user level privileges.

=head3 field

Field to check privileges on

=head3 user

User to check field privileges for

=cut

sub canViewField {
    my $self      = shift;
    my $session   = $self->session;
    my $field     = shift;
    my $user      = shift;

    return 0 unless ($field && $user);
    #Always true for yourself
    return 1 if ($self->userId eq $user->userId);
    
    my $privacySetting = $self->getProfileFieldPrivacySetting($field);
    return 0 unless (WebGUI::Utility::isIn($privacySetting,qw(all none friends)));
    return 1 if ($privacySetting eq "all");
    return 0 if ($privacySetting eq "none");

    #It's friends so return whether or not user is a friend
    return WebGUI::Friends->new($session,$self)->isFriend($user->userId); 
}   

#-------------------------------------------------------------------

=head2 dateCreated ( )

Returns the epoch for when this user was created.

=cut

sub dateCreated {
        return $_[0]->{_user}{dateCreated};
}

#-------------------------------------------------------------------

=head2 delete ( )

Deletes this user, removes their user profile data, cleans up their
inbox, removes userSessionScratch data and authentication information,
removes them from any groups they belong to and deletes their
Friend's group.

=cut

sub delete {
    my $self = shift;
    my $userId = $self->userId;
	$self->uncache;
    my $db = $self->session->db;
	foreach my $groupId (@{$self->getGroups($userId)}) {
		WebGUI::Group->new($self->session,$groupId)->deleteUsers([$userId]);
	}
    $self->friends->delete if ($self->{_user}{"friendsGroup"} ne "");
	$db->write("delete from inbox where userId=? and (groupId is null or groupId='')",[$userId]);
	require WebGUI::Operation::Auth;
	my $authMethod = WebGUI::Operation::Auth::getInstance($self->session,$self->authMethod,$userId);
	$authMethod->deleteParams($userId);
	my $rs = $db->read("select sessionId from userSession where userId=?",[$userId]);
	while (my ($id) = $rs->array) {
        	$db->write("delete from userSessionScratch where sessionId=?",[$id]);
	}
    $db->write("delete from userSession where userId=?",[$userId]);
    $db->write("delete from userProfileData where userId=?",[$userId]);
    $db->write("delete from users where userId=?",[$userId]);
}

#-------------------------------------------------------------------

=head2 deleteFromGroups ( groups )

Deletes this user from the specified groups.

=head3 groups

An array reference containing a list of groups.

=cut

sub deleteFromGroups {
	my $self = shift;
	my $groups = shift;
	$self->uncache;
	foreach my $groupId (@{$groups}) {
		WebGUI::Group->new($self->session,$groupId)->deleteUsers([$self->userId]);
	}
	$self->session->stow->delete("gotGroupsForUser");
}

#-------------------------------------------------------------------

=head2 DESTROY ( )

Deconstructor.

=cut

sub DESTROY {
        my $self = shift;
        if (exists $self->{_friendsGroup}) {
            $self->{_friendsGroup}->DESTROY;
        }
        undef $self;
}


#-------------------------------------------------------------------

=head2 friends ( )

Returns the WebGUI::Group for this user's Friend's Group.  

=cut

sub friends {
    my $self = shift;
    my $myFriends;

    # If the user already has a friend group fetch it.
    if ( $self->{_user}{"friendsGroup"} ne "" ) {
        if ( ! exists $self->{_friendsGroup} ) {
            # Friends group is not in cache, so instantiate and cache it.
            $myFriends = WebGUI::Group->new($self->session, $self->{_user}{"friendsGroup"});
            $self->{_friendsGroup} = $myFriends;
        }
        else {
            # Friends group is cached, so fetch it from cache.
            $myFriends = $self->{_friendsGroup};
        }
    }

    # If there's no instantiated friends group, either the user has none yet or the group has been deleted. 
    # Whatever the reason may be, we need to create a new friends group for this user.
    unless ( $myFriends ) {
        $myFriends = WebGUI::Group->new($self->session, "new",0,1);
        $myFriends->name($self->username." Friends");
        $myFriends->description("Friends of user ".$self->userId);
        $myFriends->expireOffset(60*60*24*365*60);
        $myFriends->showInForms(0);
        $myFriends->isEditable(0);
        $self->uncache;
        $self->{_user}{"friendsGroup"} = $myFriends->getId;
        $self->{_user}{"lastUpdated"} = $self->session->datetime->time();
        $self->session->db->write("update users set friendsGroup=?, lastUpdated=? where userId=?",
            [$myFriends->getId, $self->session->datetime->time(), $self->userId]);
        $self->{_friendsGroup} = $myFriends;
    }

    return $myFriends;
}

#-------------------------------------------------------------------

=head2 getFirstName ( )

Returns first name, or alias, or username depeneding upon what exists.

=cut

sub getFirstName {
    my $self = shift;
    return $self->profileField('firstName') || $self->profileField('alias') || $self->username;
}   

#-------------------------------------------------------------------

=head2 getGroups ( [ withoutExpired ] )

Returns an array reference containing a list of groups this user is in.  Group lookups are cached.
If a cached lookup is returned, it will be a safe copy of the data in the cache.

=head3 withoutExpired

If set to "1" then the listing will not include expired groupings. Defaults to "0".

=cut

sub getGroups {
    my $self = shift;
    my $withoutExpired = shift;
    my $clause = "";
    if ($withoutExpired) {
        $clause = "and expireDate>".$self->session->datetime->time();
    }
    my $gotGroupsForUser = $self->session->stow->get("gotGroupsForUser");
    if (exists $gotGroupsForUser->{$self->userId}) {
        my $cachedGroups = $gotGroupsForUser->{$self->userId};
        my @safeCopy = @{ $cachedGroups };
        return \@safeCopy;
    }
    else {
        my @groups = $self->session->db->buildArray("select groupId from groupings where userId=? $clause", [$self->userId]);
        my $isInGroup = $self->session->stow->get("isInGroup");
        foreach my $gid (@groups) {
            $isInGroup->{$self->userId}{$gid} = 1;
        }
        $self->session->stow->set("isInGroup",$isInGroup);
        $gotGroupsForUser->{$self->userId} = \@groups;
        $self->session->stow->set("gotGroupsForUser",$gotGroupsForUser);
        my @safeGroups = @groups;
        return \@safeGroups;
    }
}

#----------------------------------------------------------------------------

=head2 getGroupIdsRecursive ( )

Get the groups the user is in AND all the groups those groups are in, recursively.
Returns a flattened array reference of unique group IDs

=cut

sub getGroupIdsRecursive {
    my $self        = shift;
    my $groupingIds = $self->getGroups( "withoutExpired" );
    my %groupIds    = map { $_ => 1 } @{ $groupingIds };
    while ( my $groupingId = shift @{ $groupingIds } ) {
        my $group   = WebGUI::Group->new( $self->session, $groupingId );
        for my $groupGroupingId ( @{ $group->getGroupsFor } ) { 
            if ( !$groupIds{ $groupGroupingId } ) {
                push @{ $groupingIds }, $groupGroupingId;
            }
            $groupIds{ $groupGroupingId } = 1;
        }
    }

    return [ keys %groupIds ];
}

#-------------------------------------------------------------------

=head2 getProfileFieldPrivacySetting ( [field ])

Returns the privacy setting for the field passed in.  If no field is passed in the entire hash is returned

=head3 field

Field to get privacy setting for.

=cut

sub getProfileFieldPrivacySetting {
    my $self      = shift;
    my $session   = $self->session;
    my $field     = shift;

    unless ($self->{_privacySettings}) {
        #Look it up manually because we want to cache this separately.
        my $privacySettings        = $session->db->quickScalar(
            q{select wg_privacySettings from userProfileData where userId=?},
            [$self->userId]
        );
        $privacySettings          = "{}" unless $privacySettings;
        $self->{_privacySettings} = JSON->new->decode($privacySettings);
    }
    
    return $self->{_privacySettings} unless ($field);

    #No privacy settings returned the privacy setting field
    return "none" if($field eq "wg_privacySettings");

    return $self->{_privacySettings}->{$field};
}   


#-------------------------------------------------------------------

=head2 getProfileUrl ( [page] )

Returns a link to the user's profile

=head3 page

If page is passed in, the profile ops will be appended to the page, otherwise
the method will return the ops appended to the current page.

=cut

sub getProfileUrl {
    my $self      = shift;
    my $session   = $self->session;
    my $page      = shift || $session->url->page;

    my $identifier = $session->config->get("profileModuleIdentifier");

    return qq{$page?op=account;module=$identifier;do=view;uid=}.$self->userId;

}   

#-------------------------------------------------------------------

=head2 getWholeName ( )

Attempts to build the user's whole name from profile fields, and ultimately their alias and username if all else
fails.

=cut

sub getWholeName {
    my $self  = shift;
    if ($self->profileField('firstName') and $self->profileField('lastName')) {
        return join ' ', $self->profileField('firstName'), $self->profileField('lastName');
    }
    return $self->profileField("alias") || $self->username;
}

#-------------------------------------------------------------------

=head2 hasFriends ( )

Returns whether or not the user has any friends on the site.

=cut

sub hasFriends {
    my $self         = shift;
    my $users = $self->friends->getUsers(1);
    return scalar(@{$users}) > 0;
}

#-------------------------------------------------------------------
# This method is depricated and is provided only for reverse compatibility. See WebGUI::Auth instead.
sub identifier {
        my ($self, $value);
        $self = shift;
        $value = shift;
        if (defined $value) {
		$self->uncache;
                $self->{_user}{"identifier"} = $value;
                $self->session->db->write("update authentication set fieldData=".$self->session->db->quote($value)."
                        where userId=".$self->session->db->quote($self->{_userId})." and authMethod='WebGUI' and fieldName='identifier'");
        }
        return $self->{_user}{"identifier"};
}


#-------------------------------------------------------------------

=head2 isAdmin ()

Returns 1 if the user is in the admins group.

=cut

sub isAdmin {
	my $self = shift;
	return $self->isInGroup(3);
}

#-------------------------------------------------------------------

=head2 isInGroup ( [ groupId ] )

Returns a boolean (0|1) value signifying that the user has the required privileges. Always returns true for Admins.

=head3 groupId

The group that you wish to verify against the user. Defaults to group with Id 3 (the Admin group).

=cut

sub isInGroup {
   my (@data, $groupId);
   my ($self, $gid, $secondRun) = @_;
   $gid = 3 unless (defined $gid);
   my $uid = $self->userId;
   ### The following several checks are to increase performance. If this section were removed, everything would continue to work as normal. 
   #my $eh = $self->session->errorHandler;
   #$eh->warn("Group Id is: $gid for ".$tgroup->name);
   return 1 if ($gid eq '7');		# everyone is in the everyone group
   return 1 if ($gid eq '1' && $uid eq '1'); 	# visitors are in the visitors group
   return 1 if ($gid eq '2' && $uid ne '1'); 	# if you're not a visitor, then you're a registered user
   ### Get data for auxillary checks.
   my $isInGroup = $self->session->stow->get("isInGroup", { noclone => 1 });
   ### Look to see if we've already looked up this group. 
   return $isInGroup->{$uid}{$gid} if exists $isInGroup->{$uid}{$gid};
   ### Lookup the actual groupings.
   my $group = WebGUI::Group->new($self->session,$gid);
   # Cope with non-existant groups. Default to the admin group if the groupId is invalid.
   $group = WebGUI::Group->new($self->session, 3) unless $group;
   ### Check for groups of groups.
   my $users = $group->getAllUsers();
   foreach my $user (@{$users}) {
      $isInGroup->{$user}{$gid} = 1;
	  if ($uid eq $user) {
	     $self->session->stow->set("isInGroup",$isInGroup);
		 return 1;
	  }
   }
   $isInGroup->{$uid}{$gid} = 0;
   $self->session->stow->set("isInGroup",$isInGroup);
   return 0;
}


#-------------------------------------------------------------------

=head2 isOnline ()

Returns a boolean indicating whether this user is logged in and actively viewing pages in the site.

=cut

sub isOnline {
    my $self = shift;
    my ($flag) = $self->session->db->quickArray('select count(*) from userSession where userId=? and lastPageView>=?',
        [$self->userId, time() - 60*10]); 
    return $flag;
}

#-------------------------------------------------------------------

=head2 isRegistered ()

Returns 1 if the user is not a visitor.

=cut

sub isRegistered {
	my $self = shift;
	return $self->userId ne '1';
}

#-------------------------------------------------------------------

=head2 isVisitor ()

Returns 1 if the user is a visitor.

=cut

sub isVisitor {
	my $self = shift;
	return $self->userId eq '1';
}


#-------------------------------------------------------------------

=head2 karma ( [ amount, source, description ] )

Returns the current level of karma this user has earned. 

=head3 amount

An integer to modify this user's karma by. Note that this number can be positive or negative.

=head3 source

A descriptive source for this karma. Typically it would be something like "MessageBoard (49)" or "Admin (3)". Source is used to track where a karma modification came from.

=head3 description

A description of why this user's karma was modified. For instance it could be "Message Board Post" or "He was a good boy!".

=cut

sub karma {
	my $self = shift;
	my $amount = shift;
	my $source = shift;
	my $description = shift;
	if (defined $amount && defined $source && defined $description) {
		$self->uncache;
		$self->{_user}{karma} += $amount;
		$self->session->db->write("update users set karma=karma+? where userId=?", [$amount, $self->userId]);
        	$self->session->db->write("insert into karmaLog values (?,?,?,?,?)",[$self->userId, $amount, $source, $description, $self->session->datetime->time()]);
	}
        return $self->{_user}{karma};
}

#-------------------------------------------------------------------

=head2 lastUpdated ( )

Returns the epoch for when this user was last modified.

=cut

sub lastUpdated {
        return $_[0]->{_user}{lastUpdated};
}

#-------------------------------------------------------------------

=head2 new ( session, userId [, overrideId ] )

Constructor.

=head3 session 

The session variable.

=head3 userId 

The userId of the user you're creating an object reference for. If left blank it will default to "1" (Visitor). If specified as "new" then a new user account will be created and assigned the next available userId. 

=head3 overrideId

A unique ID to use instead of the ID that WebGUI will generate for you. It must be absolutely unique and can be up to 22 alpha numeric characters long.

=cut

sub new {
    my $class       = shift;
    my $session     = shift;
    my $userId      = shift || 1;
    my $overrideId  = shift;
    $userId         = _create($session, $overrideId) if ($userId eq "new");
    my $cache       = WebGUI::Cache->new($session,["user",$userId]);
    my $self        = $cache->get || {};
    bless $self, $class;
    $self->{_session} = $session;
    unless ($self->{_userId} && $self->{_user}{username}) {
        my %user;
        tie %user, 'Tie::CPHash';
        %user = $session->db->quickHash("select * from users where userId=?",[$userId]);
        my %profile 
            = $session->db->quickHash(
                "select * from userProfileData where userId=?",
                [$user{userId}]
            );
        delete $profile{userId};

        # remove undefined fields so they will fall back on defaults when requested
        for my $key (keys %profile) {
            if (!defined $profile{$key} || $profile{$key} eq '') {
                delete $profile{$key};
            }
        }

        if (($profile{alias} =~ /^\W+$/ || $profile{alias} eq "") and $user{username}) {
            $profile{alias} = $user{username};
        }
        $self->{_userId}    = $userId;
        $self->{_user}      = \%user,
        $self->{_profile}   = \%profile,
        $self->cache;
    }
    return $self;
}


#-------------------------------------------------------------------

=head2 newByEmail ( session, email )

Instanciates a user by email address. Returns undef if the email address could not be found.
Visitor may not be looked up with this method.

=head3 session

A reference to the current session.

=head3 email

The email address to search for.

=cut

sub newByEmail {
	my $class = shift;
	my $session = shift;
	my $email = shift;
	my ($id) = $session->dbSlave->quickArray("select userId from userProfileData where email=?",[$email]);
	my $user = $class->new($session, $id);
	return undef if ($user->isVisitor); # visitor is never valid for this method
	return undef unless $user->username;
	return $user;
}


#-------------------------------------------------------------------

=head2 newByUsername ( session, username )

Instanciates a user by username. Returns undef if the username could not be found.
Visitor may not be looked up with this method.

=head3 session

A reference to the current session.

=head3 username

The username to search for.

=cut

sub newByUsername {
	my $class = shift;
	my $session = shift;
	my $username = shift;
	my ($id) = $session->dbSlave->quickArray("select userId from users where username=?",[$username]);
	my $user = $class->new($session, $id);
	return undef if ($user->isVisitor); # visitor is never valid for this method
	return undef unless $user->username;
	return $user;
}


#-------------------------------------------------------------------

=head2 profileField ( fieldName [, value ] )

Returns a profile field's value. If "value" is specified, it also sets the field to that value. 

=head3 fieldName 

The profile field name such as "language" or "email" or "cellPhone".

=head3 value

The value to set the profile field name to.

=cut

sub profileField {
    my $self        = shift;
    my $fieldName   = shift;
    my $value       = shift;
    my $db          = $self->session->db;
    return "" if ($fieldName eq "wg_privacySettings");  # this is a special internal field, don't try to process it.
    if (!exists $self->{_profile}{$fieldName} && !$self->session->db->quickScalar("SELECT COUNT(*) FROM userProfileField WHERE fieldName = ?", [$fieldName])) {
        $self->session->errorHandler->warn("No such profile field: $fieldName");
        return undef;
    }
    if (defined $value) {
        $self->uncache;
        $self->{_profile}{$fieldName} = $value;
        $db->write(
            "UPDATE userProfileData SET ".$db->dbh->quote_identifier($fieldName)."=? WHERE userId=?",
            [$value, $self->{_userId}]
        );
        my $time = $self->session->datetime->time;
        $self->{_user}{"lastUpdated"} = $time;
        $self->session->db->write("update users set lastUpdated=? where userId=?", [$time, $self->{_userId}]);
    }
    elsif (!exists $self->{_profile}{$fieldName}) {
        my $default = $self->session->db->quickScalar("SELECT dataDefault FROM userProfileField WHERE fieldName=?", [$fieldName]);
        $self->{_profile}{$fieldName} = WebGUI::Operation::Shared::secureEval($self->session, $default);
        $self->cache;
    }
    if (ref $self->{_profile}{$fieldName} eq 'ARRAY') {
        ##Return a scalar, that is a string with all the defaults
        return join ',', @{ $self->{_profile}{$fieldName} };
    }
	return $self->{_profile}{$fieldName};
}

#-------------------------------------------------------------------

=head2 profileIsViewable ( user  )

Returns whether or not the user's profile is viewable by the user passed in

=head3 user

The user to test to see if the profile is viewable for.  If no user is passed in,
the current user in session will be tested

=cut

sub profileIsViewable {
    my $self     = shift;
    my $user     = shift || $self->session->user;
    my $userId   = $user->userId;

    return 0 if ($self->isVisitor);  #Can't view visitor's profile
    return 1 if ($self->userId eq $userId);  #Users can always view their own profile

    my $profileSetting = $self->profileField('publicProfile');
    
    return 0 if ($profileSetting eq "none");
    return 1 if ($profileSetting eq "all");

    my $friendsGroup = $self->friends;
    return $user->isInGroup($friendsGroup->getId);
}

#-------------------------------------------------------------------

=head2 referringAffiliate ( [ value ] )

Returns the unique identifier of the affiliate that referred this user to the site. 

=head3 value

An integer containing the unique identifier of the affiliate.

=cut

sub referringAffiliate {
        my $self = shift;
        my $value = shift;
        if (defined $value) {
		$self->uncache;
                $self->{_user}{"referringAffiliate"} = $value;
                $self->{_user}{"lastUpdated"} =$self->session->datetime->time();
                $self->session->db->write("update users set referringAffiliate=".$self->session->db->quote($value).",
                        lastUpdated=".$self->session->datetime->time()." where userId=".$self->session->db->quote($self->userId));
        }
        return $self->{_user}{"referringAffiliate"};
}

#-------------------------------------------------------------------

=head2 session ( ) 

Returns a reference to the current session.

=cut

sub session {
	my $self = shift;
	return $self->{_session};
}


#-------------------------------------------------------------------

=head2 setProfileFieldPrivacySetting ( settings ) 

Sets the profile field privacy settings

=head3 settings

hash ref containing the field and it's corresponding privacy setting

=cut

sub setProfileFieldPrivacySetting {
    my $self     = shift;
    my $session  = $self->session;
    my $settings = shift;
    
    return undef unless scalar(keys %{$settings});

    #Get the current settings
    my $currentSettings = $self->getProfileFieldPrivacySetting;
    
    foreach my $fieldId (keys %{$settings}) {
        my $privacySetting = $settings->{$fieldId};
        next unless (WebGUI::Utility::isIn($privacySetting,qw(all none friends)));
        $currentSettings->{$fieldId} = $settings->{$fieldId};
    }
    
    #Store the data in the database
    my $json = JSON->new->encode($currentSettings);
    $session->db->write("update userProfileData set wg_privacySettings=? where userId=?",[$json,$self->userId]);

    #Recache the current settings
    $self->{_privacySettings} = $currentSettings;
}


#-------------------------------------------------------------------

=head2 status ( [ value ] )

Returns the status of the user. 

=head3 value

If specified, the status is set to this value.  Possible values are 'Active', 'Selfdestructed' and 'Deactivated'.
'Selfdestructed' means that the user deactivated their own account.  'Deactivated' means that either
their status has been changed by an Admin, or that this is a new account that is pending email
confirmation before activation.

=cut

sub status {
	my $self = shift;
	my $value = shift;
	if (defined $value) {
		$self->uncache;
		$self->{_user}{"status"} = $value;
		$self->{_user}{"lastUpdated"} =$self->session->datetime->time();
		$self->session->db->write("update users set status=".$self->session->db->quote($value).",
		lastUpdated=".$self->session->datetime->time()." where userId=".$self->session->db->quote($self->userId));
		if ($value eq 'Deactivated') {
			my $rs = $self->session->db->read("select sessionId from userSession where userId=?",[$self->{_userId}]);
			while (my ($id) = $rs->array) {
				$self->session->db->write("delete from userSessionScratch where sessionId=?",[$id]);
			}
			$self->session->db->write("delete from userSession where userId=?",[$self->{_userId}]);
		}
	}
	return $self->{_user}{"status"};
}

#-------------------------------------------------------------------

=head2 uncache ( )

Deletes this user object out of the cache.

=cut

sub uncache {
	my $self = shift;
	my $cache = WebGUI::Cache->new($self->session,["user",$self->userId]);
	$cache->delete;
}

#-------------------------------------------------------------------

=head2 updateProfileFields ( profile )

Saves profile data to a user's profile.  Does not validate any of the data.

=head3 profile

Hash ref of key/value pairs of data in the users's profile to update.

=cut

sub updateProfileFields {
    my $self    = shift;
    my $profile = shift;

	foreach my $fieldName (keys %{$profile}) {
		$self->profileField($fieldName,$profile->{$fieldName});
	}
}

#-------------------------------------------------------------------

=head2 username ( [ value ] )

Returns the username. 

=head3 value

If specified, the username is set to this value. 

=cut

sub username {
    my $self = shift;
    my $value = shift;
    if (defined $value) {
        $self->uncache;
        $self->{_user}{"username"} = $value;
        $self->{_user}{"lastUpdated"} = $self->session->datetime->time();
        $self->session->db->write("update users set username=?, lastUpdated=? where userId=?",
            [$value, $self->session->datetime->time(), $self->userId]);
    }
    return $self->{_user}{"username"};
}

#-------------------------------------------------------------------

=head2 userId ( )

Returns the userId for this user.

=cut

sub userId {
        return $_[0]->{_userId};
}

#-------------------------------------------------------------------

=head2 validateProfileDataFromForm ( fields )

Validates profile data from the session form variables.  Returns an data structure which contains the following

{
    profile        => Hash reference containing all of the profile fields and their values
    errors         => Array reference of error messages to be displayed
    errorCategory  => Category in which the first error was thrown
    warnings       => Array reference of warnings to be displayed
    errorFields    => Array reference of the fieldIds that threw an error
    warningFields  => Array reference of the fieldIds that threw a warning
}

=head3 fields

An array reference of profile field Ids to validate.

=cut

sub validateProfileDataFromForm {
	my $self        = shift;
    my $session     = $self->session;
	my $fields      = shift;

    my $i18n        = WebGUI::International->new($session);

    my $data        = {};
    my $errors      = [];
    my $warnings    = [];
    my $errorCat    = undef;
    my $errorFields = [];
    my $warnFields  = [];
    
	FIELD: foreach my $field (@{$fields}) {
        my $fieldId       = $field->getId;
        my $fieldLabel    = $field->getLabel;
    	my $fieldValue    = $field->formProcess;
        my $isValid       = $field->isValid($fieldValue);

        if(!$isValid) {
            $errorCat = $field->get("profileCategoryId") unless (defined $errorCat);
            push (@{$errors}, sprintf($i18n->get("required error"),$fieldLabel));
            push(@{$errorFields},$fieldId);
        }
        #The language field is special and must be always be valid or WebGUI will croak
        elsif($fieldId eq "language" && !(exists $i18n->getLanguages()->{$fieldValue})) {
            $errorCat = $field->get("profileCategoryId") unless (defined $errorCat);
            push (@{$errors}, sprintf($i18n->get("language not available error"),$fieldValue));
            push(@{$errorFields},$fieldId);
        }
        #Duplicate emails throw warnings
        elsif($fieldId eq "email" && $field->isDuplicate($fieldValue,$self->userId)) {
            $errorCat = $field->get("profileCategoryId") unless (defined $errorCat);
            push (@{$warnings},$i18n->get(1072));
            push(@{$warnFields},$fieldId);
        }

        ##Do not return data unless the form field was actually in the posted data.
        next FIELD unless $field->isInRequest;
        $data->{$fieldId} = (ref $fieldValue eq "ARRAY") ? $fieldValue->[0] : $fieldValue;

    }

	return {
        profile       => $data,
        errors        => $errors,
        warnings      => $warnings,
        errorCategory => $errorCat,
        errorFields   => $errorFields,
        warningFields => $warnFields,
    };
}

#-------------------------------------------------------------------

=head2 validUserId ( userId )

Returns true if the userId exists in the users table. 

=cut

sub validUserId {
	my ($class, $session, $userId) = @_;
	my $sth = $session->db->read('select userId from users where userId=?',[$userId]);
	return ($sth->rows == 1);
}

1;
