package WebGUI::Asset::WikiPage;

# -------------------------------------------------------------------
#  WebGUI is Copyright 2001-2006 Plain Black Corporation.
# -------------------------------------------------------------------
#  Please read the legal notices (docs/legal.txt) and the license
#  (docs/license.txt) that came with this distribution before using
#  this software.
# -------------------------------------------------------------------
#  http://www.plainblack.com                     info@plainblack.com
# -------------------------------------------------------------------

use base 'WebGUI::Asset';
use strict;
use Tie::IxHash;
use WebGUI::International;
use WebGUI::Storage::Image;
use WebGUI::Utility;

#-------------------------------------------------------------------
# Buggo, semi-duplication with WikiMaster; move this into a common utility routine somewhere
sub _appendFuncTemplateVars {
	my $self = shift;
	my $var = shift;
	my @funcs = @_;
	my $i18n = WebGUI::International->new($self->session, 'Asset_WikiPage');
	my %specialFuncs = ();
	my $revision = $self->session->form->process('revision');
	my $revisionSuffix = defined($revision)? ";revision=$revision" : '';
	@funcs = (qw/view edit pageHistory protect unprotect delete wikiPurgeRevision/) unless @funcs;

	foreach my $func (@funcs) {
		$var->{$func.'Url'} = $self->getUrl($specialFuncs{$func}
						     || "func=$func$revisionSuffix");
		$var->{$func.'Label'} = $i18n->get("func $func link text");
		my $confirmation = $i18n->get("func $func link confirm");
		if (length $confirmation) {
			$confirmation =~ s/\'/\\\'/g;
			$var->{$func.'Confirm'} = "return confirm('$confirmation')";
		}
	}
}

#-------------------------------------------------------------------

=head2 addChild ( )

You can't add children to a wiki page.

=cut

sub addChild {
	return undef;
}

#-------------------------------------------------------------------

=head2 addRevision ( )

Override the default method in order to deal with attachments.

=cut

sub addRevision {
        my $self = shift;
        my $newSelf = $self->SUPER::addRevision(@_);
        if ($self->get("storageId")) {
                my $newStorage = WebGUI::Storage->get($self->session,$self->get("storageId"))->copy;
                $newSelf->update({storageId=>$newStorage->getId});
        }
	my $now = time();
	$newSelf->update({
		isHidden => 1,
		dateUpdated=>$now,
		});
        return $newSelf;
}

#-------------------------------------------------------------------
sub canAdd {
	my $class = shift;
	my $session = shift;
	$class->SUPER::canAdd($session, undef, '7');
}

#-------------------------------------------------------------------
sub canDelete {
	my $self = shift;
	my $userId = shift || $self->session->user->userId;
	return $self->getWiki->canAdminister($userId);
}

#-------------------------------------------------------------------
sub canEdit {
	my $self = shift;
	my $userId = shift || $self->session->user->userId;
	return 0 if $self->isProtected and not $self->getWiki->canAdminister($userId);
	return $self->couldEdit($userId);
}

#-------------------------------------------------------------------
sub canProtect {
	my $self = shift;
	my $userId = shift || $self->session->user->userId;
	return $self->getWiki->canAdminister($userId);
}

#-------------------------------------------------------------------
sub couldEdit {
	my $self = shift;
	my $userId = shift || $self->session->user->userId;
	return 0 unless $self->getWiki->canEditPages($userId);
	return 1;
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift;
	my $i18n = WebGUI::International->new($session, "Asset_WikiPage");

	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties =
	    (
	     storageId => { fieldType => 'image',
			    defaultValue => undef },
	     content => { fieldType => "HTMLArea",
			  defaultValue => undef },
	    );

	push @$definition,
	     {
	      assetName => $i18n->get('assetName'),
	      icon => 'wikiPage.gif',
	      autoGenerateForms => 1,
	      tableName => 'WikiPage',
	      className => 'WebGUI::Asset::WikiPage',
	      properties => \%properties,
	     };

	return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------
# BUGGO: how to handle this?
sub duplicate {
	my $self = shift;
	my $newAsset = $self->SUPER::duplicate(@_);
	return $newAsset;
}


#-------------------------------------------------------------------
sub getStorageLocation {
	my $self = shift;
	unless (exists $self->{_storageLocation}) {
		if ($self->get("storageId") eq "") {
			$self->{_storageLocation} = WebGUI::Storage::Image->create($self->session);
			$self->update({storageId=>$self->{_storageLocation}->getId});
		} else {
			$self->{_storageLocation} = WebGUI::Storage::Image->get($self->session,$self->get("storageId"));
		}
	}
	return $self->{_storageLocation};
}

#-------------------------------------------------------------------
sub getWiki {
	my $self = shift;
	my $parent = $self->getParent;
	return undef unless defined $parent and $parent->isa('WebGUI::Asset::Wobject::WikiMaster');
	return $parent;
}

#-------------------------------------------------------------------
sub indexContent {
	my $self = shift;
	my $indexer = $self->SUPER::indexContent;
	$indexer->addKeywords($self->get('content'));
	return $indexer;
}

#-------------------------------------------------------------------
sub isProtected {
	my $self = shift;
	return $self->{_isProtected} if exists $self->{_isProtected};
	($self->{_isProtected}) = $self->session->db->quickArray("SELECT COUNT(assetId) FROM WikiPage_protected WHERE assetId = ?", [$self->getId]);
	return $self->{_isProtected};
}

#-------------------------------------------------------------------
sub preparePageTemplate {
	my $self = shift;
	return $self->{_pageTemplate} if $self->{_pageTemplate};
	$self->{_pageTemplate} =
	    WebGUI::Asset::Template->new($self->session, $self->getWiki->get('pageTemplateId'));
	$self->{_pageTemplate}->prepare;
	return $self->{_pageTemplate};
}

#-------------------------------------------------------------------
sub prepareView {
	my $self = shift;
	$self->SUPER::prepareView;
	$self->preparePageTemplate;
}

#-------------------------------------------------------------------
sub processPageTemplate {
	my $self = shift;
	my $content = shift;
	my $func = shift || $self->session->form->process('func');
	my $var = {};
	my $template = $self->preparePageTemplate;

	$var->{content} = $content;
	$var->{canEdit} = $self->canEdit;
	$var->{couldEdit} = $self->couldEdit;
	$var->{canProtect} = $self->canProtect;
	$var->{canDelete} = $self->canDelete;
	$var->{isProtected} = $self->isProtected;
	$var->{inEdit} = isIn($func, qw/edit add/);
	$var->{inView} = isIn($func, qw/view/) || !defined $func;
	$var->{inHistory} = isIn($func, qw/pageHistory/);
	$self->_appendFuncTemplateVars($var);

	return $self->processTemplate($var, undef, $template);
}

#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	$self->SUPER::processPropertiesFromFormPost(@_);
	$self->update({ groupIdView => $self->getWiki->get('groupIdView'),
			groupIdEdit => $self->getWiki->get('groupIdEdit') });
	$self->getWiki->updateTitleIndex([$self], from => 'edit');
	delete $self->{_storageLocation};
	my $size = 0;
        my $storage = $self->getStorageLocation;
        foreach my $file (@{$storage->getFiles}) {
                if ($storage->isImage($file)) {
                        ##Use generateThumbnail to shrink size to site's max image size
                        ##We should look into using the new resize method instead.
                        $storage->generateThumbnail($file, $self->getWiki->get("maxImageSize") || $self->session->setting->get("maxImageSize"));
                        $storage->deleteFile($file);
                        $storage->renameFile('thumb-'.$file,$file);
                        $storage->generateThumbnail($file, $self->getWiki->get("thumbnailSize"));
                }
                $size += $storage->getFileSize($file);
        }
        $self->setSize($size);
	# allows us to let the cs post use it's own workflow approval process
        my $currentTag = WebGUI::VersionTag->getWorking($self->session);
        if ($currentTag->getAssetCount < 2) {
                $currentTag->set({workflowId=>$self->getWiki->get("approvalWorkflow")});
                $currentTag->requestCommit;
        } else {
                my $newTag = WebGUI::VersionTag->create($self->session, {
                        name=>$self->getTitle." / ".$self->session->user->username,
                        workflowId=>$self->getWiki->get("approvalWorkflow")
                        });
                $self->session->db->write("update assetData set tagId=? where assetId=? and tagId=?",[$newTag->getId, $self->getId, $currentTag->getId]);
                $self->purgeCache;
                $newTag->requestCommit;
        }
}	

#-------------------------------------------------------------------
sub purge {
	my $self = shift;
	$self->getWiki->updateTitleIndex([$self], from => 'purge');
	$self->session->db->write("DELETE FROM WikiPage_protected WHERE assetId = ?", [$self->getId]);
	$self->session->db->write("DELETE FROM WikiPage_extraHistory WHERE assetId = ?", [$self->getId]);
	return $self->SUPER::purge;
}

#-------------------------------------------------------------------
sub purgeRevision {
	my $self = shift;
	$self->getWiki->updateTitleIndex([$self], from => 'purgeRevision');
	return $self->SUPER::purgeRevision;
}

#-------------------------------------------------------------------
sub updateWikiHistory {
	my $self = shift;
	my $action = shift;
	my $userId = shift || $self->session->user->userId;
	$self->session->db->write("INSERT INTO WikiPage_extraHistory (assetId, userId, dateStamp, actionTaken, url, title) VALUES (?, ?, ?, ?, ?, ?)", [$self->getId, $userId, $self->session->datetime->time, $action, $self->getUrl, $self->get('title')]);
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my $var = {};
	my $content = $self->getWiki->autolinkHtml($self->get('content'));
	return $self->processPageTemplate($content, 'view');
}

#-------------------------------------------------------------------
sub www_delete {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canDelete;
	$self->trash;
	$self->session->asset($self->getParent);
	return $self->getParent->www_view;
}

#-------------------------------------------------------------------
sub www_edit {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canEdit;

	my $template = WebGUI::Asset::Template->new($self->session, $self->getWiki->get('pageEditTemplateId'));
	my $var = {};
	my $newPage = 0;
	$template->prepare;
	$var->{'form.header'} = WebGUI::Form::formHeader($self->session, { action => $self->getWiki->getUrl })
		     .WebGUI::Form::hidden($self->session, { name => 'func', value => 'editSave' })
		     .WebGUI::Form::hidden($self->session, { name => 'class', value => ref $self });
	$var->{'form.title'} = WebGUI::Form::text
	    ($self->session, { name => 'title', maxlength => 255,
			       size => 40, value => $self->get('title') });
	$var->{'form.content'} = WebGUI::Form::HTMLArea
	    ($self->session, { name => 'content', richEditId => $self->getWiki->get('richEditor'),
			       value => $self->get('content') });
	$var->{'form.submit'} = WebGUI::Form::submit
	    ($self->session, { value => 'Save' });
	$var->{'form.footer'} = WebGUI::Form::formFooter($self->session);
	$self->_appendFuncTemplateVars($var);

	$var->{title} = "Editing ".(defined($self->get('title'))? $self->get('title') : 'new page');

	return $self->getWiki->processStyle( $self->processPageTemplate($self->processTemplate($var, undef, $template), 'edit'));
}

#-------------------------------------------------------------------
sub www_pageHistory {
	my $self = shift;
	my $template = WebGUI::Asset::Template->new($self->session, $self->getWiki->get('pageHistoryTemplateId'));
	$template->prepare;

	# Buggo: hardcoded count
	my $var = {};
	$var->{title} = sprintf(WebGUI::International->new($self->session, 'Asset_WikiPage')->get('pageHistory title'), $self->get('title'));
	$self->getWiki->_appendPageHistoryVars($var, [0, 50], $self);

	return $self->getWiki->processStyle($self->processPageTemplate($self->processTemplate($var, undef, $template), 'pageHistory'));
}

#-------------------------------------------------------------------
sub www_protect {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canProtect;
	return $self->www_view if $self->isProtected;

	$self->session->db->write("DELETE FROM WikiPage_protected WHERE assetId = ?", [$self->getId]);
	$self->session->db->write("INSERT INTO WikiPage_protected (assetId) VALUES (?)", [$self->getId]);
	$self->{_isProtected} = 1;
	$self->updateWikiHistory('protected');
	return $self->www_view;
}

#-------------------------------------------------------------------
sub www_unprotect {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canProtect;
	return $self->www_view if !$self->isProtected;

	$self->session->db->write("DELETE FROM WikiPage_protected WHERE assetId = ?", [$self->getId]);
	$self->{_isProtected} = 0;
	$self->updateWikiHistory('unprotected');
	return $self->www_view;
}

#-------------------------------------------------------------------
sub www_view {
	my $self = shift;
	return $self->session->privilege->noAccess unless $self->canView;
	$self->update({ views => $self->get('views')+1 });
	# TODO: This should probably exist, as the CS has one.
#	$self->session->http->setCacheControl($self->getWiki->get('visitorCacheTimeout'))
#	    if ($self->session->user->userId eq '1');
	$self->session->http->sendHeader;
	$self->prepareView;
	return $self->getWiki->processStyle($self->view);
}


#-------------------------------------------------------------------
sub www_wikiPurgeRevision {
	my $self = shift;
	return $self->session->privilege->insufficient unless $self->canDelete;
	$self->purgeRevision;
	$self->session->asset($self->getParent);
	return $self->getParent->www_view;
}

1;
