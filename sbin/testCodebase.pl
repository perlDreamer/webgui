#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2006 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

$|=1;

use strict;
use FindBin;
use lib "$FindBin::Bin/../t/lib";
use Getopt::Long;

my $configFile;
my $help;
my $verbose;
my $perlBase;

GetOptions(
	'verbose'=>\$verbose,
	'configFile=s'=>\$configFile,
	'perl-base=s'=>\$perlBase,
	'help'=>\$help,
	);

my $helpmsg=<<STOP;

	perl $0 --configFile

	--configFile		The config file of the WebGUI site you'll use
				to test the codebase. Note that you should not
				use a production config file as some tests may
				be destructive.

	--verbose		Turns on additional output.

	--perl-base		The path of the perl installation you want to 
				use. Defaults to the perl installation in your
				PATH.

STOP

my $verboseFlag = "-v" if ($verbose);
my $config = $ENV{WEBGUI_CONFIG};

$perlBase .= '/bin/' if ($perlBase);

if ( $configFile ) {
	system("WEBGUI_CONFIG=".$configFile." ".$perlBase."prove ".$verboseFlag." -r ../t");
	exit;
} elsif ( defined @ENV{WEBGUI_CONFIG} ) {
        system($perlBase."prove ".$verboseFlag." -r ../t");
	exit;
} else {
	print $helpmsg;
}
