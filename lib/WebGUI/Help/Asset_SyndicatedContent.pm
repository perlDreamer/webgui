package WebGUI::Help::Asset_SyndicatedContent;

our $HELP = {
	'syndicated content add/edit' => {
		title => '61',
		body => '71',
		isa => [
			{
				namespace => "Asset_Wobject",
				tag => "wobject add/edit"
			},
		],
		fields => [
                        {
                                title => 'cache timeout',
                                namespace => 'Asset_SyndicatedContent',
                                description => 'cache timeout help',
				uiLevel => 8,
                        },
                        {
                                title => '72',
                                description => '72 description',
                                namespace => 'Asset_SyndicatedContent',
                        },
                        {
                                title => 'displayModeLabel',
                                description => 'displayModeLabel description',
                                namespace => 'Asset_SyndicatedContent',
                        },
                        {
                                title => 'hasTermsLabel',
                                description => 'hasTermsLabel description',
                                namespace => 'Asset_SyndicatedContent',
                        },
                        {
                                title => '1',
                                description => '1 description',
                                namespace => 'Asset_SyndicatedContent',
                        },
                        {
                                title => '3',
                                description => '3 description',
                                namespace => 'Asset_SyndicatedContent',
                        },
		],
		related => [
			{
				tag => 'syndicated content template',
				namespace => 'Asset_SyndicatedContent'
			},
			{
				tag => 'wobjects using',
				namespace => 'Asset_Wobject'
			},
			{
				tag => 'asset fields',
				namespace => 'Asset'
			},
		]
	},
	'syndicated content template' => {
		title => '72',
		body => '73',
		fields => [
		],
		variables => [
		          {
		            'name' => 'channel.title'
		          },
		          {
		            'name' => 'channel.description'
		          },
		          {
		            'name' => 'channel.link'
		          },
		          {
		            'name' => 'rss.url',
		            'variables' => [
		                             {
		                               'name' => 'rss.url.0.9'
		                             },
		                             {
		                               'name' => 'rss.url.0.91'
		                             },
		                             {
		                               'name' => 'rss.url.1.0'
		                             },
		                             {
		                               'name' => 'rss.url.2.0'
		                             }
		                           ]
		          },
		          {
		            'name' => 'item_loop',
		            'variables' => [
		                             {
		                               'name' => 'site_title'
		                             },
		                             {
		                               'name' => 'site_link'
		                             },
		                             {
		                               'name' => 'new_rss_site'
		                             },
		                             {
		                               'name' => 'title'
		                             },
		                             {
		                               'name' => 'description'
		                             },
		                             {
		                               'name' => 'link'
		                             }
		                           ]
		          }
		],
		related => [
			{
				tag => 'syndicated content add/edit',
				namespace => 'Asset_SyndicatedContent'
			},
			{
				tag => 'wobject template',
				namespace => 'Asset_Wobject'
			}
		]
	},
};

1;
