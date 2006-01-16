package WebGUI::Session::Style;

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

=cut


use strict;
use Tie::CPHash;
use WebGUI::International;
use WebGUI::Macro;
use WebGUI::Asset::Template;

=head1 NAME

Package WebGUI::Session::Style

=head1 DESCRIPTION

This package contains utility methods for WebGUI's style system.

=head1 SYNOPSIS

 use WebGUI::Session::Style;
 $style = WebGUI::Session::Style->new($session);

 $html = $style->generateAdditionalHeadTags();
 $html = $style->process($content);

 $session = $style->session;
 
 $style->makePrintable(1);
 $style->setLink($url,\%params);
 $style->setMeta(\%params);
 $style->setRawHeadTags($html);
 $style->setScript($url, \%params);
 $style->useEmptyStyle(1);

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head DESTROY ( )

Deconstructor.

=cut

sub DESTROY {
        my $self = shift;
        undef $self;
}


#-------------------------------------------------------------------

=head2 generateAdditionalHeadTags ( )

Creates tags that were set using setLink, setMeta, setScript, extraHeadTags, and setRawHeadTags.

=cut

sub generateAdditionalHeadTags {
	my $self = shift;
	# generate additional raw tags
	my $tags = $self->{_raw};
        # generate additional link tags
	foreach my $url (keys %{$self->{_link}}) {
		$tags .= '<link href="'.$url.'"';
		foreach my $name (keys %{$self->{_link}{$url}}) {
			$tags .= ' '.$name.'="'.$self->{_link}{$url}{$name}.'"';
		}
		$tags .= ' />'."\n";
	}
	# generate additional javascript tags
	foreach my $tag (@{$self->{_javascript}}) {
		$tags .= '<script';
		foreach my $name (keys %{$tag}) {
			$tags .= ' '.$name.'="'.$tag->{$name}.'"';
		}
		$tags .= '></script>'."\n";
	}
	# generate additional meta tags
	foreach my $tag (@{$self->{_meta}}) {
		$tags .= '<meta';
		foreach my $name (keys %{$tag}) {
			$tags .= ' '.$name.'="'.$tag->{$name}.'"';
		}
		$tags .= ' />'."\n";
	}
	# append extraHeadTags
#	$tags .= $self->session->asset->getExtraHeadTags."\n" if ($self->session->asset);
	delete $self->{_meta};
	delete $self->{_raw};
	delete $self->{_javascript};
	delete $self->{_link};
	return $tags;
}


#-------------------------------------------------------------------

=head2 makePrintable ( boolean ) 

Tells the system to use the make printable style instead of the normal style.

=head3 boolean

If set to 1 then the printable style will be used, otherwise the regular style will be used.

=cut

sub makePrintable {
	my $self = shift;
	$self->{_makePrintable} = shift;
}


#-------------------------------------------------------------------

=head2 new ( session ) 

Constructor.

=head3 session

A reference to the current session.

=cut

sub new {
	my $class = shift;
	my $session = shift; use WebGUI; WebGUI::dumpSession($session);
	bless {_session=>$session}, $class;
}

#-------------------------------------------------------------------

=head2 process ( content, templateId )

Returns a parsed style with content based upon the current WebGUI session information.

=head3 content

The content to be parsed into the style. Usually generated by WebGUI::Page::generate().

=head3 templateId

The unique identifier for the template to retrieve. 

=cut

sub process {
	my $self = shift;
	my %var;
	$var{'body.content'} = shift;
	my $templateId = shift;
	if ($self->{_makePrintable} && $self->session->asset) {
		$templateId = $self->session->asset->get("printableStyleTemplateId");
		my $currAsset = $self->session->asset;
		until ($templateId) {
			# some assets don't have this property.  But at least one ancestor should....
			$currAsset = $currAsset->getParent;
			$templateId = $currAsset->get("printableStyleTemplateId");
		}
	} elsif ($self->session->scratch->get("personalStyleId") ne "") {
		$templateId = $self->session->scratch->get("personalStyleId");
	} elsif ($self->{_useEmptyStyle}) {
		$templateId = 6;
	}
$var{'head.tags'} = '
<meta name="generator" content="WebGUI '.$WebGUI::VERSION.'" />
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<meta http-equiv="Content-Script-Type" content="text/javascript" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<script type="text/javascript">
function getWebguiProperty (propName) {
var props = new Array();
props["extrasURL"] = "'.$self->session->config->get("extrasURL").'";
props["pageURL"] = "'.$self->session->url->page(undef, undef, 1).'";
return props[propName];
}
</script>
';
if ($self->session->user->isInGroup(2)) {
	# This "triple incantation" panders to the delicate tastes of various browsers for reliable cache suppression.
	$var{'head.tags'} .= '
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Cache-Control" content="no-cache, must-revalidate, max-age=0" />
<meta http-equiv="Expires" content="0" />
';
}
	$var{'head.tags'} .= "\n<!-- macro head tags -->\n";
	my $style = WebGUI::Asset::Template->new($self->session,$templateId);
	my $output;
	if (defined $style) {
		$output = $style->process(\%var);
	} else {
		$output = "WebGUI was unable to instantiate your style template.".$var{'body.content'};
	}
	WebGUI::Macro::process($self->session,\$output);
	my $macroHeadTags = generateAdditionalHeadTags();
	WebGUI::Macro::process($self->session,\$macroHeadTags);
	$output =~ s/\<\!-- macro head tags --\>/$macroHeadTags/;
	if ($self->session->errorHandler->canShowDebug()) {
		$output .= $self->session->errorHandler->showDebug();
	}
	return $output;
}	


#-------------------------------------------------------------------

=head2 session ( )

Returns a reference to the current session.

=cut

sub session {
	my $self = shift;
	return $self->{_session};
}

#-------------------------------------------------------------------

=head2 setLink ( url, params )

Sets a <link> tag into the <head> of this rendered page for this page view. This is typically used for dynamically adding references to CSS and RSS documents.

=head3 url

The URL to the document you are linking.

=head3 params

A hash reference containing the other parameters to be included in the link tag, such as "rel" and "type".

=cut

sub setLink {
	my $self = shift;
	my $url = shift;
	my $params = shift;
	$self->{_link}{$url} = $params;
}



#-------------------------------------------------------------------

=head2 setMeta ( params )

Sets a <meta> tag into the <head> of this rendered page for this page view. 

=head3 params

A hash reference containing the parameters of the meta tag.

=cut

sub setMeta {
	my $self = shift;
	my $params = shift;
	push(@{$self->{_meta}},$params);
}



#-------------------------------------------------------------------

=head2 setRawHeadTags ( tags )

Sets data to be output into the <head> of the current rendered page for this page view.

=head3 tags

A raw string containing tags. This is just a raw string so you must actually pass in the full tag to use this call.

=cut

sub setRawHeadTags {
	my $self = shift;
	my $tags = shift;
	$self->{_raw} .= $tags;
}


#-------------------------------------------------------------------

=head2 setScript ( url, params )

Sets a <script> tag into the <head> of this rendered page for this page view. This is typically used for dynamically adding references to Javascript or ECMA script.

=head3 url

The URL to your script.

=head3 params

A hash reference containing the additional parameters to include in the script tag, such as "type" and "language".

=cut

sub setScript {
	my $self = shift;
	my $url = shift;
	my $params = shift;
	$params->{src} = $url;
	my $found = 0;
	foreach my $script (@{$self->{_javascript}}) {
		$found = 1 if ($script->{src} eq $url);
	}
	push(@{$self->{_javascript}},$params) unless ($found);	
}

#-------------------------------------------------------------------

=head2 useEmptyStyle ( boolean ) 

Tells the style system to use an empty style rather than outputing the normal style. This is useful when you want your code to dynamically generate a style.

=head3 boolean

If set to 1 it will use an empty style, if set to 0 it will use the regular style. Defaults to 0.

=cut

sub useEmptyStyle {
	my $self = shift;
	$self->{_useEmptyStyle} = shift;
}

#-------------------------------------------------------------------

=head2 userStyle ( content )

Wrapper's the content in the user style defined in the settings.

=head3 content

The content to be wrappered.

=cut

sub userStyle {
	my $self = shift;
        my $output = shift;
        if ($output) {
                return $self->process($output,$self->session->setting->get("userFunctionStyleId"));
        } else {
                return undef;
        }       
}  

1;
