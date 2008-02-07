#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";

use WebGUI::Test;
use WebGUI::Session;
use WebGUI::Operation::Help;
use WebGUI::International;
use Data::Dumper;

#The goal of this test is to make sure that all required labels
#for the help system exist.

use Test::More; # increment this value for each test you create
my $numTests = 0;

my $session = WebGUI::Test->session;

my @helpFileSet = WebGUI::Operation::Help::_getHelpFilesList($session);

$numTests = scalar @helpFileSet;

plan tests => $numTests;

foreach my $fileSet (@helpFileSet) {
	my $file = $fileSet->[1];
	ok(WebGUI::Operation::Help::_getHelpName($session, $file), "Missing label for $file");
}
