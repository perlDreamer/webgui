package WebGUI::PerformanceProfiler;

=head1 LEGAL
                                              ,
                                            ,o
                                            :o
                   _....._                  `:o
                 .'       ``-.                \o
                /  _      _   \                \o
               :  /*\    /*\   )                ;o
               |  \_/    \_/   /                ;o
               (       U      /                 ;o
                \  (\_____/) /                  /o
                 \   \_m_/  (                  /o
                  \         (                ,o:
                  )          \,           .o;o'           ,o'o'o.
                ./          /\o;o,,,,,;o;o;''         _,-o,-'''-o:o.
 .             ./o./)        \    'o'o'o''         _,-'o,o'         o
 o           ./o./ /       .o \.              __,-o o,o'
 \o.       ,/o /  /o/)     | o o'-..____,,-o'o o_o-'
 `o:o...-o,o-' ,o,/ |     \   'o.o_o_o_o,o--''
 .,  ``o-o'  ,.oo/   'o /\.o`.
 `o`o-....o'o,-'   /o /   \o \.                       ,o..         o
   ``o-o.o--      /o /      \o.o--..          ,,,o-o'o.--o:o:o,,..:o
                 (oo(          `--o.o`o---o'o'o,o,-'''        o'o'o
                  \ o\              ``-o-o''''
   ,-o;o           \o \
  /o/               )o )      WebGUI::PerformanceProfiler
 (o(               /o /			By Len Kranendonk
  \o\.       ...-o'o /				ilance.nl
    \o`o`-o'o o,o,--' 
      ```o--'''  

=cut

=head1 USAGE

This module provides functionality to profile your
WebGUI code, and find slow routines.

Using this module is simple, just add:

PerlModule WebGUI::PerformanceProfiler
PerlChildInitHandler WebGUI::PerformanceProfiler
PerlOutputFilterHandler WebGUI::PerformanceProfiler

To the apache configuration.

By default all preloaded WebGUI code will get profiled. 
You can limit the profiling to specific modules like this:

PerlSetVar whatToProfile WebGUI::Asset::Wobject

=cut

use strict;
use Time::HiRes qw(time);
use Apache2::Const -compile => qw(OK DECLINED NOT_FOUND);
use Apache2::ServerUtil;
use Apache2::Filter;
use Apache2::FilterRec;
use Apache2::RequestIO;
use Apache2::RequestRec;
use ModPerl::Util;

my @subTimes = ();
my $depth = 0;
my %pointer;

sub handler {
	my $r = shift;
	my $callback = ModPerl::Util::current_callback();
	if($callback eq 'PerlChildInitHandler') {
		return addProfilerCode();
	} else {
		return output($r);
	}
}

sub addProfilerCode {
	my $r = shift; 
	my $s = Apache2::ServerUtil->server;
        my $whatToProfile = $s->dir_config('WhatToProfile') || 'WebGUI';

	my %subs = findSubs($whatToProfile);
	my $myself = __PACKAGE__;
	while(my($name, $ref) = each(%subs)) {
		unless($name =~ /$myself/i 		# Dont instrument ourself.
			|| $name =~ /AUTOLOAD/i		# Dont instrument AUTOLOAD
			|| is_constant($name,$ref)	# Dont instrument CONSTANTS
			){
			instrumentSub($name, $ref);
		}
	}
	return Apache2::Const::DECLINED;
}

sub output {
	my $f = shift;
	return Apache2::Const::DECLINED unless($f->r->content_type =~ 'text/html');
	while($f->read(my $buffer, 1024)) {
		my $content .= $buffer;
		if ($content =~ /(<\/body)/i) {
			my $results = results();
			$content =~ s/<\/body(.*)/${results}<\/body$1/i;
		}	
		$f->print($content);
	}
	return Apache2::Const::OK;
}

sub findSubs {
	my $pkg = shift;
	my %_subs;
	my @symbols;
	eval('@symbols = keys(%'.$pkg.'::);');
	foreach my $sym (@symbols) {
		next if ($sym eq $pkg.'::');		# Self refering routine 
		next if ($sym =~ /^__/);
		if($sym =~ /\:\:$/) {
			$sym =~ s/\:\:$//;
			%_subs = (%_subs, findSubs($pkg . '::' . $sym));
			next;
		}
		next if ($sym =~ /\W/);
		my $code_ref;
		eval('$code_ref = *'.$pkg.'::'.$sym.'{CODE};');
		next unless($code_ref);
		$_subs{$pkg."::".$sym} = $code_ref;
	}
	return %_subs;
}

sub instrumentSub {
	my $name = shift;
	my $coderef = shift;
	my $prototype;
	if(defined(prototype($name))) {
		$prototype = '('.prototype($name).')';
	}
	my $instrumented_body = q(
	{
		profileSubStart( $name );
		my $ret_val_scalar;
		my @ret_val_array;

		if(wantarray) {
			eval { @ret_val_array = &$coderef; };
		} else {
			eval { $ret_val_scalar = &$coderef; };
        	}
		die ($@) if ($@);
		profileSubEnd( $name );
		if(wantarray) {
			return @ret_val_array;
		} else {
			return $ret_val_scalar;
		}
	};
	);
	eval "no warnings 'redefine'; *$name = sub $prototype $instrumented_body" ;
}

sub profileSubStart {
	my $routine = shift;
	push(@subTimes, {
		routine => $routine,
		'start' => time(),
		depth => ++$depth
	});
	$pointer{$routine} = $#subTimes;
}

sub profileSubEnd {
	my $routine = shift;
	my $call = $subTimes[$pointer{$routine}];
	$call->{end} = time();
	$depth--;
}

sub results {
	my $output = qq|
<script> 
function showhide(id){ 
if (document.getElementById){ 
obj = document.getElementById(id); 
if (obj.style.display == "none"){ 
obj.style.display = ""; 
} else { 
obj.style.display = "none"; 
} 
} 
} 
</script>|;
	$output .= '<h2>Stack Profiler</h2>';
	my $total = sprintf("%.4f",($subTimes[-1]->{'end'} - $subTimes[0]->{'start'}));
	$output .= '<i>Function calls: '.scalar(@subTimes).' took: '.$total.'s</i><br><br>';
	for(my $entry=0;$entry <= $#subTimes;$entry++) {
		my $call = $subTimes[$entry];
		$call->{duration} = $call->{end} - $call->{start};
		$output .= "\n".'&nbsp;&nbsp;&nbsp;&nbsp;';
		$output .= '&nbsp;|&nbsp;' for(2..$call->{depth});
		if($subTimes[$entry + 1] && ($subTimes[$entry + 1]->{depth} > $call->{depth})) {
			$call->{id} = $entry;
			$output .= qq|<a href="#" onclick="showhide('profile$call->{id}'); return(false);"> + </a>|;
		} else {
			$output .= ' | ';
		}
		$output .= "<b>" if($call->{duration} > .3);
		$output .= $call->{routine} . " (".sprintf("%.5f",$call->{duration})."s)";
		$output .= "</b>" if($call->{duration} > .3);
		$output .= "<br>\n";
		my $nextDepth;
		if(ref($subTimes[$entry +1])) {
			$output .= qq|<div id="profile$entry" style="display:none;">| if ($subTimes[$entry + 1]->{depth} > $call->{depth});
			$nextDepth = $subTimes[$entry + 1]->{depth};
		} else {
			$nextDepth = 1;
		}
		if($nextDepth < $call->{depth}) {
			$nextDepth++;
			for($nextDepth .. $call->{depth}) {
				$output .= "\n</div>\n";
			}
		}
	}
	$output .= "<br>\n<br>\n<br>\n<br>\n";
	undef(@subTimes);
	return $output;
}

sub is_constant {
	no strict 'refs';
	my ($name, $code) = @_;
	my $proto = prototype($code);
	return 0 if defined $proto and length $proto;
	my $is_const;
	{
        	local $SIG{__WARN__} = sub { $is_const = 1 if $_[0] =~ /^Constant/ };
		eval { *{$name} = sub { "TEST" } };
		eval { *{$name} = $code; };
	}
	return $is_const;
}

1;
