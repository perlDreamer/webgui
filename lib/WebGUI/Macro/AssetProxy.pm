package WebGUI::Macro::AssetProxy;

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
use Time::HiRes;
use WebGUI::Asset;
use WebGUI::ErrorHandler;
use WebGUI::Session;
use WebGUI::International;

=head1 NAME

Package WebGUI::Macro::AssetProxy

=head1 DESCRIPTION

Macro for displaying the output of an Asset in another location.

=head2 process ( url )

=head3 url

The URL of the Asset whose output will be returned.  If no Asset with that URL
can be found, an internationalized error message will be returned instead.

No editing controls (toolbar) will be displayed in the Asset output, even if
Admin is turned on.

=cut

#-------------------------------------------------------------------
sub process {
        my $url = shift;
	my $t = [Time::HiRes::gettimeofday()] if (WebGUI::ErrorHandler::canShowPerformanceIndicators());
	my $asset = WebGUI::Asset->newByUrl($url);
	#Sorry, you cannot proxy the notfound page.
	if (defined $asset && $asset->getId ne $session{setting}{notFoundPage}) {
		$asset->toggleToolbar;
		my $output = $asset->canView ? $asset->view : undef;
		$output .= "AssetProxy:".Time::HiRes::tv_interval($t) if (WebGUI::ErrorHandler::canShowPerformanceIndicators());
		return $output;
	} else {
		return WebGUI::International::get('invalid url', 'Macro_AssetProxy');
	}
}


1;


