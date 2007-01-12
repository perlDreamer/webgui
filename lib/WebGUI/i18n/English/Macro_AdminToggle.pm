package WebGUI::i18n::English::Macro_AdminToggle;

our $I18N = {

    'macroName' => {
        message => q|Admin Toggle|,
        lastUpdated => 1128837629,
    },

    'admin toggle title' => {
        message => q|Admin Toggle Macro|,
        lastUpdated => 1112466408,
    },

	'toggle.url' => {
		message => q|The URL to activate or deactivate Admin mode.|,
		lastUpdated => 1149178440,
	},

	'toggle.text' => {
		message => q|The Internationalized label for turning on or off Admin (depending on the state of the macro), or the text that you supply to the macro.|,
		lastUpdated => 1149178440,
	},

	'admin toggle body' => {
		message => q|

<p><b>&#94;AdminToggle();</b><br />
<b>&#94;AdminToggle([<i>enable admin</i>], [<i>disable admin</i>], [<i>template name</i>]);</b><br />
Places a link on the page which is only visible to content managers and administrators. The link toggles on/off admin mode. You can optionally specify other messages to display like this: &#94;AdminToggle("Edit On","Edit Off"); This macro optionally takes a third parameter that allows you to specify an alternate template name in the Macro/AdminToggle namespace.
</p>
<p>This Macro may be nested inside other Macros if the text does not contain commas or quotes.</p>
<p>
The following variables are available in the template:
</p>

|,
		lastUpdated => 1168558355,
	},

	'516' => {
		message => q|Turn Admin On!|,
		lastUpdated => 1031514049
	},

	'517' => {
		message => q|Turn Admin Off!|,
		lastUpdated => 1031514049
	},
};

1;
