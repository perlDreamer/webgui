package WebGUI::i18n::English::WebGUIProfile;

our $I18N = {
	'787' => {
		message => q|Edit this profile field.|,
		lastUpdated => 1036964659
	},

	'469' => {
		message => q|Id|,
		lastUpdated => 1031514049
	},

	'470' => {
		message => q|Category Name|,
		lastUpdated => 1031514049
	},

	'475' => {
		message => q|Field Name|,
		lastUpdated => 1031514049
	},

	'472' => {
		message => q|Label|,
		lastUpdated => 1031514049
	},

	'486' => {
		message => q|Data Type|,
		lastUpdated => 1031514049
	},

	'487' => {
		message => q|Possible Values|,
		lastUpdated => 1031514049
	},

	'488' => {
		message => q|Default Value(s)|,
		lastUpdated => 1031514049
	},

	'790' => {
		message => q|Delete this profile category.|,
		lastUpdated => 1036964807
	},

        '475 description' => {
                message => q|The name of the field, used internally in the database.|,
                lastUpdated => 1122316558,
        },

        '472 description' => {
                message => q|A short, descriptive label displayed to the user.  This can be a call to WebGUI's
Internationalizaton system if labels need to be localized.|,
                lastUpdated => 1122316558,
        },

        '474 description' => {
                message => q|Should the user be required to fill out this field?|,
                lastUpdated => 1122316558,
        },

        '486 description' => {
                message => q|Choose the type of form element for this field.   This is also used
to validate any input that the user may supply.|,
                lastUpdated => 1122316558,
        },

        '487 description' => {
                message => q|<p>This area should only be used in with the following form fields:
<br /><br />
Checkbox List<br />
Combo Box<br />
Hidden List<br />
Radio List<br />
Select Box<br />
Select List<br />
<br><br>
None of the other profile fields should use the Possible Values field as it will be ignored.<br />
If you do enter a Possible Values list, it MUST be formatted as follows
<pre>
{
   "key1"=>"value1",
   "key2"=>"value2",
   "key3"=>"value3"
   ...
}
</pre><br />
Braces, quotes and all.  You simply replace "key1"/"value1" with your own name/value pairs.|,
                lastUpdated => 1132542146,
        },

        '488 description' => {
                message => q|<p>
				   This area should only be used if you have used the Possible Values area above which is to say that it should only be used in conjunction with:
<br />
Checkbox List<br />
Combo Box<br />
Hidden List<br />
Radio List<br />
Select Box<br />
Select List<br />
<br><br>
None of the other profile fields should use the Default Values field as it will be ignored.  If you do enter Default Values, they MUST directly reference one or more of your Possible Values keys as follows:
<pre>["key1","key2",...]</pre><br />
Brackets, quotes and all.<br /><br />
If you wish to set the Default Value for any other field.  Create the field without setting this area, then go into the Visitor's profile and save the value you'd like to display by default for the newly created field.  This will result in the desired result of having the default field set whenever you create a new user.
</p>|,
                lastUpdated => 1122316558,
        },

        '489 description' => {
                message => q|Select a category to place this field under.|,
                lastUpdated => 1122316558,
        },

	'627' => {
		message => q|<p>Profiles are used to extend the information of a particular user. In some cases profiles are important to a site, in others they are not. The profiles system is completely extensible. You can add as much information to the user profiles as you like.
</p>
<p>If you would like to change the default settings for new users on the site, then edit the User Profile for the user Visitor.</p>
|,
		lastUpdated => 1163395390
	},

	'492' => {
		message => q|Profile fields list|,
		lastUpdated => 1031514049
	},

	'637' => {
		message => q|<p><b>First Name</b><br />
The given name of this user.
</p>

<p><b>Middle Name</b><br />
The middle name of this user.
</p>

<p><b>Last Name</b><br />
The surname (or family name) of this user.
</p>

<p><b>Email Address</b><br />
The user's email address. This must only be specified if the user will partake in functions that require email.
</p>

<p><b>ICQ UIN</b><br />
The <a href="http://www.icq.com/">ICQ</a> UIN is the "User ID Number" on the ICQ network. ICQ is a very popular instant messaging platform.
</p>

<p><b>AIM Id</b><br />
The account id for the <a href="http://www.aim.com/">AOL Instant Messenger</a> system.
</p>

<p><b>MSN Messenger Id</b><br />
The account id for the <a href="http://messenger.msn.com/">Microsoft Network Instant Messenger</a> system.
</p>

<p><b>Yahoo! Messenger Id</b><br />
The account id for the <a href="http://messenger.yahoo.com/">Yahoo! Instant Messenger</a> system.
</p>

<p><b>Cell Phone</b><br />
This user's cellular telephone number.
</p>

<p><b>Pager</b><br />
This user's pager telephone number.
</p>

<p><b>Email To Pager Gateway</b><br />
This user's text pager email address.
</p>

<p><b>Home Information</b><br />
The postal (or street) address for this user's home.
</p>

<p><b>Work Information</b><br />
The postal (or street) address for this user's company.
</p>

<p><b>Gender</b><br />
This user's sex.
</p>

<p><b>Birth Date</b><br />
This user's date of birth.
</p>

<p><b>Language</b><br />
The language used to display system related messages.
</p>

<p><b>Time Offset</b><br />
A number of hours (plus or minus) different this user's time is from the server. This is used to adjust for time zones.
</p>

<p><b>First Day Of Week</b><br />
The first day of the week on this user's local calendar. For instance, in the United States the first day of the week is Sunday, but in many places in Europe, the first day of the week is Monday.
</p>

<p><b>Date Format</b><br />
What format should dates on this site appear in?
</p>

<p><b>Time Format</b><br />
What format should times on this site appear in? 
</p>

<p><b>Discussion Layout</b><br />
Should discussions be laid out flat or threaded? Flat puts all replies on one page in the order they were created. Threaded shows the hierarchical list of replies as they were created.
</p>

<p><b>Inbox Notifications</b><br />
How should this user be notified when they get a new WebGUI message?
</p>

|,
		lastUpdated => 1146526248,
	},


	'682' => {
		message => q|User Profile, Edit|,
		lastUpdated => 1031514049
	},

	'672' => {
		message => q|User Profile Settings, Edit|,
		lastUpdated => 1122315465
	},

	'466' => {
		message => q|Are you certain you wish to delete this category and move all of its fields to the Miscellaneous category?|,
		lastUpdated => 1031514049
	},

	'468' => {
		message => q|Edit User Profile Category|,
		lastUpdated => 1031514049
	},

        '470 description' => {
                message => q|The name of the this category.|,
                lastUpdated => 1122315199,
        },

        '473 description' => {
                message => q|Should the category be visible to users?|,
                lastUpdated => 1122315199,
        },

        '473a description' => {
                message => q|Should the field be visible to users?|,
                lastUpdated => 1141667205,
        },

        '897 description' => {
                message => q|Should the category be editable by users?|,
                lastUpdated => 1122315199,
        },

        '897a description' => {
                message => q|Should the field be editable by users?|,
                lastUpdated => 1141667241,
        },

	'user profile category add/edit title' => {
		message => q|User Profile Category, Add/Edit|,
		lastUpdated => 1122314930
	},

	'user profile category add/edit body' => {
		message => q|
WebGUI's user profile is completely configurable, including the ability to add
new categories of profile settings.

|,
		lastUpdated => 1122314932
	},

	'489' => {
		message => q|Profile Category|,
		lastUpdated => 1031514049
	},

	'471' => {
		message => q|Edit User Profile Field|,
		lastUpdated => 1031514049
	},

	'491' => {
		message => q|Add a profile field.|,
		lastUpdated => 1031514049
	},

	'467' => {
		message => q|Are you certain you wish to delete this field and all user data attached to it?|,
		lastUpdated => 1031514049
	},

	'897' => {
		message => q|Editable?|,
		context => q|Label for profile categories|,
		lastUpdated => 1050167573
	},

	'897a' => {
		message => q|Editable?|,
		context => q|Label for profile fields|,
		lastUpdated => 1141667261
	},

	'474' => {
		message => q|Required?|,
		lastUpdated => 1031514049
	},

	'789' => {
		message => q|Edit this profile category.|,
		lastUpdated => 1036964795
	},

	'490' => {
		message => q|Add a profile category.|,
		lastUpdated => 1031514049
	},

	'788' => {
		message => q|Delete this profile field.|,
		lastUpdated => 1036964681,
	},

	'473' => {
		message => q|Visible?|,
		lastUpdated => 1031514049,
		context => q|Label for visibility field for profile categories|,
	},

	'473a' => {
		message => q|Visible?|,
		lastUpdated => 1141667189,
		context => q|Label for visibility field for profile fields|,
	},

	'user profiling' => {
		message => q|User Profiling|,
		lastUpdated =>1092930637,
                context => q|Title of the user profile settings manager for the admin console.|
        },

	'topicName' => {
		message => q|User Profile|,
		lastUpdated => 1128920410,
	},

        'forceImageOnly label' => {
                message => q|Force Image Only Uploads|,
                lastUpdated => 1162945563
        },

        'forceImageOnly hoverHelp' => {
                message => "If set to yes, this form control will only allow image file types to be uploaded through it.",
                lastUpdated => 1162945563
        },

        'forceImageOnly description' => {
                message => "If your profile field requires uploading an Image, you will provided with an additional field that will only allow image file types are uploaded.",
                lastUpdated => 1165447428
        },

	'showAtRegistration label' => {
                message => "Show at Registration?",
                lastUpdated => 1164237018
        },

	'showAtRegistration hoverHelp' => {
                message => "Show an entry for this field at the registration screen for newly-registering users.  The field will not actually be required unless Required is also set.",
                lastUpdated => 1164237018
        },

	'requiredForPasswordRecovery label' => {
                message => "Required for password recovery?",
                lastUpdated => 1165401097
        },

	'requiredForPasswordRecovery hoverHelp' => {
                message => "Require users to enter this field for password recovery.  Only users that enter all such fields correctly and uniquely to them will be able to perform password recovery.",
                lastUpdated => 1165401097
        },
};

1;
