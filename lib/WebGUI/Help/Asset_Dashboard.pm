package WebGUI::Help::Asset_Dashboard;

our $HELP = {
	'dashboard add/edit' => {
		title => 'dashboard add/edit title',
		body => 'dashboard add/edit body',
		fields => [
                        {
                                title => 'dashboard template field label',
                                description => 'dashboard template description',
                                namespace => 'Asset_Dashboard',
			},
                        {
                                title => 'dashboard adminsGroupId field label',
                                description => 'dashboard adminsGroupId description',
                                namespace => 'Asset_Dashboard',
			},
                        {
                                title => 'dashboard usersGroupId field label',
                                description => 'dashboard usersGroupId description',
                                namespace => 'Asset_Dashboard',
			},
                        {
                                title => 'assets to hide',
                                description => 'assets to hide description',
                                namespace => 'Asset_Dashboard',
                                uiLevel => 9,
			},
		],
		related => [
			{
				tag => 'shortcut add/edit',
				namespace => 'Asset_Shortcut'
			}
		]
	}
};

1;
