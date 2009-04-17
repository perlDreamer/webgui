package WebGUI::AssetAspect::RssFeed;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use Class::C3;
use WebGUI::Exception;
use WebGUI::Storage;
use XML::FeedPP;
use Path::Class::File;

=head1 NAME

Package WebGUI::AssetAspect::RssFeed

=head1 DESCRIPTION

This is an aspect which exposes an asset's items as an RSS or Atom feed.

=head1 SYNOPSIS

 use Class::C3;
 use base qw(WebGUI::AssetAspect::RssFeed WebGUI::Asset);

And then wherever you would call $self->SUPER::someMethodName call $self->next::method instead.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 definition

Extends the definition to add the RSS fields.

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my $i18n = WebGUI::International->new($session,'AssetAspect_RssFeed');
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
		itemsPerFeed => {
			noFormPost		=> 0,
			fieldType       => "integer",
			defaultValue    => 25,
    		tab             => "rss",
    		label           => $i18n->get('itemsPerFeed'),
    		hoverHelp       => $i18n->get('itemsPerFeed hoverHelp')
			},
		feedCopyright => {
			noFormPost		=> 0,
			fieldType       => "text",
			defaultValue    => "",
    		tab             => "rss",
    		label           => $i18n->get('feedCopyright'),
    		hoverHelp       => $i18n->get('feedCopyright hoverHelp')
			},
		feedTitle => {
			noFormPost		=> 0,
			fieldType       => "text",
			defaultValue    => "",
    		tab             => "rss",
    		label           => $i18n->get('feedTitle'),
    		hoverHelp       => $i18n->get('feedTitle hoverHelp')
			},
		feedDescription => {
			noFormPost		=> 0,
			fieldType       => "textarea",
			defaultValue    => "",
    		tab             => "rss",
    		label           => $i18n->get('feedDescription'),
    		hoverHelp       => $i18n->get('feedDescription hoverHelp')
			},
		feedImage => {
			noFormPost		=> 0,
			fieldType       => "image",
    		tab             => "rss",
    		label           => $i18n->get('feedImage'),
    		hoverHelp       => $i18n->get('feedImage hoverHelp')
			},
		feedImageLink => {
			noFormPost		=> 0,
			fieldType       => "url",
			defaultValue    => "",
    		tab             => "rss",
    		label           => $i18n->get('feedImageLink'),
    		hoverHelp       => $i18n->get('feedImageLink hoverHelp')
			},
		feedImageDescription => {
			noFormPost		=> 0,
			fieldType       => "text",
			defaultValue    => "",
    		tab             => "rss",
    		label           => $i18n->get('feedImageDescription'),
    		hoverHelp       => $i18n->get('feedImageDescription hoverHelp')
			},
        feedHeaderLinks => {
            fieldType       => "checkList",
            allowEmpty      => 1,
            defaultValue    => "rss\natom",
            tab             => "rss",
            options         => do {
                my %headerLinksOptions;
                tie %headerLinksOptions, 'Tie::IxHash';
                %headerLinksOptions = (
                    rss  => $i18n->get('rssLinkOption'),
                    atom => $i18n->get('atomLinkOption'),
                    rdf  => $i18n->get('rdfLinkOption'),
                );
                \%headerLinksOptions;
            },
            label           => $i18n->get('feedHeaderLinks'),
            hoverHelp       => $i18n->get('feedHeaderLinks hoverHelp')
        },
	    );
	push(@{$definition}, {
		autoGenerateForms   => 1,
		tableName           => 'assetAspectRssFeed',
		className           => 'WebGUI::AssetAspect::RssFeed',
		properties          => \%properties
	    });
	return $class->next::method($session, $definition);
}

#-------------------------------------------------------------------

=head2 exportAssetCollateral ()

Extended from WebGUI::Asset and exports the www_viewRss() and
www_viewAtom() methods with filenames generated by
getStaticAtomFeedUrl() and getStaticRssFeedUrl().

This method will be called with the following parameters:

=head3 basePath

A L<Path::Class> object representing the base filesystem path for this
particular asset.

=head3 params

A hashref with the quiet, userId, depth, and indexFileName parameters from
L<WebGUI::Asset/exportAsHtml>.

=head3 session

The session doing the full export.  Can be used to report status messages.

=cut

sub exportAssetCollateral {
    # Lots of copy/paste here from AssetExportHtml.pm, since none of the methods there were
    #   directly useful without ginormous refactoring.
    my $self = shift;
    my $basepath = shift;
    my $args = shift;
    my $reportSession = shift;

    my $reporti18n = WebGUI::International->new($self->session, 'Asset');

    my $basename = $basepath->basename;
    my $filedir;
    my $filenameBase;

    # We want our .rss and .atom files to "appear" at the same level as the asset.
    if ($basename eq 'index.html') {
        # Get the 2nd ancestor, since the asset url had no dot in it (and it therefore
        #   had its own directory created for it).
        $filedir = $basepath->parent->parent->absolute->stringify;
        # Get the parent dir's *path* (essentially the name of the dir) relative to
        #   its own parent dir.
        $filenameBase = $basepath->parent->relative( $basepath->parent->parent )->stringify;
    } else {
        # Get the 1st ancestor, since the asset is a file recognized by apache, so
        #   we want our files in the same dir.
        $filedir = $basepath->parent->absolute->stringify;
        # just use the basename.
        $filenameBase = $basename;
    }

    if ( $reportSession && !$args->{quiet} ) {
        $reportSession->output->print('<br />');
    }

    foreach my $ext (qw( rss atom )) {
        my $dest = Path::Class::File->new($filedir, $filenameBase . '.' . $ext);

        # tell the user which asset we're exporting.
        if ( $reportSession && !$args->{quiet} ) {
            my $message = sprintf $reporti18n->get('exporting page'), $dest->absolute->stringify;
            $reportSession->output->print(
                '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' . $message . '<br />');
        }
        my $exportSession = WebGUI::Session->open(
            $self->session->config->getWebguiRoot,
            $self->session->config->getFilename,
            undef,
            undef,
            $self->session->getId,
        );

        # open another session as the user doing the exporting...
        my $selfdupe = WebGUI::Asset->newByDynamicClass( $exportSession, $self->getId );

        # next, get the contents, open the file, and write the contents to the file.
        my $fh = eval { $dest->open('>:utf8') };
        if($@) {
            $exportSession->close;
            WebGUI::Error->throw(error => "can't open " . $dest->absolute->stringify . " for writing: $!");
        }
        $exportSession->asset($selfdupe);
        $exportSession->output->setHandle($fh);
        my $contents;
        if ($ext eq 'rss') {
            $contents = $selfdupe->www_viewRss;
        }
        else {
            $contents = $selfdupe->www_viewAtom;
        } # add more for more extensions.

        # chunked content is already printed, no need to print it again
        unless($contents eq 'chunked') {
            $exportSession->output->print($contents);
        }

        $exportSession->close;

        # tell the user we did this asset collateral correctly
        if ( $reportSession && !$args->{quiet} ) {
            $reportSession->output->print($reporti18n->get('done'));
        }
    }
    return $self->next::method($basepath, $args, $reportSession);
}

#-------------------------------------------------------------------

=head2 getRssFeedItems ()

This method needs to be overridden by any class that is using it.  To ensure
this, it will throw an exception.

It returns an array reference of hash references.  The list below shows
which ones are required, along with some common keys which are optional.
Other keys may be added, as well.

=head3 Hash reference keys

=head4 title

=head4 description

=head4 link

This is a url to the item.

=head4 date

An epoch date, an RFC 1123 date, or a date in ISO format (referred to as MySQL format
inside WebGUI)

=head4 author

This is optional.

=head4 guid

This is optional.  A unique descriptor for this item.

=cut

sub getRssFeedItems {
    WebGUI::Error::OverrideMe->throw();
}

#-------------------------------------------------------------------

=head2 getAtomFeedUrl ()

Returns $self->getUrl('func=viewAtom').

=cut

sub getAtomFeedUrl {
    shift->getUrl("func=viewAtom");
}

#-------------------------------------------------------------------

=head2 getRdfFeedUrl ()

Returns $self->getUrl('func=viewRdf').

=cut

sub getRdfFeedUrl {
    shift->getUrl("func=viewRdf");
}

#-------------------------------------------------------------------

=head2 getRssFeedUrl ()

Returns $self->getUrl('func=viewRss').

=cut

sub getRssFeedUrl {
    shift->getUrl("func=viewRss");
}

#-------------------------------------------------------------------

=head2 getStaticAtomFeedUrl ()

Returns the current asset's URL with .atom concatenated onto it.

=cut

sub getStaticAtomFeedUrl {
    my $self = shift;
    my $url = $self->get("url") . '.atom';
    $url = $self->session->url->gateway($url);
    if ($self->get("encryptPage")) {
        $url = $self->session->url->getSiteURL . $url;
        $url =~ s/^http:/https:/;
    }
    return $url;
}

#-------------------------------------------------------------------

=head2 getStaticRdfFeedUrl ()

Returns the current asset's URL with .rdf concatenated onto it.

=cut

sub getStaticRdfFeedUrl {
    my $self = shift;
    my $url = $self->get("url") . '.rdf';
    $url = $self->session->url->gateway($url);
    if ($self->get("encryptPage")) {
        $url = $self->session->url->getSiteURL . $url;
        $url =~ s/^http:/https:/;
    }
    return $url;
}

#-------------------------------------------------------------------

=head2 getStaticRssFeedUrl ()

Returns the current asset's URL with .rss concatenated onto it.

=cut

sub getStaticRssFeedUrl {
    my $self = shift;
    my $url = $self->get("url") . '.rss';
    $url = $self->session->url->gateway($url);
    if ($self->get("encryptPage")) {
        $url = $self->session->url->getSiteURL . $url;
        $url =~ s/^http:/https:/;
    }
    return $url;
}

#-------------------------------------------------------------------

=head2 getFeed ()

Adds the syndicated items to the feed; returns the stringified edition.
TODO: convert dates?

=cut

sub getFeed {
    my $self = shift;
    my $feed = shift;
    foreach my $item ( @{ $self->getRssFeedItems } ) {
        my $set_permalink_false = 0;
        my $new_item = $feed->add_item( %{ $item } );
        if (!$new_item->guid) {
            if ($new_item->link) {
                $new_item->guid( $new_item->link );
            } else {
                $new_item->guid( $self->session->id->generate );
                $set_permalink_false = 1;
            }
        }
        $new_item->guid( $new_item->guid, isPermaLink => 0 ) if $set_permalink_false;
    }
    $feed->title( $self->get('feedTitle') || $self->get('title') );
    $feed->description( $self->get('feedDescription') || $self->get('synopsis') );
    $feed->pubDate( $self->getContentLastModified );
    $feed->copyright( $self->get('feedCopyright') );
    $feed->link( $self->getUrl );
    # $feed->language( $lang );
    if ($self->get('feedImage')) {
        my $storage = WebGUI::Storage->get($self->session, $self->get('feedImage'));
        my @files = @{ $storage->getFiles };
        if (scalar @files) {
            $feed->image(
                $storage->getUrl( $files[0] ),
                $self->get('feedImageDescription') || $self->getTitle,
                $self->get('feedImageUrl') || $self->getUrl,
                $self->get('feedImageDescription') || $self->getTitle,
                ( $storage->getSizeInPixels( $files[0] ) ) # expands to width and height
            );
        }
    }
    return $feed;
}

#-------------------------------------------------------------------

=head2 prepareView ()

Extend the master class to insert head links via addHeaderLinks.

=cut

sub prepareView {
    my $self = shift;
    $self->addHeaderLinks;
    return $self->next::method(@_);
}

#-------------------------------------------------------------------

=head2 addHeaderLinks ()

Add RSS, Atom, or RDF links in the HEAD block of the Asset, depending
on how the Asset has configured feedHeaderLinks.

=cut

sub addHeaderLinks {
    my $self = shift;
    my $style = $self->session->style;
    my $title = $self->get('feedTitle') || $self->get("title");
    my %feeds = map { $_ => 1 } split /\n/, $self->get('feedHeaderLinks');
    my $addType = keys %feeds > 1;
    if ($feeds{rss}) {
        $style->setLink($self->getRssFeedUrl, {
            rel   => 'alternate',
            type  => 'application/rss+xml',
            title => $title . ( $addType ? ' (RSS)' : ''),
        });
    }
    if ($feeds{atom}) {
        $style->setLink($self->getAtomFeedUrl, {
            rel   => 'alternate',
            type  => 'application/atom+xml',
            title => $title . ( $addType ? ' (Atom)' : ''),
        });
    }
    if ($feeds{rdf}) {
        $style->setLink($self->getRdfFeedUrl, {
            rel   => 'alternate',
            type  => 'application/rdf+xml',
            title => $title . ( $addType ? ' (RDF)' : ''),
        });
    }
}

#-------------------------------------------------------------------

=head2 www_viewAtom ()

Return Atom view of the syndicated items.

=cut

sub www_viewAtom {
    my $self = shift;
    $self->session->http->setMimeType('application/atom+xml');
    return $self->getFeed( XML::FeedPP::Atom->new )->to_string;
}

#-------------------------------------------------------------------

=head2 www_viewRdf ()

Return Rdf view of the syndicated items.

=cut

sub www_viewRdf {
    my $self = shift;
    $self->session->http->setMimeType('application/rdf+xml');
    return $self->getFeed( XML::FeedPP::RDF->new )->to_string;
}

#-------------------------------------------------------------------

=head2 www_viewRss ()

Return RSS view of the syndicated items.

=cut

sub www_viewRss {
    my $self = shift;
    $self->session->http->setMimeType('application/rss+xml');
    return $self->getFeed( XML::FeedPP::RSS->new )->to_string;
}

#-------------------------------------------------------------------

=head2 getEditTabs ()

Adds an RSS tab to the Edit Tabs.

=cut

sub getEditTabs {
    my $self = shift;
    my $i18n = WebGUI::International->new($self->session,'AssetAspect_RssFeed');
    return ($self->next::method, ['rss', $i18n->get('RSS tab'), 1]);
}

1;

