package WebGUI::Commerce::ShoppingCart;

use strict;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Commerce::Item;
use WebGUI::Commerce::Payment;

=head1 NAME

Package WebGUI::Commerce::ShoppingCart

=head1 DESCRIPTION

This package implements a shopping cart for the E-Commerce system of WebGUI. This
shopping cart is tied to the sessionId and, thus, expires when the sessionId expires.

=head1 SYNOPSIS

$shoppingCart = WebGUI::Commerce::ShoppingCart->new;

$shoppingCart->add('myItemId', 'myItem', 3);
$shoppingCart->setQuantity('myItemId', 'myItem', 2);

$shoppingCart->delete('myItemId', 'myItem');		# These two lines are equivalent;
$shoppingCart->setQuantity('myItemId', 'myItem', 0);	#

$shoppingCart->empty;					# Remove contents from cart

($normal, $recurring) = $shoppingCart->getItems;
$normal->[0]->{quantity}	# quantity of first normal item
$recurring->[2]->{period}	# period of third recurring item
$normal->[0]->{item}->id	# the id of the first normal item

=head1 METHODS

This package provides the following methods:

=cut

#-------------------------------------------------------------------

=head2 add ( itemId, itemType, quantity )

This will add qunatity items of type itemType and with id itemId to the shopping cart.

=head3 itemId

The id of the item to add.

=head3 itemType

The type (namespace) of the item that's to be added to the cart.

=head3 quantity

The number of items to add. Defaults to 1 if quantity is not given.

=cut

sub add {
	my ($self, $itemId, $itemType, $quantity, $item);
	$self = shift;
	$itemId = shift;
	$itemType = shift;
	$quantity = shift || 1;

	$item = WebGUI::Commerce::Item->new($itemId, $itemType);
	return "" unless ($item->available);
	
	$self->{_items}{$itemId."_".$itemType} = {
		itemId		=> $itemId,
		itemType	=> $itemType,
		quantity	=> $self->{_items}{$itemId."_".$itemType}{quantity} + $quantity
		};
		
	$self->session->db->write("delete from shoppingCart where sessionId=".$self->session->db->quote($self->{_sessionId})." and itemId=".$self->session->db->quote($itemId)." and itemType=".$self->session->db->quote($itemType));
	$self->session->db->write("insert into shoppingCart ".
		"(sessionId, itemId, itemType, quantity) values ".
		"(".$self->session->db->quote($self->{_sessionId}).",".$self->session->db->quote($itemId).",".$self->session->db->quote($itemType).",".$self->{_items}{$itemId."_".$itemType}{quantity}.")");
}

#-------------------------------------------------------------------

=head2 delete ( itemId, itemType )

Deletes the item identified by the passed parameters from the cart.

=head3 itemId

The id of the item to delete.

=head3 itemType

the type (namespace) of the item to delete.

=cut

sub delete {
	my ($self, $itemId, $itemType);
	
	$self = shift;
	$itemId = shift;
	$itemType = shift;

	$self->session->db->write("delete from shoppingCart where sessionId=".$self->session->db->quote($self->{_sessionId}).
		" and itemId=".$self->session->db->quote($itemId)." and itemType=".$self->session->db->quote($itemType));
	
	delete $self->{_items}{$itemId."_".$itemType};
}

#-------------------------------------------------------------------

=head2 setQuantity ( itemId, itemType, quantity )

Sets the quantity of an item (identified by itemId and itemType) in the shopping 
cart. When quantity is set to zero or a negative number, the item will be deleted
from the cart.

This method only operates on items that are already in the cart. You cannot use it
to add new items to the cart. In order to that use the add method.

Generates a fatal error when the quantity is not a number.

=head3 itemId

The is of item you want to set the quantity for.

=head3 itemType

The type (namespace) of the item.

=head3 quantity

The quantity you want to set the item to.

=cut

sub setQuantity {
	my ($self, $itemId, $itemType, $quantity);
	$self = shift;
	$itemId = shift;
	$itemType = shift;
	$quantity = shift;

	$self->session->errorHandler->fatal('No quantity or quantity is not a number: ('.$quantity.')') unless ($quantity =~ /^-?\d+$/);

	return $self->delete($itemId, $itemType) if ($quantity <= 0);
	
	$self->{_items}{$itemId."_".$itemType}->{quantity} = $quantity;

	$self->session->db->write("update shoppingCart set quantity=".$self->session->db->quote($quantity).
		" where sessionId=".$self->session->db->quote($self->{_sessionId})." and itemId=".$self->session->db->quote($itemId)." and itemType=".$self->session->db->quote($itemType));
}

#-------------------------------------------------------------------

=head2 empty ( )

Invoking this method will purge all content from the shopping cart.

=cut

sub empty {
	my ($self);
	$self = shift;
	
	$self->session->db->write("delete from shoppingCart where sessionId=".$self->session->db->quote($self->{_sessionId}));
}

#-------------------------------------------------------------------

=head2 getItems ( )

This method will return two arrayrefs repectively containing the normal items and the recurring
items in the shoppingcart.

Items are returned as a hashref with the following properties:

=head3 quantity

The quantity of this item.

=head3 period

The duration of a billingperiod if this this is a recurring transaction.

=head3 name

The name of this item.

=head3 price

The price of a single item.

=head3 totalPrice

The total price of this item. Ie. totalPrice = quantity * price.

=head3 item

The instantiated plugin of this item. See WebGUI::Commerce::Item for a detailed API.

=cut

sub getItems {
	my ($self, $periodResolve, %cartContent, $item, $properties, @recurring, @normal);
	$self = shift;
	
	$periodResolve = WebGUI::Commerce::Payment::recurringPeriodValues;
	%cartContent = %{$self->{_items}};
	foreach (values(%cartContent)) {
		$item = WebGUI::Commerce::Item->new($_->{itemId}, $_->{itemType});
		$properties = {
			quantity        => $_->{quantity},
			period          => lc($periodResolve->{$item->duration}),
			name		=> $item->name,
			price		=> sprintf('%.2f', $item->price),
			totalPrice	=> sprintf('%.2f', $item->price * $_->{quantity}),
			item		=> $item,
			};

		if ($item->isRecurring) {
			push(@recurring, $properties);
		} else {
			push(@normal, $properties);
		}
	}
	
	return (\@normal, \@recurring);
}

#-------------------------------------------------------------------

=head2 new ( sessionId )

Returns a shopping cart object tied to session id sessionId or the current session.

=head3 sessionId

The session id this cart should be tied to. If omitted this will default to the session id 
of the current user.

=cut

sub new {
	my ($class, $sessionId, $sth, $row, %items);
	$class = shift;
	$sessionId = shift || $self->session->var->get("sessionId");

	$sth = $self->session->db->read("select * from shoppingCart where sessionId=".$self->session->db->quote($sessionId));
	while ($row = $sth->hashRef) {
		$items{$row->{itemId}."_".$row->{itemType}} = $row;
	}

	bless {_sessionId => $sessionId, _items => \%items}, $class;
}

1;
