package WebGUI::i18n::English::Asset_Snippet;

our $I18N = {

	'assetName' => {
		message => q|Snippet|,
        	lastUpdated => 1128830080,
		context => 'Default name of all snippets'
	},

	'process as template' => {
		message => q|Process as template?|,
        	lastUpdated => 1104630516,
	},

	'mimeType' => {
		message => q|MIME Type|,
        	lastUpdated => 1104630516,
	},
	

	'snippet add/edit title' => {
		message => q|Snippet, Add/Edit|,
        	lastUpdated => 1104630516,
	},

	'snippet add/edit body' => {
                message => q|<P>Snippets are bits of text that may be reused on your site. Things like java scripts, cascading style sheets, HTML segments, XML or company slogans can all be used as snippets. Best of all, if you need to change the text, you need change it in only one location to update the snippet whereever it is used.</P>

<P>Since Snippets are Assets, so they have all the properties that Assets do.</P>
|,
                context => 'Describing snippets',
        	lastUpdated => 1130880179,
	},

        'snippet description' => {
                message => q|This is the snippet.  Either type it in or copy and paste it into the form field.|,
                lastUpdated => 1130880361,
        },

        'process as template description' => {
                message => q|This will run the snippet through the template engine. It will enable you to use session variables in the snippet at the cost of slower processing of the snippet.|,
                lastUpdated => 1130880425,
        },

        'mimeType description' => {
                message => q|Allows you to specify the MIME type of this asset when viewed via the web, useful if you'd like to serve CSS, plain text,  javascript or other text files directly from the WebGUI asset system. Defaults to <b>text/html</b>.|,
                lastUpdated => 1130880372,
        },

};

1;
