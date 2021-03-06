package WebGUI::Flux::Operator::IsLessThanOrEqualTo;
use strict;

use base 'WebGUI::Flux::Operator';
use Scalar::Util qw(looks_like_number);

=head1 NAME

Package WebGUI::Flux::Operator::IsLessThanOrEqualTo

=head1 DESCRIPTION

Less than or equal to operator ('<=' for numbers, 'le' for strings).

See WebGUI::Flux::Operator base class for more information.

=cut

#-------------------------------------------------------------------

=head2 evaluate

See WebGUI::Flux::Operator base class for more information.

=cut

sub evaluate {
    my ($self) = @_;

    my $a = $self->operand1();
    my $b = $self->operand2();

    if ( looks_like_number($a) && looks_like_number($b) ) {
        return $a <= $b;
    }
    else {
        return $a && $b && $a le $b;
    }
}

1;
