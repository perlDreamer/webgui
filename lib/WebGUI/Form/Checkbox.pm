package WebGUI::Form::Checkbox;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2007 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

use strict;
use base 'WebGUI::Form::Control';

=head1 NAME

Package WebGUI::Form::Checkbox

=head1 DESCRIPTION

Creates a check box form field.

=head1 SEE ALSO

This is a subclass of WebGUI::Form::Control.

=head1 METHODS 

The following methods are specifically available from this class. Check the superclass for additional methods.

=cut

#-------------------------------------------------------------------

=head2 definition ( [ additionalTerms ] )

See the super class for additional details.

=head3 additionalTerms

The following additional parameters have been added via this sub class.

=head4 checked

Defaults to "0". Set to "1" if this field should be checked.

=head4 defaultValue

The value returned by this field if it is checked and no value is specified. Defaults to "1".

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
			defaultValue=>$i18n->get("943"),
			},
		checked=>{
			defaultValue=> 0
			},
		defaultValue=>{
			defaultValue=>1
			},
		profileEnabled=>{
			defaultValue=>0
			}
		});
        return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------

=head2 generateIdParameter ( )

A class method that returns a value to be used as the autogenerated ID for this field instance. Returns undef because this field type can have more than one with the same name, therefore autogenerated ID's aren't terribly useful.

=cut

sub generateIdParameter {
	return undef;
}

#-------------------------------------------------------------------

=head2 getValueFromPost ( [ value ] )

Retrieves a value from a form GET or POST and returns it. If the value comes back as undef, this method will return undef.

=head3 value

An optional value to process, instead of POST input.

=cut

sub getValueFromPost {
	my $self = shift;
	my $formValue = @_ ? shift : $self->session->form->param($self->get("name"));
	if (defined $formValue) {
		return $formValue;
	} else {
		return undef;
	}
}

#-------------------------------------------------------------------

=head2 toHtml ( )

Renders and input tag of type checkbox.

=cut

sub toHtml {
	my $self = shift;
	my $value = $self->fixMacros($self->fixQuotes($self->fixSpecialCharacters($self->get("value")))) || '';
	my $checkedText = $self->get("checked") ? ' checked="checked"' 			: '';
	my $idText 		= $self->get('id') 		? ' id="'.$self->get('id').'" ' : '';
	return '<input type="checkbox" name="'.($self->get("name")||'').'" value="'.$value.'"'.$idText.$checkedText.' '.($self->get("extras")||'').' />';
}


1;

