package WebGUI::Content::Shop;

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
use WebGUI::AdminConsole;
use WebGUI::Shop::AddressBook;
use WebGUI::Shop::Cart;
#use WebGUI::Shop::Pay;
use WebGUI::Shop::Ship;
use WebGUI::Shop::Tax;

=head1 NAME

Package WebGUI::Content::Shop

=head1 DESCRIPTION

A content handler that opens up all the commerce functionality.

=head1 SYNOPSIS

 use WebGUI::Content::Shop;
 my $output = WebGUI::Content::Shop::handler($session);

=head1 SUBROUTINES

These subroutines are available from this package:

=cut

#-------------------------------------------------------------------

=head2 handler ( session ) 

The content handler for this package.

=cut

sub handler {
    my ($session) = @_;
    my $output = undef;
    my $function = "www_".$session->form->get("shop");
    if ($function ne "www_" && (my $sub = __PACKAGE__->can($function))) {
        $output = $sub->($session);
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_address ()

Hand off to the address book.

=cut

sub www_address {
    my $session = shift;
    my $output = undef;
    my $method = "www_". ( $session->form->get("method") || "view");
    my $cart = WebGUI::Shop::AddressBook->create($session);
    if ($cart->can($method)) {
        $output = $cart->$method();
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_admin ()

Hand off to admin processor.

=cut

sub www_admin {
    my $session = shift;
    my $output = undef;
    my $method = "www_". ( $session->form->get("method") || "editSettings");
    my $admin = WebGUI::Shop::Admin->new($session);
    if ($admin->can($method)) {
        $output = $admin->$method();
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_cart ()

Hand off to the cart.

=cut

sub www_cart {
    my $session = shift;
    my $output = undef;
    my $method = "www_". ( $session->form->get("method") || "view");
    my $cart = WebGUI::Shop::Cart->create($session);
    if ($cart->can($method)) {
        $output = $cart->$method();
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_pay ()

Hand off to the payment gateway.

=cut

sub www_pay {
    my $session = shift;
    my $output = undef;
    my $method = "www_".$session->form->get("method");
    my $pay = WebGUI::Shop::Pay->new($session);
    if ($method ne "www_" && $pay->can($method)) {
        $output = $pay->$method();
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_ship ()

Hand off to the shipper.

=cut

sub www_ship {
    my $session = shift;
    my $output = undef;
    my $method = "www_".$session->form->get("method");
    my $ship = WebGUI::Shop::Ship->new($session);
    if ($method ne "www_" && $ship->can($method)) {
        $output = $ship->$method($session);
    }
    return $output;
}

#-------------------------------------------------------------------

=head2 www_tax ()

Hand off to the tax system.

=cut

sub www_tax {
    my $session = shift;
    my $output = undef;
    my $method = "www_".$session->form->get("method");
    my $tax = WebGUI::Shop::Tax->create($session);
    if ($method ne "www_" && $tax->can($method)) {
        $output = $tax->$method();
    }
    return $output;
}


1;

