package WebGUI::i18n::English::Asset_Shortcut;

our $I18N = {

	'disable content lock' => {
		message => q|Disable content lock?|,
		lastUpdated => 0,
		context=> q|asset property|
	},

	'85' => {
		message => q|Description|,
		lastUpdated => 1031514049
	},

	'Criteria' => {
		message => q|Criteria|,
		lastUpdated => 1053183804
	},

	'Random' => {
		message => q|Random|,
		lastUpdated => 1053183804
	},

	'Resolve Multiples' => {
		message => q|Resolve Multiples?|,
		lastUpdated => 1127959325
	},

	'7' => {
		message => q|Override title?|,
		lastUpdated => 1053183682
	},

	'isnt' => {
		message => q|isn't|,
		lastUpdated => 1053183804
	},

	'is' => {
		message => q|is|,
		lastUpdated => 1053183804
	},

	'2' => {
		message => q|Edit Shortcut|,
		lastUpdated => 1031514049
	},

	'equal to' => {
		message => q|equal to|,
		lastUpdated => 1053183804
	},

	'1' => {
		message => q|Asset to Mirror|,
		lastUpdated => 1031514049
	},

	'6' => {
		message => q|<p>With the Shortcut you can mirror an asset in another location. This is useful if you want to reuse the same content in multiple sections of your site.</p>

<p><b>NOTES:</b><br />
The shortcut is not available through the Add Content menu, but instead through the shortcut icon on each Asset's toolbar.
</p>
<p><b>Overrides</b><br />
You can also create overrides and user preferences.  The 6.8 upgrade automatically converted your previous override settings to overrides.  These are shown on the Overrides tab.  You can also view them by clicking "Manage overrides" on the right menu bar while editing a Shortcut.  The list of fields is the list of the shortcutted asset's properties.  If one is overridden, its values are displayed to the right, and you may edit or delete the override by clicking on the icons.  if there is no override, you can click Edit to edit that property.</p>
<p><b>User Preference Fields</b><br />
You may also create User Preference fields, which autogenerate form fields for your users to customize settings on Dashlets on a Dashboard.  These are displayed when the dashboard user clicks the (default) green Edit hoverbutton on the titlebar of a Dashlet.  You can choose from the form field types: text, textlist (multiline text box), selectList (choose one from a drop-down list), and checkList (choose one or more from a list of checkboxes).  You can set the possibleValues while editing a User Preference field.  You can also directly create an override by creating a User Preference field whose unique fieldName corresponds to a field on the shortcutted asset.
<p><b>Chaining</b><br />
In an override's New Value field, you can put a substitution call for the value of a User Preference Field.  This is helpful for the Dashboard container, primarily.  Let's say you create a user preference selectList field named myFavColor, with possible values blue, green, red, and yellow.  Then you want to override the shorcutted asset's Title with: "My Favorite Color is XXXX."  You create an override for "title", and in the New Value box, place the following text:<br />
<pre>My Favorite Color is ##userPref:myFavColor##.</pre><br />  Make sure to create a default Value under the myFavColor user preference field.<br /><br />
Now, go back to manage Overrides, and it should show the original value, new value, and the parsed/replaced value.  You can use this for all kinds of choices: templateIds, formats, or any other kind of preference.  </p>
<p><b>Fields</b></p>
|,
		lastUpdated => 1133619940,
	},

        '85 description' => {
                message => q|Content for this shortcut.  This is normally not used.|,
                lastUpdated => 1133619940,
        },

        'shortcut template title description' => {
                message => q|Select a template from the list to display the Shortcut.|,
                lastUpdated => 1119905806,
        },

        'override asset template description' => {
                message => q|Select a template that can optionally override the original Asset template.|,
                lastUpdated => 1119905806,
        },

        '7 description' => {
                message => q|Set to "yes" to use the title of the shortcut instead of the original title of the asset.|,
                lastUpdated => 1119905806,
        },

        '8 description' => {
                message => q|Set to "yes" to use the display title setting of the shortcut instead of the original display title setting of the asset.|,
                lastUpdated => 1119905806,
        },

        '9 description' => {
                message => q|Set to "yes" to use the description of the shortcut instead of the original description of the asset.|,
                lastUpdated => 1119905806,
        },

        '1 description' => {
                message => q|Provides a link to the original Asset being mirrored.|,
                lastUpdated => 1119905806,
        },

        '10 description' => {
                message => q|Set to "yes" to use the override template of the shortcut instead of the original template of the asset.|,
                lastUpdated => 1119905806,
        },

        'Shortcut by alternate criteria description' => {
                message => q|Set to "yes" to enable selecting a asset based upon custom criteria. Metadata must be enabled for this option to function properly.|,
                lastUpdated => 1127927137,
        },

        'disable content lock description' => {
                message => q|By default if you proxy by alternate criteria the shortcut will lock on to a particular piece of content and show you only that piece of content until the end of your session. However, in some circumstances you may wish for this content to rotate. You can do that by disabling the content lock.|,
                lastUpdated => 1119905806,
        },

        'Resolve Multiples description' => {
                message => q|Sets the order to use when multiple assets are selected. Random means that if multiple assets match the shortcut criteria then the shortcut will select a random asset.<br />
Most Recent will select the most recent asset that match the shortcut criteria.|,
                lastUpdated => 1146540399,
        },

        'Criteria description' => {
                message => q|A statement to determinate what to mirror, in the form of "color = blue and weight != heavy". Multiple expressions may be joined with "and" and "or". <br />
A property or value must be quoted if it contains spaces. Feel free to use the criteria builder to build your statements.|,
                lastUpdated => 1146540405,
        },


	'greater than' => {
		message => q|greater than|,
		lastUpdated => 1053183804
	},

	'assetName' => {
		message => q|Shortcut|,
		lastUpdated => 1031514049
	},

	'9' => {
		message => q|Override description?|,
		lastUpdated => 1053183804
	},

	'Shortcut by alternate criteria' => {
		message => q|Shortcut by alternate criteria?|,
		lastUpdated => 1127927125
	},

	'not equal to' => {
		message => q|not equal to|,
		lastUpdated => 1053183804
	},

	'less than' => {
		message => q|less than|,
		lastUpdated => 1053183804
	},

	'8' => {
		message => q|Override display title?|,
		lastUpdated => 1053183719
	},

	'AND' => {
		message => q|AND|,
		lastUpdated => 1053183804
	},

	'4' => {
		message => q|Asset mirroring failed. Perhaps the original asset has been deleted.|,
		lastUpdated => 1031514049
	},

	'Most Recent' => {
		message => q|Most Recent|,
		lastUpdated => 1053183804
	},

	'override asset template' => {
		message => q|Override Asset Template|,
		lastUpdated => 1119896310
	},

	'OR' => {
		message => q|OR|,
		lastUpdated => 1053183804
	},

	'5' => {
		message => q|Shortcut, Add/Edit|,
		lastUpdated => 1031514049
	},

	'shortcut template title' => {
		message => q|Shortcut Template|,
		lastUpdated => 1109525763,
	},

	'shortcut template body' => {
		message => q|<p>These variables are available in Shortcut Templates:</p>
<p><b>shortcut.content</b><br />
The content from the mirrored Asset.  If any overrides were enabled in the Shortcut then the override content will be used instead of the content from the mirrored Asset.</p>
<p><b>originalURL</b><br />
The URL to the Asset being mirrored by this Shortcut.</p>
<p><b>isShortcut</b><br />
A boolean indicating that this Asset is a Shortcut.  This can be used in conjuction with another boolean for Admin mode to quickly show Content Managers that this is a Shortcut Asset.</p>
<p><b>shortcut.label</b><br />
The word "Shortcut".</p>
<p><b>shortcut.<b>properties</b><br />
Any properties assigned to this shortcut will be available in the template by their name.</p>
                |,
		lastUpdated => 1146540530,
	},

	'The unique name of a user preference parameter you are inventing' => {
		message => q|The unique name of a user preference parameter you are inventing.|,
		lastUpdated => 1133619940,
	},

	'Label for This Field.' => {
		message => q|Label for This Field.|,
		lastUpdated => 1133619940,
	},

	'Possible Values' => {
		message => q|Possible Values|,
		lastUpdated => 1133619940,
	},

	'Default Value for this field' => {
		message => q|Default Value for this field.|,
		lastUpdated => 1133619940,
	},

	'Field' => {
		message => q|Field|,
		lastUpdated => 1133619940,
	},

	'shortcut template title' => {
		message => q|Shortcut Template|,
		lastUpdated => 1133619940,
	},

	'Hover Help Description for this Field' => {
		message => q|Hover Help (Description) for this Field.|,
		lastUpdated => 1133619940,
	},

	'Type of Field' => {
		message => q|Type of Field|,
		lastUpdated => 1133619940,
	},

	'Edit User Preference Field' => {
		message => q|Edit User Preference Field|,
		lastUpdated => 1133619940,
	},

	'Back to Edit Shortcut' => {
		message => q|Back to Edit Shortcut|,
		lastUpdated => 1133619940,
	},


	'Overrides' => {
		message => q|Overrides|,
		lastUpdated => 1133619940,
	},

	'Manage Profile Fields' => {
		message => q|Manage Profile Fields|,
		lastUpdated => 1133619940,
	},

	'fieldName' => {
		message => q|Field Name|,
		lastUpdated => 1133619940,
	},

	'edit delete fieldname' => {
		message => q|Edit/Delete Fieldname|,
		lastUpdated => 1133619940,
	},

	'Original Value' => {
		message => q|Original Value|,
		lastUpdated => 1133619940,
	},

	'Replacement value' => {
		message => q|Replacement value|,
		lastUpdated => 1133619940,
	},

	'New value' => {
		message => q|New value|,
		lastUpdated => 1133619940,
	},

	'Displaying this shortcut would cause a feedback loop' => {
		message => q|Displaying this shortcut would cause a feedback loop.|,
		lastUpdated => 1133619940,
	},

	'Manage Shortcut Overrides' => {
		message => q|Manage Shortcut Overrides|,
		lastUpdated => 1133619940,
	},

	'Manage User Preferences' => {
		message => q|Manage User Preferences|,
		lastUpdated => 1133619940,
	},

	'Edit Field Directly' => {
		message => q|Edit Field Directly|,
		lastUpdated => 1133619940,
	},

	'Use this field to edit the override using the native form handler for this field type' => {
		message => q|Use this field to edit the override using the native form handler for this field type|,
		lastUpdated => 1133619940,
	},

	'New Override Value' => {
		message => q|New Override Value|,
		lastUpdated => 1133619940,
	},

	'Place something in this box if you dont want to use the automatically generated field' => {
		message => q|Place something in this box if you don't want to use the automatically generated field.  You may also insert user preference values into this field by using the following syntax: if you wanted it to display "My Favorite color is blue.", and you have a user preference field called myFavColor, in this box you would put: My Favorite color is ##userPref:myFavColor##.|,
		lastUpdated => 1133619940,
	},

	'This is the example output of the field when parsed for user preference macros' => {
		message => q|This is the example output of the field when parsed for user preference macros|,
		lastUpdated => 1133619940,
	},

	'Replacement Value' => {
		message => q|Replacement Value|,
		lastUpdated => 1133619940,
	},

	'Edit Override' => {
		message => q|Edit Override|,
		lastUpdated => 1133619940,
	},

	'Possible values for this Field Only applies to selectList and checkList' => {
		message => q|Possible values for this Field.  Only applies to selectList and checkList.|,
		lastUpdated => 1133619940,
	},

	'field add/edit title' => {
		message => q|Add/Edit User Preference|,
		lastUpdated => 1133619940,
	},

	'field add/edit body' => {
		message => q|<p>User Preferences are the key to personalization of a Shortcut, and the key to creating a personalized dashboard.  You can create a user preference field of one of four types: text, textArea, checkList, and selectList.  If yours is a list type, you can put the possible choices in the Possible Choices box, and each one will be its own entry in a list of that type (select: choose one, or check: choose none or any or all).  </p><p>You can use a user preference field to generate a list of templates from which the user can pick, a choice of some kind of other preference, such as US or metric units format, or any other kind of user preference.  User Preference fields are asset-(shortcut-)specific, whereas user profile fields are site-wide.  The user preference fields will be exposed to your override fields in the format ##userPref:myUserPrefField##, and will be exposed everywhere else as normal template variables (<tmpl_var myUserPrefField>).</p>|,
		lastUpdated => 1133619940,
	},

	'pref fields to show' => {
		message => q|Preference Fields to Show|,
		lastUpdated => 1133619940,
	},

	'pref fields to show description' => {
		message => q|These are the user profile fields you want to expose as user preferences to the users who can personalize this dashboard.|,
		lastUpdated => 1133619940,
	},

	'pref fields to import' => {
		message => q|Preference Fields to Import|,
		lastUpdated => 1133619940,
	},

	'pref fields to import description' => {
		message => q|These are the user profile fields you want exposed to your override fields (in the form ##userPref:nameOfProfileField##).  Check these if you want to expose profile fields from other areas of the site or the general user profile fields.|,
		lastUpdated => 1133619940,
	},

	'Preferences' => {
		message => q|Preferences|,
		lastUpdated => 1133619940,
	},

	'show reload icon' => {
		message => q|Show Reload Icon?|,
		lastUpdated => 1133619940,
	},

	'show reload icon description' => {
		message => q|Whether or not to show the yellow reload dashlet icon on this Shortcut/Dashlet.|,
		lastUpdated => 1133619940,
	},

	'no metadata yet' => {
		message => q|No metadata defined yet. <a href="%s">Click here</a> to define metadata attributes.|,
		lastUpdated => 1146539258,
	},

};

1;
