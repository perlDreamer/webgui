package WebGUI::Asset::Wobject::EventManagementSystem;

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
use base 'WebGUI::Asset::Wobject';
use Tie::IxHash;
use WebGUI::HTMLForm;
use JSON;
use WebGUI::Workflow::Instance;
use WebGUI::Cache;
use WebGUI::International;
use WebGUI::Commerce::ShoppingCart;
use WebGUI::Commerce::Item;
use WebGUI::Utility;
use Data::Dumper;



#-------------------------------------------------------------------
sub _getFieldHash {
	my $self = shift;
	return $self->{_fieldHash} if ($self->{_fieldHash});

	my %hash;
	tie %hash, "Tie::IxHash";
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	%hash = (
		"eventName"=>{
			name=>$i18n->get('add/edit event title'),
			type=>"text",
			compare=>"text",
			method=>"text",
			columnName=>"title",
			tableName=>"p",
			initial=>1
		},
		"eventDescription"=>{
			name=>$i18n->get("add/edit event description"),
			type=>"text",
			compare=>"text",
			method=>"text",
			columnName=>"description",
			tableName=>"p",
			initial=>1
		},
		"maxAttendees"=>{
			name=>$i18n->get("add/edit event maximum attendees"),
			type=>"text",
			compare=>"numeric",
			method=>"integer",
			columnName=>"maximumAttendees",
			tableName=>"e",
			initial=>1
		},
		"seatsAvailable"=>{
			name=>$i18n->get("seats available"),
			type=>"text",
			method=>"integer",
			compare=>"numeric",
			calculated=>1,
			initial=>1
		},
		"price"=>{
			name=>$i18n->get("add/edit event price"),
			type=>"text",
			compare=>"numeric",
			method=>"float",
			columnName=>"price",
			tableName=>"p",
			initial=>1
		},
		"startDate"=>{
			name=>$i18n->get("add/edit event start date"),
			type=>"dateTime",
			compare=>"numeric",
			method=>"dateTime",
			columnName=>"startDate",
			tableName=>"e",
			initial=>1
		},
		"endDate"=>{
			name=>$i18n->get("add/edit event end date"),
			type=>"dateTime",
			compare=>"numeric",
			method=>"dateTime",
			columnName=>"endDate",
			tableName=>"e",
			initial=>1
		},
		"requirement"=>{
			name=>$i18n->get('add/edit event required events'),
			type=>"select",
			list=>{''=>$i18n->get('select one'),$self->_getAllEvents()},
			compare=>"boolean",
			method=>"selectBox",
			calculated=>1,
			initial=>0
		}
	);
	# Add custom metadata fields to the list, matching the types up
	# automatically.
	my $fieldList = $self->getEventMetaDataArrayRef;
	foreach my $field (@{$fieldList}) {
	    next unless $field->{visible};
		my $dataType = $field->{dataType};
		my $compare = $self->_matchTypes($dataType);
		my $type;
		if ($dataType =~ /^date/i) {
			$type = lcfirst($dataType);
		} elsif ($compare eq 'text' || $compare eq 'numeric') {
			$type = 'text';
		} else {
			$type = 'select';
		}
		$hash{$field->{fieldId}} = {
			name=>$field->{label},
			type=>$type,
			method=>$dataType,
			initial=>$field->{autoSearch},
			compare=>$compare,
			calculated=>1,
			metadata=>1
		};
		if ($hash{$field->{fieldId}}->{type} eq 'select') {
			$hash{$field->{fieldId}}->{list} = $self->_matchPairs($field->{possibleValues});
		}
	}
	$self->{_fieldHash} = \%hash;
	return $self->{_fieldHash};
}

#-------------------------------------------------------------------
sub _acWrapper {
	my $self = shift;
	my $html = shift;
	my $title = shift;
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	$self->getAdminConsole->setHelp('add/edit event','Asset_EventManagementSystem');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=search'),$i18n->get("manage events"));
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=manageEventMetadata'), $i18n->get('manage event metadata'));
		$self->getAdminConsole->addSubmenuItem($self->getUrl('func=managePrereqSets'), $i18n->echo('manage prerequisite sets'));
	return $self->getAdminConsole->render($html,$title);
}

	
#-------------------------------------------------------------------

sub _matchPairs {
	my $self = shift;
	my $options = shift;
	my %hash;
	tie %hash, 'Tie::IxHash';
	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
	$hash{''} = $i18n->get('select one');
	foreach (split("\n",$options)) {
		my $val = $_;
		#$val =~ s/\s//g;
		$val =~ s/\r//g;
		$val =~ s/\n//g;
		$hash{$val} = $val;
	}
	return \%hash;
}
	
#-------------------------------------------------------------------

sub _matchTypes {
	my $self = shift;
	my $dataType = lc(shift);
	return 'text' if (
		WebGUI::Utility::isIn($dataType, qw(
			codearea
			email
			htmlarea
			phone
			text
			textarea
			url
			zipcode
		))
	);
	return 'numeric' if (
		WebGUI::Utility::isIn($dataType, qw(
			date
			datetime
			float
			integer
			interval
		))
	);
	return 'boolean' if (
		WebGUI::Utility::isIn($dataType, qw(
			checkbox
			combo
			selectlist
			checklist
			contenttype
			databaselink
			fieldtype
			group
			ldaplink
			radio
			radiolist
			selectbox
			template
			timezone
			yesno
		))
	);
	return 'text';
}

#-------------------------------------------------------------------

sub _getAllEvents {
	my $self = shift;
	my $conditionalWhere;
	if ($self->get("globalPrerequisites") == 0) {
		$conditionalWhere = "and e.assetId=".$self->session->db->quote($self->get('assetId'));
	}
	my $sql = "select p.productId, p.title from products as p, EventManagementSystem_products as e
		   where p.productId = e.productId $conditionalWhere";
	return $self->session->db->buildHash($sql);
}

#-------------------------------------------------------------------
#
# Temporary Shopping Cart to store subevent selections for prerequisite and conflict checking
# Contents are moved to real shopping cart after attendee information is entered and the scratchCart gets emptied.
#
sub addToScratchCart {
	my $self = shift;
	my $event = shift;

	my @eventsInCart = split("\n",$self->session->scratch->get('EMS_scratch_cart'));
	push(@eventsInCart, $event) unless isIn($event,@eventsInCart);

	$self->session->scratch->delete('EMS_scratch_cart');
	$self->session->scratch->set('EMS_scratch_cart', join("\n", @eventsInCart));
}

#-------------------------------------------------------------------

sub canApproveEvents {
	my $self = shift;
	return $self->session->user->isInGroup($self->get("groupToApproveEvents"));
}


#-------------------------------------------------------------------

sub canAddEvents {
	my $self = shift;
	return $self->session->user->isInGroup($self->get("groupToAddEvents"));
}


#-------------------------------------------------------------------

sub buildMenu {
	my $self = shift;
	my $var = shift;
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $fields = $self->_getFieldHash();
	my $counter = 0;
	my $js = "var filterList = {\n";
	foreach my $fieldId (keys %{$fields}) {
		my $field = $fields->{$fieldId};
		next if $fieldId eq 'requirement';
		$js .= ",\n" if($counter++ > 0);
		my $fieldName = $field->{name};
		my $fieldType = $field->{type};
		my $compareType = $field->{compare};
		my $autoSearch = $field->{initial};
		$js .= qq|"$fieldId": {|;
		$js .= qq| "name":"$fieldName"|;
		$js .= qq| ,"type":"$fieldType"|;
		$js .= qq| ,"compare":"$compareType"|;
		$js .= qq| ,"autoSearch":"$autoSearch"|;
		if($fieldType eq "select") {
			my $list = $field->{list};
			my $fieldList = "";
			foreach my $key (keys %{$list}) {
				$fieldList .= "," if($fieldList ne "");
				my $value = $list->{$key};
				$value =~ s/"/\"/g;
				$fieldList .= qq|"$key":"$value"|
			}
			$js .= qq| ,"list":{ $fieldList }|;
		}
		$js .= q| }|;
	}
	$js .= "\n};\n";
	
	$var->{'search.filters.options'} = $js;
	$var->{'search.data.url'} = $self->getUrl;
}

#-------------------------------------------------------------------

=head2 checkConflicts ( )

Check for scheduling conflicts in events in the user's cart.  A conflict is defined as
whenever two events have overlapping times.

=cut

sub checkConflicts {
	my $self = shift;
#	my $eventsInCart = $self->getEventsInCart;
	my $checkSingleEvent = shift;
	my $eventsInCart = $self->getEventsInScratchCart;
	# $self->session->errorHandler->warn(Dumper($eventsInCart));
	my @schedule;
	
	# Get schedule info for events in cart and sort asc by start date
	my $sth = $self->session->db->read("
		select productId, startDate, endDate from EventManagementSystem_products
		where productId in (".$self->session->db->quoteAndJoin($eventsInCart).")
		order by startDate"
	);
	
	# Build our schedule
	while (my $scheduleData = $sth->hashRef) {
	
		# make sure it's a subevent... 
		my ($isSubEvent) = $self->session->db->quickArray("
			select count(*) from EventManagementSystem_products
			where (prerequisiteId is not null or prerequisiteId != '') and productId=?", [$scheduleData->{productId}]
		);
		next unless ($isSubEvent);
				
		push(@schedule, $scheduleData);
	}
	my $singleData = {};
	$singleData = $self->session->db->quickHashRef("select productId, startDate, endDate from EventManagementSystem_products where productId=?", [$checkSingleEvent]) if $checkSingleEvent;
	
	# Check the schedule for conflicts
	for (my $i=0; $i < scalar(@schedule); $i++) {
		next if ($i == 0 && !$checkSingleEvent);
		if ($checkSingleEvent) {
			return 1 if ($singleData->{startDate} < $schedule[$i]->{endDate} && $singleData->{endDate} > $schedule[$i]->{startDate});
		}	else {
			unless ($schedule[$i]->{startDate} > $schedule[$i-1]->{endDate}) {
				 #conflict
				return [{ 'event1'    => $schedule[$i]->{productId},
					  'event2'    => $schedule[$i-1]->{productId},
					  'type'      => 'conflict'
				       }]; 	
			}
		}
	}
	return 0 if $checkSingleEvent;
	return [];
}

#-------------------------------------------------------------------

=head2 checkRequiredFields ( requiredFields )

Check for null form fields.

Returns an array reference containing error messages

=head3 requiredFields

A hash reference whose keys correspond to field names and values correspond to the field name as it should be shown to the user in an error.

=cut

sub checkRequiredFields {
  my $self = shift;
  my $requiredFields = shift;
  my @errors;
  
  foreach my $requiredField (keys %{$requiredFields}) {
    if ($self->session->form->get($requiredField) eq "") {
      push(@errors, {
        type  	  => "nullField",
        fieldName => $requiredFields->{"$requiredField"}
        }
      );
    }

  }
        
  return \@errors;    
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	my $i18n = WebGUI::International->new($session,'Asset_EventManagementSystem');
	%properties = (
			displayTemplateId =>{
				fieldType=>"template",
				defaultValue=>'EventManagerTmpl000001',	
				tab=>"display",
				namespace=>"EventManagementSystem",
                		hoverHelp=>$i18n->get('display template description'),
                		label=>$i18n->get('display template')
				},
			checkoutTemplateId =>{
				fieldType=>"template",
				defaultValue=>'EventManagerTmpl000003',
				tab=>"display",
				namespace=>"EventManagementSystem_checkout",
                		hoverHelp=>$i18n->get('checkout template description'),
                		label=>$i18n->get('checkout template')
				},
			managePurchasesTemplateId =>{
				fieldType=>"template",
				defaultValue=>'EventManagerTmpl000004',
				tab=>"display",
				namespace=>"EventManagementSystem_managePurchas",
                		hoverHelp=>$i18n->get('manage purchases template description'),
                		label=>$i18n->get('manage purchases template')
				},
			viewPurchaseTemplateId =>{
				fieldType=>"template",
				defaultValue=>'EventManagerTmpl000005',
				tab=>"display",
				namespace=>"EventManagementSystem_viewPurchase",
                		hoverHelp=>$i18n->get('view purchase template description'),
                		label=>$i18n->get('view purchase template')
				},
			searchTemplateId =>{
				fieldType=>"template",
				defaultValue=>'EventManagerTmpl000006',
				tab=>"display",
				namespace=>"EventManagementSystem_search",
                		hoverHelp=>$i18n->get('search template description'),
                		label=>$i18n->get('search template')
				},
			paginateAfter =>{
				fieldType=>"integer",
				defaultValue=>10,
				tab=>"display",
				hoverHelp=>$i18n->get('paginate after description'),
				label=>$i18n->get('paginate after')
				},
			groupToAddEvents =>{
				fieldType=>"group",
				defaultValue=>3,
				tab=>"security",
				hoverHelp=>$i18n->get('group to add events description'),
				label=>$i18n->get('group to add events')
				},
			groupToApproveEvents =>{
				fieldType=>"group",
				defaultValue=>3,
				tab=>"security",
				hoverHelp=>$i18n->get('group to approve events description'),
				label=>$i18n->get('group to approve events')
				},
			globalPrerequisites  =>{
				fieldType=>"yesNo",
				defaultValue=>1,
				tab=>"properties",
				label=>$i18n->get('global prerequisite'),
				hoverHelp=>$i18n->get('global prerequisite description')
				},
			globalMetadata  =>{
				fieldType=>"yesNo",
				defaultValue=>1,
				tab=>"properties",
				label=>$i18n->get('global metadata'),
				hoverHelp=>$i18n->get('global metadata description')
				},
		);
	push(@{$definition}, {
		assetName=>$i18n->get('assetName'),
		icon=>'ems.gif',
		autoGenerateForms=>1,
		tableName=>'EventManagementSystem',
		className=>'WebGUI::Asset::Wobject::EventManagementSystem',
		properties=>\%properties
		});
	return $class->SUPER::definition($session,$definition);
}

#------------------------------------------------------------------

=head2 deleteOrphans ( )

Utility method that checks for prerequisite groupings that no longer have any events assigned to them and deletes it

=cut

sub deleteOrphans {
	my $self = shift;
	
	# MSW Note - as this is on 4/27/2006, I don't think query will ever return any results.
	
	#Check for orphaned prerequisite definitions
	my @orphans = $self->session->db->quickArray("select p.prerequisiteId from EventManagementSystem_prerequisites as p 
							left join EventManagementSystem_prerequisiteEvents as pe 
							on p.prerequisiteId = pe.prerequisiteId 
							where pe.prerequisiteId is null");
	foreach my $orphan (@orphans) {
		$self->session->db->write("delete from EventManagementSystem_prerequisites where prerequisiteId=".
					   $self->session->db->quote($orphan));
		

	} 
}

#-------------------------------------------------------------------
sub emptyScratchCart {
	my $self = shift;	
	$self->session->scratch->delete('EMS_scratch_cart');
}

#-------------------------------------------------------------------

=head2 error ( errors, callback )

Generates error messages and calls specified method to display them.

=head3 errors

An array reference containing an error stack

=cut

=head3 callback

The method to call and pass the generated error messages to for display to the user

=cut

sub error {
	my $self = shift;
	my $errors = shift;
	my $callback = shift;
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my @errorMessages;
	
	foreach my $error (@$errors) {
		#Null Field Error
		if ($error->{type} eq "nullField") {
		  push(@errorMessages, sprintf($i18n->get('null field error'),$error->{fieldName}));
		}
		
		#General Error Message
		elsif ($error->{type} eq "general") {
		  push(@errorMessages, $error->{message});
		}
		
		#Scheduling Conflict
		elsif ($error->{type} eq "conflict") {
		  push(@errorMessages, $self->resolveConflictForm($error->{event1}, $error->{event2}));
		}
		
		elsif ($error->{type} eq "special") {
		  push(@errorMessages, unpack("u",$error->{message}));
		}
	}
	return $self->$callback(\@errorMessages);
}

#------------------------------------------------------------------

=head2 eventIsApproved ( eventId )

Returns approval status of a specified event

=head3 eventId

Id of event whose approval status you are trying to determine

=cut

sub eventIsApproved {
	my $self = shift;
	my $eventId = shift;
	my ($result) = $self->session->db->quickArray("select approved from EventManagementSystem_products where productId=?",[$eventId]);
	return $result;
}

#------------------------------------------------------------------

=head2 getAssignedPrerequisites ( eventId )

Returns prerequisiteId of every prerequisite grouping assigned to eventId passed in.

=head3 eventId

Id of the event whose prerequisites you want returned

=cut

sub getAssignedPrerequisites {
	my $self = shift;
	my $eventId = shift;
	my $returnProductIdFlag = shift;
	my $sql;

	unless ($returnProductIdFlag) {
		$sql = "select prereqs.prerequisiteId, prereqs.operator from EventManagementSystem_prerequisites as prereqs, EventManagementSystem_products as p 
			where prereqs.prerequisiteId = p.prerequisiteId and p.productId=?";
	}
	else {
		$sql = "select prereqs.prerequisiteId, prereqs.operator from EventManagementSystem_prerequisites as prereqs, EventManagementSystem_products as p 
		   where where prereqs.prerequisiteId = p.prerequisiteId and p.productId=?";
	}
	
	return $self->session->db->buildHashRef($sql,[$eventId]); 
}

#------------------------------------------------------------------

=head2 getEventsInCart ( )

Returns an array ref of all items in the cart, by id.

=cut

sub getEventsInCart {
	my $self = shift;
	my $cart = WebGUI::Commerce::ShoppingCart->new($self->session);
	my ($cartItems) = $cart->getItems;
	
	my @eventsInCart = map { $_->{item}->id } @{ $cartItems };

	return \@eventsInCart;
}

#------------------------------------------------------------------
sub getEventsInScratchCart {
	my $self = shift;
	my @eventsInCart = split("\n",$self->session->scratch->get('EMS_scratch_cart'));
	return \@eventsInCart;
}

#------------------------------------------------------------------
sub getEventName {
	my $self = shift;
	my $eventId = shift;
	
	my ($eventName) = $self->session->db->quickArray("select title from products where productId=?",[$eventId]);
	
	return $eventName;
}


#------------------------------------------------------------------

=head2 getPrerequisiteEventList ( eventId )

Returns hash reference of EventId, Name pairs of events that qualify to be a specified Event Id's prerequisite

This method returns all events except for
 a) the event matching the eventId parameter passed in AND
 b) any events currently assigned as a prerequisite to the eventId parameter passed in
as a hash reference with the productId, and title

 Checks property globalPrerequisites to determine if events from all defined Event Managers should be displayed
 or only the events defined in this particular Event Manager

=head3 eventId

Id of the event that you want to return eligible prerequisites for

=cut

sub getPrerequisiteEventList {
	my $self = shift;
	my $eventId = shift;
	my $conditionalWhere;
	
	if ($self->get("globalPrerequisites") == 0) {
		$conditionalWhere = "and e.assetId=".$self->session->db->quote($self->get('assetId'));
	}
	
	my $sql = "select p.productId, p.title from products as p, EventManagementSystem_products as e
		   where p.productId = e.productId 
		         and p.productId !=".$self->session->db->quote($eventId)."
		         $conditionalWhere
		         and p.productId not in
		         (select requiredProductId from EventManagementSystem_prerequisites as p,
							EventManagementSystem_prerequisiteEvents as pe 
			  where p.prerequisiteId = pe.prerequisiteId 
			        and p.productId=".$self->session->db->quote($eventId).")";
	
	return $self->session->db->buildHashRef($sql);
}


#------------------------------------------------------------------

=head2 getEventMetaDataArrayRef (  )

Returns an arrayref of hash references of the metadata fields.

Checks $self->get("globalMetadata") by default; otherwise uses the first parameter.

=head3 useGlobalMetadata

Whether or not to use the asset's global setting, and the override.

=cut

sub getEventMetaDataArrayRef {
	my $self = shift;
	my $useGlobalMetadata = shift;
	my $productId = shift;
	$useGlobalMetadata = ($useGlobalMetadata)?$useGlobalMetadata:$self->get("globalMetadata");
	my $globalWhere = ($useGlobalMetadata == 0 || $useGlobalMetadata == 'false')?" where assetId='".$self->getId."'":'';
	return $self->getEventMetaDataFields($productId) if $productId;
	return $self->session->db->buildArrayRefOfHashRefs("select * from EventManagementSystem_metaField $globalWhere order by sequenceNumber, assetId");
}


#-------------------------------------------------------------------

=head2 getEventMetaDataFields ( productId )

Returns a hash reference containing all metadata field properties.

=head3 productId

Which product to get metadata for.

=cut

sub getEventMetaDataFields {
	my $self = shift;
	my $productId = shift;
	my $useGlobalMetadata = shift;
	my $globalWhere = ($useGlobalMetadata == 0 || $useGlobalMetadata == 'false')?" where f.assetId='".$self->getId."'":'';
	my $sql = "select f.*, d.fieldData
		from EventManagementSystem_metaField f
		left join EventManagementSystem_metaData d on f.fieldId=d.fieldId and d.productId=".$self->session->db->quote($productId)." $globalWhere order by f.sequenceNumber";
		tie my %hash, 'Tie::IxHash';
		my $sth = $self->session->db->read($sql);
		while( my $h = $sth->hashRef) {
			foreach(keys %$h) {
				$hash{$h->{fieldId}}{$_} = $h->{$_};
			}
		}
	$sth->finish;
	return \%hash;
}

#------------------------------------------------------------------

sub getBadgeSelector {
	my $self = shift;
	my $output;
	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
	my $selfName = ($self->session->var->get('userId') ne '1') ? $self->session->user->profileField('firstName').' '.$self->session->user->profileField('lastName').' ('.$i18n->get('you').')' : $i18n->get('create a badge for myself');
	$selfName = $i18n->get('create a badge for myself') if $selfName eq '  ('.$i18n->get('you').')';
	my %options;
	tie %options, 'Tie::IxHash';
	%options = (
		'thisIsI' => $selfName,
		'new' => $i18n->get('create a badge for someone else')
	);
	my $isAdmin = $self->canAddEvents;
	
	my $badges = {};
	my $me = $self->session->var->get('userId');
	my $addBadgeId = $self->session->scratch->get('EMS_add_purchase_badgeId');
	
	if ($isAdmin) {
		# all badges in the system.
		$badges = $self->session->db->buildHashRef("select badgeId, CONCAT(lastName,', ',firstName) from EventManagementSystem_badges order by lastName");
	} elsif ($me eq '1') {
		#none
		$badges = {};
		%options = ();
	} else {
		#badges we have purchased.
		$badges = $self->session->db->buildHashRef("select b.badgeId, CONCAT(b.lastName,', ',b.firstName) from EventManagementSystem_badges as b where b.userId='".$me."' or b.createdByUserId='".$me."' order by b.lastName");
	}
	if ($addBadgeId) {
		$badges = $self->session->db->buildHashRef("select badgeId, CONCAT(lastName,', ',firstName) from EventManagementSystem_badges where badgeId=?",[$addBadgeId]);
		%options = ();
	}
	my $js;
	my %badgeJS;
	my $defaultBadge;
	my $IHaveOne = 0;
	foreach (keys %$badges) {
		$badgeJS{$_} = $self->session->db->quickHashRef("select * from EventManagementSystem_badges where badgeId=?",[$_]);
		$defaultBadge ||= $badgeJS{$_}->{badgeId};
		if ($badgeJS{$_}->{userId} eq $me) {
			# we have a match!
			$IHaveOne = 1;
			delete $options{'thisIsI'};
			$defaultBadge = $badgeJS{$_}->{badgeId};
		}
	}
	if (!$IHaveOne && !$isAdmin && $me ne '1') {
		$defaultBadge = 'thisIsI';
		my $meUser = WebGUI::User->new($me);
		$badgeJS{'thisIsI'} = {
			firstName=>$meUser->profileField('firstName'),
			lastName=>$meUser->profileField('lastName'),
			'address'=>$meUser->profileField('homeAddress'),
			city=>$meUser->profileField('homeCity'),
			state=>$meUser->profileField('homeState'),
			zipCode=>$meUser->profileField('homeZip'),
			country=>$meUser->profileField('homeCountry'),
			phone=>$meUser->profileField('homePhone'),
			email=>$meUser->profileField('email')
		};
	}
	$js = '<script type="text/javascript">
	var badges = '.objToJson(\%badgeJS,{autoconv=>0, skipinvalid=>1}).';
	</script>';
	%options = (%options,%{$badges});
	$output .= WebGUI::Form::selectBox($self->session,{
		name => 'badgeId',
		options => \%options,
		value => ($addBadgeId ? $addBadgeId : $defaultBadge),
		extras => 'onchange="swapBadgeInfo(this.value)" onkeyup="swapBadgeInfo(this.value)"'
	}).($addBadgeId ? WebGUI::Form::hidden($self->session,{
		name => 'badgeId',value=>$addBadgeId
	}) : '');
	
	return $js.$output if scalar(keys(%options));
	return '';
}

#------------------------------------------------------------------

=head2 getRequiredEventName ( prerequisiteId )

Returns names of every event assigned to the prerequisite grouping of the prerequisite group id passed in

=head3 prerequisiteId

Id of the prerequisite group whose assigned event names you want returned

=cut

sub getRequiredEventNames {
	my $self = shift;
	my $prerequisiteId = shift;
	#use Data::Dumper;
	#$self->session->errorHandler->warn("<pre>".Dumper($prerequisiteId)."</pre>");
	
	my $sql = "select title from products as p, EventManagementSystem_prerequisites as pr, EventManagementSystem_prerequisiteEvents as pe
		   where 
		     pe.requiredProductId = p.productId 
		     and pr.prerequisiteId = pe.prerequisiteId 
		     and pr.prerequisiteId=?";
	
	return $self->session->db->buildArrayRef($sql,[$prerequisiteId]);
}

#------------------------------------------------------------------
#sub findSubEvents {
#	my $self = shift;
#	my $eventId = shift;
#	my $returnEverythingFlag = shift;
#
#	my $eventsInCart = $self->getEventsInScratchCart;
#	
#	# Get the prerequisites for the sub events passed in
#	my $subEventPrerequisites = $self->getSubEventPrerequisites($eventId);
#	
#	# Now we need to see if the prerequisites are satisfied
#	my @failedSubEvents;
#	my @subEvents;
#	foreach my $subEventPrerequisite (keys %{$subEventPrerequisites}) {
#		
#		my ($prerequisiteId, $productId) = split(':',$subEventPrerequisite);
#		
#		# Is this an 'And' or an 'Or' prerequisite
#		my $operator = $subEventPrerequisites->{$subEventPrerequisite};
#
#		# All of the required events per this prerequisite definition
#		my @requiredEventList = $self->session->db->buildArray("
#			select requiredProductId from EventManagementSystem_prerequisiteEvents
#			where prerequisiteId=".$self->session->db->quote($prerequisiteId)
#		);
#		
#		# Check to see that every required prerequisite is met
#		#
#		# If a sub-event fails one of it's prerequisites we'll push the productId onto a failure list
#		# At the end, we'll only return events whos productId is not in the failure list.
#		#
#		if ($operator eq 'and') { # make sure every required event is in the users cart
#		  foreach my $requiredEvent (@requiredEventList) {
# 		    unless ( WebGUI::Utility::isIn($requiredEvent, @{$eventsInCart}) ) {
#		      push (@failedSubEvents, $productId);
#		      last;
#		    }
#		  }
#		} elsif ($operator eq 'or') { # make sure one of the required events is in the users cart
#
#		  my $atLeastOneFlag = 0;
#		  foreach my $requiredEvent (@requiredEventList) {
#		    if ( WebGUI::Utility::isIn($requiredEvent, @{$eventsInCart}) ) {
#		      $atLeastOneFlag = 1;
#		      last;
#	 	    }
#		  }
#		  push(@failedSubEvents, $productId) unless ($atLeastOneFlag);  
#		}	
#	}
#	
#	# Return list of 
#	
#	# Check our list against the failed events, return productIds of valid subevents
#	foreach my $subEvent (keys %{$subEventPrerequisites}) {
#		
#		my ($prerequisiteId, $productId) = split(':', $subEvent);
#		push (@subEvents, $productId) unless (WebGUI::Utility::isIn($productId, @failedSubEvents));
#	}
#	return \@subEvents;	
#}

#------------------------------------------------------------------
sub getRegistrationInfo {
	my $self = shift;
	my %var;
	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
			     .WebGUI::Form::hidden($self->session,{name=>"func",value=>"saveRegistration"});
	$var{'form.message'} = $i18n->get('registration info message');
	$var{'form.footer'} = WebGUI::Form::formFooter($self->session);
	$var{'form.submit'} = WebGUI::Form::submit($self->session);
	$var{'form.firstName.label'} = $i18n->get("first name");
	$var{'form.lastName.label'} = $i18n->get("last name");
	$var{'form.address.label'} = $i18n->get("address");
	$var{'form.city.label'} = $i18n->get("city");
	$var{'form.state.label'} = $i18n->get("state");
	$var{'form.zipCode.label'} = $i18n->get("zip code");
	$var{'form.country.label'} = $i18n->get("country");
	$var{'form.phoneNumber.label'} = $i18n->get("phone number");
	$var{'form.email.label'} = $i18n->get("email address");
	$var{'form.badgeId.label'} = $i18n->get("which badge");
	$var{'form.firstName'} = WebGUI::Form::Text($self->session,{name=>'firstName'});
	$var{'form.lastName'} = WebGUI::Form::Text($self->session,{name=>'lastName'});
	$var{'form.address'} = WebGUI::Form::Text($self->session,{name=>'address'});
	$var{'form.city'} = WebGUI::Form::Text($self->session,{name=>'city'});
	$var{'form.state'} = WebGUI::Form::Text($self->session,{name=>'state'});
	$var{'form.zipCode'} = WebGUI::Form::Text($self->session,{name=>'zipCode'});
	$var{'form.country'} = WebGUI::Form::SelectBox($self->session,{name=>'country', options => {'us' => 'UnitedStates'}});
	$var{'form.phoneNumber'} = WebGUI::Form::Phone($self->session,{name=>'phone'});
	$var{'form.badgeId'} = $self->getBadgeSelector;
	$var{'form.updateProfile'} = WebGUI::Form::Checkbox($self->session,{name=>'updateProfile'});
	$var{isLoggedIn} = 1 if ($self->session->user->userId ne '1');
	$var{'form.email'} = WebGUI::Form::Email($self->session,{name=>'email'});
	$var{'registration'} = 1;	
	return \%var;
}

#------------------------------------------------------------------
#sub getSubEventPrerequisites {
#	my $self = shift;
#	my $eventId = shift;
#
#	# All prerequisiteIds, and operators where eventId is listed as a requiredEvent
#	# 
#	# This will give us the prerequisite definitions which require the eventId passed in.
#	
#	my $prerequisites = $self->session->db->buildHashRef("
#		    select distinct(pe.prerequisiteId), pr.productId, pr.operator 
#		    from EventManagementSystem_prerequisiteEvents as pe, EventManagementSystem_prerequisites as pr
#		    where
#			pe.requiredProductId=".$self->session->db->quote($eventId)."
#			and pe.prerequisiteId = pr.prerequisiteId"
#	);
#
#	# A subevent can have more than one prerequisite definition and the second or third, etc
#	# may require other events before they should be listed as a sub-event to the parentId passed in.
#	# So, we can't search for them the way we did above.
#	#
#	# We need to look up these prerequisites by getting the productId from the prerequisites table 
#	# for all of the prerequisiteIds returned above and use it to search the prerequisites table again
#	# for any more entries that contain that productId.  The productId is the id of the parent event.
#	# This gives us all prerequistes defined for the parent product.
#	#
#	
#	# Make a copy of the $prerequisites hash so we can use it for itteration and insert any newly found
#	# prerequisites into the $prerequisites hash.  Apparently looping through a hash and adding keys to it
#	# is a no no.
#	my %tempHash = %{$prerequisites};
#	
#	foreach my $prerequisiteId (keys %tempHash) {
#		
#		$prerequisiteId =~ s/^(.*):.*$/$1/;  #strip the productId from the key for our query
#		
#		my $otherPrerequisites = $self->session->db->buildHashRef("
#			select prerequisiteId, productId, operator from EventManagementSystem_prerequisites
#			where productId = 
#		                (select productId from EventManagementSystem_prerequisites
#				 where prerequisiteId =".$self->session->db->quote($prerequisiteId).")
#		");
#		
#		foreach my $otherPrerequisiteId (keys %{$otherPrerequisites}) {
#			$prerequisites->{$otherPrerequisiteId} = $otherPrerequisites->{$otherPrerequisiteId};
#		}
#	}
#	return $prerequisites;
#}

#------------------------------------------------------------------
#sub getSubEvents {
#	my $self = shift;
#	my $eventIds = shift;
#	my $subEvents;
#	my @subEventData;
##	my $eventsInCart = $self->getEventsInCart;
#	my $eventsInCart = $self->getEventsInScratchCart;
#	#use Data::Dumper;
#	# $self->session->errorHandler->warn("getsubevents: <pre>".Dumper($eventIds)."</pre>");
#	foreach my $eventId (@$eventIds) {
#	
#		$subEvents = $self->findSubEvents($eventId);	
#		foreach my $subEventId (@$subEvents) {	
#			# Query to get event details
#			my $subEventFields = $self->session->db->read("
#				select productId, title, price, description
#				from products
#				where
#				productId = ".$self->session->db->quote($subEventId)."
#				and productId not in (".$self->session->db->quoteAndJoin($eventsInCart).")"
#			);
#			push (@subEventData, $subEventFields);
#		}
#	}
#
#	return \@subEventData;
#}

#------------------------------------------------------------------
#sub getSubEventForm {
#	my $self = shift;
#	my $pids = shift;
#	my $subEvents = $self->getSubEvents($pids);
#	my @usedEventIds;
#	my %var;
#	my @arr = $self->session->form->param("subEventPID");
#	return undef if ($self->session->form->process("method") eq 'addSubEvents' && !scalar(@arr));
#	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
#	
#	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
#			     .WebGUI::Form::hidden($self->session,{name=>"func",value=>"addToCart"})
#			     .WebGUI::Form::hidden($self->session,{name=>"method",value=>"addSubEvents"}
#	);
#
#	$var{'form.footer'} = WebGUI::Form::formFooter($self->session);
#	$var{'form.submit'} = WebGUI::Form::Submit($self->session);
#	$var{'message'}	    = $i18n->get('allowed sub events');
#
#	my @subEventLoop;
#	foreach my $subEvent (@$subEvents) {
#	 while (my $eventData = $subEvent->hashRef) {
#
#	   # Track used event ids so we can prevent listing a subevent more than once.
#	   next if (WebGUI::Utility::isIn($eventData->{productId}, @usedEventIds));
#	   next if $self->checkConflicts($eventData->{productId});
#	   push (@usedEventIds, $eventData->{productId});
#	   
#	   push(@subEventLoop, {
#	   	'form.checkBox' => WebGUI::Form::checkbox($self->session, {
#					value => $eventData->{productId},
#	   	                        name  => "subEventPID"}),
#		'title'		=> $eventData->{title},
#		'description'	=> $eventData->{description},
#		'price'		=> $eventData->{price}
#	   });
#	 }
#	}
#	
#	return '' unless scalar(@subEventLoop);
#	
#	my $scratchCart = [split("\n",$self->session->scratch->get('EMS_scratch_cart'))];
#	
#	foreach (@$scratchCart) {
#		my $details = $self->getEventDetails($_);
#		push(@subEventLoop, {
#			'form.checkBox' => WebGUI::Form::checkbox($self->session, {
#				value => 1,
#				checked => 1,
#				name  => "subEventDisregard",
#				extras => 'disabled="disabled"',
#			}),
#			'title'		=> $details->{title},
#			'description'	=> $details->{description},
#			'price'		=> $details->{price}
#		});
#	}
#
#	$var{'subevents_loop'} = \@subEventLoop;
#	$var{'chooseSubevents'} = 1;
#	my $output;
#	$output = \%var if scalar(@subEventLoop);
#	
#	return $output;	
#}

#------------------------------------------------------------------
sub prerequisiteIsMet {
	my $self = shift;
	my $operator = shift;
	my $requiredEvents = shift;
	my $userSelectedEvents = $self->getEventsInScratchCart;
	
	if ($operator eq 'and') { # make sure every required event is in the users cart
		  foreach my $requiredEvent (@$requiredEvents) {
 		    unless ( isIn($requiredEvent, @{$userSelectedEvents}) ) {
		      return 0;
		    }
		  }
		  return 1;
	} elsif ($operator eq 'or') { # make sure one of the required events is in the users cart
		  foreach my $requiredEvent (@$requiredEvents) {
		    if ( isIn($requiredEvent, @{$userSelectedEvents}) ) {
		      return 1;
	 	    }
		  }
		  return 0;
	}	
}


#------------------------------------------------------------------
sub getCountries {
	my $self = shift;
	my %countries;
	tie %countries, 'Tie::IxHash';
	%countries = (
'Afghanistan' => 'Afghanistan',
'Albania' => 'Albania',
'Algeria' => 'Algeria',
'American Samoa' => 'American Samoa',
'Andorra' => 'Andorra',
'Anguilla' => 'Anguilla',
'Antarctica' => 'Antarctica',
'Antigua And Barbuda' => 'Antigua And Barbuda',
'Argentina' => 'Argentina',
'Armenia' => 'Armenia',
'Aruba' => 'Aruba',
'Australia' => 'Australia',
'Austria' => 'Austria',
'Azerbaijan' => 'Azerbaijan',
'Bahamas' => 'Bahamas',
'Bahrain' => 'Bahrain',
'Bangladesh' => 'Bangladesh',
'Barbados' => 'Barbados',
'Belarus' => 'Belarus',
'Belgium' => 'Belgium',
'Belize' => 'Belize',
'Benin' => 'Benin',
'Bermuda' => 'Bermuda',
'Bhutan' => 'Bhutan',
'Bolivia' => 'Bolivia',
'Bosnia and Herzegovina' => 'Bosnia and Herzegovina',
'Botswana' => 'Botswana',
'Bouvet Island' => 'Bouvet Island',
'Brazil' => 'Brazil',
'British Indian Ocean Territory' => 'British Indian Ocean Territory',
'Brunei Darussalam' => 'Brunei Darussalam',
'Bulgaria' => 'Bulgaria',
'Burkina Faso' => 'Burkina Faso',
'Burundi' => 'Burundi',
'Cambodia' => 'Cambodia',
'Cameroon' => 'Cameroon',
'Canada' => 'Canada',
'Cape Verde' => 'Cape Verde',
'Cayman Islands' => 'Cayman Islands',
'Central African Republic' => 'Central African Republic',
'Chad' => 'Chad',
'Chile' => 'Chile',
'China' => 'China',
'Christmas Island' => 'Christmas Island',
'Cocos (Keeling) Islands' => 'Cocos (Keeling) Islands',
'Colombia' => 'Colombia',
'Comoros' => 'Comoros',
'Congo' => 'Congo',
'Congo, the Democratic Republic of the' => 'Congo, the Democratic Republic of the',
'Cook Islands' => 'Cook Islands',
'Costa Rica' => 'Costa Rica',
'Cote d\'Ivoire' => 'Cote d\'Ivoire',
'Croatia' => 'Croatia',
'Cyprus' => 'Cyprus',
'Czech Republic' => 'Czech Republic',
'Denmark' => 'Denmark',
'Djibouti' => 'Djibouti',
'Dominica' => 'Dominica',
'Dominican Republic' => 'Dominican Republic',
'East Timor' => 'East Timor',
'Ecuador' => 'Ecuador',
'Egypt' => 'Egypt',
'El Salvador' => 'El Salvador',
'England' => 'England',
'Equatorial Guinea' => 'Equatorial Guinea',
'Eritrea' => 'Eritrea',
'Espana' => 'Espana',
'Estonia' => 'Estonia',
'Ethiopia' => 'Ethiopia',
'Falkland Islands' => 'Falkland Islands',
'Faroe Islands' => 'Faroe Islands',
'Fiji' => 'Fiji',
'Finland' => 'Finland',
'France' => 'France',
'French Guiana' => 'French Guiana',
'French Polynesia' => 'French Polynesia',
'French Southern Territories' => 'French Southern Territories',
'Gabon' => 'Gabon',
'Gambia' => 'Gambia',
'Georgia' => 'Georgia',
'Germany' => 'Germany',
'Ghana' => 'Ghana',
'Gibraltar' => 'Gibraltar',
'Great Britain' => 'Great Britain',
'Greece' => 'Greece',
'Greenland' => 'Greenland',
'Grenada' => 'Grenada',
'Guadeloupe' => 'Guadeloupe',
'Guam' => 'Guam',
'Guatemala' => 'Guatemala',
'Guinea' => 'Guinea',
'Guinea-Bissau' => 'Guinea-Bissau',
'Guyana' => 'Guyana',
'Haiti' => 'Haiti',
'Heard and Mc Donald Islands' => 'Heard and Mc Donald Islands',
'Honduras' => 'Honduras',
'Hong Kong' => 'Hong Kong',
'Hungary' => 'Hungary',
'Iceland' => 'Iceland',
'India' => 'India',
'Indonesia' => 'Indonesia',
'Ireland' => 'Ireland',
'Israel' => 'Israel',
'Italy' => 'Italy',
'Jamaica' => 'Jamaica',
'Japan' => 'Japan',
'Jordan' => 'Jordan',
'Kazakhstan' => 'Kazakhstan',
'Kenya' => 'Kenya',
'Kiribati' => 'Kiribati',
'Korea, Republic of' => 'Korea, Republic of',
'Korea (South)' => 'Korea (South)',
'Kuwait' => 'Kuwait',
'Kyrgyzstan' => 'Kyrgyzstan',
"Lao People's Democratic Republic" => "Lao People's Democratic Republic",
'Latvia' => 'Latvia',
'Lebanon' => 'Lebanon',
'Lesotho' => 'Lesotho',
'Liberia' => 'Liberia',
'Libya' => 'Libya',
'Liechtenstein' => 'Liechtenstein',
'Lithuania' => 'Lithuania',
'Luxembourg' => 'Luxembourg',
'Macau' => 'Macau',
'Macedonia' => 'Macedonia',
'Madagascar' => 'Madagascar',
'Malawi' => 'Malawi',
'Malaysia' => 'Malaysia',
'Maldives' => 'Maldives',
'Mali' => 'Mali',
'Malta' => 'Malta',
'Marshall Islands' => 'Marshall Islands',
'Martinique' => 'Martinique',
'Mauritania' => 'Mauritania',
'Mauritius' => 'Mauritius',
'Mayotte' => 'Mayotte',
'Mexico' => 'Mexico',
'Micronesia, Federated States of' => 'Micronesia, Federated States of',
'Moldova, Republic of' => 'Moldova, Republic of',
'Monaco' => 'Monaco',
'Mongolia' => 'Mongolia',
'Montserrat' => 'Montserrat',
'Morocco' => 'Morocco',
'Mozambique' => 'Mozambique',
'Myanmar' => 'Myanmar',
'Namibia' => 'Namibia',
'Nauru' => 'Nauru',
'Nepal' => 'Nepal',
'Netherlands' => 'Netherlands',
'Netherlands Antilles' => 'Netherlands Antilles',
'New Caledonia' => 'New Caledonia',
'New Zealand' => 'New Zealand',
'Nicaragua' => 'Nicaragua',
'Niger' => 'Niger',
'Nigeria' => 'Nigeria',
'Niue' => 'Niue',
'Norfolk Island' => 'Norfolk Island',
'Northern Ireland' => 'Northern Ireland',
'Northern Mariana Islands' => 'Northern Mariana Islands',
'Norway' => 'Norway',
'Oman' => 'Oman',
'Pakistan' => 'Pakistan',
'Palau' => 'Palau',
'Panama' => 'Panama',
'Papua New Guinea' => 'Papua New Guinea',
'Paraguay' => 'Paraguay',
'Peru' => 'Peru',
'Philippines' => 'Philippines',
'Pitcairn' => 'Pitcairn',
'Poland' => 'Poland',
'Portugal' => 'Portugal',
'Puerto Rico' => 'Puerto Rico',
'Qatar' => 'Qatar',
'Reunion' => 'Reunion',
'Romania' => 'Romania',
'Russia' => 'Russia',
'Russian Federation' => 'Russian Federation',
'Rwanda' => 'Rwanda',
'Saint Kitts and Nevis' => 'Saint Kitts and Nevis',
'Saint Lucia' => 'Saint Lucia',
'Saint Vincent and the Grenadines' => 'Saint Vincent and the Grenadines',
'Samoa (Independent)' => 'Samoa (Independent)',
'San Marino' => 'San Marino',
'Sao Tome and Principe' => 'Sao Tome and Principe',
'Saudi Arabia' => 'Saudi Arabia',
'Scotland' => 'Scotland',
'Senegal' => 'Senegal',
'Serbia and Montenegro' => 'Serbia and Montenegro',
'Seychelles' => 'Seychelles',
'Sierra Leone' => 'Sierra Leone',
'Singapore' => 'Singapore',
'Slovakia' => 'Slovakia',
'Slovenia' => 'Slovenia',
'Solomon Islands' => 'Solomon Islands',
'Somalia' => 'Somalia',
'South Africa' => 'South Africa',
'South Georgia and the South Sandwich Islands' => 'South Georgia and the South Sandwich Islands',
'South Korea' => 'South Korea',
'Spain' => 'Spain',
'Sri Lanka' => 'Sri Lanka',
'St. Helena' => 'St. Helena',
'St. Pierre and Miquelon' => 'St. Pierre and Miquelon',
'Suriname' => 'Suriname',
'Svalbard and Jan Mayen Islands' => 'Svalbard and Jan Mayen Islands',
'Swaziland' => 'Swaziland',
'Sweden' => 'Sweden',
'Switzerland' => 'Switzerland',
'Taiwan' => 'Taiwan',
'Tajikistan' => 'Tajikistan',
'Tanzania' => 'Tanzania',
'Thailand' => 'Thailand',
'Togo' => 'Togo',
'Tokelau' => 'Tokelau',
'Tonga' => 'Tonga',
'Trinidad' => 'Trinidad',
'Trinidad and Tobago' => 'Trinidad and Tobago',
'Tunisia' => 'Tunisia',
'Turkey' => 'Turkey',
'Turkmenistan' => 'Turkmenistan',
'Turks and Caicos Islands' => 'Turks and Caicos Islands',
'Tuvalu' => 'Tuvalu',
'Uganda' => 'Uganda',
'Ukraine' => 'Ukraine',
'United Arab Emirates' => 'United Arab Emirates',
'United Kingdom' => 'United Kingdom',
'United States' => 'United States',
'United States Minor Outlying Islands' => 'United States Minor Outlying Islands',
'Uruguay' => 'Uruguay',
'Uzbekistan' => 'Uzbekistan',
'Vanuatu' => 'Vanuatu',
'Vatican City State (Holy See)' => 'Vatican City State (Holy See)',
'Venezuela' => 'Venezuela',
'Viet Nam' => 'Viet Nam',
'Virgin Islands (British)' => 'Virgin Islands (British)',
'Virgin Islands (U.S.)' => 'Virgin Islands (U.S.)',
'Wales' => 'Wales',
'Wallis and Futuna Islands' => 'Wallis and Futuna Islands',
'Western Sahara' => 'Western Sahara',
'Yemen' => 'Yemen',
'Zambia' => 'Zambia',
'Zimbabwe' => 'Zimbabwe'
	);
	return \%countries;
}

#------------------------------------------------------------------
sub removeFromScratchCart {
	my $self = shift;
	my $event = shift;
	my $events =  $self->getEventsInScratchCart();
	my @newArr;
	foreach (@{$events}) {
		push (@newArr,$_) unless $_ eq $event;
	}
	$self->session->scratch->set('EMS_scratch_cart', join("\n",@newArr));
}

#------------------------------------------------------------------
sub resolveConflictForm {
	my $self = shift;
	my $event1 = shift;
	my $event2 = shift;
	my $deleteIcon = $self->session->icon->getBaseURL()."delete.gif";
	my %var;
	my $sth = $self->session->db->read("
		select productId, title, price, description
		from products where productId in (".$self->session->db->quote($event1).","
		.$self->session->db->quote($event2).")"
	);
	
	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');

	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
			     .WebGUI::Form::hidden($self->session,{name=>"func",value=>"deleteCartItem"})
			     .WebGUI::Form::hidden($self->session,{name=>"event1",value=>"$event1"})
			     .WebGUI::Form::hidden($self->session,{name=>"event2",value=>"$event2"}
	);

	$var{'form.footer'} = WebGUI::Form::formFooter($self->session);
	$var{'form.submit'} = WebGUI::Form::Submit($self->session);
	$var{'message'}	    = $i18n->get('scheduling conflict message');

	my @loop;
	while (my $data = $sth->hashRef) {
		push(@loop, {
			'form.deleteControl' => "<input type='image' src='$deleteIcon' name='productToRemove' value='".$data->{productId}."' style='border: 0px;'/>",
			'title' => $data->{title},
			'description' => $data->{description},
			'price' => $data->{price}			
		});
	}
	$var{'conflict_loop'} = \@loop;
	$var{'resolveConflicts'} = 1;

	return \%var;
}

#------------------------------------------------------------------
sub verifyAllPrerequisites {
	my $self = shift;
#	my $returnArrayFlag = shift;
	my $cache;
	my $pId;
#	if ($returnArrayFlag) {
#		$pId = $self->getEventDetails($returnArrayFlag)->{prerequisiteId};
#		$cache = WebGUI::Cache->new($self->session,["verifyAllPrerequisites",$pId]);
#		my $eventData = $cache->get;
#		return $eventData->{$pId} if defined $eventData->{$pId};
#	}
	#use Data::Dumper;
	#start with the events in the scratch cart.  See if all prerequisites are met	
	my $startingEvents = {};
	my $scratchEvents;
#	if ($returnArrayFlag) {
#		$startingEvents = {$returnArrayFlag=>$self->getEventDetails($returnArrayFlag)};
#	} else {
		$scratchEvents = $self->getEventsInScratchCart;
		foreach (@$scratchEvents) {
			$startingEvents->{$_} = $self->getEventDetails($_);
		}
#	}
	my ($lastResults, $msgLoop) = $self->verifyEventPrerequisites($startingEvents,1);
	my $lastResultsSize = scalar(keys %$lastResults);
	my $currentResultsSize = -4;
	# initial case must not qualify as the base case
	return [] unless $lastResultsSize;
	until ($currentResultsSize == $lastResultsSize) {
		$currentResultsSize = $lastResultsSize;
		my ($hashTemp,$newMsgLoop) = $self->verifyEventPrerequisites($lastResults,1);
		$lastResults = {%$lastResults,%$hashTemp};
		foreach my $newMsg (@$newMsgLoop) {
			my $add = 1;
			foreach my $oldMsg (@$msgLoop) {
				$add = 0 if $oldMsg->{productId} eq $newMsg->{productId};
			}
			push (@$msgLoop,$newMsg) if $add;
		}
		$lastResultsSize = scalar(keys %$lastResults);
	}
	
	my $rowsLoop = [];
#	if ($returnArrayFlag) {
#		my @silliness = keys %$lastResults;
#		$cache->set({$pId=>\@silliness}, 60*60*24*360);
#		return \@silliness;
#	}
	foreach (keys %$lastResults) {
		my $details = $lastResults->{$_};
		push(@$rowsLoop, {
			'form.checkBox' => WebGUI::Form::checkbox($self->session, {
				value => $_,
				name  => "subEventPID"}
			),
			'title'		=> $details->{title},
			'description'	=> $details->{description},
			'price'		=> $details->{price}
		});
	}
	# $self->session->errorHandler->warn("verifyAllPrerequisites: <pre>".Dumper($msgLoop).Dumper($rowsLoop).Dumper($lastResults)."</pre>");
	return $msgLoop, $rowsLoop;
}

#------------------------------------------------------------------
sub verifyEventPrerequisites {
	my $self = shift;
	my $lastResults = shift;
	my $returnMsgLoop = shift;
	my $msgLoop = [];
	my $newResults = {};
	foreach (keys %$lastResults) {
		my ($required,$messageLoop) = $self->getAllPossibleEventPrerequisites($_);
		# add in any new ones.
		foreach my $req (@$required) {
			$newResults->{$req} = $self->getEventDetails($req);
		}
		if ($returnMsgLoop) {
			my $details = $self->getEventDetails($_);
			push (@$msgLoop,{%$details,messageLoop=>$messageLoop}) if (scalar(@$messageLoop));
		}
	}
	return $newResults,$msgLoop if $returnMsgLoop;
	return $newResults;
}

#------------------------------------------------------------------
sub getAllPossibleEventPrerequisites {
	my $self = shift;
	my $eventId = shift;
	my $required = [];
	my $messageLoop = [];
	
	# Get all prerequisite definitions defined for this event
	my $prerequisiteDefinitions = $self->session->db->buildHashRef("select prereqs.prerequisiteId, prereqs.operator from EventManagementSystem_prerequisites as prereqs, EventManagementSystem_products as p
									where prereqs.prerequisiteId = p.prerequisiteId and p.approved=1 and p.productId=?",[$eventId]);
	foreach my $prerequisiteId (keys %{$prerequisiteDefinitions}) {
		my $message;
		my $operator = $prerequisiteDefinitions->{$prerequisiteId};
									       
		# Get the events required for each prerequisite definition (the events required for attending $eventId)
		my $requiredEvents = $self->session->db->buildArrayRef("select requiredProductId from EventManagementSystem_prerequisiteEvents
								       where prerequisiteId=?",[$prerequisiteId]);

		unless ($self->prerequisiteIsMet($operator, $requiredEvents)) {

			#compare all the required events to the events in the scratch cart and build a list of the ones
			#that are required but not currently in the scratch cart.
			my $scratchCart = $self->getEventsInScratchCart;
			my @missingEventIds;
			
			foreach my $requiredEvent (@$requiredEvents) {
				push (@missingEventIds, $requiredEvent) unless isIn($requiredEvent, @$scratchCart);
			}
			
			my $missingEventNames = $self->getRequiredEventNames($prerequisiteId);
			
			foreach my $missingEventName (@$missingEventNames) {
				$message .= "$missingEventName $operator ";
			}
			
			$message =~ s/(\sand\s|\sor\s)$//;  #remove trailing 'and' or 'or' from the message
			
			foreach (@missingEventIds) {
				push(@$required,$_) unless isIn($_,@$required);
			}
		}
		push(@$messageLoop,{reqmessage=>$message}) if $message;
	}	
	return $required,$messageLoop;
}


#------------------------------------------------------------------
sub getAllPossibleRequiredEvents {
	my $self = shift;
	my $pId = shift;
	my $cache = WebGUI::Cache->new($self->session,["gAPRE",$pId]);
	my $eventData = $cache->get;
	return $eventData->{$pId} if defined $eventData->{$pId};

	# Get all required events for this event (base case)
	my $lastResults = $self->session->db->buildArrayRef("select distinct(r.requiredProductId) from EventManagementSystem_prerequisiteEvents as r where r.prerequisiteId = ?",[$pId]);
	$cache->set({$pId=>$lastResults}, 60*60*24*360);
	return $lastResults;
	my $lastResultsSize = scalar(@$lastResults);
	my $currentResultsSize = -4;
	# initial case must not qualify as the base case
	return [] unless $lastResultsSize;
	until ($currentResultsSize == $lastResultsSize) {
		$currentResultsSize = $lastResultsSize;
		my $newResults = $self->session->db->buildArrayRef("select distinct(r.requiredProductId) from EventManagementSystem_prerequisiteEvents as r, EventManagementSystem_products as p where r.prerequisiteId = p.prerequisiteId and p.approved=1 and p.productId in (".$self->session->db->quoteAndJoin($lastResults).")");
		return $lastResults unless scalar(@$newResults);
		$lastResults = $newResults;
		$lastResultsSize = scalar(@$lastResults);
	}
	$cache->set({$pId=>$lastResults}, 60*60*24*360);
	return $lastResults;
}


#------------------------------------------------------------------
sub getEventDetails {
	my $self = shift;
	my $eventId = shift;
	return $self->{_eventDetails}{$eventId} if $self->{_eventDetails}{$eventId};
	$self->{_eventDetails}{$eventId} = $self->session->db->quickHashRef(
		"select productId, title, price, description from products where productId = ?"
		,[$eventId]
	);
	return $self->{_eventDetails}{$eventId};
}


#------------------------------------------------------------------
sub verifyPrerequisitesForm {
	my $self = shift;
	my ($missingEventMessageLoop, $allPrereqsLoop) = $self->verifyAllPrerequisites;
	my @usedEventIds;
	my $scratchCart = $self->getEventsInScratchCart;
	#use Data::Dumper;
	# $self->session->errorHandler->warn("scratch: <pre>".Dumper($scratchCart)."</pre>");
	my %var;

	#If there is no missing event data, return nothing
	return unless scalar(@$missingEventMessageLoop);

	my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
	
	$scratchCart = [split("\n",$self->session->scratch->get('EMS_scratch_cart'))];
	
	foreach (@$scratchCart) {
		my $details = $self->getEventDetails($_);
		push(@$allPrereqsLoop, {
			'form.checkBox' => WebGUI::Form::checkbox($self->session, {
				value => 1,
				checked => 1,
				name  => "subEventDisregard",
				extras => 'disabled="disabled"',
			}),
			'title'		=> $details->{title},
			'description'	=> $details->{description},
			'price'		=> $details->{price}
		});
	}
	
	$var{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
			     .WebGUI::Form::hidden($self->session,{name=>"func",value=>"addToCart"})
			     .WebGUI::Form::hidden($self->session,{name=>"method",value=>"addSubEvents"}
	);

	$var{'form.footer'} = WebGUI::Form::formFooter($self->session);
	$var{'form.submit'} = WebGUI::Form::Submit($self->session);
	$var{'message'}	    = $i18n->get('missing prerequisites message');	
		
	#Set the template vars needed to inform the user of the missing prereqs.
	$var{'prereqsAreMissing'} = 1;
	$var{'message_loop'} = $missingEventMessageLoop;
	$var{'missingEvents_loop'} = $allPrereqsLoop;
	return \%var;
}

#------------------------------------------------------------------

=head2 validateEditEventForm ( )

Returns array reference containing any errors generated while validating the input of the Add/Edit Event Form

=cut

sub validateEditEventForm {
  my $self = shift;
  my $errors;
  my $i18n = WebGUI::International->new($self->session, 'Asset_EventManagementSystem');
  
  my %requiredFields;
  tie %requiredFields, 'Tie::IxHash';
  
  #-----Form name--------------User Friendly Name----#
  %requiredFields  = (
  	"title"	   		=>	$i18n->get("add/edit event title"),
  	"description" 		=> 	$i18n->get("add/edit event description"),
  	"price"			=>	$i18n->get("add/edit event price"),
  	"maximumAttendees"	=>	$i18n->get("add/edit event maximum attendees"),
	"sku"			=>	$i18n->get("sku"),
  );

	my $mdFields = $self->getEventMetaDataFields;
	foreach my $mdField (keys %{$mdFields}) {
		next unless $mdFields->{$mdField}->{required};
		$requiredFields{'metadata_'.$mdField} = $mdFields->{$mdField}->{name};
	}

  $errors = $self->checkRequiredFields(\%requiredFields);
  
  #Check price greater than zero
  if ($self->session->form->get("price") < 0) {
      push (@{$errors}, {
      	type      => "general",
        message   => $i18n->get("price must be greater than zero"),
        }
      );
  }
  if ($self->session->form->get("pid") eq "meetmymaker") {
     push (@{$errors}, {
     	type	  => "special",
     	message   => "+4F]Y(&UA9&4@;64",
     	}
      );
  }
     	
  
  #Other checks go here
  
  return $errors;
}

#-------------------------------------------------------------------

=head2 www_addToCart (  )

Method that will add an event to the users shopping cart.

=cut

sub www_addToCart {
	my ($self, $pid, @pids, $output, $errors, $conflicts, $errorMessages, $shoppingCart);
	$self = shift;
	$conflicts = shift;
	$pid = shift;
	$shoppingCart = WebGUI::Commerce::ShoppingCart->new($self->session);
	# $self->session->errorHandler->warn("scratch before: <pre>".Dumper($self->getEventsInScratchCart).Dumper($self->session->db->buildHashRef("select name,value from userSessionScratch where sessionId=?",[$self->session->getId]))."</pre>");
	# Check if conflicts were found that the user needs to fix
	$output = $conflicts->[0] if defined $conflicts;
	
	unless ($output) { #Skip this if we have errors

		if ($self->session->form->get("method") eq "addSubEvents") { # List of ids from subevent form
			@pids = $self->session->form->process("subEventPID", "checkList");
		}
		else {  # A single id, i.e., a master event
			my $newPid = $self->session->form->get("pid") || $pid;
			push(@pids, $newPid) unless ($newPid eq "_noid_");
		}

		foreach my $eventId (@pids) {
			$self->addToScratchCart($eventId);
		}

		# Check to make sure all the prerequisites for this event have been satisfied
		$output = $self->verifyPrerequisitesForm;

		#$output = $self->getSubEventForm(\@pids) unless ($output);
		#$output = $self->getSubEventForm($self->getEventsInScratchCart) unless ($output);
		
		$errors = $self->checkConflicts;
		if (scalar(@$errors) > 0) { return $self->error($errors, "www_addToCart"); }
		
		unless ($output) {
			$output = $self->getRegistrationInfo;
		}		
	}
	# $self->session->errorHandler->warn("scratch after: <pre>".Dumper($self->getEventsInScratchCart).Dumper($self->session->db->buildHashRef("select name,value from userSessionScratch where sessionId=?",[$self->session->getId]))."</pre>");
	return $self->session->style->process($self->processTemplate($output,$self->getValue("checkoutTemplateId")),$self->getValue("styleTemplateId"));
} 

#-------------------------------------------------------------------
sub www_addToScratchCart {
	my $self = shift;	
	my $pid = $self->session->form->get("pid");
	my $nameOfEventAdded = $self->getEventName($pid);
	my $masterEventId = $self->session->form->get("mid");
	$self->addToScratchCart($pid); #tsc
	
	return $self->www_search(undef, undef, $nameOfEventAdded, $masterEventId, "requirement", "eq", $self->session->form->get("pn"));
}


#-------------------------------------------------------------------

=head2 www_approveEvent ( )

Method that will set the status of some events to approved.

=cut

sub www_approveEvents {
	my $self = shift;
	return $self->session->privilege->insufficient unless ($self->canApproveEvents);
	my @eventsToCheck = $self->session->form->process('eventIdToCheck','selectList');
	my @events = $self->session->form->process('eventId','checkList');
	foreach (@eventsToCheck) {
		my $isIn = WebGUI::Utility::isIn($_,@events) ? '1' : '0';
		$self->session->db->write("update EventManagementSystem_products set approved=? where productId=?",[$isIn,$_]);
	}
	return $self->www_manageEvents;
}

#-------------------------------------------------------------------
sub www_deleteCartItem {
	my $self = shift;
	my $event1 = $self->session->form->get("event1");
	my $event2 = $self->session->form->get("event2");
	my $eventUserDeleted = $self->session->form->get("productToRemove");
	#my $cart = WebGUI::Commerce::ShoppingCart->new($self->session);
	
	# Delete all of the subevents last added by the user
	#$cart->delete($event1, 'Event');
	#$cart->delete($event2, 'Event');

	$self->removeFromScratchCart($event1);
	$self->removeFromScratchCart($event2);
	
	# Add the subevents back to the cart except for the one the user choose to remove.
	# This will re-trigger the conflict/sub-event display code correctly

	my $eventToAdd = ($event1 eq $eventUserDeleted) ? $event2 : $event1;

	return $self->www_addToCart(undef,$eventToAdd);
}

#-------------------------------------------------------------------

=head2 www_deleteEvent ( )

Method to delete an event, and to remove the deleted event from all prerequisite definitions

=cut

sub www_deleteEvent {
	my $self = shift;
	my $eventId = $self->session->form->get("pid");

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	#Remove this event as a prerequisite to any other event
	$self->session->db->write("delete from EventManagementSystem_prerequisiteEvents where requiredProductId=?",
				   [$eventId]);
	$self->deleteOrphans;	

	#Remove the event
	$self->deleteCollateral('EventManagementSystem_products', 'productId', $eventId);
	$self->deleteCollateral('products','productId',$eventId);
	$self->reorderCollateral('EventManagementSystem_products', 'productId');

	return $self->www_search;			  
}

#-------------------------------------------------------------------

=head2 www_deletePrerequisite ( )

Method to delete a prerequisite assignment of one event to another

=cut

sub www_deletePrerequisite {
	my $self = shift;
	my $eventId = $self->session->form->get("id");
	
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->session->db->write("delete from EventManagementSystem_prerequisiteEvents where prerequisiteId=?",
				   [$eventId]);
	$self->session->db->write("delete from EventManagementSystem_prerequisites where prerequisiteId=?",
				   [$eventId]);
	
	return $self->www_editEvent;
}

#-------------------------------------------------------------------

=head2 www_edit (  )

Edit wobject method.

=cut 

sub www_edit {
	my $self = shift;
	return $self->session->privilege->insufficient() unless $self->canEdit;
	my ($tag) = ($self->get("className") =~ /::(\w+)$/);
	my $tag2 = $tag;
	$tag =~ s/([a-z])([A-Z])/$1 $2/g;  #Separate studly caps
	$tag =~ s/([A-Z]+(?![a-z]))/$1 /g; #Separate acronyms
	$self->getAdminConsole->setHelp(lc($tag)." add/edit", "Asset_".$tag2);
	my $i18n = WebGUI::International->new($self->session,'Asset_Wobject');
	my $addEdit = ($self->session->form->process("func") eq 'add') ? $i18n->get('add') : $i18n->get('edit');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=manageEventMetadata'), $i18n->get('manage event metadata', 'Asset_EventManagementSystem'));
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=manageEvents'), $i18n->get('manage events', 'Asset_EventManagementSystem'));
	return $self->getAdminConsole->render($self->getEditForm->print,$addEdit.' '.$self->getName);
}

#-------------------------------------------------------------------

=head2 www_editEvent ( errors )

Method to generate form to Add or Edit an events properties including prerequisite assignments and event approval.

=head3 errors

An array reference of error messages to display to the user

=cut 

sub www_editEvent {
	my $self = shift;
	my $errors = shift;
	my $errorMessages;

	return $self->session->privilege->insufficient unless ($self->canAddEvents);

	my $pid = shift || $self->session->form->get("pid");
	my ($storageId) = $self->session->db->quickArray("select imageId from EventManagementSystem_products where productId=?",[$pid]) unless ($pid eq "");

	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');

	my $event = $self->session->db->quickHashRef("
		select p.productId, p.title, p.description, p.price, p.weight, p.sku, p.templateId, p.skuTemplate, e.prerequisiteId,
		       e.startDate, e.endDate, e.maximumAttendees, e.approved
		from
		       products as p, EventManagementSystem_products as e
		where
		       p.productId = e.productId and p.productId=?",[$pid]
	); 

	my $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
	
	# Errors
	foreach (@$errors) {
		$errorMessages .= sprintf "<span style='color: red; font-weight: bold;'>%s: %s </span><br />", $i18n->get('add/edit event error'), $_;
	}
	$f->readOnly( -value=>$errorMessages );
	
	$f->hidden( -name=>"assetId", -value=>$self->get("assetId") );
	$f->hidden( -name=>"func",-value=>"editEventSave" );
	$f->hidden( -name=>"pid", -value=>$pid );
		
	if ($self->canApproveEvents) {
		$f->yesNo(
			-value => $event->{approved},
			-name => 'approved',
			-label => $i18n->get('approve event'),
			-hoverHelp => $i18n->get('approve event description')
		);
	} else {
		$f->hidden(
			-name  => "approved",
			-value => $event->{approved}
		);
	}
	
	$f->text(
		-name  => "title",
		-value => $self->session->form->get("title") || $event->{title},
		-hoverHelp => $i18n->get('add/edit event title description'),
		-label => $i18n->get('add/edit event title')
	);
	
	$f->HTMLArea(
		-name  => "description",
		-value => $self->session->form->get("description") || $event->{description},
		-hoverHelp => $i18n->get('add/edit event description description'),
		-label => $i18n->get('add/edit event description')
	);
	
	$f->image(
		-name => "image",
		-hoverHelp => $i18n->get('add/edit event image description'),
		-label => $i18n->get('add/edit event image'),
		-value => $storageId
	 );
	
	$f->float(
		-name  => "price",
		-value => $self->session->form->get("price") || $event->{price},
		-hoverHelp => $i18n->get('add/edit event price description'),		
		-label => $i18n->get('add/edit event price')
	);
	
	$f->template(
		-name  => "templateId",
		-namespace => "EventManagementSystem_product",
		-value => $self->session->form->get("templateId") || $event->{templateId},
		-hoverHelp => $i18n->get('add/edit event template description'),		
		-label => $i18n->get('add/edit event template')
	);
	
	$f->float(
		-name  => "weight",
		-value => $self->session->form->get("weight") || $event->{weight} || 0,
		-hoverHelp => $i18n->get('weight description'),
		-label => $i18n->get('weight'),
	);
	
	$f->text(
		-name  => "sku",
		-value => $self->session->form->get("sku") || $event->{sku} || $self->session->id->generate(),
		-hoverHelp => $i18n->get('sku description'),
		-label => $i18n->get('sku'),
	);
	
	$f->text(
		 -name  => "skuTemplate",
		 -value => $self->session->form->get("skuTemplate") || $event->{skuTemplate},
		 -hoverHelp => $i18n->get('sku template description'),
		 -label => $i18n->get('sku template'),
	);
	
	$f->dateTime(
		-name  => "startDate",
		-value => $self->session->form->process("startDate",'dateTime') || $event->{startDate},
		-hoverHelp => $i18n->get('add/edit event start date description'),
		-label => $i18n->get('add/edit event start date')
	);
	
	$f->dateTime(
		-name  => "endDate",
		-value => $self->session->form->process("endDate",'dateTime') || $event->{endDate},
		-defaultValue => time()+3600, #one hour from start date
		-hoverHelp => $i18n->get('add/edit event end date description'),
		-label => $i18n->get('add/edit event end date')
	);

	$f->integer(
		-name  => "maximumAttendees",
		-value => $self->session->form->get("maximumAttendees") || $event->{maximumAttendees},
		-defaultValue => 100,
		-hoverHelp => $i18n->get('add/edit event maximum attendees description'),
		-label => $i18n->get('add/edit event maximum attendees')
	);
	my %prereqSets;
	tie %prereqSets, 'Tie::IxHash';
	%prereqSets = $self->session->db->buildHash("select prerequisiteId, name from EventManagementSystem_prerequisites order by name");
	my %prereqMemberships = $self->session->db->buildHash("select prerequisiteId, requiredProductId from EventManagementSystem_prerequisiteEvents where requiredProductId=?",[$pid]);
	if (scalar(keys(%prereqSets)) && (scalar(keys(%prereqMemberships)) == 0)) {
		#there are some prereq sets entered into the system, and 
		#this event is not a member of any of them.
		%prereqSets = (''=>$i18n->echo('select one'),%prereqSets);
		$f->selectBox(
			-name=>'prerequisiteId',
			-options=>\%prereqSets,
			-label=>$i18n->echo('Assigned Prerequisite Set'),
			-hoverHelp=>$i18n->echo('Which Prerequisite Set this event requires in order to be added to a badge.'),
			-value=>$self->session->form->get("prerequisiteId") || $event->{prerequisiteId}
		);
	}
	
	# add dynamically added metadata fields.
	my $meta = {};
	my $fieldList = $self->getEventMetaDataArrayRef;
	if ($pid ne 'new') {
		$meta = $self->getEventMetaDataFields($pid);
	} else {
		foreach my $field1 (@{$fieldList}) {
			$meta->{$field1->{fieldId}} = $field1;
			$meta->{$field1->{fieldId}}->{fieldData} = $field1->{defaultValues};
		}
	}
	my $i18n3 = WebGUI::International->new($self->session, "Asset");
	foreach my $field (@{$fieldList}) {
		my $dataType = $meta->{$field->{fieldId}}{dataType};
		my $options;
		# Add a "Select..." option on top of a select list to prevent from
		# saving the value on top of the list when no choice is made.
		if($dataType eq "selectList" || $dataType eq "selectBox") {
			$options = {"", $i18n3->get("Select")};
		}
		
		my $val = $self->session->form->process("metadata_".$meta->{$field->{fieldId}}{fieldId},$dataType);
		
		if(!$val || (ref $val eq "ARRAY" && scalar(@{$val}) == 0 ) ) {
		  $val = $meta->{$field->{fieldId}}{fieldData};
		}
		
		$f->dynamicField(
			name=>"metadata_".$meta->{$field->{fieldId}}{fieldId},
			label=>$meta->{$field->{fieldId}}{label},
			value=>$val,
			extras=>qq/title="$meta->{$field->{fieldId}}{label}"/,
			possibleValues=>$meta->{$field->{fieldId}}{possibleValues},
			options=>$options,
			fieldType=>$dataType
		);
	}

	$f->submit;

	my $output = $f->print;
	$self->getAdminConsole->setHelp('add/edit event','Asset_EventManagementSystem');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=search'),$i18n->get("manage events"));
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=manageEventMetadata'), $i18n->get('manage event metadata'));
	my $addEdit = ($pid eq "new" or !$pid) ? $i18n->get('add', 'Asset_Wobject') : $i18n->get('edit', 'Asset_Wobject');
	return $self->getAdminConsole->render($output, $addEdit.' '.$i18n->get('event'));
}

#-------------------------------------------------------------------

=head2 www_editEventSave ( )

Method that validates the edit event form and saves its contents to the database

=cut

sub www_editEventSave {
	my $self = shift;

	return $self->session->privilege->insufficient unless ($self->canAddEvents);

	my $errors = $self->validateEditEventForm;
        if (scalar(@$errors) > 0) { return $self->error($errors, "www_editEvent"); }

	my $pid = $self->session->form->get("pid");
        my $eventIsNew = 1 if ($pid eq "" || $pid eq "new");
        my $event;
	my $storageId;
	$storageId = $self->session->form->process("image","image",undef,{name=>"image", value=>$storageId});

	#Save the extended product data
	$pid = $self->setCollateral("EventManagementSystem_products", "productId",{
		productId  => $pid,
		startDate  => $self->session->form->process("startDate",'dateTime'),
		endDate	=> $self->session->form->process("endDate",'dateTime'),
		maximumAttendees => $self->session->form->get("maximumAttendees"),
		approved	=> $self->session->form->get("approved"),
		imageId		=> $storageId,
		prerequisiteId => $self->session->form->process("prerequisiteId",'selectBox')
	},1,1);

	#Save the event metadata
	my $mdFields = $self->getEventMetaDataFields;
	foreach my $mdField (keys %{$mdFields}) {
		my $value = $self->session->form->process("metadata_".$mdField,$mdFields->{$mdField}->{dataType});
		$self->session->db->write("insert into EventManagementSystem_metaData values (".$self->session->db->quoteAndJoin([$mdField,$pid,$value]).") on duplicate key update fieldData=".$self->session->db->quote($value));
	}
	
	#Save the standard product data
	$event = {
		productId	=> $pid,
		title		=> $self->session->form->get("title", "text"),
		description	=> $self->session->form->get("description", "HTMLArea"),
		price		=> $self->session->form->get("price", "float"),
		weight		=> $self->session->form->get("weight", "float"),
		sku		=> $self->session->form->get("sku", "text"),
		skuTemplate	=> $self->session->form->get("skuTemplate", "text"),
		templateId	=> $self->session->form->get("templateId", "template"),
	};

	if ($eventIsNew) { # Event is new we need to use the same productId so we can join them later
		$self->session->db->setRow("products", "productId",$event,$pid);
	}
	else { # Updating the row
		$self->session->db->setRow("products", "productId", $event);
	}
	
	return $self->www_search("managePrereqs",$pid) if ($self->session->form->get("whatNext") eq "managePrereqs");
	return $self->www_search;
}


#-------------------------------------------------------------------

=head2 www_manageEventMetadata ( )

Method to display the event metadata management console.

=cut

sub www_manageEventMetadata {
	my $self = shift;

	return $self->session->privilege->insufficient unless ($self->canAddEvents);

	my $output;
	my $metadataFields = $self->getEventMetaDataArrayRef('false');
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $count = 0;
	my $number = scalar(@{$metadataFields});
	if ($number) {
		foreach my $row1 (@{$metadataFields}) {
			my %row = %{$row1};
			$count++;
			$output .= "<div>".
			$self->session->icon->delete('func=deleteEventMetaDataField;fieldId='.$row{fieldId},$self->getUrl,$i18n->get('confirm delete event metadata')).
			$self->session->icon->edit('func=editEventMetaDataField;fieldId='.$row{fieldId}, $self->getUrl).
			$self->session->icon->moveUp('func=moveEventMetaDataFieldUp;fieldId='.$row{fieldId}, $self->getUrl,($count == 1)?1:0);
			$output .= $self->session->icon->moveDown('func=moveEventMetaDataFieldDown;fieldId='.$row{fieldId}, $self->getUrl,($count == $number)?1:0).
			" ".$row{name}." ( ".$row{label}." )</div>";
		}
	} else {
		$output .= $i18n->get('you do not have any metadata fields to display');
	}
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=editEventMetaDataField;fieldId=new'), $i18n->get("add new event metadata field"));
	return $self->_acWrapper($output, $i18n->get("manage event metadata"));
}

#-------------------------------------------------------------------

=head2 www_managePurchases ( )

Method to display list of purchases.  Event admins can see everyone's purchases.

=cut

sub www_managePurchases {
	my $self = shift;
	return $self->session->privilege->insufficient if $self->session->var->get('userId') eq '1';
	my %var = $self->get();
	my $isAdmin = $self->canAddEvents;

	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $whereClause = ($isAdmin)?'':" and (t.userId='".$self->session->user->userId."' or b.userId='".$self->session->user->userId."' or b.createdByUserId='".$self->session->user->userId."') and e.endDate > '".$self->session->datetime->time()."'";
	my $sql = "select distinct(t.transactionId) as purchaseId, t.initDate as initDate from transaction as t, EventManagementSystem_purchases as p, EventManagementSystem_registrations as r, EventManagementSystem_badges as b, EventManagementSystem_products as e where p.transactionId=t.transactionId and b.badgeId=r.badgeId and p.purchaseId=r.purchaseId and r.productId=e.productId $whereClause order by t.initDate";
	my $sth = $self->session->db->read($sql);
	my @purchasesLoop;
	while (my $purchase = $sth->hashRef) {
		$purchase->{datePurchasedHuman} = $self->session->datetime->epochToHuman($purchase->{initDate});
		$purchase->{purchaseUrl} = $self->getUrl."?func=viewPurchase;tid=".$purchase->{purchaseId};
		
		push(@purchasesLoop,$purchase);
	}
	$var{managePurchasesTitle} = $i18n->get('manage purchases');
	$sth->finish;
	$var{'purchasesLoop'} = \@purchasesLoop;
	return $self->session->style->process($self->processTemplate(\%var,$self->getValue("managePurchasesTemplateId")),$self->getValue("styleTemplateId"));
}

#-------------------------------------------------------------------

=head2 www_viewPurchase ( )

Method to display a purchase.  From this screen, admins can 
return the whole purchase, return a whole badge (registration, 
a.k.a itinerary for a single person), or return a single event
from an itinerary.  The purchaser can just add events to 
individual registrations that have at least one event that 
hasn't occurred yet.

=cut

sub www_viewPurchase {
	my $self = shift;
	my %var = $self->get();
	my $isAdmin = $self->canAddEvents;
	my $tid = $self->session->form->process('tid');
	my ($userId) = $self->session->db->quickArray("select userId from transaction where transactionId=?",[$tid]);
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $sql = "select distinct(r.purchaseId), b.* from EventManagementSystem_registrations as r, EventManagementSystem_badges as b, EventManagementSystem_purchases as t where r.badgeId=b.badgeId and r.purchaseId=t.purchaseId and t.transactionId=? order by b.lastName";
	my $sth = $self->session->db->read($sql,[$tid]);
	my @purchasesLoop;
	$var{canReturnTransaction} = 0;
	while (my $purchase = $sth->hashRef) {
		my $badgeId = $purchase->{badgeId};
		my $pid = $purchase->{purchaseId};
		my $sql2 = "select r.registrationId, p.title, p.description, p.price, p.templateId, r.returned, e.approved, e.maximumAttendees, e.startDate, e.endDate, b.userId, b.createdByUserId from EventManagementSystem_registrations as r, EventManagementSystem_badges as b, EventManagementSystem_products as e, products as p where p.productId = r.productId and p.productId = e.productId and r.badgeId=b.badgeId and r.badgeId=? and r.purchaseId=? group by r.registrationId order by b.lastName";
		my $sth2 = $self->session->db->read($sql2,[$badgeId,$pid]);
		$purchase->{regLoop} = [];
		$purchase->{canReturnItinerary} = 0;
		while (my $reg = $sth2->hashRef) {
			$reg->{startDateHuman} = $self->session->datetime->epochToHuman($reg->{'startDate'});
			$reg->{endDateHuman} = $self->session->datetime->epochToHuman($reg->{'endDate'});
			$purchase->{canReturnItinerary} = 1 unless $reg->{'returned'};
			$purchase->{canAddEvents} = 1 if ($isAdmin || ($userId eq $self->session->var->get('userId')) || ($reg->{userId} eq $self->session->var->get('userId'))  || ($reg->{createdByUserId} eq $self->session->var->get('userId')));
			push(@{$purchase->{regLoop}},$reg);
		}
		$var{canReturnTransaction} = 1 if $purchase->{canReturnItinerary};
		push(@purchasesLoop,$purchase);
	}
	
	$var{viewPurchaseTitle} = $i18n->get('view purchase');
	$var{canReturn} = $isAdmin;
	$var{transactionId} = $tid;
	$var{appUrl} = $self->getUrl;
	$sth->finish;
	$var{purchasesLoop} = \@purchasesLoop;
	return $self->session->style->process($self->processTemplate(\%var,$self->getValue("viewPurchaseTemplateId")),$self->getValue("styleTemplateId"));
}

#-------------------------------------------------------------------

=head2 www_addEventsToBadge ( )

Method to go into badge-addition mode.

=cut

# remember to account for editing the purchase from the commerce cart
# after calling this method...

sub www_addEventsToBadge {
	my $self = shift;
	my %var = $self->get();
	my $isAdmin = $self->canAddEvents;
	my $bid = $self->session->form->process('bid');
	$self->session->scratch->delete('EMS_add_purchase_badgeId');
	$self->session->scratch->set('EMS_add_purchase_badgeId',$bid);
	my @pastEvents = $self->session->db->buildArray("select r.productId from EventManagementSystem_registrations as r, EventManagementSystem_purchases as p where r.returned=0 and r.badgeId=? and p.purchaseId=r.purchaseId group by productId",[$bid]);
	$self->session->scratch->delete('EMS_add_purchase_events');
	$self->session->scratch->set('EMS_add_purchase_events',join("\n",@pastEvents));
	$self->session->scratch->delete('EMS_scratch_cart');
	$self->session->scratch->set('EMS_scratch_cart',join("\n",@pastEvents));
	my @mainEvents = $self->session->db->buildArray("select p.productId from products as p, EventManagementSystem_products as e where p.productId = e.productId and approved=1 and e.assetId =? and (e.prerequisiteId is NULL or e.prerequisiteId = '')	order by sequenceNumber",[$self->get("assetId")]);
	my $mainEvent; # here we have to guess as to which main event they bought.
	foreach(@mainEvents) {
		$mainEvent = $_ if isIn($_,@pastEvents);
	}
	$self->session->http->setRedirect($self->getUrl."?func=search;cfilter_s0=requirement;cfilter_c0=eq;subSearch=1;cfilter_t0=".$mainEvent);
	return 1;
}

#-------------------------------------------------------------------

=head2 www_returnItem ( )

Method to set some registrations as returned.

=cut

sub www_returnItem {
	my $self = shift;
	my %var = $self->get();
	my $isAdmin = $self->canAddEvents;
	my $rid = $self->session->form->process('rid');
	my $tid = $self->session->form->process('tid');
	my $pid = $self->session->form->process('pid');
	my @regs;
	if ($pid) {
		@regs = $self->session->db->buildArray("select registrationId from EventManagementSystem_registrations where purchaseId=?",[$pid]);
	} elsif ($tid) {
		@regs = $self->session->db->buildArray("select registrationId from EventManagementSystem_purchases as t,EventManagementSystem_registrations as r where r.purchaseId=t.purchaseId and t.transactionId=?",[$tid]);
	} elsif ($rid) {
		@regs = ($rid);
	}
	foreach (@regs) {
		$self->session->db->write("update EventManagementSystem_registrations set returned=1 where registrationId=?",[$_]);
	}
	return $self->www_managePurchases;
}

#-------------------------------------------------------------------
sub www_editEventMetaDataField {
	my $self = shift;
	my $fieldId = shift || $self->session->form->process("fieldId");
	my $error = shift;
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $i18n2 = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $i18n = WebGUI::International->new($self->session,"WebGUIProfile");
	my $f = WebGUI::HTMLForm->new($self->session, (
		action => $self->getUrl."?func=editEventMetaDataFieldSave;fieldId=".$fieldId
	));
	my $data = {};
	if ($error) {
		# load submitted data.
		$data = {
			name => $self->session->form->process("name"),
			label => $self->session->form->process("label"),
			dataType => $self->session->form->process("dataType",'fieldType'),
			visible => $self->session->form->process("visible",'yesNo'),
			required => $self->session->form->process("required",'yesNo'),
			possibleValues => $self->session->form->process("possibleValues",'textarea'),
			defaultValues => $self->session->form->process("defaultValues",'textarea'),
		};
		$f->readOnly(
			-name => 'error',
			-label => 'Error:',
			-value => '<span style="color:red;font-weight:bold">'.$error.'</span>',
		);
	} elsif ($fieldId ne 'new') {
		$data = $self->session->db->quickHashRef("select * from EventManagementSystem_metaField where fieldId=?",[$fieldId]);
	} else {
		# new field defaults
		$data = {
			name => $i18n2->get('type name here'),
			label => $i18n2->get('type label here'),
			dataType => 'text',
			visible => 0,
			required => 0,
			autoSearch => 0
		};
	}
	$f->text(
		-name => "name",
		-label => $i18n->get(475),
		-hoverHelp => $i18n->get('475 description'),
		-extras=>(($data->{name} eq $i18n2->get('type name here'))?' style="color:#bbbbbb" ':'').' onblur="if(!this.value){this.value=\''.$i18n2->get('type name here').'\';this.style.color=\'#bbbbbb\';}" onfocus="if(this.value == \''.$i18n2->get('type name here').'\'){this.value=\'\';this.style.color=\'\';}"',
		-value => $data->{name},
	);
	$f->text(
		-name => "label",
		-label => $i18n->get(472),
		-hoverHelp => $i18n->get('472 description'),
		-value => $data->{label},
		-extras=>(($data->{label} eq $i18n2->get('type label here'))?' style="color:#bbbbbb" ':'').' onblur="if(!this.value){this.value=\''.$i18n2->get('type label here').'\';this.style.color=\'#bbbbbb\';}" onfocus="if(this.value == \''.$i18n2->get('type label here').'\'){this.value=\'\';this.style.color=\'\';}"',
	);
	$f->yesNo(
		-name=>"visible",
		-label=>$i18n->get('473a'),
		-hoverHelp=>$i18n->get('473a description'),
		-value=>$data->{visible}
	);
	$f->yesNo(
		-name=>"required",
		-label=>$i18n->get(474),
		-hoverHelp=>$i18n->get('474 description'),
		-value=>$data->{required}
	);
	my $fieldType = WebGUI::Form::FieldType->new($self->session,
		-name=>"dataType",
		-label=>$i18n->get(486),
		-hoverHelp=>$i18n->get('486 description'),
		-value=>ucfirst $data->{dataType},
		-defaultValue=>"Text",
	);
	my @profileForms = ();
	foreach my $form ( sort @{ $fieldType->get("types") }) {
		next if $form eq 'DynamicField';
		my $cmd = join '::', 'WebGUI::Form', $form;
		eval "use $cmd";
		my $w = eval {"$cmd"->new($self->session)};
		push @profileForms, $form if $w->get("profileEnabled");
	}

	$fieldType->set("types", \@profileForms);
	$f->raw($fieldType->toHtmlWithWrapper());
	$f->textarea(
		-name => "possibleValues",
		-label => $i18n->get(487),
		-hoverHelp => $i18n->get('487 description'),
		-value => $data->{possibleValues},
	);
	$f->textarea(
		-name => "defaultValues",
		-label => $i18n->get(488),
		-hoverHelp => $i18n->get('488 description'),
		-value => $data->{defaultValues},
	);
	$f->yesNo(
		-name => "autoSearch",
		-label => $i18n2->get('auto search'),
		-hoverHelp => $i18n2->get('auto search description'),
		-value => $data->{autoSearch},
	);
	my %hash;
	foreach my $category (@{WebGUI::ProfileCategory->getCategories($self->session)}) {
		$hash{$category->getId} = $category->getLabel;
	}
	$f->submit;
		$self->getAdminConsole->setHelp('event management system manage events','Asset_EventManagementSystem');
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=editEventMetaDataField;fieldId=new'), $i18n2->get("add new event metadata field"));
	return $self->_acWrapper($f->print, $i18n2->get("add new event metadata field"));
}

#-------------------------------------------------------------------
sub www_editEventMetaDataFieldSave {
	my $self = shift;
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $error = '';
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	foreach ('name','label') {
		if ($self->session->form->get($_) eq "" || 
			$self->session->form->get($_) eq $i18n->get('type name here') ||
			$self->session->form->get($_) eq $i18n->get('type label here')) {
			$error .= sprintf($i18n->get('null field error'),$_)."<br />";
		}
	}
	return $self->www_editEventMetaDataField(undef,$error) if $error;
	my $newId = $self->setCollateral("EventManagementSystem_metaField", "fieldId",{
		fieldId=>$self->session->form->process('fieldId'),
		name => $self->session->form->process("name"),
		label => $self->session->form->process("label"),
		dataType => $self->session->form->process("dataType",'fieldType'),
		visible => $self->session->form->process("visible",'yesNo'),
		required => $self->session->form->process("required",'yesNo'),
		possibleValues => $self->session->form->process("possibleValues",'textarea'),
		defaultValues => $self->session->form->process("defaultValues",'textarea'),
		autoSearch => $self->session->form->process("autoSearch",'yesNo')
	},1,1);
	return $self->www_manageEventMetadata();
}



#-------------------------------------------------------------------

=head2 www_moveEventMetaDataFieldDown ( )

Method to move an event down one position in display order

=cut

sub www_moveEventMetaDataFieldDown {
	my $self = shift;
	my $eventId = $self->session->form->get("fieldId");
	
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->moveCollateralDown('EventManagementSystem_metaField', 'fieldId', $eventId);

	return $self->www_manageEventMetadata;
}

#-------------------------------------------------------------------

=head2 www_moveEventMetaDataFieldUp ( )

Method to move an event metdata field up one position in display order

=cut

sub www_moveEventMetaDataFieldUp {
	my $self = shift;
	my $eventId = $self->session->form->get("fieldId");

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->moveCollateralUp('EventManagementSystem_metaField', 'fieldId', $eventId);
	
	return $self->www_manageEventMetadata;
}


#-------------------------------------------------------------------

=head2 www_deleteEventMetaDataField ( )

Method to move an event metdata field up one position in display order

=cut

sub www_deleteEventMetaDataField {
	my $self = shift;
	my $eventId = $self->session->form->get("fieldId");

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->deleteCollateral('EventManagementSystem_metaField', 'fieldId', $eventId);
	$self->reorderCollateral('EventManagementSystem_metaField', 'fieldId');
	$self->deleteCollateral('EventManagementSystem_metaData', 'fieldId', $eventId); # deleteCollateral doesn't care about assetId.
	
	return $self->www_manageEventMetadata;
}

#-------------------------------------------------------------------

=head2 www_moveEventDown ( )

Method to move an event down one position in display order

=cut

sub www_moveEventDown {
	my $self = shift;
	my $eventId = $self->session->form->get("pid");
	
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->moveCollateralDown('EventManagementSystem_products', 'productId', $eventId);

	return $self->www_search;
}

#-------------------------------------------------------------------

=head2 www_moveEventUp ( )

Method to move an event up one position in display order

=cut

sub www_moveEventUp {
	my $self = shift;
	my $eventId = $self->session->form->get("pid");

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	
	$self->moveCollateralUp('EventManagementSystem_products', 'productId', $eventId);
	
	return $self->www_search;
}

#-------------------------------------------------------------------
# Disable until new prerequ UI is in place
#
#
#sub www_savePrerequisites {
#	my $self = shift;
#	my $eventToAssignPrereqTo = $self->session->form->get("eventToAssignPrereqTo");
#	
#	return $self->session->privilege->insufficient unless ($self->canAddEvents);
#	
#	my $prerequisiteList = $self->session->form->process("eventList", "checkList");
#	my @list = split(/\n/, $prerequisiteList);
#	unless ($prerequisiteList eq "") {
#		my $prerequisiteId = $self->setCollateral("EventManagementSystem_prerequisites", "prerequisiteId",
#				{
#				 prerequisiteId  => "new",
#				 productId       => $eventToAssignPrereqTo,
#				 operator	 => $self->session->form->get("requirement")
#				},0,0
#		);
#		
#		foreach my $requiredEvent (@list) {
#			$self->setCollateral("EventManagementSystem_prerequisiteEvents", "prerequisiteEventId",{
#				prerequisiteEventId => "new",
#				prerequisiteId      => $prerequisiteId,
#				requiredProductId   => $requiredEvent
#			},0,0);
#		}
#	}
#	
#	my $instance = WebGUI::Workflow::Instance->create($self->session, {
#		workflowId=>'EMSworkflow00000000001'
#	});
#	
#	return $self->www_editEvent(undef,$eventToAssignPrereqTo);
#}

#-------------------------------------------------------------------
sub www_saveRegistration {
	my $self = shift;
	my $eventsInCart = $self->getEventsInScratchCart;
	my $purchaseId = $self->session->id->generate;
	my ($myBadgeId) = $self->session->db->quickArray("select badgeId from EventManagementSystem_badges where userId=?",[$self->session->var->get('userId')]);
	$myBadgeId ||= "new"; # if there is no badge for this user yet, have setCollateral create one, assuming thisIsI.
	my $theirBadgeId = $self->session->form->get('badgeId') || "new";
	  # ^ if this is "new", the person is not currently logged in, so they 
	  # get a new badgeId no matter what.  If someone wants to add registrations
	  # to an existing badge, they need to log in first.
	my $thisIsI = $theirBadgeId eq 'thisIsI';
	my $badgeId = $thisIsI ? $myBadgeId : $theirBadgeId;
	my $userId = $thisIsI ? $self->session->var->get('userId') : '';
	my $firstName = $self->session->form->get("firstName", "text");
	my $lastName = $self->session->form->get("lastName", "text");
	my $address = $self->session->form->get("address", "text");
	my $city = $self->session->form->get("city", "text");
	my $state = $self->session->form->get("state", "text");
	my $zipCode = $self->session->form->get("zipCode", "text");
	my $country = $self->session->form->get("country", "selectBox");
	my $phoneNumber = $self->session->form->get("phone", "phone");
	my $email = $self->session->form->get("email", "email");
	my $addingNew = ($badgeId eq 'new') ? 1 : 0;
	my $details = {
		badgeId => $badgeId, # if this is "new", setCollateral will return the new one.
		firstName       => $firstName,
		lastName	 => $lastName,
		address         => $address,
		city            => $city,
		state		 => $state,
		zipCode	 => $zipCode,
		country	 => $country,
		phone		 => $phoneNumber,
		email		 => $email
	};
	$details->{userId} = $userId if ($userId && $userId ne '1');
	$details->{createdByUserId} = $self->session->var->get('userId') if ($addingNew && $userId ne '1');
	$badgeId = $self->setCollateral("EventManagementSystem_badges", "badgeId",$details,0,0);
	
	my $shoppingCart = WebGUI::Commerce::ShoppingCart->new($self->session);
	
	my @addingToPurchase = split("\n",$self->session->scratch->get('EMS_add_purchase_events'));
	# @addingToPurchase = () if ($self->session->scratch->get('EMS_add_purchase_badgeId') && !($self->session->scratch->get('EMS_add_purchase_badgeId') eq $badgeId));
	foreach my $eventId (@$eventsInCart) {
		next if isIn($eventId,@addingToPurchase);
		my $registrationId = $self->setCollateral("EventManagementSystem_registrations", "registrationId",{
			registrationId  => "new",
			purchaseId	 => $purchaseId,
			productId	 => $eventId,
			badgeId => $badgeId
		},0,0);
		$shoppingCart->add($eventId, 'Event');
	}
	$self->emptyScratchCart;
	$self->session->scratch->delete('EMS_add_purchase_badgeId');
	$self->session->scratch->delete('EMS_add_purchase_events');
	
	my ($theirUserId) = $self->session->db->quickArray("select userId from EventManagementSystem_badges where badgeId=?",[$badgeId]);
	$userId = $theirUserId unless $thisIsI;
	if ($userId && $userId ne '1') {
		my $u = WebGUI::User->new($self->session,$userId);
		$u->profileField('firstName',$firstName);
		$u->profileField('lastName',$lastName);
		$u->profileField('homeAddress',$address);
		$u->profileField('homeCity',$city);
		$u->profileField('homeState',$state);
		$u->profileField('homeZip',$zipCode);
		$u->profileField('homeCountry',$country);
		$u->profileField('homePhone',$phoneNumber);
		$u->profileField('email',$email);
	}
	#Our item plug-in needs to be able to associate these records with the result of the payment attempt
	my $counter = 0;
	while (1) {
		unless ($self->session->scratch->get("purchaseId".$counter)) {
			$self->session->scratch->set("purchaseId".$counter, $purchaseId);
			last;
		}
		$counter++;	
	}	
	return $self->www_view;
}

#-------------------------------------------------------------------

=head2 prepareView ( )

See WebGUI::Asset::prepareView() for details.

=cut

sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView();
	my $templateId = $self->get("displayTemplateId");
	my $template = WebGUI::Asset::Template->new($self->session, $templateId);
	$template->prepare;
	$self->{_viewTemplate} = $template;
}

#-------------------------------------------------------------------
sub www_search {
	my $self = shift;
	my $managePrereqs = shift || $self->session->form->get("managePrereqs");
	my $eventToAssignPrereqTo = shift || $self->session->form->get("eventToAssignPrereqTo");

	#these allow us to show a specific page of subevents after an add to scratch cart
	my $eventAdded = shift;
	my $cfilter_t0 = shift;
	my $cfilter_s0 = shift;
	my $cfilter_c0 = shift;
	my $pn;
	my $subSearchFlag;
	my $showAllFlag;
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $addToBadgeMessage;
	if ($cfilter_t0 && $cfilter_s0 && $cfilter_c0) {
		$pn = shift || 1;
		$subSearchFlag = 1;
		$showAllFlag = 1;
		$addToBadgeMessage = sprintf $i18n->get('add to badge message'), $eventAdded;
	}
	
	my $prerequisiteHash = $self->getPrerequisiteEventList($eventToAssignPrereqTo) if ($eventToAssignPrereqTo);
	my @prerequisiteList;
	my %var;
	my $keywords = $self->session->form->get("searchKeywords");
	my @keys;
	my $joins;
	my $selects;
	my @joined;
	
	my $language  = $i18n->getLanguage(undef,"languageAbbreviation");
	$var{'calendarJS'} = '<script type="text/javascript" src="'.$self->session->url->extras('calendar/calendar.js').'"></script><script type="text/javascript" src="'.$self->session->url->extras('calendar/lang/calendar-'.$language.'.js').'"></script><script type="text/javascript" src="'.$self->session->url->extras('calendar/calendar-setup.js').'"></script>';
	
	#Get the eventIds of valid prereqs if we're in prereq mode
	#Put the productIds of valid prereqs into a list so we can return only valid prereq choices in our search
	if (scalar(keys %{$prerequisiteHash})) {
		foreach (keys %{$prerequisiteHash}) {
			push (@prerequisiteList, $_);
		}
	}

	push(@keys,$keywords) if $keywords;
	unless ($keywords =~ /^".*"$/) {
		foreach (split(" ",$keywords)) {
			push(@keys,$_) unless $keywords eq $_;
		}
	} else {
		$keywords =~ s/"//g;
		@keys = ($keywords);
	}
	my $searchPhrases;
	if (scalar(@keys)) {
		#$searchPhrases = " and ( ";
		my $count = 0;
		foreach (@keys) {
			$searchPhrases .= ' and ' if $count;
			my $val = $self->session->db->quote('%'.$_.'%');
			$searchPhrases .= "(p.title like $val or p.description like $val or p.sku like $val)";
			$count++;
		}
		#$searchPhrases .= " )";
	}
	my $basicSearch = $searchPhrases;
	my %reqHash;
	my $seatsAvailable = 'none';
	my $seatsCompare;
	if ($self->session->form->get("advSearch") || $self->session->form->get("subSearch") || $subSearchFlag) {
		my $fields = $self->_getFieldHash();
		my $count = 0;
		if ($basicSearch ne "") {
		   $count = 1;
		}
		for (my $cfilter = 0; $cfilter < 50; $cfilter++) {
			my $value;
			my $fieldId;
			my $compare;
			
			# filter 0 is reserved for passing a search filter via the url
			# or as parameters to this method call.  All user selectable filters
			# begin with number 1, i.e., cfilter_t1, cfilter_s1, cfilter_c1
			#
			if ($cfilter_t0 && $cfilter_s0 && $cfilter_c0 && $pn) { # a filter was passed as params to the method call
				if ($cfilter == 0) { #don't want to overwrite the user filters
					$value = $cfilter_t0;
					$fieldId = $cfilter_s0;
					$compare = $cfilter_c0;
				}
			}
			
			$value = $self->session->form->get("cfilter_t".$cfilter) unless ($value);
			$fieldId = $self->session->form->get("cfilter_s".$cfilter) unless ($fieldId);
			if ($fieldId eq 'requirement') {
				$reqHash{$value} = 1 if $value;
			}
			if ($fieldId eq 'seatsAvailable') {
				$seatsAvailable = $value if ($value || $value eq '0');
				$seatsCompare = $self->session->form->get("cfilter_c".$cfilter);
			}
			# temporary
			next if ($fieldId eq 'seatsAvailable' || $fieldId eq 'requirement');
			# end temporary
			next unless (($value || $value =~ /^0/) && defined $fields->{$fieldId});
			$compare = $self->session->form->get("cfilter_c".$cfilter) unless ($compare);
			#Format Value with Operator
			$value =~ s/%//g;
			my $field = $fields->{$fieldId};
			if ($field->{type} =~ /^date/i) {
        $value = $self->session->datetime->setToEpoch($value);
			} else {
				$value = lc($value);
			}
			my $compareType = $field->{compare};
			if($compare eq "eq") {
				$value = "=".$self->session->db->quote($value);
			} elsif($compare eq "ne"){
				$value = "<>".$self->session->db->quote($value);
			} elsif($compare eq "notlike") {
				$value = "not like ".$self->session->db->quote("%".$value."%");
			} elsif($compare eq "starts") {
				$value = "like ".$self->session->db->quote($value."%");
			} elsif($compare eq "ends") {
				$value = "like ".$self->session->db->quote("%".$value);
			} elsif($compare eq "gt") {
				$value = "> ".$value;
			} elsif($compare eq "lt") {
				$value = "< ".$value;
			} elsif($compare eq "lte") {
				$value = "<= ".$value;
			} elsif($compare eq "gte") {
				$value = ">= ".$value;
			} elsif($compare eq "like") {
				$value = " like ".$self->session->db->quote("%".$value."%");
			}
			$searchPhrases .= " and " if($count);
			$count++;
			my $isMeta = $field->{metadata};		
			my $phrase;
			if ($isMeta) {
				unless(WebGUI::Utility::isIn($fieldId,@joined)) {
					$joins .= " left join EventManagementSystem_metaData joinedField$count on e.productId=joinedField$count.productId and joinedField$count.fieldId='$fieldId'";
					push(@joined,$fieldId);
				}
			#	$selects .= ", joinedField$count.fieldData as joinedField".$count.'a';
				$phrase = " joinedField".$count.".fieldData ";
				$searchPhrases .= " ".$phrase." ".$value;
			} else {
				# shouldn't need to join anything else
				$phrase = $field->{tableName}.'.'.$field->{columnName};
				if ($compareType ne 'numeric') {
					$searchPhrases .= " lower(".$phrase.") ".$value;
				} else {
					$searchPhrases .= " ".$phrase." ".$value;
				}
			}
		}
		#$searchPhrases &&= " and ( ".$searchPhrases." )";
	}
	$searchPhrases &&= " and ( ".$searchPhrases." )";
	# $self->session->errorHandler->warn("searchPhrases: $searchPhrases<br />basicSearch: $basicSearch<br />");
	# Get the products available for sale for this page
	my $approvalPhrase = ($self->canApproveEvents)?' ':' and approved=1';
	my $sql = "select p.productId, p.title, p.description, p.price, p.templateId, p.weight, p.sku, p.skuTemplate, e.approved, e.maximumAttendees, e.startDate, e.endDate, e.prerequisiteId $selects
		   from products as p, EventManagementSystem_products as e 
		   $joins 
		   where
		   	p.productId = e.productId $approvalPhrase
		   	and e.assetId =".$self->session->db->quote($self->get("assetId")).$searchPhrases. " order by sequenceNumber";
#		   	." 
#			and p.productId not in (select distinct(productId) from EventManagementSystem_prerequisites)";		

	$var{'basicSearch.formHeader'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl("func=search;advSearch=0")}).
					 WebGUI::Form::hidden($self->session,{name=>"subSearch", value => $self->session->form->get("subSearch")}).
					 WebGUI::Form::hidden($self->session,{name => "cfilter_s0", value => "requirement"}).
					 WebGUI::Form::hidden($self->session,{name => "cfilter_c0", value => "eq"}).
					 WebGUI::Form::hidden($self->session,{name => "cfilter_t0", value => $self->session->form->get("cfilter_t0")}).
					 WebGUI::Form::hidden($self->session,{name => "managePrereqs", value => $managePrereqs}).
					 WebGUI::Form::hidden($self->session,{name => "eventToAssignPrereqTo", value => $eventToAssignPrereqTo});
	$var{'advSearch.formHeader'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl("func=search;advSearch=1")}).
				       WebGUI::Form::hidden($self->session,{name => "cfilter_s0", value => "requirement"}).
				       WebGUI::Form::hidden($self->session,{name => "cfilter_c0", value => "eq"}).
				       WebGUI::Form::hidden($self->session,{name => "cfilter_t0", value => $self->session->form->get("cfilter_t0")}).
				       WebGUI::Form::hidden($self->session,{name => "managePrereqs", value => $managePrereqs}).
				       WebGUI::Form::hidden($self->session,{name => "eventToAssignPrereqTo", value => $eventToAssignPrereqTo});
	$var{isAdvSearch} = $self->session->form->get('advSearch');
	$var{'search.formFooter'} = WebGUI::Form::formFooter($self->session);
	$var{'search.formSubmit'} = WebGUI::Form::submit($self->session, {name=>"filter",value=>$i18n->get('filter')});
	my $searchUrl = $self->getUrl("a=1");  #a=1 is a hack to get the ? appended to the url in the right place.  This param/value does nothing.
	my $formVars = $self->session->form->paramsHashRef();
	my @paramsUsed;
	foreach ($self->session->form->param) {
		$searchUrl .= ';'.$_.'='.$formVars->{$_} if (($_ ne 'pn') && ($formVars->{$_} || $formVars->{$_} eq '0') && !isIn(@paramsUsed, $_) && $_ ne "a");
		push (@paramsUsed, $_);
	}
	my $p = WebGUI::Paginator->new($self->session,$searchUrl,$self->get("paginateAfter"));
	my (@results, $sth, $data);
	$sth = $self->session->db->read($sql);
	while ($data = $sth->hashRef) {
		my $shouldPush = 1;
		my $eventId = $data->{productId};
		my $requiredList = 
			($data->{prerequisiteId})
			?$self->getAllPossibleRequiredEvents($data->{prerequisiteId})
			:[];
		if ($seatsAvailable ne 'none') {
			my ($numberRegistered) = $self->session->db->quickArray("select count(*) from EventManagementSystem_registrations as r, EventManagementSystem_purchases as p
	  	where r.purchaseId = p.purchaseId and r.returned=0 and r.productId=".$self->session->db->quote($eventId));
	  	if($seatsCompare eq "eq") {
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered == $seatsAvailable);
			} elsif($seatsCompare eq "ne"){
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered != $seatsAvailable);
			} elsif($seatsCompare eq "gt") {
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered > $seatsAvailable);
			} elsif($seatsCompare eq "lt") {
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered < $seatsAvailable);
			} elsif($seatsCompare eq "lte") {
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered <= $seatsAvailable);
			} elsif($seatsCompare eq "gte") {
				$shouldPush = 0 unless ($data->{'maximumAttendees'} - $numberRegistered >= $seatsAvailable);
			}
		}
		foreach (keys %reqHash) {
			$shouldPush = 0 unless isIn($_,@{$requiredList});
		}
		if ($managePrereqs) { #prereq mode
			#$self->session->errorHandler->warn("prereq list<pre>".Dumper(@prerequisiteList)."</pre>");
			#$self->session->errorHandler->warn("productId<pre>".Dumper($data->{productId})."</pre>");
			$shouldPush = 0 unless (isIn($data->{productId}, @prerequisiteList)); #include only valid prereqs in results
			#$self->session->errorHandler->warn("<pre>".Dumper($shouldPush)."</pre>");
		}
		push(@results,$data) if $shouldPush;
	}
	#$self->session->errorHandler->warn("<pre>".Dumper(@results)."</pre>");
	$sth->finish;
	my $maxResultsForInitialDisplay = 50000;
	my $numSearchResults = scalar(@results);
	@results = () unless ( ($numSearchResults <= $maxResultsForInitialDisplay) || ($self->session->form->get("advSearch") || $self->session->form->get("searchKeywords") || $showAllFlag));	
	$p->setDataByArrayRef(\@results);
	my $eventData = $p->getPageData($pn);
	my @events;
	foreach my $event (@$eventData) {
	  my %eventFields;
	
	  $eventFields{'title'} = $event->{'title'};
	  $eventFields{'description'} = $event->{'description'};
	  $eventFields{'price'} = '$'.$event->{'price'};
	  $eventFields{'sku'} = $event->{'sku'};
	  $eventFields{'skuTemplate'} = $event->{'skuTemplate'};
	  $eventFields{'weight'} = $event->{'weight'};
	  my ($numberRegistered) = $self->session->db->quickArray("select count(*) from EventManagementSystem_registrations as r, EventManagementSystem_purchases as p
	  	where r.purchaseId = p.purchaseId and r.productId=".$self->session->db->quote($event->{'productId'}));
	  $eventFields{'numberRegistered'} = $numberRegistered;
	  $eventFields{'maximumAttendees'} = $event->{'maximumAttendees'};
	  $eventFields{'seatsRemaining'} = $event->{'maximumAttendees'} - $numberRegistered;
	  $eventFields{'startDate.human'} = $self->session->datetime->epochToHuman($event->{'startDate'});
	  $eventFields{'startDate'} = $event->{'startDate'};
	  $eventFields{'endDate.human'} = $self->session->datetime->epochToHuman($event->{'endDate'});
	  $eventFields{'endDate'} = $event->{'endDate'};
	  $eventFields{'productId'} = $event->{'productId'};
	  $eventFields{'eventIsFull'} = ($eventFields{'seatsRemaining'} <= 0);
	  $eventFields{'eventIsApproved'} = $event->{'approved'};
	  $eventFields{'manageToolbar'} = $self->session->icon->delete('func=deleteEvent;pid='.$event->{productId}, $self->getUrl,
					  $i18n->get('confirm delete event')).
					  $self->session->icon->edit('func=editEvent;pid='.$event->{productId}, $self->getUrl).
					  $self->session->icon->moveUp('func=moveEventUp;pid='.$event->{productId}, $self->getUrl).
					  $self->session->icon->moveDown('func=moveEventDown;pid='.$event->{productId}, $self->getUrl);

	  if ($eventFields{'eventIsFull'}) {
	  	$eventFields{'purchase.label'} = $i18n->get('sold out');
	  }
	  else {
		my $masterEventId = $cfilter_t0 || $self->session->form->get("cfilter_t0");
	  	$eventFields{'purchase.url'} = $self->getUrl('func=addToScratchCart;pid='.$event->{'productId'}.";mid=".$masterEventId);
	  	$eventFields{'purchase.label'} = $i18n->get('add to cart');
	  }
	  
	  # Set template vars for managing prerequisites if we're in manage prereqs mode
	  if ($managePrereqs) {
		$eventFields{'prereqForm.checkbox'} = WebGUI::Form::checkbox($self->session,{
						-name => 'eventList',
						#-checked => $row{approved},
						-value => $event->{productId}
					});
	  }
	  
	  push (@events, {'event' => $self->processTemplate(\%eventFields, $event->{'templateId'}), %eventFields });
	} 
	
	$var{'events_loop'} = \@events;
	$var{'paginateBar'} = $p->getBarTraditional;
	$var{'manageEvents.url'} = $self->getUrl('func=search');
	$var{'manageEvents.label'} = $i18n->get('manage events');
	$var{'managePurchases.url'} = $self->getUrl('func=managePurchases');
	$var{'managePurchases.label'} = $i18n->get('manage purchases');
	$var{'noSearchDialog'} = ($self->session->form->get('hide') eq "1") ? 1 : 0;
	$var{'addEvent.url'} = $self->getUrl('func=editEvent;pid=new');
	$var{'addEvent.label'} = $i18n->get('add event');
	$var{'managePrereqs'} = ($managePrereqs) ? 1 : 0;
	$var{'managePrereqsMessage'} = sprintf $i18n->get('managePrereqsMessage'), $self->getEventName($eventToAssignPrereqTo);
	$var{'prereqForm.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl}).
					      WebGUI::Form::hidden($self->session,{name=>"eventToAssignPrereqTo", value=>$eventToAssignPrereqTo}).
					      WebGUI::Form::hidden($self->session,{name=>"func", value=>"savePrerequisites"});
	$var{'prereqForm.submit'} = WebGUI::Form::submit($self->session);
	$var{'prereqForm.footer'} = WebGUI::Form::formFooter($self->session);
	$var{'prereqForm.operator'} = WebGUI::Form::radioList($self->session,{
					name  => "requirement",
					options => { 'and' => $i18n->get("and"),
						      'or'  => $i18n->get("or"),
						    },
					value => 'and',
					label => $i18n->get("add/edit event operator"),
					hoverHelp => $i18n->get("add/edit event operator description")
									     });
	if ($self->session->user->isInGroup($self->get("groupToManageEvents"))) {
		$var{'canManageEvents'} = 1;
	}
	else {
		$var{'canManageEvents'} = 0;
	}
	my $message;
	$subSearchFlag = $self->session->form->get("subSearch") || ($self->session->form->get("func"));
	my $advSearchFlag = $self->session->form->get("advSearch");
	my $basicSearchFlag = $self->session->form->get("searchKeywords");
	my $managePrereqsFlag = $var{'managePrereqs'};
	my $paginationFlag = $self->session->form->get("pn") || $pn;
	my $hasSearchedFlag = ($self->session->form->get("filter"));
	
	#Determine type of search results we're displaying
	if ($subSearchFlag && !$managePrereqsFlag && ($numSearchResults <= $maxResultsForInitialDisplay || $paginationFlag || $hasSearchedFlag)) {
		if ($self->canEdit) { #Admin manage sub events small resultset
			$message = $i18n->get('Admin manage sub events small resultset');
		} else { #User sub events small resultset
			$message = $i18n->get("User sub events small resultset");
		}
	} elsif ($subSearchFlag && $numSearchResults > $maxResultsForInitialDisplay && !$managePrereqsFlag && !$paginationFlag) {
		if ($self->canEdit) { #Admin manage sub events large resultset
			$message = $i18n->get('Admin manage sub events large resultset');   
		} else { #User sub events large resultset
			$message = $i18n->get('User sub events large resultset');   
		}

	} elsif ($managePrereqsFlag && ($numSearchResults <= $maxResultsForInitialDisplay || $paginationFlag || $hasSearchedFlag)) {
		$message = $i18n->get('option to narrow');
	} elsif ($managePrereqsFlag && $numSearchResults > $maxResultsForInitialDisplay && !$paginationFlag) {
		$message = $i18n->get('forced narrowing');
	}
	
	my $somethingInScratch = scalar(@{$self->getEventsInScratchCart});
	$var{'message'} = $message;
	$var{'numberOfSearchResults'} = $numSearchResults;
	$var{'continue.url'} = $self->getUrl('func=addToCart;pid=_noid_') unless ($managePrereqsFlag || !$somethingInScratch);
	$var{'continue.label'} = "Continue" unless ($managePrereqsFlag || !$somethingInScratch);
	$var{'name.label'} = "Event";
	$var{'starts.label'} = "Starts";
	$var{'ends.label'} = "Ends";
	$var{'price.label'} = "Price";
	$var{'seats.label'} = "Seats Available";
	$var{'addToBadgeMessage'} = $addToBadgeMessage;

	$p->appendTemplateVars(\%var);
	$self->buildMenu(\%var);
	$var{'ems.wobject.dir'} = $self->session->url->extras("wobject/EventManagementSystem");
	
	return $self->session->style->process($self->processTemplate(\%var,$self->getValue("searchTemplateId")),$self->getValue("styleTemplateId"));
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my %var;
	
	# If we're at the view method there is no reason we should have anything in our scratch cart
	# so let's empty it to prevent strange and awful things from happening
	unless ($self->session->scratch->get('EMS_add_purchase_badgeId')) {
		$self->emptyScratchCart;
		$self->session->scratch->delete('EMS_add_purchase_events');
	}
	
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	# Get the products available for sale for this page
	my $sql = "select p.productId, p.title, p.description, p.price, p.weight, p.sku, p.skuTemplate, p.templateId, e.approved, e.maximumAttendees 
		   from products as p, EventManagementSystem_products as e
		   where
		   	p.productId = e.productId and approved=1
		   	and e.assetId =".$self->session->db->quote($self->get("assetId"))."
			and (e.prerequisiteId is NULL or e.prerequisiteId = '')";
			#and p.productId not in (select distinct(productId) from EventManagementSystem_prerequisites) order by sequenceNumber";		

	my $p = WebGUI::Paginator->new($self->session,$self->getUrl,$self->get("paginateAfter"));
	$p->setDataByQuery($sql);
	my $eventData = $p->getPageData;
	my @events;

	#We are getting each events information, passing it to the *events* template and processing it
	#The html returned from each events template is returned to the Event Manager Display Template for arranging
	#how the events are displayed in relation to one another.
	foreach my $event (@$eventData) {
	  my %eventFields;
	  
	  $eventFields{'title'} = $event->{'title'};
	  $eventFields{'title.url'} = $self->getUrl('func=search;cfilter_s0=requirement;cfilter_c0=eq;subSearch=1;cfilter_t0='.$event->{'productId'});
	  $eventFields{'description'} = $event->{'description'};
	  $eventFields{'price'} = '$'.$event->{'price'};
	  $eventFields{'sku'} = $event->{'sku'};
	  $eventFields{'skuTemplate'} = $event->{'skuTemplate'};
	  $eventFields{'weight'} = $event->{'weight'};
	  my ($numberRegistered) = $self->session->db->quickArray("select count(*) from EventManagementSystem_registrations as r, EventManagementSystem_purchases as p
	  	where r.purchaseId = p.purchaseId and r.returned=0 and r.productId=".$self->session->db->quote($event->{'productId'}));
	  $eventFields{'numberRegistered'} = $numberRegistered;
	  $eventFields{'maximumAttendees'} = $event->{'maximumAttendees'};
	  $eventFields{'seatsRemaining'} = $event->{'maximumAttendees'} - $numberRegistered;
	  $eventFields{'eventIsFull'} = ($eventFields{'seatsRemaining'} <= 0);
	  $eventFields{'eventIsApproved'} = $event->{'approved'};
	  
	  if ($eventFields{'eventIsFull'}) {
	  	$eventFields{'purchase.label'} = $i18n->get('sold out');
	  }
	  else {
	  	#$eventFields{'purchase.url'} = $self->getUrl('func=addToCart;isMaster=1;pid='.$event->{'productId'});
		$eventFields{'purchase.message'} = "Would you like to see available subevents?";
		$eventFields{'purchase.wantToSearch.url'} = $self->getUrl('func=search;cfilter_s0=requirement;cfilter_c0=eq;subSearch=1;cfilter_t0='.$event->{productId});
	        $eventFields{'purchase.wantToContinue.url'} = $self->getUrl('func=addToCart;pid='.$event->{productId});
	  	$eventFields{'purchase.label'} = $i18n->get('add to cart');
	  }
	  push (@events, {'event' => $self->processTemplate(\%eventFields, $event->{'templateId'}) });	  
	} 
	$var{'checkout.url'} = $self->getUrl('op=viewCart');			

	$var{'checkout.label'} = $i18n->get('checkout');
	$var{'events_loop'} = \@events;
	$var{'paginateBar'} = $p->getBarTraditional;
	$var{'manageEvents.url'} = $self->getUrl('func=search');
	$var{'manageEvents.label'} = $i18n->get('manage events');
	$var{'managePurchases.url'} = $self->getUrl('func=managePurchases');
	$var{'managePurchases.label'} = $i18n->get('manage purchases');
	if ($self->session->user->isInGroup($self->get("groupToManageEvents"))) {
		$var{'canManageEvents'} = 1;
	}
	else {
		$var{'canManageEvents'} = 0;
	}
	$p->appendTemplateVars(\%var);
	
	my $templateId = $self->get("displayTemplateId");

	return $self->processTemplate(\%var, undef, $self->{_viewTemplate});
}

#-------------------------------------------------------------------

=head2 www_managePrereqSets ( )

Method to display the prereq set management console.

=cut

sub www_managePrereqSets {
	my $self = shift;

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	
	my $output;
	my $sth = $self->session->db->read("select prerequisiteId, name from EventManagementSystem_prerequisites order by name");
	
	if ($sth->rows) {

		while (my %row = $sth->hash) {
			$output .= "<div>";
			$output .= $self->session->icon->delete('func=deletePrereqSet;psid='.$row{prerequisiteId}, $self->getUrl,
							       $i18n->echo('are you sure you want to delete this prerequisite set  this will also unlink any events that are currently set to require this prerequisite set')).
				  $self->session->icon->edit('func=editPrereqSet;psid='.$row{prerequisiteId}, $self->getUrl).
				  " ".$row{name}."</div>";
		}
	} else {
		$output .= $i18n->echo('you do not have any prerequisite sets to display');
	}
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=editPrereqSet;psid=new'), $i18n->echo('add prerequisite set'));

	return $self->_acWrapper($output, $i18n->echo("manage prerequisite sets"));
}


#-------------------------------------------------------------------
sub www_editPrereqSet {
	my $self = shift;
	my $psid = shift || $self->session->form->process("psid") || 'new';
	my $error = shift;
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	my $f = WebGUI::HTMLForm->new($self->session, (
		action => $self->getUrl."?func=editPrereqSetSave;psid=".$psid
	));
	my $data = {};
	if ($error) {
		# load submitted data.
		$data = {
			name => $self->session->form->process("name"),
			requiredEvents => $self->session->form->process("requiredEvents",'selectList'),
		};
		$f->readOnly(
			-name => 'error',
			-label => 'Error:',
			-value => '<span style="color:red;font-weight:bold">'.$error.'</span>',
		);
	} elsif ($psid eq 'new') {
		$data->{name} = $i18n->get('type name here');
		$data->{operator} = 'or';
	} else {
		$data = $self->session->db->quickHashRef("select * from EventManagementSystem_prerequisites where prerequisiteId=?",[$psid]);
	}
	$f->text(
		-name => "name",
		-label => $i18n->echo('prereq set name field label'),
		-hoverHelp => $i18n->echo('prereq set name field description'),
		-extras=>(($data->{name} eq $i18n->get('type name here'))?' style="color:#bbbbbb" ':'').' onblur="if(!this.value){this.value=\''.$i18n->get('type name here').'\';this.style.color=\'#bbbbbb\';}" onfocus="if(this.value == \''.$i18n->get('type name here').'\'){this.value=\'\';this.style.color=\'\';}"',
		-value => $data->{name},
	);
	$f->radioList(
		-name=>"operator",
		-vertical=>1,
		-label=>$i18n->echo('operator type'),
		-hoverHelp => $i18n->echo('whether any or all of the selected events should be required'),
		-options=>{
			'or'=>'any',
			'and'=>'all'
		},
		-value=>$data->{operator}
	);
	$f->checkList(
		-name=>"requiredEvents",
		-vertical=>1,
		-label=>$i18n->echo('events required by this prerequisite set'),
		-hoverHelp => $i18n->echo('place a check beside the events that are part of this prerequisite set'),
		-options=>$self->session->db->buildHashRef("select p.productId, p.title
		   from products as p, EventManagementSystem_products as e
		   where
		   	p.productId = e.productId 
			and (e.prerequisiteId is NULL or e.prerequisiteId = '')"),
		-value=>$self->session->db->buildArrayRef("select requiredProductId from EventManagementSystem_prerequisiteEvents where prerequisiteId=?",[$psid])
	);
	$f->submit;
	return $self->_acWrapper($f->print, $i18n->get("edit event metadata field"));
}

#-------------------------------------------------------------------
sub www_editPrereqSetSave {
	my $self = shift;
	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $error = '';
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	foreach ('name') {
		if ($self->session->form->get($_) eq "" || 
			$self->session->form->get($_) eq $i18n->get('type name here')) {
			$error .= sprintf($i18n->get('null field error'),$_)."<br />";
		}
	}
	return $self->www_editPrereqSet(undef,$error) if $error;
	my $psid = $self->session->form->process('psid');
	$psid = $self->setCollateral("EventManagementSystem_prerequisites", "prerequisiteId",{
		prerequisiteId=>$psid,
		name => $self->session->form->process("name"),
		operator => $self->session->form->process("operator",'radioList')
	},0,0);
	$self->session->db->write("delete from EventManagementSystem_prerequisiteEvents where prerequisiteId=?",[$psid]);
	my @newRequiredEvents = $self->session->form->process('requiredEvents','checkList');
	foreach (@newRequiredEvents) {
		$self->session->db->write("insert into EventManagementSystem_prerequisiteEvents values (?,?)",[$psid,$_]);
	}
	return $self->www_managePrereqSets();
}


#-------------------------------------------------------------------

=head2 www_manageRegistrants ( )

Method to display the registrant management console.

=cut

sub www_manageRegistrants {
	my $self = shift;

	return $self->session->privilege->insufficient unless ($self->canAddEvents);
	my $i18n = WebGUI::International->new($self->session,'Asset_EventManagementSystem');
	
	my $output;
	my $sth = "select * from EventManagementSystem_badges order by lastName";
	

	while (my %row = $sth->hash) {
		$output .= "<div>";
	#	$output .= $self->session->icon->delete('func=deleteRegistrant;psid='.$row{prerequisiteId}, $self->getUrl,
	#					       $i18n->echo('are you sure you want to delete this prerequisite set  this will also unlink any events that are currently set to require this prerequisite set'));
		$output .= $self->session->icon->edit('func=editRegistrant;badgeId='.$row{badgeId}, $self->getUrl).
			"&nbsp;&nbsp;".$row{lastName}.",&nbsp;".$row{firstName}."(&nbsp;".$row{email}.")</div>";
	}
	
	$self->getAdminConsole->addSubmenuItem($self->getUrl('func=editPrereqSet;psid=new'), $i18n->echo('add prerequisite set'));

	return $self->_acWrapper($output, $i18n->echo("manage registrants"));
}




1;
