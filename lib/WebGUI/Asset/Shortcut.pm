package WebGUI::Asset::Shortcut;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use WebGUI::Asset;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Macro;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;

our @ISA = qw(WebGUI::Asset);

#-------------------------------------------------------------------
sub _drawQueryBuilder {
	my $self = shift;
	# Initialize operators
	my @textFields = qw|text yesNo selectList radioList|;
	my %operator;
	foreach (@textFields) {
		$operator{$_} = {
			"=" => WebGUI::International::get("is","Asset_Shortcut"),
			"!=" => WebGUI::International::get("isnt","Asset_Shortcut")
		};
	}
	$operator{integer} = {
		"=" => WebGUI::International::get("equal to","Asset_Shortcut"),
		"!=" => WebGUI::International::get("not equal to","Asset_Shortcut"),
		"<" => WebGUI::International::get("less than","Asset_Shortcut"),
		">" => WebGUI::International::get("greater than","Asset_Shortcut")
	};

	# Get the fields and count them
	my $fields = $self->getMetaDataFields();
	my $fieldCount = scalar(keys %$fields);

	unless ($fieldCount) {	# No fields found....
		return 'No metadata defined yet.
		<a href="'.WebGUI::URL::page('func=manageMetaData').
		'">Click here</a> to define metadata attributes.';
	}

	# Static form fields
	my $shortcutCriteriaField = WebGUI::Form::textarea({
		name=>"shortcutCriteria",
		value=>$self->getValue("shortcutCriteria"),
		extras=>'style="width: 100%" '.$self->{_disabled}
	});
	my $conjunctionField = WebGUI::Form::selectBox({
		name=>"conjunction",
		options=>{
			"AND" => WebGUI::International::get("AND","Asset_Shortcut"),
			"OR" => WebGUI::International::get("OR","Asset_Shortcut")},
			value=>["OR"],
			extras=>'class="qbselect"',
		}
	);

	# html
	my $output;
	$output .= '<script type="text/javascript" src="'.
	$session{config}{extrasURL}.'/wobject/Shortcut/querybuilder.js"></script>';
	$output .= '<link href="'.$session{config}{extrasURL}.
	'/wobject/Shortcut/querybuilder.css" type="text/css" rel="stylesheet">';
	$output .= qq|<table cellspacing="0" cellpadding="0" border="0"><tr><td colspan="5" align="right">$shortcutCriteriaField</td></tr><tr><td></td><td></td><td></td><td></td><td class="qbtdright"></td></tr><tr><td></td><td></td><td></td><td></td><td class="qbtdright">$conjunctionField</td></tr>|;

	# Here starts the field loop
	my $i = 1;
	foreach my $field (keys %$fields) {
		my $fieldLabel = $fields->{$field}{fieldName};
		my $fieldType = $fields->{$field}{fieldType} || "text";

		# The operator select field
		my $opFieldName = "op_field".$i;
		my $opField = WebGUI::Form::selectList({
			name=>$opFieldName,
			uiLevel=>5,
			options=>$operator{$fieldType},
			extras=>'class="qbselect"'
		});
		# The value select field
		my $valFieldName = "val_field".$i;
		my $valueField = WebGUI::Form::dynamicField(
			fieldType=>$fieldType,
			name=>$valFieldName,
			uiLevel=>5,
			extras=>qq/title="$fields->{$field}{description}" class="qbselect"/,
			possibleValues=>$fields->{$field}{possibleValues},
		);
		# An empty row
		$output .= qq|<tr><td></td><td></td><td></td><td></td><td class="qbtdright"></td></tr>|;

		# Table row with field info
		$output .= qq|
		<tr>
		<td class="qbtdleft"><p class="qbfieldLabel">$fieldLabel</p></td>
		<td class="qbtd">
		$opField
		</td>
		<td class="qbtd">
		<span class="qbText">$valueField</span>
		</td>
		<td class="qbtd"></td>
		<td class="qbtdright">
		<input class="qbButton" type=button value=Add onclick="addCriteria('$fieldLabel', this.form.$opFieldName, this.form.$valFieldName)"></td>
		</tr>
		|;
		$i++;
	}
	# Close the table
	$output .= "</table>";

	return $output;
}

sub parseOverride {
	my $self = shift;
	my $value = shift;
	my @userPrefs = $self->getUserPrefs;
	foreach my $field (@userPrefs) {
		my $id = $field->getId;
		my $fieldName = $field->getFieldName;
		use WebGUI::Asset::Field;
		my $fieldValue = WebGUI::Asset::Field->getUserPref($id);
		$value =~ s/\#\#userPref\:${fieldName}\#\#/$fieldValue/g;
	}
}

#-------------------------------------------------------------------
sub _submenu {
	my $self = shift;
	my $workarea = shift;
	my $title = shift;
	my $help = shift;
	my $ac = WebGUI::AdminConsole->new("shortcutmanager");
	$ac->setHelp($help) if ($help);
	$ac->setIcon($self->getIcon);
	$ac->addSubmenuItem($self->getUrl('func=edit'), WebGUI::International::get("Back to Edit Shortcut","Asset_Shortcut"));
	$ac->addSubmenuItem($self->getUrl("func=manageOverrides"),WebGUI::International::get("Manage Shortcut Overrides","Asset_Shortcut"));
	$ac->addSubmenuItem($self->getUrl("func=manageUserPrefs"),WebGUI::International::get("Manage User Preferences","Asset_Shortcut"));
	return $ac->render($workarea, $title);
}

#-------------------------------------------------------------------
sub canEdit {
	my $self = shift;
return 1 if ($self->SUPER::canEdit || (ref $self->getParent eq 'WebGUI::Asset::Wobject::Dashboard' && $self->getParent->canManage));
	return 0;
}

#-------------------------------------------------------------------
sub canManage {
	my $self = shift;
	return $self->canEdit;
}

#-------------------------------------------------------------------
sub definition {
        my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
		assetName=>WebGUI::International::get('assetName',"Asset_Shortcut"),
		icon=>'shortcut.gif',
                tableName=>'Shortcut',
                className=>'WebGUI::Asset::Shortcut',
                properties=>{
                        shortcutToAssetId=>{
				noFormPost=>1,
				fieldType=>"hidden",
				defaultValue=>undef
				},
#			overrideTitle=>{
#				fieldType=>"yesNo",
#				defaultValue=>0
#				},
#			overrideTemplate=>{
#				fieldType=>"yesNo",
#				defaultValue=>0
#				},
#			overrideDisplayTitle=>{
#				fieldType=>"yesNo",
#				defaultValue=>0
#				},
#			overrideDescription=>{
#				fieldType=>"yesNo",
#				defaultValue=>0
#				},
#			overrideTemplateId=>{
#				fieldType=>"template",
#				defaultValue=>undef
#				},
			shortcutByCriteria=>{
				fieldType=>"yesNo",
				defaultValue=>0,
				},
			disableContentLock=>{
				fieldType=>"yesNo",
				defaultValue=>0
				},
			resolveMultiples=>{
				fieldType=>"selectBox",
				defaultValue=>"mostRecent",
				},
			shortcutCriteria=>{
				fieldType=>"textarea",
				defaultValue=>"",
				},
			templateId=>{
				fieldType=>"template",
				defaultValue=>"PBtmpl0000000000000140"
				},
			description=>{
				fieldType=>"HTMLArea",
				defaultValue=>undef
			},
		}
	});
	return $class->SUPER::definition($definition);
}



#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm();
	my $originalTemplate;
	my $i18n = WebGUI::International->new("Asset_Shortcut");
	$tabform->getTab("properties")->readOnly(
		-label=>WebGUI::International::get(1,"Asset_Shortcut"),
		-hoverHelp=>WebGUI::International::get('1 description',"Asset_Shortcut"),
		-value=>'<a href="'.$self->getShortcut->getUrl.'">'.$self->getShortcut->get('title').'</a> ('.$self->getShortcut->getId.')'
		);
	$tabform->getTab("display")->template(
		-value=>$self->getValue("templateId"),
		-label=>WebGUI::International::get('shortcut template title', 'Asset_Shortcut'),
		-hoverHelp=>WebGUI::International::get('shortcut template title description', 'Asset_Shortcut'),
		-namespace=>"Shortcut"
	);
	if($session{setting}{metaDataEnabled}) {
		$tabform->getTab("properties")->yesNo(
			-name=>"shortcutByCriteria",
			-value=>$self->getValue("shortcutByCriteria"),
			-label=>WebGUI::International::get("Shortcut by alternate criteria","Asset_Shortcut"),
			-hoverHelp=>WebGUI::International::get("Shortcut by alternate criteria description","Asset_Shortcut"),
			-extras=>q|onchange="
				if (this.form.shortcutByCriteria[0].checked) { 
 					this.form.resolveMultiples.disabled=false;
					this.form.shortcutCriteria.disabled=false;
				} else {
 					this.form.resolveMultiples.disabled=true;
					this.form.shortcutCriteria.disabled=true;
				}"|
                );
		$tabform->getTab("properties")->yesNo(
			-name=>"disableContentLock",
			-value=>$self->getValue("disableContentLock"),
			-label=>WebGUI::International::get("disable content lock","Asset_Shortcut"),
			-hoverHelp=>WebGUI::International::get("disable content lock description","Asset_Shortcut")
			);
		if ($self->getValue("shortcutByCriteria") == 0) {
			$self->{_disabled} = 'disabled=true';
		}
		$tabform->getTab("properties")->selectBox(
			-name=>"resolveMultiples",
			-value=>[ $self->getValue("resolveMultiples") ],
			-label=>WebGUI::International::get("Resolve Multiples","Asset_Shortcut"),
			-hoverHelp=>WebGUI::International::get("Resolve Multiples description","Asset_Shortcut"),
			-options=>{
				mostRecent=>WebGUI::International::get("Most Recent","Asset_Shortcut"),
				random=>WebGUI::International::get("Random","Asset_Shortcut"),
			},
			-extras=>$self->{_disabled}
		);

		 $tabform->getTab("properties")->readOnly(
        		-value=>$self->_drawQueryBuilder(),
		        -label=>WebGUI::International::get("Criteria","Asset_Shortcut"),
		        -hoverHelp=>WebGUI::International::get("Criteria description","Asset_Shortcut")
	        );
	}
	$tabform->addTab('overrides',$i18n->get('Overrides'));
	$tabform->getTab('overrides')->raw($self->getOverridesList);
	return $tabform;
}


#-------------------------------------------------------------------

=head2 getExtraHeadTags (  )

Returns the extraHeadTags stored in the asset.  Called in WebGUI::Style::generateAdditionalHeadTags if this asset is the $session{asset}.  Also called in WebGUI::Layout::view for its child assets.  Overriden here in Shortcut.pm.

=cut

sub getExtraHeadTags {
	my $self = shift;
	return $self->get("extraHeadTags")."\n".$self->getShortcut->get("extraHeadTags");
}

#-------------------------------------------------------------------
sub getFieldsList {
	my $self = shift;
	my $i18n = WebGUI::International->new("Asset_Shortcut");
	my $output = '<a href="'.$self->getUrl('func=add;class=WebGUI::Asset::Field').'" class="formLink">'.$i18n->get('Add Preference Field').'</a><br /><br />';
	my @fielden;
	@fielden = $self->getUserPrefs;
	return $output unless scalar @fielden > 0;
	$output .= '<table cellspacing="0" cellpadding="3" border="1">';
	$output .= '<tr class="tableHeader"><td>'.$i18n->get('fieldName').'</td><td>'.$i18n->get('edit delete fieldname').'</td></tr>';
	foreach my $field (@fielden) {
		$output .= '<tr>';
		$output .= '<td class="tableData"><a href="'.$field->getUrl('func=edit').'">'.$field->get("fieldName").'</a></td>';
		$output .= '<td class="tableData">';
		$output .= editIcon('func=edit',$field->getUrl());
		$output .= deleteIcon('func=delete',$field->getUrl());
		$output .= '</td>';
		$output .= '</tr>';
	}
	$output .= '</table>';
	return $output;
}

#-------------------------------------------------------------------
sub getOverridesList {
	my $self = shift;
	my $output = '';
	my $i18n = WebGUI::International->new("Asset_Shortcut");
	my %overrides = $self->getOverrides;
	$output .= '<table cellspacing="0" cellpadding="3" border="1">';
	$output .= '<tr class="tableHeader"><td>'.$i18n->get('fieldName').'</td><td>'.$i18n->get('edit delete fieldname').'</td><td>'.$i18n->get('Original Value').'</td><td>'.$i18n->get('New value').'</td><td>'.$i18n->get('Replacement value').'</td></tr>';
	foreach my $definition (@{$self->getShortcutOriginal->definition}) {
		foreach my $prop (keys %{$definition->{properties}}) {
			next if $definition->{properties}{$prop}{fieldType} eq 'hidden';
			$output .= '<tr>';
			$output .= '<td class="tableData"><a href="'.$self->getUrl('func=editOverride;fieldName='.$prop).'">'.$prop.'</a></td>';
			$output .= '<td class="tableData">';
			$output .= editIcon('func=editOverride;fieldName='.$prop,$self->getUrl());
			$output .= deleteIcon('func=deleteOverride;fieldName='.$prop,$self->getUrl()) if exists $overrides{overrides}{$prop};
			$output .= '</td><td>';
			$output .= $overrides{overrides}{$prop}{origValue};
			$output .= '</td><td>';
			$output .= $overrides{overrides}{$prop}{newValue};
			$output .= '</td><td>';
			$output .= $overrides{overrides}{$prop}{parsedValue};
			$output .= '</td></tr>';
		}
	}
	$output .= '</table>';
	return $output;
}


#-------------------------------------------------------------------
sub getOverrides {
	my $self = shift;
	my $i = 0;
	#cache by userId, assetId of this shortcut, and whether adminMode is on or not.
	my $cache = WebGUI::Cache->new(["shortcutOverrides",$self->getId,$session{user}{userId},$session{var}{adminOn}]);
	my $overridesRef = $cache->get;
	unless ($overridesRef->{cacheNotExpired}) {
		my %overrides;
		my $orig = $self->getShortcutOriginal;
		unless (exists $orig->{_propertyDefinitions}) {
			my %properties;
			foreach my $definition (@{$orig->definition}) {
				%properties = (%properties, %{$definition->{properties}});
			}
			$orig->{_propertyDefinitions} = \%properties;
		}
		$overrides{cacheNotExpired} = 1;
		my $sth = WebGUI::SQL->read("select fieldName, newValue from Shortcut_overrides where assetId=".quote($self->getId)." order by fieldName");
		while (my ($fieldName, $newValue) = $sth->array) {
			$overrides{overrides}{$fieldName}{fieldType} = $orig->{_propertyDefinitions}{$fieldName}{fieldType};
			$overrides{overrides}{$fieldName}{origValue} = $self->getShortcutOriginal->get($fieldName);
			$overrides{overrides}{$fieldName}{newValue} = $newValue;
			$overrides{overrides}{$fieldName}{parsedValue} = $newValue;
		}
		$sth->finish;
		my @userPrefs = $self->getUserPrefs;
		foreach my $field (@userPrefs) {
			my $id = $field->getId;
			my $fieldName = $field->getFieldName;
			my $fieldValue = $field->getUserPref($id);
			$overrides{userPrefs}{$fieldName}{value} = $fieldValue;
			#  'myTemplateId is ##userPref:myTemplateId##', for example.
			foreach my $overr (keys %{$overrides{overrides}}) {
				$overrides{overrides}{$fieldName}{parsedValue} =~ s/\#\#userPref\:${fieldName}\#\#/$fieldValue/g;
			}
		}
		$cache->set(\%overrides, 60*60);
		$overridesRef = \%overrides;
	}
	return %$overridesRef;
}

#-------------------------------------------------------------------
sub getShortcut {
	my $self = shift;
	unless ($self->{_shortcut}) {
		$self->{_shortcut} = $self->getShortcutOriginal;
	}
	$self->{_shortcut}{_properties}{displayTitle} = undef if (ref $self->getParent eq 'WebGUI::Asset::Wobject::Dashboard');
	# Hide title by default.  If you want, you can create an override
	# to display it.  But it's being shown in the dragheader by default.
	my %overhash = $self->getOverrides;
	if (exists $overhash{overrides}) {
		my %overrides = %{$overhash{overrides}};
		foreach my $override (keys %overrides) {
			$self->{_shortcut}{_properties}{$override} = $overrides{$override}{parsedValue};
		}
		foreach my $userPref ($self->getUserPrefs) {
			$self->{_shortcut}{_properties}{$userPref->getFieldName} = $userPref->getUserPref($userPref->getId) unless (exists $overrides{$userPref->getFieldName});
		}
	}
	return $self->{_shortcut};
}

#-------------------------------------------------------------------

=head2 getShortcutByCriteria ( hashRef )

This function will search for a asset that match a metadata criteria set.
If no asset is found, undef will be returned.

=cut

sub getShortcutByCriteria {
	my $self = shift;
	my $assetProxy = shift;
	my $criteria = $self->get("shortcutCriteria");
	my $order = $self->get("resolveMultiples");
	my $assetId = $self->getId;

	# Parse macro's in criteria
	WebGUI::Macro::process(\$criteria);

	# Once a asset is found, we will stick to that asset, 
	# to prevent the proxying of multiple- depth assets like Surveys and USS.
	my $scratchId;
	if ($assetId) {
		$scratchId = "Shortcut_" . $assetId;
		if($session{scratch}{$scratchId} && !$self->getValue("disableContentLock")) {
			return $session{scratch}{$scratchId} unless ($session{var}{adminOn});
		}
	}

	# $criteria = "State = Wisconsin AND Country != Sauk";
	#
	# State          =             Wisconsin AND Country != Sauk
	# |              |             |
	# |- $field      |_ $operator  |- $value
	# |_ $attribute                |_ $attribute
	my $operator = qr/<>|!=|=|>=|<=|>|<|like/i;
	my $attribute = qr/['"][^()|=><!]+['"]|[^()|=><!\s]+/i; 
                                                                                                      
	my $constraint = $criteria;
	
	# Get each expression from $criteria
	foreach my $expression ($criteria =~ /($attribute\s*$operator\s*$attribute)/gi) {
		# $expression will match "State = Wisconsin"

        	my $replacement = $expression;	# We don't want to modify $expression.
						# We need it later.

		# Get the field (State) and the value (Wisconsin) from the $expression.
	        $expression =~ /($attribute)\s*$operator\s*($attribute)/gi;
	        my $field = $1;
	        my $value = $2;

		# quote the field / value variables.
		my $quotedField = $field;
		my $quotedValue = $value;
		unless ($field =~ /^\s*['"].*['"]\s*/) {
			$quotedField = quote($field);
		}
                unless ($value =~ /^\s*['"].*['"]\s*/) {
                        $quotedValue = quote($value);
                }
		
		# transform replacement from "State = Wisconsin" to 
		# "(fieldname=State and value = Wisconsin)"
	        $replacement =~ s/\Q$field/(fieldname=$quotedField and value /;
	        $replacement =~ s/\Q$value/$quotedValue )/i;

		# replace $expression with the new $replacement in $constraint.
	        $constraint =~ s/\Q$expression/$replacement/;
	}
	my $sql =  "	select w.assetId 
			from metaData_values d, metaData_properties f, asset w 
			where f.fieldId = d.fieldId
				and w.assetId = d.assetId
				and w.className=".quote($self->getShortcutDefault->get("className"));

	
	# Add constraint only if it has been modified.
	$sql .= " and ".$constraint if (($constraint ne $criteria) && $constraint ne "");
# Can't do this without extensive refactoring.....!  
#	$sql .= " order by assetData.revisionDate desc";

	# Execute the query with an unconditional read
	my @ids;
        my $sth = WebGUI::SQL->unconditionalRead($sql);
        while (my ($data) = $sth->array) {
		push (@ids, $data);
        }
        $sth->finish;

	# No matching assets found.
        if (scalar(@ids) == 0) {
                return $self->getShortcutDefault; # fall back to the originally mirrored asset.
	}
	my $id;
	# Grab a wid from the results
	if ($order eq 'random') {
		$id = $ids[ rand @ids ];
	} else { 
				 #default order is mostRecent
		$id = $ids[0]; # 1st element in list is most recent.
	}

	# Store the matching assetId in user scratch. 
	WebGUI::Session::setScratch($scratchId,$id) if ($scratchId);

	return WebGUI::Asset->newByDynamicClass($id);		
}

#-------------------------------------------------------------------
sub getShortcutDefault {
	my $self = shift;
	return WebGUI::Asset->newByDynamicClass($self->get("shortcutToAssetId"));
}

#-------------------------------------------------------------------
sub getShortcutOriginal {
	my $self = shift;
	if ($self->get("shortcutByCriteria")) {
		return $self->getShortcutByCriteria;
	} else {
		return $self->getShortcutDefault;
	}
}

#-------------------------------------------------------------------
sub getUserPrefs {
	my $self = shift;
	my $bibibib = $self->getLineage(["children"],{includeOnlyClasses=>["WebGUI::Asset::Field"],returnObjects=>1});
	return @$bibibib;
}

#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	$self->SUPER::processPropertiesFromFormPost;
	my $scratchId = "Shortcut_" . $self->getId;
	WebGUI::Session::deleteAllScratch($scratchId);
}

#-------------------------------------------------------------------

sub purge {
	my $self = shift;
	# delete and purge all associated FieldIds and their preferences.
	return $self->SUPER::purge;
}

#-------------------------------------------------------------------

sub purgeRevision {
	my $self = shift;
	return $self->SUPER::purgeRevision;
}

#-------------------------------------------------------------------

sub uncacheOverrides {
	my $self = shift;
	WebGUI::Cache->new(["shortcutOverrides",$self->getId])->delete;
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $content;
	my $shortcut = $self->getShortcut;
	if ($self->get("shortcutToAssetId") eq $self->get("parentId")) {
		$content = WebGUI::International::get("Displaying this shortcut would cause a feedback loop","Asset_Shortcut");
	} else {
		$content = $shortcut->view;
	}
	my %var = (
		isShortcut => 1,
		'shortcut.content' => $content,
		'shortcut.label' => WebGUI::International::get('3',"Asset_Shortcut"),
		originalURL => $shortcut->getUrl
		);
	return $self->processTemplate(\%var,$self->getValue("templateId"));
}

#-------------------------------------------------------------------
sub www_edit {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	$self->getAdminConsole->setHelp("shortcut add/edit","Asset_Shortcut");
	$self->getAdminConsole->addSubmenuItem($self->getUrl("func=manageOverrides"),WebGUI::International::get("Manage Shortcut Overrides","Asset_Shortcut"));
	$self->getAdminConsole->addSubmenuItem($self->getUrl("func=manageUserPrefs"),WebGUI::International::get("Manage User Preferences","Asset_Shortcut"));
	return $self->getAdminConsole->render($self->getEditForm->print,WebGUI::International::get(2,"Asset_Shortcut"));
}

#-------------------------------------------------------------------
sub www_getUserPrefsForm {
	#This is a form retrieved by "ajax".
	my $self = shift;
	return 'nuhuh' unless $self->getParent->canPersonalize;
	my @fielden = $self->getUserPrefs;
	my $f = WebGUI::HTMLForm->new(extras=>' onSubmit="submitForm(this,\''.$self->getId.'\',\''.$self->getUrl.'\');return false;"');
	$f->hidden(  
		-name => 'func', 
		-value => 'saveUserPrefs'
	);
	foreach my $field (@fielden) {
		my $fieldType = $field->get("fieldType") || "text";
		my $options;
		my $params = {name=>$field->getId,
			label=>$field->get("fieldName"),
			uiLevel=>5,
			value=>$field->getUserPref($field->getId),
			extras=>'',
			possibleValues=>$field->get("possibleValues"),
			options=>$options,
			fieldType=>$fieldType
		};
		if (lc($fieldType) eq 'textarea') {
			$params->{rows} = 4;
			$params->{columns} = 20;
		}
		$f->dynamicField(%$params);
	}
	$f->submit;
	return $f->print;
}

#-------------------------------------------------------------------
sub www_manageUserPrefs {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	my $output = $self->getFieldsList;
	return $self->_submenu($output,WebGUI::International::get("Manage User Preferences","Asset_Shortcut"));
}

#-------------------------------------------------------------------
sub www_manageOverrides {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	return $self->_submenu($self->getOverridesList,WebGUI::International::get("Manage Shortcut Overrides","Asset_Shortcut"));
}

#-------------------------------------------------------------------
sub www_purgeOverrideCache {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	$self->uncacheOverrides;
	return $self->www_manageOverrides;
}

#-------------------------------------------------------------------
sub www_deleteOverride {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	WebGUI::SQL->write('delete from Shortcut_overrides where assetId='.quote($self->getId).' and fieldName='.quote($session{form}{fieldName}));
	$self->uncacheOverrides;
	return $self->www_manageOverrides;
}

#-------------------------------------------------------------------
sub www_saveUserPrefs {
	my $self = shift;
	return '' unless $self->getParent->canPersonalize;
	my @fellowFields = $self->getUserPrefs;
	foreach my $fieldId (keys %{$session{form}}) {
		my $field = WebGUI::Asset->newByDynamicClass($fieldId);
		next unless $field;
		$field->setUserPref($fieldId,$session{form}{$fieldId});
	}
	return $self->view;
}

#-------------------------------------------------------------------
sub www_getNewTitle {
	my $self = shift;
	return '' unless $self->getParent->canPersonalize;
	my $foo = $self->getShortcut;
	return $foo->{_properties}{title};
}

#-------------------------------------------------------------------
sub www_editOverride {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	my $i18n = WebGUI::International->new("Asset_Shortcut");
	my $fieldName = $session{form}{fieldName};
	my %overrides = $self->getOverrides;
	my $output = '';
	my %props;
	foreach my $def (@{$self->getShortcutOriginal->definition}) {
		%props = (%props,%{$def->{properties}});
	}
	$output .= '</table>';
  my $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
  $f->hidden(-name=>"func",-value=>"saveOverride");
  $f->hidden(-name=>"overrideFieldName",-value=>$session{form}{fieldName});
  $f->readOnly(-label=>$i18n->get("Field Name"),-value=>$session{form}{fieldName});
  $f->readOnly(-label=>$i18n->get("Original Value"),-value=>$overrides{overrides}{$fieldName}{origValue});
  my %params;
  foreach my $key (keys %{$props{$fieldName}}) {
		next if ($key eq "tab");
			$params{$key} = $props{$fieldName}{$key};
		}
	$params{value} = $overrides{overrides}{$fieldName}{origValue};
	$params{name} = $fieldName;
	$params{label} = $params{label} || $i18n->get("Edit Field Directly");
	$params{hoverhelp} = $params{hoverhelp} || $i18n->get("Use this field to edit the override using the native form handler for this field type");
	if ($fieldName eq 'templateId') {$params{namespace} = $params{namespace} || WebGUI::Asset->newByDynamicClass($overrides{overrides}{templateId}{origValue})->get("namespace");}
	$f->dynamicField(%params);
	$f->textarea(
		-name=>"newOverrideValueText",
		-label=>$i18n->get("New Override Value"),
		-value=>$overrides{overrides}{$fieldName}{newValue},
		-hoverHelp=>$i18n->get("Place something in this box if you dont want to use the automatically generated field")
	);
	$f->readOnly(-label=>$i18n->get("Replacement Value"),-value=>$overrides{overrides}{$fieldName}{parsedValue},-hoverHelp=>$i18n->get("This is the example output of the field when parsed for user preference macros"));
  $f->submit;
  $output .= $f->print;
	return $self->_submenu($output,$i18n->get('Edit Override'));
}

#-------------------------------------------------------------------
sub www_saveOverride {
	my $self = shift;
	return WebGUI::Privilege::insufficient() unless $self->canEdit;
	my $fieldName = $session{form}{overrideFieldName};
	my %overrides = $self->getOverrides;
	my $output = '';
	my %props;
	foreach my $def (@{$self->getShortcutOriginal->definition}) {
		%props = (%props,%{$def->{properties}});
	}
	my $fieldType = $props{$fieldName}{fieldType};
	my $value = WebGUI::FormProcessor::process($fieldName,$fieldType);
	$value = $session{form}{newOverrideValueText} || $value;
	WebGUI::SQL->write("delete from Shortcut_overrides where assetId=".quote($self->getId)." and fieldName=".quote($fieldName));
	WebGUI::SQL->write("insert into Shortcut_overrides values (".quote($self->getId).",".quote($fieldName).",".quote($value).")");
	$self->uncacheOverrides;
	return $self->www_manageOverrides;
}

#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	if (ref($self->getParent) eq 'WebGUI::Asset::Wobject::Dashboard') {
		return WebGUI::Privilege::noAccess() unless $self->canView;
		$session{asset} = $self->getParent;
		return $session{asset}->www_view;
	} else {
		return $self->getShortcut->www_view;
	}
}

1;

