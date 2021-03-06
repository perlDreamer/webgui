package WebGUI::Shop::Tax;

use strict;

use Class::InsideOut qw{ :std };
use WebGUI::Text;
use WebGUI::Storage;
use WebGUI::Exception::Shop;
use WebGUI::Shop::Admin;
use WebGUI::Shop::Cart;
use WebGUI::Shop::CartItem;
use List::Util qw{sum};

=head1 NAME

Package WebGUI::Shop::Tax

=head1 DESCRIPTION

This package manages tax information, and calculates taxes on a shopping cart.  It isn't a classic object
in that the only data it contains is a WebGUI::Session object, but it does provide several methods for
handling the information in the tax tables.

Taxes are accumulated through increasingly specific geographic information.  For example, you can
specify the sales tax for a whole country, then the additional sales tax for a state in the country,
all the way down to a single code inside of a city.

=head1 SYNOPSIS

 use WebGUI::Shop::Tax;

 my $tax = WebGUI::Shop::Tax->new($session);

=head1 METHODS

These subroutines are available from this package:

=cut

readonly session => my %session;

#-------------------------------------------------------------------

=head2 add ( [$params] )

Add tax information to the table.  Returns the taxId of the newly created tax information.  

=head3 $params

A hash ref of the geographic and rate information.  The country and taxRate parameters
must have defined values.

=head4 country

The country this tax information applies to.

=head4 state

The state this tax information applies to.  state and country together are unique.

=head4 city

The ciy this tax information applies to.  Cities are unique with state and country information.

=head4 code

The postal code this tax information applies to.  codes are unique with state and country information.

=head4 taxRate

This is the tax rate for the location, as specified by the geographical
fields country, state, city and/or code.  The tax rate is stored as
a percentage, like 5.5 .

=cut

sub add {
    my $self   = shift;
    my $params = shift;

    WebGUI::Error::InvalidParam->throw(error => 'Must pass in a hashref of params')
        unless ref($params) eq 'HASH';
    WebGUI::Error::InvalidParam->throw(error => "Missing required information.", param => 'country')
        unless exists($params->{country}) and $params->{country};
    WebGUI::Error::InvalidParam->throw(error => "Missing required information.", param => 'taxRate')
        unless exists($params->{taxRate}) and defined $params->{taxRate};

    $params->{taxId} = 'new';
    my $id = $self->session->db->setRow('tax', 'taxId', $params);
    return $id;
}

#-------------------------------------------------------------------

=head2 calculate ( $cart )

Calculate the tax for the contents of the cart.  The tax rate is calculated off
of the shipping address stored in the cart.  If an item in the cart has an alternate
address, that is used instead.  Finally, if the item in the cart has a Sku with a tax
rate override, that rate overrides all. Returns 0 if no shipping address has been attached to the cart yet.

=cut

sub calculate {
    my $self = shift;
    my $cart = shift;
    WebGUI::Error::InvalidParam->throw(error => 'Must pass in a WebGUI::Shop::Cart object')
        unless ref($cart) eq 'WebGUI::Shop::Cart';
    my $book = $cart->getAddressBook;
    return 0 if $cart->get('shippingAddressId') eq "";
    my $address = $book->getAddress($cart->get('shippingAddressId'));
    my $tax = 0;
    ##Fetch the tax data for the cart address so it doesn't have to look it up for every item
    ##in the cart with that address.
    my $cartTaxables = $self->getTaxRates($address);
    foreach my $item (@{ $cart->getItems }) {
        my $sku = $item->getSku;
        my $unitPrice = $sku->getPrice;
        my $quantity  = $item->get('quantity');
        ##Check for an item specific shipping address
        my $taxables;
        if (defined $item->get('shippingAddressId')) {
            my $itemAddress = $book->getAddress($item->get('shippingAddressId'));
            $taxables = $self->getTaxRates($itemAddress);
        }
        else {
            $taxables = $cartTaxables;
        }
        ##Check for a SKU specific tax override rate
        my $skuTaxRate = $sku->getTaxRate();
        my $itemTax;
        if (defined $skuTaxRate) {
            $itemTax = $skuTaxRate;
        }
        else {
            $itemTax = sum(@{$taxables});
        }
        $itemTax /= 100;
        $tax += $unitPrice * $quantity * $itemTax;
    }
    return $tax;
}

#-------------------------------------------------------------------

=head2 delete ( [$params] )

Deletes data from the tax table by taxId.

=head3 $params

A hashref containing the taxId of the data to delete from the table.

=head4 taxId

The taxId of the data to delete from the table.

=cut

sub delete {
    my $self   = shift;
    my $params = shift;
    WebGUI::Error::InvalidParam->throw(error => 'Must pass in a hashref of params')
        unless ref($params) eq 'HASH';
    WebGUI::Error::InvalidParam->throw(error => "Hash ref must contain a taxId key with a defined value")
        unless exists($params->{taxId}) and defined $params->{taxId};
    $self->session->db->write('delete from tax where taxId=?', [$params->{taxId}]);
    return;
}

#-------------------------------------------------------------------

=head2 exportTaxData ( )

Creates a tab deliniated file containing all the information from
the tax table.  Returns a temporary WebGUI::Storage object containing
the file.  The file will be named "siteTaxData.csv".

=cut

sub exportTaxData {
    my $self = shift;
    my $taxIterator = $self->getItems;
    my @columns = grep { $_ ne 'taxId' } $taxIterator->getColumnNames;
    my $taxData = WebGUI::Text::joinCSV(@columns) . "\n";
    while (my $taxRow = $taxIterator->hashRef() ) {
        my @taxData = @{ $taxRow }{@columns};
        foreach my $column (@taxData) {
            $column =~ tr/,/|/;  ##Convert to the alternation syntax for the text file
        }
        $taxData .= WebGUI::Text::joinCSV(@taxData) . "\n";
    }
    my $storage = WebGUI::Storage->createTemp($self->session);
    $storage->addFileFromScalar('siteTaxData.csv', $taxData);
    return $storage;
}

#-------------------------------------------------------------------

=head2 getAllItems ( )

Returns an arrayref of hashrefs, where each hashref is the data for one row of
tax data.  taxId is dropped from the dataset.

=cut

sub getAllItems {
    my $self = shift;
    my $taxes = $self->session->db->buildArrayRefOfHashRefs('select country,state,city,code,taxRate from tax order by country, state');
    return $taxes;
}

#-------------------------------------------------------------------

=head2 getItems ( )

Returns a WebGUI::SQL::Result object for accessing all of the data in the tax table.  This
is a convenience method for listing and/or exporting tax data.

=cut

sub getItems {
    my $self = shift;
    my $result = $self->session->db->read('select * from tax order by country, state');
    return $result;
}

#-------------------------------------------------------------------

=head2 getTaxRates ( $address )

Given a WebGUI::Shop::Address object, return all rates associated with the address as an arrayRef.

=cut

sub getTaxRates {
    my $self = shift;
    my $address = shift;
    WebGUI::Error::InvalidObject->throw(error => 'Need an address.', expected=>'WebGUI::Shop::Address', got=>(ref $address))
        unless ref($address) eq 'WebGUI::Shop::Address';
    my $country = $address->get('country');
    my $state   = $address->get('state');
    my $city    = $address->get('city');
    my $code    = $address->get('code');
    my $result = $self->session->db->buildArrayRef(
    q{
        select taxRate from tax where find_in_set(?, country)
        and (state='' or find_in_set(?, state))
        and (city=''  or find_in_set(?, city))
        and (code=''  or find_in_set(?, code))
    },
    [ $country, $state, $city, $code, ]);
    return $result;
}

#-------------------------------------------------------------------

=head2 importTaxData ( $filePath )

Import tax information from the specified file in CSV format.  The
first line of the file should contain only the name of the columns, in
any order.  It may not contain any comments.

These are the column names, each is required:

=over 4

=item *

country

=item *

state

=item *

city

=item *

code

=item *

taxRate

=back

The following lines will contain tax information.  Blank
lines and anything following a '#' sign will be ignored from
the second line of the file, on to the end.

Returns 1 if the import has taken place.  This is to help you know
if old data has been deleted and new has been inserted.  If an error is
detected, it will throw exceptions.

=head3 $filePath

The path to a file with data to import into the Product system.

=cut

sub importTaxData {
    my $self     = shift;
    my $filePath = shift;
    WebGUI::Error::InvalidParam->throw(error => q{Must provide the path to a file})
        unless $filePath;
    WebGUI::Error::InvalidFile->throw(error => qq{File could not be found}, brokenFile => $filePath)
        unless -e $filePath;
    WebGUI::Error::InvalidFile->throw(error => qq{File is not readable}, brokenFile => $filePath)
        unless -r $filePath;
    open my $table, '<', $filePath or
        WebGUI::Error->throw(error => qq{Unable to open $filePath for reading: $!\n});
    my $headers;
    $headers = <$table>;
    chomp $headers;
    my @headers = WebGUI::Text::splitCSV($headers);
    WebGUI::Error::InvalidFile->throw(error => qq{Bad header found in the CSV file}, brokenFile => $filePath)
        unless (join(q{-}, sort @headers) eq 'city-code-country-state-taxRate')
           and (scalar @headers == 5);
    my @taxData = ();
    my $line = 1;
    while (my $taxRow = <$table>) {
        chomp $taxRow;
        $taxRow =~ s/\s*#.+$//;
        next unless $taxRow;
        local $_;
        my @taxRow = map { tr/|/,/; $_; } WebGUI::Text::splitCSV($taxRow);
        WebGUI::Error::InvalidFile->throw(error => qq{Error found in the CSV file}, brokenFile => $filePath, brokenLine => $line)
            unless scalar @taxRow == 5;
        push @taxData, [ @taxRow ];
    }
    ##Okay, if we got this far, then the data looks fine.
    return unless scalar @taxData;
    $self->session->db->beginTransaction;
    $self->session->db->write('delete from tax');
    foreach my $taxRow (@taxData) {
        my %taxRow;
        @taxRow{ @headers } = @{ $taxRow }; ##Must correspond 1:1, or else...
        $self->add(\%taxRow);
    }
    $self->session->db->commit;
    return 1;
}

#-------------------------------------------------------------------

=head2 new ( $session )

Constructor for the WebGUI::Shop::Tax.  Returns a WebGUI::Shop::Tax object.

=cut

sub new {
    my $class   = shift;
    my $session = shift;
    my $self    = {};
    bless $self, $class;
    register $self;
    $session{ id $self } = $session;
    return $self;
}

#-------------------------------------------------------------------

=head2 session (  )

Accessor for the session object.  Returns the session object.

=cut

#-------------------------------------------------------------------

=head2 www_deleteTax (  )

Delete a row of tax information, using the form variable taxId as
the id of the row to delete.

=cut

sub www_deleteTax {
    my $self = shift;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    my $taxId = $session->form->get('taxId');
    $self->delete({ taxId => $taxId });
    return $self->www_manage;
}

#-------------------------------------------------------------------

=head2 www_addTax (  )

Add new tax information into the database, via the UI.

=cut

sub www_addTax {
    my $self    = shift;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    my $params;
    my ($form)    = $session->quick('form');
    $params->{country} = $form->get('country', 'text');
    $params->{state}   = $form->get('state',   'text');
    $params->{city}    = $form->get('city',    'text');
    $params->{code}    = $form->get('code',    'text');
    $params->{taxRate} = $form->get('taxRate', 'float');
    $self->add($params);
    return $self->www_manage;
}

#-------------------------------------------------------------------

=head2 www_exportTax (  )

Export the entire tax table as a CSV file the user can download.

=cut

sub www_exportTax {
    my $self = shift;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    my $storage = $self->exportTaxData();
    $self->session->http->setRedirect($storage->getUrl($storage->getFiles->[0]));
    return "redirect";
}

#-------------------------------------------------------------------

=head2 www_getTaxesAsJson (  )

Servers side pagination for tax data that is sent as JSON back to the browser to be
displayed in a YUI DataTable.

=cut

sub www_getTaxesAsJson {
    my ($self) = @_;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    my ($db, $form) = $session->quick(qw(db form));
    my $startIndex      = $form->get('startIndex') || 0;
    my $numberOfResults = $form->get('results')    || 25;
    my %goodKeys = qw/country 1 state 1 city 1 code 1 'tax rate' 1/;
    my $sortKey = $form->get('sortKey');
    $sortKey = $goodKeys{$sortKey} == 1 ? $sortKey : 'country';
    my $sortDir = $form->get('sortDir');
    $sortDir = lc($sortDir) eq 'desc' ? 'desc' : 'asc';
    my @placeholders = ();
    my $sql = 'select SQL_CALC_FOUND_ROWS * from tax';
    my $keywords = $form->get("keywords");
    if ($keywords ne "") {
        $db->buildSearchQuery(\$sql, \@placeholders, $keywords, [qw{country state city code}])
    }
    push(@placeholders, $startIndex, $numberOfResults);
    $sql .= sprintf (" order by %s limit ?,?","$sortKey $sortDir");
    my %results = ();
    my @records = ();
    my $sth = $db->read($sql, \@placeholders);
	while (my $record = $sth->hashRef) {
		push(@records,$record);
	}
    $results{'recordsReturned'} = $sth->rows()+0;
	$sth->finish;
    $results{'records'}      = \@records;
    $results{'totalRecords'} = $db->quickScalar('select found_rows()')+0; ##Convert to numeric
    $results{'startIndex'}   = $startIndex;
    $results{'sort'}         = undef;
    $results{'dir'}          = $sortDir;
    $session->http->setMimeType('application/json');
    return JSON::to_json(\%results);
}

#-------------------------------------------------------------------

=head2 www_importTax (  )

Import new tax data from a file provided by the user.  This will replace the current
data with the new data.

=cut

sub www_importTax {
    my $self = shift;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    my $storage = WebGUI::Storage->create($session);
    my $taxFile = $storage->addFileFromFormPost('importFile', 1);
    eval {
        $self->importTaxData($storage->getPath($taxFile)) if $taxFile;
    };
    my ($exception, $status_message);
    if ($exception = Exception::Class->caught('WebGUI::Error::InvalidFile')) {
        $status_message = sprintf 'A problem was found with your file: %s',
            $exception->error;
        if ($exception->brokenLine) {
            $status_message .= sprintf ' on line %d', $exception->brokenLine;
        }
    }
    elsif ($exception = Exception::Class->caught()) {
        $status_message = sprintf 'A problem happened during the import: %s', $exception->error;
    }
    return $self->www_manage($status_message);
}

#-------------------------------------------------------------------

=head2 www_manage ( $status_message )

User interface to manage taxes.  Provides a list of current taxes, and forms for adding
new tax info, exporting and importing sets of taxes, and deleting individual tax data.

=head3 $status_message

A message to display to the user.  This is usually a problem that was found during
import.

=cut

sub www_manage {
    my $self           = shift;
    my $status_message = shift;
    my $session = $self->session;
    my $admin = WebGUI::Shop::Admin->new($session);
    return $session->privilege->insufficient
        unless $admin->canManage;
    ##YUI specific datatable CSS
    my ($style, $url) = $session->quick(qw(style url));
    $style->setLink($url->extras('/yui/build/fonts/fonts-min.css'), {rel=>'stylesheet', type=>'text/css'});
    $style->setLink($url->extras('yui/build/datatable/assets/skins/sam/datatable.css'), {rel=>'stylesheet', type => 'text/CSS'});
    $style->setLink($url->extras('yui/build/paginator/assets/skins/sam/paginator.css'), {rel=>'stylesheet', type => 'text/CSS'});
    $style->setScript($url->extras('/yui/build/utilities/utilities.js'), {type=>'text/javascript'});
    $style->setScript($url->extras('yui/build/json/json-min.js'), {type => 'text/javascript'});
    $style->setScript($url->extras('yui/build/paginator/paginator-min.js'), {type => 'text/javascript'});
    $style->setScript($url->extras('yui/build/datasource/datasource-min.js'), {type => 'text/javascript'});
    ##YUI Datatable
    $style->setScript($url->extras('yui/build/datatable/datatable-min.js'), {type => 'text/javascript'});
    ##Default CSS
    $style->setRawHeadTags('<style type="text/css"> #paging a { color: #0000de; } #search, #export form { display: inline; } </style>');
    my $i18n=WebGUI::International->new($session, 'Tax');

    my $exportForm = WebGUI::Form::formHeader($session,{action => $url->page('shop=tax;method=exportTax')})
                   . WebGUI::Form::submit($session,{value=>$i18n->get('export tax','Shop'), extras=>q{style="float: left;"} })
                   . WebGUI::Form::formFooter($session);
    my $importForm = WebGUI::Form::formHeader($session,{action => $url->page('shop=tax;method=importTax')})
                   . WebGUI::Form::submit($session,{value=>$i18n->get('import tax','Shop'), extras=>q{style="float: left;"} })
                   . q{<input type="file" name="importFile" size="10" />}
                   . WebGUI::Form::formFooter($session);

    my $addForm = WebGUI::HTMLForm->new($session,action=>$url->page('shop=tax;method=addTax'));
    $addForm->text(
        label     => $i18n->get('country'),
        hoverHelp => $i18n->get('country help'),
        name      => 'country',
    );
    $addForm->text(
        label     => $i18n->get('state'),
        hoverHelp => $i18n->get('state help'),
        name      => 'state',
    );
    $addForm->text(
        label     => $i18n->get('city'),
        hoverHelp => $i18n->get('city help'),
        name      => 'city',
    );
    $addForm->text(
        label     => $i18n->get('code'),
        hoverHelp => $i18n->get('code help'),
        name      => 'code',
    );
    $addForm->float(
        label     => $i18n->get('tax rate'),
        hoverHelp => $i18n->get('tax rate help'),
        name      => 'taxRate',
    );
    $addForm->submit(
        value => $i18n->get('add a tax'),
    );
    my $output;
    if ($status_message) {
        $output = <<EOSM;
<div class="error">
$status_message
</div>
EOSM
    }
    
    $output .= q|
    
    
  <div class="yui-skin-sam">  
    <div id="search"><form id="keywordSearchForm"><input type="text" name="keywords" id="keywordsField" /><input type="submit" value="|.$i18n->get(364, 'WebGUI').q|" /></form></div>
    <div id="dynamicdata"></div>
    <div id="adding">|.$addForm->print.q|</div>
    <div id="importExport">|.$exportForm.$importForm.q|</div>
  </div>

<script type="text/javascript">
var taxtable = function() {
    // Column definitions
    formatDeleteTaxId = function(elCell, oRecord, oColumn, orderNumber) {
        elCell.innerHTML = '<a href="|.$url->page(q{shop=tax;method=deleteTax}).q|;taxId='+oRecord.getData('taxId')+'">|.$i18n->get('delete').q|</a>';
    };
    var myColumnDefs = [ // sortable:true enables sorting
        {key:"country", label:"|.$i18n->get('country').q|", sortable: true},
        {key:"state",   label:"|.$i18n->get('state').q|", sortable: true},
        {key:"city",    label:"|.$i18n->get('city').q|", sortable: true},
        {key:"code",    label:"|.$i18n->get('code').q|", sortable: true},
        {key:"taxRate", label:"|.$i18n->get('tax rate').q|"},
        {key:"taxId",   label:"", formatter:formatDeleteTaxId}
    ];
    
    // DataSource instance
    var myDataSource = new YAHOO.util.DataSource("|.$url->page('shop=tax;method=getTaxesAsJson;').q|");
    myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
    myDataSource.responseSchema = {
        resultsList: "records",
        fields: [
            {key:"country", parser:"string"},
            {key:"state",   parser:"string"},
            {key:"city",    parser:"string"},
            {key:"code",    parser:"string"},
            {key:"taxRate", parser:"number"},
            {key:"taxId",   parser:"string"}
        ],
        metaFields: {
            totalRecords: "totalRecords" // Access to value in the server response
        }
    };
    
    // DataTable configuration
    var myConfigs = {
        initialRequest: 'startIndex=0;results=25', // Initial request for first page of data
        dynamicData: true, // Enables dynamic server-driven data
        sortedBy : {key:"country", dir:YAHOO.widget.DataTable.CLASS_ASC}, // Sets UI initial sort arrow
        paginator: new YAHOO.widget.Paginator({ rowsPerPage:25 }) // Enables pagination 
    };
    
    // DataTable instance
    var myDataTable = new YAHOO.widget.DataTable("dynamicdata", myColumnDefs, myDataSource, myConfigs);
    // Update totalRecords on the fly with value from server to allow pagination
    myDataTable.handleDataReturnPayload = function(oRequest, oResponse, oPayload) {
        oPayload.totalRecords = oResponse.meta.totalRecords;
        return oPayload;
    }

    //Setup the form to submit an AJAX request back to the site.
    YAHOO.util.Dom.get('keywordSearchForm').onsubmit = function () {
        var state = myDataTable.getState();
        state.pagination.recordOffset = 0;
        myDataSource.sendRequest('keywords=' + YAHOO.util.Dom.get('keywordsField').value + ';startIndex=0;results=25', {success: myDataTable.onDataReturnInitializeTable, scope:myDataTable, argument:state});  
        return false;
    };        
    
    return {
        ds: myDataSource,
        dt: myDataTable
    };


}();


</script>

|;
    
    return $admin->getAdminConsole->render($output, $i18n->get('taxes', 'Shop'));
}

1;
