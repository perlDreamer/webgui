# vim:syntax=perl
#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#------------------------------------------------------------------

# Write a little about what this script tests.
# 
#

use FindBin;
use strict;
use lib "$FindBin::Bin/../../lib";
use Test::More;
use WebGUI::Test; # Must use this before any other WebGUI modules
use WebGUI::Session;
#use Data::Dumper;

#----------------------------------------------------------------------------
# Init
my $session         = WebGUI::Test->session;

# Do our work in the import node
my $node = WebGUI::Asset->getImportNode($session);

# Create a version tag to work in
my $versionTag = WebGUI::VersionTag->getWorking($session);
$versionTag->set({name=>"EventManagementSystem Test"});
my $ems = $node->addChild({className=>'WebGUI::Asset::Wobject::EventManagementSystem'});


#----------------------------------------------------------------------------
# Tests

plan tests => 20;        # Increment this number for each test you create

#----------------------------------------------------------------------------

use_ok('WebGUI::Asset::Wobject::EventManagementSystem');
use_ok('WebGUI::Asset::Sku::EMSBadge');

# Test for a sane object type
isa_ok($ems, 'WebGUI::Asset::Wobject::EventManagementSystem');

# Test to see if we can set new values
my $newEMSSettings = {
        timezone => 'America/New York',
};

# update the new values for this instance
$ems->update($newEMSSettings);

# Let's check our updated values
foreach my $newSetting (keys %{$newEMSSettings}) {
        is ($ems->get($newSetting), $newEMSSettings->{$newSetting}, "updated $newSetting is ".$newEMSSettings->{$newSetting});
}

my $preparedView = $ems->prepareView();
ok($preparedView, 'prepareView returns something');

my $view = $ems->view();
ok($view, 'View returns something');

ok($ems->isRegistrationStaff == 0, 'User is not part of registration staff');

# Become admin for testing
$session->user({ userId => 3 });
ok($ems->isRegistrationStaff == 1, 'User is part of registration staff');

# Add two badges, using addChild instead of Mech
my @badges;
push(@badges, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSBadge'}));
push(@badges, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSBadge'}));
foreach my $badge(@badges) {
	ok(ref($badge) eq 'WebGUI::Asset::Sku::EMSBadge', 'Badge added');
}

# Check that both badges exists
ok($ems->can('getBadges'), 'Can get badges');
ok(scalar($ems->getBadges) == 2, 'Two Badges exist');

# Add tickets
my @tickets;
push(@tickets, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSTicket'}));
push(@tickets, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSTicket'}));

foreach my $ticket(@tickets) {
	ok(ref($ticket) eq 'WebGUI::Asset::Sku::EMSTicket', 'Ticket added');
}

ok($ems->can('getTickets'), 'Can get tickets');
ok(scalar($ems->getTickets) == 2, 'Two tickets exist');

# Add ribbons
my @ribbons;
push(@ribbons, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSRibbon'}));
push(@ribbons, $ems->addChild({className=>'WebGUI::Asset::Sku::EMSRibbon'}));

foreach my $ribbon(@ribbons) {
	ok(ref($ribbon) eq 'WebGUI::Asset::Sku::EMSRibbon', 'Ribbon added');
}

ok($ems->can('getRibbons'), 'Can get ribbons');
ok(scalar($ems->getRibbons) == 2, 'Two ribbons exist');

#----------------------------------------------------------------------------
# Cleanup
END {
		$ems->purge;

        # Clean up after thy self
        $versionTag->rollback();
}
