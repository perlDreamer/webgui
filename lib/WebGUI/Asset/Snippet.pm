package WebGUI::Asset::Snippet;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2008 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use WebGUI::Asset;
use WebGUI::Asset::Template;
use WebGUI::Macro;

our @ISA = qw(WebGUI::Asset);


=head1 NAME

Package WebGUI::Asset::Snippet

=head1 DESCRIPTION

Provides a mechanism to publish arbitrary code snippets to WebGUI for reuse in other pages. Can be used for things like HTML segments, javascript, and cascading style sheets. You can also specify the MIME type of the snippet, allowing you to serve XML, CSS and other text files directly from the WebGUI asset system and have browsers recognize them correctly.

=head1 SYNOPSIS

use WebGUI::Asset::Snippet;


=head1 METHODS

These methods are available from this class:

=cut



#-------------------------------------------------------------------

=head2 definition ( definition )

Defines the properties of this asset.

=head3 definition

A hash reference passed in from a subclass definition.

=cut

sub definition {
        my $class = shift;
        my $session = shift;
        my $definition = shift;
	my $i18n = WebGUI::International->new($session,"Asset_Snippet");
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
 			snippet=>{
                        	fieldType=>'codearea',
				tab=>"properties",
				label=>$i18n->get('assetName'),
				hoverHelp=>$i18n->get('snippet description'),
                                defaultValue=>undef
                                },
			cacheTimeout => {
				tab => "display",
				fieldType => "interval",
				defaultValue => 3600,
				uiLevel => 8,
				label => $i18n->get("cache timeout"),
				hoverHelp => $i18n->get("cache timeout help")
				},
 			processAsTemplate=>{
                        	fieldType=>'yesNo',
				label=>$i18n->get('process as template'),
				hoverHelp=>$i18n->get('process as template description'),
				tab=>"properties",
                                defaultValue=>0
                                },
			mimeType=>{
				tab=>"properties",
				hoverHelp=>$i18n->get('mimeType description'),
				label=>$i18n->get('mimeType'),
                        	fieldType=>'mimeType',
                                defaultValue=>'text/html'
                                }

                        );
        push(@{$definition}, {
		assetName=>$i18n->get('assetName'),
		uiLevel => 5,
		icon=>'snippet.gif',
		autoGenerateForms=>1,
                tableName=>'snippet',
                className=>'WebGUI::Asset::Snippet',
                properties=>\%properties
                });
        return $class->SUPER::definition($session,$definition);
}


#-------------------------------------------------------------------

=head2 exportGetUrlAsPath ( index )

Translates a URL into an appropriate path and filename for exporting.
Overridden here to return a filename corresponding to the URL of this asset
as-is.

=head3 index

index filename passed from exportAsHtml

=cut

sub exportGetUrlAsPath {
    my $self            = shift;

    # we don't use this, but get it anyway
    my $index           = shift || 'index.html';

    my $config          = $self->session->config;

    # make sure that the export path is valid
    WebGUI::Asset->exportCheckPath($self->session);

    # if we're still here, it's valid. get it.
    my $exportPath      = $config->get('exportPath');

    # get the asset's URL as a URI::URL object for easy parsing of components
    my $url             = URI::URL->new($config->get("sitename")->[0] . $self->getUrl);
    my @pathComponents  = $url->path_components;
    shift @pathComponents; # first item is the empty string
    my $filename        = pop @pathComponents;

    # return a path with the filename part of the URL. No fancy twiddling needed.
    return Path::Class::File->new($exportPath, @pathComponents, $filename);
}

#-------------------------------------------------------------------

=head2 getToolbar ( )

Returns a toolbar with a set of icons that hyperlink to functions that delete, edit, promote, demote, cut, and copy.

=cut

sub getToolbar {
	my $self = shift;
	return undef if ($self->getToolbarState);
	return '<p>'.$self->SUPER::getToolbar().'</p>';
}

#-------------------------------------------------------------------

=head2 indexContent ( )

Indexing the content of the snippet. See WebGUI::Asset::indexContent() for additonal details. 

=cut

sub indexContent {
	my $self = shift;
	my $indexer = $self->SUPER::indexContent;
	$indexer->addKeywords($self->get("snippet"));
	$indexer->setIsPublic(0);
}

#-------------------------------------------------------------------

=head2 purgeCache ( )

Extending purgeCache to handle caching of the rendered snippet

=cut

sub purgeCache {
	my $self = shift;

	WebGUI::Cache->new($self->session,"view__".$self->getId)->delete;
	WebGUI::Cache->new($self->session,"view_1_".$self->getId)->delete;	
	$self->SUPER::purgeCache();
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $calledAsWebMethod = shift;
    my $session = $self->session;
    my $versionTag = WebGUI::VersionTag->getWorking($session, 1);
    my $noCache =
        $session->var->isAdminOn
        || $self->get("cacheTimeout") <= 10
        || ($versionTag && $versionTag->getId eq $self->get("tagId"));
    unless ($noCache) {
		my $out = WebGUI::Cache->new($session,"view_".$calledAsWebMethod."_".$self->getId)->get;
		return $out if $out;
	}
	my $output = $self->get("snippet");
	$output = $self->getToolbar.$output if ($session->var->isAdminOn && !$calledAsWebMethod);
	if ($self->getValue("processAsTemplate")) {
		$output = WebGUI::Asset::Template->processRaw($session, $output, $self->get);
	}
	WebGUI::Macro::process($session,\$output);
    unless ($noCache) {
		WebGUI::Cache->new($session,"view_".$calledAsWebMethod."_".$self->getId)->set($output,$self->get("cacheTimeout"));
	}
       	return $output;
}

#-------------------------------------------------------------------
sub www_edit {
    my $self = shift;
    return $self->session->privilege->insufficient() unless $self->canEdit;
    return $self->session->privilege->locked() unless $self->canEditIfLocked;
	return $self->getAdminConsole->render($self->getEditForm->print,$self->addEditLabel);

}

#-------------------------------------------------------------------

=head2 www_view

A web accessible version of the view method.

=cut

sub www_view {
	my $self = shift;
        return $self->session->privilege->insufficient() unless $self->canView;
	my $mimeType=$self->getValue('mimeType');
	$self->session->http->setMimeType($mimeType || 'text/html');
	$self->session->http->setCacheControl($self->get("cacheTimeout"));
	return $self->view(1);
}


1;

