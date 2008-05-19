package WebGUI::Shop::Transaction;

use strict;

use Class::InsideOut qw{ :std };
use JSON;
use WebGUI::Asset::Template;
use WebGUI::Exception::Shop;
use WebGUI::Form;
use WebGUI::International;
use WebGUI::Paginator;
use WebGUI::Shop::Admin;
use WebGUI::Shop::AddressBook;
use WebGUI::Shop::Credit;
use WebGUI::Shop::TransactionItem;

=head1 NAME

Package WebGUI::Shop::Transaction

=head1 DESCRIPTION

This package keeps records of every puchase made.

=head1 SYNOPSIS

 use WebGUI::Shop::Transaction;

 my $transaction = WebGUI::Shop::Transaction->new($session, $id);
 
 # typical transaction goes like this:
 my $transaction = WebGUI::Shop::Transaction->create({ cart=>$cart, paymentMethod=>$paymentMethod, paymentAddress=>$address});
 my ($transactionNumber, $status, $message) = $paymentMethod->tryTransaction;
 if ($status eq "somekindofsuccess") {
    $transaction->completePurchase($cart, $transactionNumber, $status, $message);
 }
 else {
    $transaction->denyPurchase($transactionNumber, $status, $message);
 }


=head1 METHODS

These subroutines are available from this package:

=cut

readonly session => my %session;
private properties => my %properties;

#-------------------------------------------------------------------

=head2 addItem ( cartitem )

Adds an item to the transaction. Returns a reference to the newly added item.

=head3 cartitem

A reference to a subclass of WebGUI::Shop::CartItem.

=cut

sub addItem {
    my ($self, $cartItem) = @_;
    my $item = WebGUI::Shop::TransactionItem->create( $self, $cartItem);
    return $item;
}

#-------------------------------------------------------------------

=head2 completePurchase ( transactionCode, statusCode, statusMessage )

See also denyPurchase(). Completes a purchase by updating the transaction as a success, and calling onCompletePurchase on all the skus in the transaction.

=head3 transactionCode

The transaction id or code given by the payment gateway.

=head3 statusCode

The status code that came back from the payment gateway when trying to process the payment.

=head3 statusMessage

The extended status message that came back from the payment gateway when trying to process the payment.

=cut

sub completePurchase {
    my ($self, $transactionCode, $statusCode, $statusMessage) = @_;
    if ($self->get('shopCreditDeduction') < 0) {
        WebGUI::Shop::Credit->new($self->session)->adjust($self->get('shopCreditDeduction'), "Paid for transaction ".$self->getId);        
    }
    foreach my $item (@{$self->getItems}) {
        $item->getSku->onCompletePurchase($item);
    }
    $self->update({
        transactionCode => $transactionCode,
        isSuccessful    => 1,
        statusCode      => $statusCode,
        statusMessage   => $statusMessage,
        });
}

#-------------------------------------------------------------------

=head2 create ( session, properties )

Constructor. Creates a new transaction object. Returns a reference to the object.

=head3 session

A reference to the current session.

=head3 properties

See update().

=cut

sub create {
    my ($class, $session, $properties) = @_;
    unless (defined $session && $session->isa("WebGUI::Session")) {
        WebGUI::Error::InvalidObject->throw(expected=>"WebGUI::Session", got=>(ref $session), error=>"Need a session.");
    }
    my $transactionId = $session->id->generate;
    $session->db->write('insert into transaction (transactionId, userId, username, dateOfPurchase) values (?,?,?,now())',
        [$transactionId, $session->user->userId, $session->user->username]);
    my $self = $class->new($session, $transactionId);
    $self->update($properties);
    return $self;
}

#-------------------------------------------------------------------

=head2 delete ()

Deletes this transaction and all transactionItems contained in it.

=cut

sub delete {
    my ($self) = @_;
    foreach my $item (@{$self->getItems}) {
        $item->delete;
    } 
    $self->session->db->write("delete from transaction where transactionId=?",[$self->getId]);
    undef $self;
    return undef;
}

#-------------------------------------------------------------------

=head2 denyPurchase ( transactionCode, statusCode, statusMessage )

Completes a purchase as a failure. It could be that the user didn't enter their credit cart correctly, or they may have insufficient funds.

=head3 transactionCode

The transaction id or code given by the payment gateway.

=head3 statusCode

The status code that came back from the payment gateway when trying to process the payment.

=head3 statusMessage

The extended status message that came back from the payment gateway when trying to process the payment.

=cut

sub denyPurchase {
    my ($self, $transactionCode, $statusCode, $statusMessage) = @_;
    $self->update({
        isSuccessful    => 0,
        transactionCode => $transactionCode,
        statusCode      => $statusCode,
        statusMessage   => $statusMessage
        });
}

#-------------------------------------------------------------------

=head2 formatAddress ( address )

Returns a formatted address.

=head3 address

A hash reference with the address properties.

=cut

sub formatAddress {
    my ($self, $address) = @_;
    my $formatted = $address->{name} . "<br />" . $address->{address1} . "<br />";
    $formatted .= $address->{address2} . "<br />" if ($address->{address2} ne "");
    $formatted .= $address->{address3} . "<br />" if ($address->{address3} ne "");
    $formatted .= $address->{city} . ", ";
    $formatted .= $address->{state} . " " if ($address->{state} ne "");
    $formatted .= $address->{code} if ($address->{code} ne "");
    $formatted .= '<br />' . $address->{country};
    $formatted .= '<br />' . $address->{phoneNumber};
    return $formatted;
}

#-------------------------------------------------------------------

=head2 formatCurrency ( amount )

Formats a number as a float with two digits after the decimal like 0.00.

=head3 amount

The number to format.

=cut

sub formatCurrency {
    my ($self, $amount) = @_;
    return sprintf("%.2f", $amount);
}

#-------------------------------------------------------------------

=head2 get ( [ property ] )

Returns a duplicated hash reference of this object�s data.

=head3 property

Any field ? returns the value of a field rather than the hash reference.

=cut

sub get {
    my ($self, $name) = @_;
    if (defined $name) {
        return $properties{id $self}{$name};
    }
    my %copyOfHashRef = %{$properties{id $self}};
    return \%copyOfHashRef;
}

#-------------------------------------------------------------------

=head2 getId ()

Returns the unique id for this transaction.

=cut

sub getId {
    my ($self) = @_;
    return $self->get("transactionId");
}

#-------------------------------------------------------------------

=head2 getItem ( itemId )

Returns a reference to a WebGUI::Shop::TransactionItem object.

=head3 itemId

The id of the item to retrieve.

=cut

sub getItem {
    my ($self, $itemId) = @_;
    return WebGUI::Shop::TransactionItem->new($self, $itemId);
}

#-------------------------------------------------------------------

=head2 getItems ( )

Returns an array reference of WebGUI::Shop::TransactionItem objects that are in the transaction.

=cut

sub getItems {
    my ($self) = @_;
    my @itemsObjects = ();
    my $items = $self->session->db->read("select itemId from transactionItem where transactionId=?",[$self->getId]);
    while (my ($itemId) = $items->array) {
        push(@itemsObjects, $self->getItem($itemId));
    }
    return \@itemsObjects;
}

#-------------------------------------------------------------------

=head2 new ( session, transactionId )

Constructor.  Instanciates a transaction based upon a transactionId.

=head3 session

A reference to the current session.

=head3 transactionId

The unique id of a transaction to instanciate.

=cut

sub new {
    my ($class, $session, $transactionId) = @_;
    unless (defined $session && $session->isa("WebGUI::Session")) {
        WebGUI::Error::InvalidObject->throw(expected=>"WebGUI::Session", got=>(ref $session), error=>"Need a session.");
    }
    unless (defined $transactionId) {
        WebGUI::Error::InvalidParam->throw(error=>"Need a transactionId.");
    }
    my $transaction = $session->db->quickHashRef('select * from transaction where transactionId=?', [$transactionId]);
    if ($transaction->{transactionId} eq "") {
        WebGUI::Error::ObjectNotFound->throw(error=>"No such transaction.", id=>$transactionId);
    }
    my $self = register $class;
    my $id        = id $self;
    $session{ $id }   = $session;
    $properties{ $id } = $transaction;
    return $self;
}

#-------------------------------------------------------------------

=head2 update ( properties )

Sets properties in the transaction.

=head3 properties

A hash reference that contains one of the following:

=head4 cart

A reference to a cart object. Will pull shipping method, shipping address, tax, items, and total from
it. Alternatively you can set manually any of the following properties that are set by cart automatically:
amount shippingAddressId shippingAddressName shippingAddress1 shippingAddress2 shippingAddress3 shippingCity
shippingState shippingCountry shippingCode shippingPhoneNumber shippingDriverId shippingDriverLabel shippingPrice
taxes shopCreditDeduction

You can also use the addItem() method to manually add items to the transaction rather than passing a cart full of items.

=head4 paymentAddress

A reference to a WebGUI::Shop::Address that contains the payment address. Alternatively you can set manually
any of the properties that are set by payment address automatically: paymentAddressId paymentAddressName
paymentAddress1 paymentAddress2 paymentAddress3 paymentCity paymentState paymentCountry paymentCode
paymentPhoneNumber 

=head4 paymentMethod

A reference to a WebGUI::Shop::PayDriver subclass that is used to make payment. Alternatively you can set
manually any of the properties that are set by payment method automatically: paymentDriverId paymentDriverLabel

=head4 isSuccessful

A boolean indicating whether the transaction was completed successfully.

=head4 transactionCode

The transaction id or code given by the payment gateway.

=head4 statusCode

The status code that came back from the payment gateway when trying to process the payment.

=head4 statusMessage

The extended status message that came back from the payment gateway when trying to process the payment.

=head4 isRecurring

A boolean indicating whether this is a recurring transaction or not. Defaults to 0.

=head4 originatingTransactionId

Most of the time this will be empty. But if this is a recurring transaction, then this will hold the id of the original transaction that started the recurrence.

=cut

sub update {
    my ($self, $newProperties) = @_;
    my $id = id $self;
    if (exists $newProperties->{cart}) {
        my $cart = $newProperties->{cart};
        $newProperties->{taxes} = $cart->calculateTaxes;
        my $address = $cart->getShippingAddress;
        $newProperties->{shippingAddressId} = $address->getId;
        $newProperties->{shippingAddressName} = $address->get('name');
        $newProperties->{shippingAddress1} = $address->get('address1');
        $newProperties->{shippingAddress2} = $address->get('address2');
        $newProperties->{shippingAddress3} = $address->get('address3');
        $newProperties->{shippingCity} = $address->get('city');
        $newProperties->{shippingState} = $address->get('state');
        $newProperties->{shippingCountry} = $address->get('country');
        $newProperties->{shippingCode} = $address->get('code');
        $newProperties->{shippingPhoneNumber} = $address->get('phoneNumber');
        my $shipper = $cart->getShipper;
        $newProperties->{shippingDriverId} = $shipper->getId;
        $newProperties->{shippingDriverLabel} = $shipper->get('label');
        $newProperties->{shippingPrice} = $shipper->calculate($cart);
        $newProperties->{amount} = $cart->calculateTotal + $newProperties->{shopCreditDeduction};
        $newProperties->{shopCreditDeduction} = $cart->calculateShopCreditDeduction($newProperties->{amount});
        $newProperties->{amount} += $newProperties->{shopCreditDeduction};
        foreach my $item (@{$cart->getItems}) {
            $self->addItem({item=>$item});
        }
    }
    if (exists $newProperties->{paymentAddress}) {
        my $address = $newProperties->{paymentAddress};
        $newProperties->{paymentAddressId} = $address->getId;
        $newProperties->{paymentAddressName} = $address->get('name');
        $newProperties->{paymentAddress1} = $address->get('address1');
        $newProperties->{paymentAddress2} = $address->get('address2');
        $newProperties->{paymentAddress3} = $address->get('address3');
        $newProperties->{paymentCity} = $address->get('city');
        $newProperties->{paymentState} = $address->get('state');
        $newProperties->{paymentCountry} = $address->get('country');
        $newProperties->{paymentCode} = $address->get('code');
        $newProperties->{paymentPhoneNumber} = $address->get('phoneNumber');
    }
    if (exists $newProperties->{paymentMethod}) {
        my $pay = $newProperties->{paymentMethod};
        $newProperties->{paymentDriverId} = $pay->getId;
        $newProperties->{paymentDriverLabel} = $pay->get('label');
    }
    my @fields = (qw( isSuccessful transactionCode statusCode statusMessage amount shippingAddressId
        shippingAddressName shippingAddress1 shippingAddress2 shippingAddress3 shippingCity shippingState
        shippingCountry shippingCode shippingPhoneNumber shippingDriverId shippingDriverLabel
        shippingPrice paymentAddressId paymentAddressName originatingTransactionId isRecurring
        paymentAddress1 paymentAddress2 paymentAddress3 paymentCity paymentState paymentCountry paymentCode
        paymentPhoneNumber paymentDriverId paymentDriverLabel taxes ));
    foreach my $field (@fields) {
        $properties{$id}{$field} = (exists $newProperties->{$field}) ? $newProperties->{$field} : $properties{$id}{$field};
    }
    $self->session->db->setRow("transaction","transactionId",$properties{$id});
}

#-------------------------------------------------------------------

=head2 www_getTransactionsAsJson ()

Retrieves a list of transactions for the www_manage() method.

=cut

sub www_getTransactionsAsJson {
    my ($class, $session) = @_;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient() unless $admin->canManage;
    my ($db, $form) = $session->quick(qw(db form));
    my $startIndex = $form->get('startIndex') || 0;
    my $numberOfResults = $form->get('results') || 25;
    my @placeholders = ();
    my $sql = 'select SQL_CALC_FOUND_ROWS orderNumber, transactionId, transactionCode, paymentDriverLabel,
        dateOfPurchase, username, amount, isSuccessful, statusCode, statusMessage
        from transaction';
    my $keywords = $form->get("keywords");
    if ($keywords ne "") {
        $db->buildSearchQuery(\$sql, \@placeholders, $keywords, [qw{amount username orderNumber shippingAddressName shippingAddress1 paymentAddressName paymentAddress1}])
    }
    push(@placeholders, $startIndex, $numberOfResults);
    $sql .= ' order by dateOfPurchase desc limit ?,?';
    my %results = ();
    my @records = ();
    my $sth = $db->read($sql, \@placeholders);
	while (my $record = $sth->hashRef) {
		push(@records,$record);
	}
    $results{'recordsReturned'} = $sth->rows()+0;
    $results{'totalRecords'} = $db->quickScalar('select found_rows()') + 0; ##Convert to numeric
    $results{'records'}      = \@records;
    $results{'startIndex'}   = $startIndex;
    $results{'sort'}         = undef;
    $results{'dir'}          = "desc";
    $session->http->setMimeType('text/json');
    return JSON->new->utf8->encode(\%results);
}

#-------------------------------------------------------------------

=head2 www_manage ()

Displays a list of all transactions in the system along with management tools for them. 

=cut

sub www_manage {
    my ($class, $session) = @_;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient() unless $admin->canManage;
    my $i18n = WebGUI::International->new($session, 'Shop');
    my ($style, $url) = $session->quick(qw(style url));
    
    # set up all the files that we need
    $style->setLink($url->extras('/yui/build/fonts/fonts-min.css'), {rel=>'stylesheet', type=>'text/css'});
    $style->setLink($url->extras('/yui/build/datatable/assets/skins/sam/datatable.css'), {rel=>'stylesheet', type=>'text/css'});
    $style->setScript($url->extras('/yui/build/utilities/utilities.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/json/json-min.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/datasource/datasource-beta-min.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/datatable/datatable-beta-min.js'), {type=>'text/javascript'});

    # draw the html markup that's needed
    $style->setRawHeadTags('<style type="text/css"> #paging a { color: #0000de; } #search form { display: inline; } </style>');
    my $output = q| 

<div class=" yui-skin-sam">
    <div id="search"><form id="keywordSearchForm"><input type="text" name="keywords" id="keywordsField" /><input type="submit" value="Search" /></form></div>
    <div id="paging"></div>
    <div id="dt"></div>
</div>

<script type="text/javascript">
YAHOO.util.Event.onDOMReady(function () {
    var DataSource = YAHOO.util.DataSource,
        Dom        = YAHOO.util.Dom,
        DataTable  = YAHOO.widget.DataTable,
        Paginator  = YAHOO.widget.Paginator;
    |;
    
    # the datasource deals with the stuff returned from www_getTransactionsAsJson
    $output .= "var mySource = new DataSource('".$url->page('shop=transaction;method=getTransactionsAsJson')."');";
    $output .= <<STOP;
    mySource.responseType   = DataSource.TYPE_JSON;
    mySource.responseSchema = {
        resultsList : 'records',
        totalRecords: 'totalRecords',
        fields      : [ 'transactionCode', 'orderNumber', 'paymentDriverLabel',
            'transactionId', 'dateOfPurchase', 'username', 'amount', 'isSuccessful', 'statusCode', 'statusMessage']
    };
STOP

    # paginator does the cool ajaxy pagination and makes the requests as needed
    $output .= <<STOP;
    var buildQueryString = function (state,dt) {
        return ";startIndex=" + state.pagination.recordOffset +
               ";keywords=" + Dom.get('keywordsField').value +
               ";results=" + state.pagination.rowsPerPage;
    };

    var myPaginator = new Paginator({
        containers         : ['paging'],
        pageLinks          : 5,
        rowsPerPage        : 25,
        rowsPerPageOptions : [10,25,50,100],
        template           : "<strong>{CurrentPageReport}</strong> {PreviousPageLink} {PageLinks} {NextPageLink} {RowsPerPageDropdown}"
    });
STOP

    # create the data table, and a special formatter for the view transaction urls
    $output .= <<STOP;
    var myTableConfig = {
        initialRequest         : ';startIndex=0',
        generateRequest        : buildQueryString,
        paginationEventHandler : DataTable.handleDataSourcePagination,
        paginator              : myPaginator
    };
    YAHOO.widget.DataTable.formatViewTransaction = function(elCell, oRecord, oColumn, orderNumber) {
STOP
	$output .= q{elCell.innerHTML = '<a href="}.$url->page(q{shop=transaction;method=view})
        .q{;transactionId=' + oRecord.getData('transactionId') + '">' + orderNumber + '</a>'; };
    $output .= '
        }; 
        var myColumnDefs = [
    ';
    $output .= '{key:"orderNumber", label:"'.$i18n->get('order number').'", formatter:YAHOO.widget.DataTable.formatViewTransaction},';
    $output .= '{key:"dateOfPurchase", label:"'.$i18n->get('date').'",formatter:YAHOO.widget.DataTable.formatDate},';
    $output .= '{key:"username", label:"'.$i18n->get('username').'"},';
    $output .= '{key:"amount", label:"'.$i18n->get('price').'",formatter:YAHOO.widget.DataTable.formatCurrency},';
    $output .= '{key:"statusCode", label:"'.$i18n->get('status code').'"},';
    $output .= '{key:"statusMessage", label:"'.$i18n->get('status message').'"},';
    $output .= '{key:"paymentDriverLabel", label:"'.$i18n->get('payment method').'"},';
    $output .= <<STOP;
    ];
    var myTable = new DataTable('dt', myColumnDefs, mySource, myTableConfig);
STOP

    # add the necessary event handler to the search button that sends the search request via ajax
    $output .= <<STOP;
    Dom.get('keywordSearchForm').onsubmit = function () {
         mySource.sendRequest(';keywords=' + Dom.get('keywordsField').value + ';startIndex=0', 
            myTable.onDataReturnInitializeTable, myTable);
        return false;
    };

});
</script>
STOP
    # render everything to a web page
    return $admin->getAdminConsole->render($output, $i18n->get('transactions'));
}


#-------------------------------------------------------------------

=head2 www_print ()

Makes transaction information printable.

=cut

sub www_print {
    my ($class, $session) = @_;
    $class->www_view($session, 1);
}

#-------------------------------------------------------------------

=head2 www_thankYou ()

Displays the default thank you page.

=cut

sub www_thankYou {
    my ($class, $session) = @_;
    return q{Thanks for your order. Need to template this.};
}

#-------------------------------------------------------------------

=head2 www_view ()

Displays the admin view of an individual transaction.

=cut

sub www_view {
    my ($class, $session, $print) = @_;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient() unless $admin->canManage;
    my $i18n = WebGUI::International->new($session, 'Shop');
    my ($style, $url) = $session->quick(qw(style url));
    my $transaction = $class->new($session, $session->form->get('transactionId'));
    
    # set up all the files that we need
    $style->setLink($url->extras('/yui/build/fonts/fonts-min.css'), {rel=>'stylesheet', type=>'text/css'});
    $style->setLink($url->extras('/yui/build/datatable/assets/skins/sam/datatable.css'), {rel=>'stylesheet', type=>'text/css'});
    $style->setScript($url->extras('/yui/build/utilities/utilities.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/json/json-min.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/datasource/datasource-beta-min.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('/yui/build/datatable/datatable-beta-min.js'), {type=>'text/javascript'});

    #render page
    my $output = q{
        <style type="text/css">
            #transactionDetail th { vertical-align: top; margin-right: 10px; border-right: 1px solid #eeeeee; text-align: left;}
            .smallAddress { font-size: 60%; }
        </style>};
    unless ($print) {
        $output .= q{   
            <div><a href="}.$url->page('shop=transaction;method=print;transactionId='.$transaction->getId).q{">}.$i18n->get('print').q{</a></div>
            };
    }
    $output .= q{   
        <table id="transactionDetail">
            <tr>
                <th>}. $i18n->get("transaction id") .q{</th><td>}. $transaction->getId .q{</td>
            </tr>
            <tr>
                <th>}. $i18n->get("order number") .q{</th><td>}. $transaction->get('orderNumber') .q{</td>
            </tr>
            <tr>
                <th>}. $i18n->get("shipping address") .q{</th><td>}. $transaction->formatAddress({
                        name        => $transaction->get('shippingAddressName'),
                        address1    => $transaction->get('shippingAddress1'),
                        address2    => $transaction->get('shippingAddress2'),
                        address3    => $transaction->get('shippingAddress3'),
                        city        => $transaction->get('shippingCity'),
                        state       => $transaction->get('shippingState'),
                        code        => $transaction->get('shippingCode'),
                        country     => $transaction->get('shippingCountry'),
                        phoneNumber => $transaction->get('shippingPhoneNumber'),
                        }) .q{</td>
            </tr>
            <tr>
                <th>}. $i18n->get("payment address") .q{</th><td>}. $transaction->formatAddress({
                        name        => $transaction->get('paymentAddressName'),
                        address1    => $transaction->get('paymentAddress1'),
                        address2    => $transaction->get('paymentAddress2'),
                        address3    => $transaction->get('paymentAddress3'),
                        city        => $transaction->get('paymentCity'),
                        state       => $transaction->get('paymentState'),
                        code        => $transaction->get('paymentCode'),
                        country     => $transaction->get('paymentCountry'),
                        phoneNumber => $transaction->get('paymentPhoneNumber'),
                        }) .q{</td>
            </tr>
            <tr>
                <th>}. $i18n->get("price") .q{</th><td>}. sprintf("%.2f", $transaction->get('amount')) .q{</td>
            </tr>
        </table>
    };
    
    # item detail
    $output .= q{
       <div id="transactionItemWrapper" class=" yui-skin-sam"> <table id="transactionItems">
        <thead>
            <tr>
            <th>Item</th>
            <th>Price</th>
            <th>Quantity</th>
            <th>Status</th>
            <th>Address</th>
            <th>Date</th>
            <th>Tracking #</th>
            </tr>
        </thead>
        <tbody>
    };
    foreach my $item (@{$transaction->getItems}) {
        my $sku = $item->getSku;
        $output .= q{
            <tr>
            <td><a href="}.$sku->getUrl('shop=transaction;method=viewItem;transactionId='.$transaction->getId.';itemId='.$item->getId).q{">}.$item->get('configuredTitle').q{</a></td>
            <td>}.$transaction->formatCurrency($item->get('price')).q{</td>
            <td>}.$item->get('quantity').q{</td>
            <td>}.$item->get('shippingStatus').q{</td>
        };
        if ($item->get('shippingAddressId') eq $transaction->get('shippingAddressId')) {
            $output .= q{<td></td>};
        }
        else {
            $output .= q{
                <td class="smallAddress">}. $transaction->formatAddress({
                            name        => $item->get('shippingAddressName'),
                            address1    => $item->get('shippingAddress1'),
                            address2    => $item->get('shippingAddress2'),
                            address3    => $item->get('shippingAddress3'),
                            city        => $item->get('shippingCity'),
                            state       => $item->get('shippingState'),
                            code        => $item->get('shippingCode'),
                            country     => $item->get('shippingCountry'),
                            phoneNumber => $item->get('shippingPhoneNumber'),
                            }) .q{</td>
            };
        }
        $output .= q{
            <td>}.$item->get('shippingDate').q{</td>
            <td>}.$item->get('shippingTrackingNumber').q{</td>
            </tr>  
        };
    }
    $output .= q{
        </tbody>
        </table></div>
    };
    
    # render data table
    $output .= <<STOP;
    <script type="text/javascript">
    YAHOO.util.Event.addListener(window, "load", function() {
    YAHOO.example.EnhanceFromMarkup = new function() {
        var myColumnDefs = [
            {key:"item",sortable:true},
            {key:"price",sortable:true},
            {key:"quantity",formatter:YAHOO.widget.DataTable.formatNumber,sortable:true},
            {key:"status",sortable:true},
            {key:"address"},
            {key:"date",sortable:true,formatter:YAHOO.widget.DataTable.formatDate},
            {key:"tracking"}
        ];


        this.myDataSource = new YAHOO.util.DataSource(YAHOO.util.Dom.get("transactionItems"));
        this.myDataSource.responseType = YAHOO.util.DataSource.TYPE_HTMLTABLE;
        this.myDataSource.responseSchema = {
            fields: [
                    {key:"item"},
                    {key:"price", parser:this.parseNumberFromCurrency},
                    {key:"quantity", parser:YAHOO.util.DataSource.parseNumber},
                    {key:"status"},
                    {key:"address"},
                    {key:"date", parser:YAHOO.util.DataSource.parseDate},
                    {key:"tracking"}
            ]
        };

        this.myDataTable = new YAHOO.widget.DataTable("transactionItemWrapper", myColumnDefs, this.myDataSource,{});
    };
});
</script>
STOP

    # send output
    if ($print) {
        return $output;   
    }
    return $admin->getAdminConsole->render($output, $i18n->get('transactions'));
}

1;
