package WebGUI::Form::YesNo;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2005 Plain Black Corporation.
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
use WebGUI::Form::Radio;
use WebGUI::International;
use WebGUI::Session;

=head1 NAME

Package WebGUI::Form::yesNo

=head1 DESCRIPTION

Creates a yes/no question field.

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

=head4 defaultValue

Can be a 1 or 0. Defaults to 0 if no value is specified.

=cut

sub definition {
	my $class = shift;
	my $definition = shift || [];
	push(@{$definition}, {
		defaultValue=>{
			defaultValue=>0
			}
		});
	return $class->SUPER::definition($definition);
}


#-------------------------------------------------------------------

=head2 getName ()

Returns the human readable name or type of this form control.

=cut

sub getName {
        return WebGUI::International::get("482","WebGUI");
}


#-------------------------------------------------------------------

=head2 getValueFromPost ( )

Returns either a 1 or 0 representing yes, no. 

=cut

sub yesNo {
	my $self = shift;
        if ($session{req}->param($self->{name}) > 0) {
                return 1;
        }
	return 0;
}

#-------------------------------------------------------------------

=head2 toHtml ( )

Renders a yes/no question field.

=cut

sub toHtml {
	my $self = shift;
        my ($checkYes, $checkNo);
        if ($self->{value}) {
                $checkYes = 1;
        } else {
                $checkNo = 1;
        }
        my $output = WebGUI::Form::Radio->new(
                checked=>$checkYes,
                name=>$self->{name},
                value=>1,
                extras=>$self->{extras}
                )->toHtml;
        $output .= WebGUI::International::get(138);
        $output .= '&nbsp;&nbsp;&nbsp;';
        $output .= WebGUI::Form::Radio->new(
                checked=>$checkNo,
                name=>$self->{name},
                value=>0,
                extras=>$self->{extras}
                )->toHtml;
        $output .= WebGUI::International::get(139);
        return $output;
}


1;

