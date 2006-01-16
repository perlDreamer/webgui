package WebGUI::Asset::Wobject::MultiSearch;

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

 Portions of the below are originally from Weather::Underground, 
 and are not included in this copyright.

=cut

use strict;

use Tie::CPHash;
use Tie::IxHash;
use JSON;
use WebGUI::International;
use WebGUI::SQL;
use WebGUI::Asset::Wobject;
use WebGUI::Utility;

our @ISA = qw(WebGUI::Asset::Wobject);


#-------------------------------------------------------------------
=head2 definition

defines wobject properties for MultiSearch instances

=cut

sub definition {
	my $class = shift;
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
	my $definition = shift;
	my $i18n = WebGUI::International->new($session, "Asset_MultiSearch");
	my $properties = {
		templateId =>{
			fieldType=>"template",
			tab=>"display",
			defaultValue=>'MultiSearchTmpl0000001',
			namespace=>"MultiSearch",
			hoverHelp=>$i18n->get('MultiSearch Template'),
			label=>$i18n->get('MultiSearch Template')
		},
#		predefinedSearches=>{
#			fieldType=>"textarea",
#			defaultValue=>"WebGUI",
#			tab=>"properties",
#			hoverHelp=>$i18n->get('article template description','Asset_Article'),
#			label=>$i18n->get(72,"Asset_Article")
#		},
	};
	push(@{$definition}, {
		tableName=>'MultiSearch',
		className=>'WebGUI::Asset::Wobject::MultiSearch',
		assetName=>$i18n->get('assetName'),
		icon=>'multiSearch.gif',
		autoGenerateForms=>1,
		properties=>$properties
	});
        return $class->SUPER::definition($session, $definition);
}

#-------------------------------------------------------------------
=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style

=cut

sub view {
	my $self = shift;	
	my %var = $self->get();
	#Set some template variables

	#Build list of searches as an array
#	my $defaults = $self->getValue("predefinedSearches");

	return $self->processTemplate(\%var, $self->get("templateId"));
}


1;
