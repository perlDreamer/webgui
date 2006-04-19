package WebGUI::Form::Image;

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
use base 'WebGUI::Form::File';
use WebGUI::International;
use WebGUI::Storage::Image;
use WebGUI::Form::YesNo;

=head1 NAME

Package WebGUI::Form::Image

=head1 DESCRIPTION

Creates a text input box form field.

=head1 SEE ALSO

This is a subclass of WebGUI::Form::File, and thereform WebGUI::Form::Image.

=head1 METHODS 

The following methods are specifically available from this class. Check the superclasses for additional methods.

=cut

#-------------------------------------------------------------------

=head2 definition ( [ additionalTerms ] )

See the super class for additional details.

=head3 additionalTerms

The following additional parameters have been added via this sub class.

=head4 name

If no name is specified a default name of "file" will be used.

=head4 profileEnabled

Flag that tells the User Profile system that this is a valid form element in a User Profile

=cut

sub definition {
	my $class = shift;
	my $session = shift;
	my $definition = shift || [];
	my $i18n = WebGUI::International->new($session);
	push(@{$definition}, {
		formName=>{
			defaultValue=>$i18n->get("image")
			},
		name=>{
			defaultValue=>"image"
			},
		profileEnabled=>{
			defaultValue=>1
			},
		});
        return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------

=head2 displayForm ( )

If an image is uploaded, then return the image and a control to
delete it.  Otherwise, display a form element to upload a file.

=cut

sub displayForm {
	my ($self) = @_;
	return $self->toHtml unless $self->get('value');
	##There are files inside here, for each one, display the image
	##and another form control for deleting it.
	my $location = WebGUI::Storage::Image->get($self->session, $self->get('value'));
	my $i18n = WebGUI::International->new($self->session);
	my $fileForm = '';
	my $file = shift @{ $location->getFiles };
	$fileForm .= sprintf qq!<img src="%s" /><br />!, $location->getUrl($file);
	$fileForm .= $i18n->get(392)
		  .  "&nbsp"x4
		  . WebGUI::Form::YesNo->new($self->session, {-name=>$self->privateName('delete'), -value=>0})->toHtml;
	$fileForm .= $self->toHtmlAsHidden();
	$fileForm .= WebGUI::Form::Hidden->new($self->session, {-name => $self->privateName('action'), -value => 'keep'})->toHtml();
	return $fileForm;
}

#-------------------------------------------------------------------

=head2 displayValue ( )

This utility method is used to format values for the Profile system.  It
displays each image in the storage location that is the value of the
profile field.

=cut

sub displayValue {
	my ($self) = @_;
	return '' unless $self->get("value");
	my $location = WebGUI::Storage::Image->get($self->session,$self->get("value"));
	my $file = shift @{ $location->getFiles };
	my $fileValue = sprintf qq|<img src="%s" />&nbsp;%s|, $location->getUrl($file), $file; 
	return $fileValue;
}

#-------------------------------------------------------------------

=head2 getValueFromFormPost ( )

See WebGUI::Form::File::getValueFromFormPost() for details. Generates a thumbnail.

=cut

sub getValueFromFormPost {
	my $self = shift;
	my $id = $self->SUPER::getValueFromFormPost(@_);
	if (defined $id) {
		my $storage = WebGUI::Storage::Image->get($self->session, $id);
		if (defined $storage) {
			foreach my $file (@{$storage->getFiles}) {
				$storage->generateThumbnail($file) if ($storage->isImage($file));
			}
		}
	}
	return $id;
}


#-------------------------------------------------------------------

=head2 toHtml ( )

Renders a file upload control.

=cut

sub toHtml {
	my $self = shift;
	my $i18n = WebGUI::International->new($self->session);
	my $uploadControl = undef;
	my $storage = WebGUI::Storage::Image->get($self->session, $self->get("value")) if ($self->get("value"));
	my @files = $storage->getFiles if (defined $storage);
	my $maxFiles = $self->get('maxAttachments') - scalar(@files);
	if ($maxFiles > 0) {
        	$self->session->style->setScript($self->session->config->get("extrasURL").'/FileUploadControl.js',{type=>"text/javascript"});
        	$uploadControl = '<script type="text/javascript">
                	var fileIcons = new Array();
                	';
        	opendir(DIR,$self->session->config->get("extrasPath").'/fileIcons');
        	my @icons = readdir(DIR);
        	closedir(DIR);
        	foreach my $file (@icons) {
                	unless ($file eq "." || $file eq "..") {
                        	my $ext = $file;
	                        $ext =~ s/(.*?)\.gif/$1/;
        	                $uploadControl .= 'fileIcons["'.$ext.'"] = "'.$self->session->config->get("extrasURL").'/fileIcons/'.$file.'";'."\n";
                	}
        	}
        	$uploadControl .= sprintf q!var uploader = new FileUploadControl("%s", fileIcons, "%s","%d");
        	uploader.addRow();
        	</script>!, $self->get("name"), $i18n->get("removeLabel"), $maxFiles;
		$uploadControl .= WebGUI::Form::Hidden->new($self->session, {-name => $self->privateName('action'), -value => 'upload'})->toHtml()."<br />";
	}
	if (scalar(@files)) {
		foreach my $file (@{$storage->getFiles}) {
			if ($self->get("deleteFileUrl")) {
				$uploadControl .= '<p style="display:inline;vertical-align:middle;"><a href="'.$self->get("deleteFileUrl").$file.'">'
				.'<img src="'.$self->session->icon->getBaseURL().'delete.gif" style="vertical-align:middle;border: 0px;" alt="x" /></a></p> ';
			}
			my $image = $storage->isImage($file) ? $storage->getThumbnailUrl($file) : $storage->getFileIconUrl($file);
			$uploadControl .= '<p style="display:inline;vertical-align:middle;"><a href="'.$storage->getUrl($file).'">'
       				.'<img src="'.$image.'" style="vertical-align:middle;border: 0px;" alt="'
				.$file.'" /> '.$file.'</a></p><br />';
		}
	}
        return $uploadControl;
}

1;
