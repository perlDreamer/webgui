package WebGUI::Operation::Shared;


#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use Exporter;
use strict;
use WebGUI::Grouping;
use WebGUI::International;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Style;
use Safe;

our @ISA = qw(Exporter);
our @EXPORT = qw(&menuWrapper);

#-------------------------------------------------------------------
 sub accountOptions {
	my @array;
	if (WebGUI::Grouping::isInGroup(12)) {
		my %hash;
		if ($session{var}{adminOn}) {
			$hash{'options.display'} .= '<a href="'.WebGUI::URL::page('op=switchOffAdmin').'">'.WebGUI::International::get(12).'</a>';
		} else {
			$hash{'options.display'} .= '<a href="'.WebGUI::URL::page('op=switchOnAdmin').'">'.WebGUI::International::get(63).'</a>';
		}
	    push(@array,\%hash);
	}
	unless ($session{form}{op} eq "displayAccount"){
		my %hash;
		$hash{'options.display'} = '<a href="'.WebGUI::URL::page('op=auth;method=init').'">'.WebGUI::International::get(342).'</a>';
		push(@array,\%hash);
	}
	unless ($session{form}{op} eq "editProfile"){
		my %hash;
		$hash{'options.display'} = '<a href="'.WebGUI::URL::page('op=editProfile').'">'.WebGUI::International::get(341).'</a>';
		push(@array,\%hash);
	}
	unless ($session{form}{op} eq "viewProfile"){
		my %hash;
		$hash{'options.display'} = '<a href="'.WebGUI::URL::page('op=viewProfile;uid='.$session{user}{userId}).'">'.WebGUI::International::get(343).'</a>';
		push(@array,\%hash);
	}
	unless ($session{form}{op} eq "viewMessageLog"){
		my %hash;
		$hash{'options.display'} = '<a href="'.WebGUI::URL::page('op=viewMessageLog').'">'.WebGUI::International::get(354).'</a>';
		push(@array,\%hash);
	}
	unless ($session{form}{op} eq "redeemSubscriptionCode") {
		push(@array, {'options.display' => '<a href="'.WebGUI::URL::page('op=redeemSubscriptionCode').'">'.WebGUI::International::get('redeem code', 'Subscription').'</a>'});
	}
		
	my %logout;
	$logout{'options.display'} = '<a href="'.WebGUI::URL::page('op=auth;method=logout').'">'.WebGUI::International::get(64).'</a>'; 
	push(@array,\%logout);
	if ($session{setting}{selfDeactivation} && !WebGUI::Grouping::isInGroup(3)){
	   my %hash;
	   $hash{'options.display'} = '<a href="'.WebGUI::URL::page('op=auth;method=deactivateAccount').'">'.WebGUI::International::get(65).'</a>';
	   push(@array,\%hash);
	}
	return \@array;
}

#-------------------------------------------------------------------
sub menuWrapper {
        my ($output, $key);
	$session{page}{useAdminStyle} = 1;
        $output = '<table width="100%" border="0" cellpadding="5" cellspacing="0">
		<tr><td width="70%" class="tableData" valign="top">';
        $output .= $_[0];
        $output .= '</td><td width="30%" class="tableMenu" valign="top">';
	foreach $key (keys %{$_[1]}) {
        	$output .= '<li><a href="'.$key.'">'.$_[1]->{$key}.'</a></li>';
	}
        $output .= '<li><a href="'.WebGUI::URL::page().'">'.WebGUI::International::get(493).'</a></li>';
        $output .= '</td></tr></table>';
        return $output;
}

#-------------------------------------------------------------------
sub userStyle {
	my $output = shift;
	if ($output) {
		return WebGUI::Style::process($output,$session{setting}{userFunctionStyleId});
	} else {
		return undef;
	}
}

#-------------------------------------------------------------------
# This function is here to replace the dangerous eval calls in the User Profile System.
sub secureEval {
	my $code = shift;

	# Handle WebGUI function calls
	my %trusted = (
		'WebGUI::International::get' => sub {WebGUI::International::get(@_)},
		'WebGUI::International::getLanguages' => sub { WebGUI::International::getLanguages(@_) },
		'WebGUI::DateTime::epochToHuman' => sub { WebGUI::DateTime::epochToHuman(@_) },
		'WebGUI::Icon::getToolbarOptions' => sub { WebGUI::Icon::getToolbarOptions(@_) },		
	);
	foreach my $function (keys %trusted ) {
		while ($code =~ /($function\(([^)]*)\)\s*;*)/g) {
			my $cmd = $1;
			my @param = split (/,/,$2);
			@param = map { s/^['"]|['"]$//g; $_; } @param;
			my $output = $trusted{$function}(@param);
			return $output if (ref $output);	
			$code =~ s/\Q$cmd/'$output'/g;
		}
	}
	
	# Execute simple perl code like ['English'] for default value.
	# Inside the Safe compartment there's no WebGUI available
	my $compartment = new Safe;
	my $eval = $compartment->reval($code);
	if ($eval) {
		return $eval;
	} 
	return $code;
}


1;
