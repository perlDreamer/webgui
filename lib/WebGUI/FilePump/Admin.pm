package WebGUI::FilePump::Admin;

use strict;
use Tie::IxHash;
use WebGUI::AdminConsole;
use WebGUI::HTMLForm;
use WebGUI::International;
use WebGUI::Pluggable;
use WebGUI::Utility;
use WebGUI::FilePump::Bundle;

=head1 NAME

Package WebGUI::FilePump::Admin

=head1 DESCRIPTION

Web interface for making, building, and editing FilePump bundles.

=cut

#----------------------------------------------------------------------------

=head2 canView ( session [, user] )

Returns true if the user can administrate this operation. user defaults to 
the current user.

=cut

sub canView {
    my $session     = shift;
    my $user        = shift || $session->user;
    return $user->isInGroup( $session->setting->get('groupIdAdminFilePump') );
}

#-------------------------------------------------------------------

=head2 www_addBundle ( )

Displays a form to add a bundle.

Note, we do not allow bundle names to be edited.  This is why.  The directory to a bundle is based on
the bundle name, and the time stamp of the last build.  If you change the name, then you have a few
options.

1) You delete the build directory with the old name, which will break every macro which references it.

2) You leave it there, which means that they accumulate with time since they can't every be deleted because
you don't know the old name.

In short, this really means that instead of an option to edit the name, it needs a copy function.  When you
copy the bundle, it asks you what you want for a new name, and it is supplied by the user at that time.

=cut

sub www_addBundle {
    my ($session) = @_;
    return $session->privilege->insufficient() unless canView($session);

    ##Build the form
	my $i18n = WebGUI::International->new($session, 'FilePump');
	my $form = WebGUI::HTMLForm->new($session);
	$form->hidden( name=>"op",       value=>"filePump");
	$form->hidden( name=>"func",     value=>"addBundleSave");
    $form->text(
        name         => 'bundleName',
        defaultValue => $i18n->get('new bundle'),
        label        => $i18n->get('bundle name'),
        hoverHelp    => $i18n->get('bundle name help'),
    );
	$form->submit;

	my $ac   = WebGUI::AdminConsole->new($session,'filePump');
	return $ac->render($form->print, $i18n->get('Add Bundle'));
}

#-------------------------------------------------------------------

=head2 www_addBundleSave ( )

Saves the results of www_addBundle().

=cut

sub www_addBundleSave {
    my $session = shift;
    return $session->privilege->insufficient() unless canView($session);
    my $form       = $session->form;
    my $bundleName = $form->get('bundleName');
    my $bundle = WebGUI::FilePump::Bundle->create($session, {
        bundleName   => $bundleName,
        lastModified => time(),
    });
    return www_manage($session);
}

#-------------------------------------------------------------------

=head2 www_deleteBundle ( )

Deletes a bundle, identified by the form variable, bundleId.

=cut

sub www_deleteBundle {
    my $session = shift;
    return $session->privilege->insufficient() unless canView($session);
    my $bundle = WebGUI::FilePump::Bundle->new($session, $session->form->get("bundleId"));
    if (defined $bundle) {
        $bundle->delete;
    }
    return www_manage($session);
}

#------------------------------------------------------------------

=head2 www_demoteFile ( session )

Moves a bundle file down one position.  The kind of file is set by the form variable filetype,
the id of the bundle is bundleId, and the id of the file to move is fileId.

=head3 session

A reference to the current session.

=cut

sub www_demoteFile {
	my $session = shift;
	return $session->privilege->insufficient() unless canView($session);
    my $bundle = WebGUI::FilePump::Bundle->new($session, $session->form->get("bundleId"));
    if (defined $bundle) {
    }
	return www_manage($session);
}

#------------------------------------------------------------------

=head2 www_promoteFile ( session )

Moves a bundle file up one position.  The kind of file is set by the form variable filetype,
the id of the bundle is bundleId, and the id of the file to move is fileId.

=head3 session

A reference to the current session.

=cut

sub www_promoteFile {
	my $session = shift;
	return $session->privilege->insufficient() unless canView($session);
    my $bundle = WebGUI::FilePump::Bundle->new($session, $session->form->get("bundleId"));
    if (defined $bundle) {
    }
	return www_manage($session);
}

#-------------------------------------------------------------------

=head2 www_manage ( session )

Display a list of available bundles.  Provide ways to add, edit and delete them.

=head3 $session

A WebGUI session object.

=cut

sub www_manage {
    my $session = shift;
    return $session->privilege->insufficient() unless canView($session);
    my $i18n   = WebGUI::International->new($session, 'FilePump');
    my $error  = shift;
    my $rows   = '';
    my $getABundle = WebGUI::FilePump::Bundle->getAllIterator($session,{ orderBy => 'bundleName' } );
    while (my $bundle = $getABundle->()) {
        $rows .= sprintf '<tr><td>&nbsp;</td><td>%s</td>', $bundle->get('bundleName');
    }
    my $output = sprintf <<EOHTML, $i18n->get('bundle name'), $rows;
<table border="1">
<tr><th>&nbsp;</th><th>%s</th></tr>
%s
</table>
EOHTML
    my $ac = WebGUI::AdminConsole->new($session,'filePump');
    $ac->addSubmenuItem($session->url->page('op=filePump;func=addBundle'), $i18n->get('add a bundle'));
    return $ac->render($error.$output, 'File Pump');
}


1;
