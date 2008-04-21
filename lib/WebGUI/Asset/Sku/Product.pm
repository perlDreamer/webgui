package WebGUI::Asset::Sku::Product;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use Tie::IxHash;
use WebGUI::Cache;
use WebGUI::HTMLForm;
use WebGUI::Storage::Image;
use WebGUI::SQL;
use WebGUI::Utility;
use JSON;

use base 'WebGUI::Asset::Sku';

#-------------------------------------------------------------------
sub _duplicateFile {
    my $self = shift;
    my $newAsset = $_[0];
    my $column = $_[1];
    if($self->get($column)){
        my $file = WebGUI::Storage->get($self->session,$self->get($column));
        my $newstore = $file->copy;
        $newAsset->update({ $column=>$newstore->getId });
    }
}

#-------------------------------------------------------------------

=head2 addRevision

Override the default method in order to deal with attachments.

=cut

sub addRevision {
    my $self = shift;
    my $newSelf = $self->SUPER::addRevision(@_);
    if ($newSelf->getRevisionCount > 1) {
        foreach my $field (qw(image1 image2 image3 brochure manual warranty)) {
            if ($self->get($field)) {
                my $newStorage = WebGUI::Storage->get($self->session,$self->get($field))->copy;
                $newSelf->update({$field=>$newStorage->getId});
            }
        }
    }
    return $newSelf;
}

#-------------------------------------------------------------------
sub definition {
    my $class = shift;
    my $session = shift;
    my $definition = shift;
    my $i18n = WebGUI::International->new($session,"Asset_Product");
    my %properties;
    tie %properties, 'Tie::IxHash';
    %properties = (
            cacheTimeout => {
                tab => "display",
                fieldType => "interval",
                defaultValue => 3600,
                uiLevel => 8,
                label => $i18n->get("cache timeout"),
                hoverHelp => $i18n->get("cache timeout help")
                },
            templateId =>{
                fieldType=>"template",
                tab => "display",
                      namespace=>"Product",
                label=>$i18n->get(62),
                hoverHelp=>$i18n->get('62 description'),
                defaultValue=>'PBtmpl0000000000000056'
            },
            price=>{
                label=>$i18n->get(10),
                hoverHelp=>$i18n->get('10 description'),
                tab => "shop",
                fieldType=>"text",
                defaultValue=>undef
            },
            image1=>{
                tab => "properties",
                fieldType=>"image",
                defaultValue=>undef,
                maxAttachments=>1,
                label=>$i18n->get(7),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=image1;filename=")
            },
            image2=>{
                tab => "properties",
                fieldType=>"image",
                maxAttachments=>1,
                label=>$i18n->get(8),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=image2;filename="),
                defaultValue=>undef
            },
            image3=>{
                tab => "properties",
                fieldType=>"image",
                maxAttachments=>1,
                label=>$i18n->get(9),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=image3;filename="),
                defaultValue=>undef
            },
            brochure=>{
                tab => "properties",
                fieldType=>"file",
                maxAttachments=>1,
                label=>$i18n->get(13),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=brochure;filename="),
                defaultValue=>undef
            },
            manual=>{
                tab => "properties",
                fieldType=>"file",
                maxAttachments=>1,
                label=>$i18n->get(14),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=manual;filename="),
                defaultValue=>undef
            },
            warranty=>{
                tab => "properties",
                fieldType=>"file",
                maxAttachments=>1,
                label=>$i18n->get(15),
                deleteFileUrl=>$session->url->page("func=deleteFileConfirm;file=warranty;filename="),
                defaultValue=>undef
            },
            parameters=>{ ##Parameters and options
                tab => "properties",
                fieldType=>"hidden",
                defaultValue=>'{}',
            },
            variants=>{ ##Which variants are enabled and/or disabled
                tab => "properties",
                fieldType=>"hidden",
                defaultValue=>'{}',
            },
        );
    push(@{$definition}, {
        assetName=>$i18n->get('assetName'),
        autoGenerateForms=>1,
        icon=>'product.gif',
        tableName=>'Product',
        className=>'WebGUI::Asset::Sku::Product',
        properties=>\%properties
        });
        return $class->SUPER::definition($session, $definition);
}

#-------------------------------------------------------------------

=head2 deleteCollateral ( tableName, keyName, keyValue )

Deletes a row of collateral data where keyName=keyValue.

=head3 tableName

The name of the table you wish to delete the data from.

=head3 keyName

The name of a column in the table. Is not checked for invalid input.

=head3 keyValue

Criteria (value) used to find the data to delete.

=cut

sub deleteCollateral {
	my $self = shift;
	my $table = shift;
	my $keyName = shift;
	my $keyValue = shift;
        $self->session->db->write("delete from $table where $keyName=".$self->session->db->quote($keyValue));
	$self->updateHistory("deleted collateral item ".$keyName." ".$keyValue);
}

#-------------------------------------------------------------------
sub duplicate {
    my $self = shift;
    my $newAsset = $self->SUPER::duplicate(@_);

    foreach my $file ('image1', 'image2', 'image3', 'manual', 'brochure', 'warranty') {
        $self->_duplicateFile($newAsset, $file);
    }

    foreach my $basename ('feature', 'benefit', 'specification') {
        my $table = "Product_${basename}";
        my $sth = $self->session->db->read("select * from $table where assetId=?", [$self->getId]);
        while (my $row = $sth->hashRef) {
            $row->{"${table}Id"} = "new";
            $row->{"assetId"} = $newAsset->getId; 
            $newAsset->setCollateral($table, "${table}Id", $row);
        }
    }
   
    foreach my $basename ('accessory', 'related') {
        my $table = "Product_${basename}";
        my $tableAssetId = "${basename}AssetId";
        my $sth = $self->session->db->read("select * from $table where assetId=?", [$self->getId]);
        my %data;
        tie %data, 'Tie::CPHash';
        while (%data = $sth->hash) {
            $self->session->db->write("insert into $table (assetId, $tableAssetId, sequenceNumber) values (?, ?, ?)", [$newAsset->getId, $data{$tableAssetId}, $data{sequenceNumber}]);
        }
    }

    return $newAsset;
}


#-------------------------------------------------------------------

=head2 getCollateral ( tableName, keyName, keyValue )

Returns a hash reference containing a row of collateral data.

=head3 tableName

The name of the table you wish to retrieve the data from.

=head3 keyName

A name of a column in the table. Usually the primary key column.

=head3 keyValue

A string containing the key value. If key value is equal to "new" or null, then an empty hashRef containing only keyName=>"new" will be returned to avoid strict errors.

=cut

sub getCollateral {
	my $self = shift;
	my $table = shift;
	my $keyName = shift;
	my $keyValue = shift;
	if ($keyValue eq "new" || $keyValue eq "") {
		return {$keyName=>"new"};
	} else {
		return $self->session->db->quickHashRef("select * from $table where $keyName=".$self->session->db->quote($keyValue));
	}
}


#-------------------------------------------------------------------
sub getFileIconUrl {
    my $self = shift;
    my $store = $_[0];
    return $store->getFileIconUrl($self->getFilename($store));
}

#-------------------------------------------------------------------
sub getFilename {
    my $self = shift;
    my $store = $_[0];
    my $files = $store->getFiles();
    foreach my $file (@{$files}){
        unless($file =~ m/^thumb-/){
            return $file;
        }
    }
    return "";
}

#-------------------------------------------------------------------
sub getFileUrl {
    my $self = shift;
    my $store = $_[0];
    return $store->getUrl($self->getFilename($store));
}

#-------------------------------------------------------------------

=head2 getParamData

Return the parameter data from this product as a perl data structure,
rather than the internally stored JSON.

=cut

sub getParamData {
    my $self = shift;
    my $structure = JSON::from_json($self->get('parameters'));
    return $structure;
}

#-------------------------------------------------------------------
sub getPrice {
    my $self = shift;
    return $self->get('price');
}

#-------------------------------------------------------------------
sub getThumbnailFilename {
    my $self = shift;
    my $filestore = $_[0];
    my $files = $filestore->getFiles();
    foreach my $file (@{$files}){
        if($file =~ m/^thumb-/){
            return $file;
        }
    }
    return "";
}

#-------------------------------------------------------------------
sub getThumbnailUrl {
    my $self = shift;
    my $store = $_[0];
    return $store->getUrl($self->getThumbnailFilename($store));
}

#-------------------------------------------------------------------

=head2 indexContent ( )

Indexing product data. See WebGUI::Asset::indexContent() for additonal details. 

=cut

sub indexContent {
    my $self = shift;
    my $indexer = $self->SUPER::indexContent;
    my @data = $self->session->db->buildArray("select feature from Product_feature where assetId=".$self->session->db->quote($self->getId));
    $indexer->addKeywords(join(" ", @data));
    @data = $self->session->db->buildArray("select benefit from Product_benefit where assetId=".$self->session->db->quote($self->getId));
    $indexer->addKeywords(join(" ", @data));
    @data = $self->session->db->buildArray("select concat(name,' ',value,' ', units) from Product_specification where assetId=".$self->session->db->quote($self->getId));
    $indexer->addKeywords(join(" ", @data));
}


#-------------------------------------------------------------------

=head2 moveCollateralDown ( tableName, keyName, keyValue [ , setName, setValue ] )

Moves a collateral data item down one position. This assumes that the collateral data table has a column called "assetId" that identifies the wobject, and a column called "sequenceNumber" that determines the position of the data item.

=head3 tableName

A string indicating the table that contains the collateral data.

=head3 keyName

A string indicating the name of the column that uniquely identifies this collateral data item.

=head3 keyValue

An iid that uniquely identifies this collateral data item.

=head3 setName

By default this method assumes that the collateral will have an assetId in the table. However, since there is not always a assetId to separate one data set from another, you may specify another field to do that.

=head3 setValue

The value of the column defined by "setName" to select a data set from.

=cut

### NOTE: There is a redundant use of assetId in some of these statements on purpose to support
### two different types of collateral data.

sub moveCollateralDown {
	my $self = shift;
	my $table = shift;
	my $keyName = shift;
	my $keyValue = shift;
	my $setName = shift || "assetId";
        my $setValue = shift;
	unless (defined $setValue) {
		$setValue = $self->get($setName);
	}
	$self->session->db->beginTransaction;
        my ($seq) = $self->session->db->quickArray("select sequenceNumber from $table where $keyName=".$self->session->db->quote($keyValue)." and $setName=".$self->session->db->quote($setValue));
        my ($id) = $self->session->db->quickArray("select $keyName from $table where $setName=".$self->session->db->quote($setValue)." and sequenceNumber=$seq+1");
        if ($id ne "") {
                $self->session->db->write("update $table set sequenceNumber=sequenceNumber+1 where $keyName=".$self->session->db->quote($keyValue)." and $setName=" .$self->session->db->quote($setValue));
                $self->session->db->write("update $table set sequenceNumber=sequenceNumber-1 where $keyName=".$self->session->db->quote($id)." and $setName=" .$self->session->db->quote($setValue));
         }
	$self->session->db->commit;
}


#-------------------------------------------------------------------

=head2 moveCollateralUp ( tableName, keyName, keyValue [ , setName, setValue ] )

Moves a collateral data item up one position. This assumes that the collateral data table has a column called "assetId" that identifies the wobject, and a column called "sequenceNumber" that determines the position of the data item.

=head3 tableName

A string indicating the table that contains the collateral data.

=head3 keyName

A string indicating the name of the column that uniquely identifies this collateral data item.

=head3 keyValue

An id that uniquely identifies this collateral data item.

=head3 setName

By default this method assumes that the collateral will have a asset in the table. However, since there is not always a assetId to separate one data set from another, you may specify another field to do that.

=head3 setValue

The value of the column defined by "setName" to select a data set from.

=cut

### NOTE: There is a redundant use of assetId in some of these statements on purpose to support
### two different types of collateral data.

sub moveCollateralUp {
	my $self = shift;
	my $table = shift;
	my $keyName = shift;
	my $keyValue = shift;
        my $setName = shift || "assetId";
        my $setValue = shift;
	unless (defined $setValue) {
		$setValue = $self->get($setName);
	}
	$self->session->db->beginTransaction;
        my ($seq) = $self->session->db->quickArray("select sequenceNumber from $table where $keyName=".$self->session->db->quote($keyValue)." and $setName=".$self->session->db->quote($setValue));
        my ($id) = $self->session->db->quickArray("select $keyName from $table where $setName=".$self->session->db->quote($setValue)
		." and sequenceNumber=$seq-1");
        if ($id ne "") {
                $self->session->db->write("update $table set sequenceNumber=sequenceNumber-1 where $keyName=".$self->session->db->quote($keyValue)." and $setName="
			.$self->session->db->quote($setValue));
                $self->session->db->write("update $table set sequenceNumber=sequenceNumber+1 where $keyName=".$self->session->db->quote($id)." and $setName="
			.$self->session->db->quote($setValue));
        }
	$self->session->db->commit;
}

#-------------------------------------------------------------------

=head2 prepareView ( )

See WebGUI::Asset::prepareView() for details.

=cut

sub prepareView {
    my $self = shift;
    $self->SUPER::prepareView();
    my $template = WebGUI::Asset::Template->new($self->session, $self->get("templateId"));
    $template->prepare;
    $self->{_viewTemplate} = $template;
}


#-------------------------------------------------------------------
sub purge {
    my $self = shift;
    my $sth = $self->session->db->read("select image1, image2, image3, brochure, manual, warranty from Product where assetId=".$self->session->db->quote($self->getId));
    while (my @array = $sth->array) {
        foreach my $id (@array){
            next if ($id eq "");
            WebGUI::Storage->get($self->session,$id)->delete; 
        }
    }
    $sth->finish;
    $self->session->db->write("delete from Product_accessory where assetId=".$self->session->db->quote($self->getId)." or accessoryAssetId=".$self->session->db->quote($self->getId));
    $self->session->db->write("delete from Product_related where assetId=".$self->session->db->quote($self->getId)." or relatedAssetId=".$self->session->db->quote($self->getId));
    $self->session->db->write("delete from Product_benefit where assetId=".$self->session->db->quote($self->getId));
    $self->session->db->write("delete from Product_feature where assetId=".$self->session->db->quote($self->getId));
    $self->session->db->write("delete from Product_specification where assetId=".$self->session->db->quote($self->getId));
    $self->SUPER::purge();
}

#-------------------------------------------------------------------

=head2 purgeCache ( )

See WebGUI::Asset::purgeCache() for details.

=cut

sub purgeCache {
    my $self = shift;
    WebGUI::Cache->new($self->session,"view_".$self->getId)->delete;
    $self->SUPER::purgeCache;
}

#-------------------------------------------------------------------

sub purgeRevision    {
    my $self = shift;
    WebGUI::Storage->get($self->session,$self->get("image1"))->delete if    ($self->get("image1"));
    WebGUI::Storage->get($self->session,$self->get("image2"))->delete if    ($self->get("image2"));
    WebGUI::Storage->get($self->session,$self->get("image3"))->delete if    ($self->get("image3"));
    WebGUI::Storage->get($self->session,$self->get("brochure"))->delete if    ($self->get("brochure"));
    WebGUI::Storage->get($self->session,$self->get("manual"))->delete if    ($self->get("manual"));
    WebGUI::Storage->get($self->session,$self->get("warranty"))->delete if    ($self->get("warranty"));
    return $self->SUPER::purgeRevision;
}

#-------------------------------------------------------------------

=head2 reorderCollateral ( tableName,keyName [,setName,setValue] )

Resequences collateral data. Typically useful after deleting a collateral item to remove the gap created by the deletion.

=head3 tableName

The name of the table to resequence.

=head3 keyName

The key column name used to determine which data needs sorting within the table.

=head3 setName

Defaults to "assetId". This is used to define which data set to reorder.

=head3 setValue

Used to define which data set to reorder. Defaults to the value of setName (default "assetId", see above) in the wobject properties.

=cut

sub reorderCollateral {
    my $self = shift;
    my $table = shift;
    my $keyName = shift;
    my $setName = shift || "assetId";
    my $setValue = shift || $self->get($setName);
    my $i = 1;
    my $sth = $self->session->db->read("select $keyName from $table where $setName=? order by sequenceNumber", [$setValue]);
	my $sth2 = $self->session->db->prepare("update $table set sequenceNumber=? where $setName=? and $keyName=?");
    while (my ($id) = $sth->array) {
        $sth2->execute([$i, $setValue, $id]);
        $i++;
    }
    $sth2->finish;
    $sth->finish;
}


#-----------------------------------------------------------------

=head2 setCollateral ( tableName,keyName,properties [,useSequenceNumber,useAssetId,setName,setValue] )

Performs and insert/update of collateral data for any wobject's collateral data. Returns the primary key value for that row of data.

=head3 tableName

The name of the table to insert the data.

=head3 keyName

The column name of the primary key in the table specified above.

=head3 properties

A hash reference containing the name/value pairs to be inserted into the database where the name is the column name. Note that the primary key should be specified in this list, and if it's value is "new" or null a new row will be created.

=head3 useSequenceNumber

If set to "1", a new sequenceNumber will be generated and inserted into the row. Note that this means you must have a sequenceNumber column in the table. Also note that this requires the presence of the assetId column. Defaults to "1".

=head3 useAssetId

If set to "1", the current assetId will be inserted into the table upon creation of a new row. Note that this means the table better have a assetId column. Defaults to "1".

=head3 setName

If this collateral data set is not grouped by assetId, but by another column then specify that column here. The useSequenceNumber parameter will then use this column name instead of assetId to generate the sequenceNumber.

=head3 setValue

If you've specified a setName you may also set a value for that set.  Defaults to the value for this id from the wobject properties.

=cut

sub setCollateral {
	my $self = shift;
	my $table = shift;
	my $keyName = shift;
	my $properties = shift;
	my $useSequence = shift;
	my $useAssetId = shift;
	my $setName = shift || "assetId";
	my $setValue = shift || $self->get($setName);
	my ($key, $seq, $dbkeys, $dbvalues);
	my $counter = 0;
	my $sql;
	if ($properties->{$keyName} eq "new" || $properties->{$keyName} eq "") {
		$properties->{$keyName} = $self->session->id->generate();
		$sql = "insert into $table (";
		my $dbkeys = "";
        my $dbvalues = "";
		unless ($useSequence eq "0") {
			unless (exists $properties->{sequenceNumber}) {
				my ($seq) = $self->session->db->quickArray("select max(sequenceNumber) from $table where $setName=?",[$setValue]);
				$properties->{sequenceNumber} = $seq+1;
			}
		}
		unless ($useAssetId eq "0") {
			$properties->{assetId} = $self->get("assetId");
		}
		foreach my $key (keys %{$properties}) {
			if ($counter++ > 0) {
				$dbkeys .= ',';
				$dbvalues .= ',';
			}
			$dbkeys .= $key;
			$dbvalues .= $self->session->db->quote($properties->{$key});
		}
		$sql .= $dbkeys.') values ('.$dbvalues.')';
		$self->updateHistory("added collateral item ".$table." ".$properties->{$keyName});
	}
    else {
		$sql = "update $table set ";
		foreach my $key (keys %{$properties}) {
			unless ($key eq "sequenceNumber") {
				$sql .= ',' if ($counter++ > 0);
				$sql .= $key."=".$self->session->db->quote($properties->{$key});
			}
		}
		$sql .= " where $keyName=".$self->session->db->quote($properties->{$keyName});
		$self->updateHistory("edited collateral item ".$table." ".$properties->{$keyName});
	}
  	$self->session->db->write($sql);
	$self->reorderCollateral($table,$keyName,$setName,$setValue) if ($properties->{sequenceNumber} < 0);
	return $properties->{$keyName};
}

#-------------------------------------------------------------------

=head2 setParamData ($paramData)

Set the product's parameter data as a perl data structure.  This is
stored in the db as JSON.  This adds a revision to the Product, since
parameters and options are stored directly in the asset table.

Returns a copy to the new version of the Product Asset.

=head2 $paramData

A hash of arrays.  The keys in the hash are names of parameters, and the
values of the arrays are subhashes, containing the names of options as
well as price and weight modifiers.

=cut

sub setParamData {
    my $self      = shift;
    my $paramData = shift;
    my $json = JSON::to_json($paramData);
    my $newSelf = $self->addRevision({parameters => $json});
    return $newSelf;
}


#-------------------------------------------------------------------
sub www_addAccessory {
   my $self = shift;
   return $self->session->privilege->insufficient() unless ($self->canEdit);
   my ($f, $accessory, @usedAccessories);
   $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
   $f->hidden(
        -name => "func",
        -value => "addAccessorySave",
   );
   @usedAccessories = $self->session->db->buildArray("select accessoryAssetId from Product_accessory where assetId=".$self->session->db->quote($self->getId));
   push(@usedAccessories,$self->getId);
   $accessory = $self->session->db->buildHashRef("select asset.assetId, assetData.title from asset left join assetData on assetData.assetId=asset.assetId where asset.className='WebGUI::Asset::Sku::Product' and asset.assetId not in (".$self->session->db->quoteAndJoin(\@usedAccessories).") and (assetData.status='approved' or assetData.tagId=".$self->session->db->quote($self->session->scratch->get("versionTag")).") group by assetData.assetId");
    my $i18n = WebGUI::International->new($self->session,"Asset_Product");
   $f->selectBox(
        -name => "accessoryAccessId",
        -options => $accessory,
        -label => $i18n->get(17),
        -hoverHelp => $i18n->get('17 description'),
   );
   $f->yesNo(
        -name => "proceed",
        -label => $i18n->get(18),
        -hoverHelp => $i18n->get('18 description'),
   );
   $f->submit;
   return $self->getAdminConsole->render($f->print, "product accessory add/edit");
}

#-------------------------------------------------------------------
sub www_addAccessorySave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    return "" unless ($self->session->form->process("accessoryAccessId"));
    my ($seq) = $self->session->db->quickArray("select max(sequenceNumber) from Product_accessory where assetId=".$self->session->db->quote($self->getId()));
    $self->session->db->write("insert into Product_accessory (assetId,accessoryAssetId,sequenceNumber) values (".$self->session->db->quote($self->getId()).",".$self->session->db->quote($self->session->form->process("accessoryAccessId")).",".($seq+1).")");
    return "" unless($self->session->form->process("proceed"));
    return $self->www_addAccessory();
}

#-------------------------------------------------------------------
sub www_addRelated {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my ($f, $related, @usedRelated);
    $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "func",
        -value => "addRelatedSave",
    );
    @usedRelated = $self->session->db->buildArray("select relatedAssetId from Product_related where assetId=".$self->session->db->quote($self->getId));
    push(@usedRelated,$self->getId);
    $related = $self->session->db->buildHashRef("select asset.assetId,assetData.title from asset left join assetData on assetData.assetId=asset.assetId where asset.className='WebGUI::Asset::Sku::Product' and asset.assetId not in (".$self->session->db->quoteAndJoin(\@usedRelated).")");
     my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    $f->selectBox(
        -name => "relatedAssetId",
        -options => $related,
        -label => $i18n->get(20),
        -hoverHelp => $i18n->get('20 description'),
    );
    $f->yesNo(
        -name => "proceed",
        -label => $i18n->get(21),
        -hoverHelp => $i18n->get('21 description'),
    );
    $f->submit;
    return $self->getAdminConsole->render($f->print,"product related add/edit");
}

#-------------------------------------------------------------------
sub www_addRelatedSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    return "" unless ($self->session->form->process("relatedAssetId"));
    my ($seq) = $self->session->db->quickArray("select max(sequenceNumber) from Product_related where assetId=".$self->session->db->quote($self->getId));
    $self->session->db->write("insert into Product_related (assetId,relatedAssetId,sequenceNumber) values (".$self->session->db->quote($self->getId).",".$self->session->db->quote($self->session->form->process("relatedAssetId")).",".($seq+1).")");
    return "" unless($self->session->form->process("proceed"));
    return $self->www_addRelated();
}

#-------------------------------------------------------------------
sub www_deleteAccessoryConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->session->db->write("delete from Product_accessory where assetId=".$self->session->db->quote($self->getId())." and accessoryAssetId=".$self->session->db->quote($self->session->form->process("aid")));
    $self->reorderCollateral("Product_accessory","accessoryAssetId");
    return "";
}

#-------------------------------------------------------------------
sub www_deleteBenefitConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->deleteCollateral("Product_benefit","Product_benefitId",$self->session->form->process("bid"));
    $self->reorderCollateral("Product_benefit","Product_benefitId");
    return "";
}

#-------------------------------------------------------------------
sub www_deleteFeatureConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->deleteCollateral("Product_feature","Product_featureId",$self->session->form->process("fid"));
    $self->reorderCollateral("Product_feature","Product_featureId");
    return "";
}

#-------------------------------------------------------------------
sub www_deleteFileConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my $column = $self->session->form->process("file");
    return $self->www_edit  unless (isIn($column, qw(image1 image2 image3 manual warranty brochure)));
    my $store = $self->get($column);
    my $file = WebGUI::Storage->get($self->session,$store);
    $file->delete if defined $file;
    $self->update({$column=>''});
    return $self->www_edit;
}

#-------------------------------------------------------------------
sub www_deleteRelatedConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->session->db->write("delete from Product_related where assetId=".$self->session->db->quote($self->getId)." and relatedAssetId=".$self->session->db->quote($self->session->form->process("rid")));
    $self->reorderCollateral("Product_related","relatedAssetId");
    return "";
}

#-------------------------------------------------------------------
sub www_deleteSpecificationConfirm {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->deleteCollateral("Product_specification","Product_specificationId",$self->session->form->process("sid"));
    $self->reorderCollateral("Product_specification","Product_specificationId");
    return "";
}


#-------------------------------------------------------------------
sub www_editBenefit {
    my $self = shift;
    my $bid = shift || $self->session->form->process("bid");
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my ($data, $f, $benefits);
    $data = $self->getCollateral("Product_benefit","Product_benefitId",$bid);
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "bid",
        -value => $data->{Product_benefitId},
    );
    $f->hidden(
        -name => "func",
        -value => "editBenefitSave",
    );
    $benefits = $self->session->db->buildHashRef("select benefit,benefit from Product_benefit order by benefit");
    $f->combo(
        -name => "benefit",
        -options => $benefits,
        -label => $i18n->get(51),
        -hoverHelp => $i18n->get('51 description'),
        -value => [$data->{benefits}],
    );
    $f->yesNo(
        -name => "proceed",
        -label => $i18n->get(52),
        -hoverHelp => $i18n->get('52 description'),
    );
    $f->submit;
    return $self->getAdminConsole->render($f->print, "product benefit add/edit");
}

#-------------------------------------------------------------------
sub www_editBenefitSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->setCollateral("Product_benefit", "Product_benefitId", {
                                                  Product_benefitId => $self->session->form->process("bid"),
                                                  benefit => $self->session->form->process("benefit","combo")
                                                });
    return "" unless($self->session->form->process("proceed"));
    return $self->www_editBenefit("new");
}

#-------------------------------------------------------------------
sub www_editFeature {
    my $self = shift;
    my $fid = shift || $self->session->form->process("fid");
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my ($data, $f, $features);
    $data = $self->getCollateral("Product_feature","Product_featureId",$fid);
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "fid",
        -value => $data->{Product_featureId},
    );
    $f->hidden(
        -name => "func",
        -value => "editFeatureSave",
    );
    $features = $self->session->db->buildHashRef("select feature,feature from Product_feature order by feature");
    $f->combo(
        -name => "feature",
        -options => $features,
        -label => $i18n->get(23),
        -hoverHelp => $i18n->get('23 description'),
        -value => [$data->{feature}],
    );
    $f->yesNo(
        -name => "proceed",
        -label => $i18n->get(24),
        -hoverHelp => $i18n->get('24 description'),
    );
    $f->submit;
    return $self->getAdminConsole->render($f->print, "product feature add/edit");
}

#-------------------------------------------------------------------
sub www_editFeatureSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->setCollateral("Product_feature", "Product_featureId", {
                                              Product_featureId => $self->session->form->process("fid"),
                                              feature => $self->session->form->process("feature","combo")
                                             });
    return "" unless($self->session->form->process("proceed"));
    return $self->www_editFeature("new");
}

#-------------------------------------------------------------------
sub www_editParameter {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my $param = shift || $self->session->form->get('name') || 'new';
    my $paramData = $self->getParamData;
    $param = "new" unless exists $paramData->{$param};
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    my $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "func",
        -value => "editParameterSave",
    );
    $f->hidden(
        -name => "origname",
        -value => $param,
    );
    $f->text(
        -name       => 'name',
        -label      => $i18n->get('edit parameter name'),
        -hoverHelp  => $i18n->get('edit parameter name description'),
        -value      => $param,
        -maxlength  => 64,
    );
    $f->submit;
    return $self->getAdminConsole->render($f->print, "edit parameter");
}

#-------------------------------------------------------------------
sub www_editParameterSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);

    my $param     = $self->session->form->get('name');
    my $origname  = lc $self->session->form->get('origname');

    my $paramData = $self->getParamData;
    if (($origname ne "new") and ($origname ne $param)) {
        $self->session->errorHandler->warn('Rename');
        ##Rename existing data
        my @options = @{ $paramData->{$origname} };
        $paramData->{$param} = \@options;
        delete $paramData->{$origname};
        my $newSelf = $self->setParamData($paramData);
        return $newSelf->www_editParameter($param);
    }
    elsif ($origname eq "new") {
        $self->session->errorHandler->warn('New');
        $paramData->{$param} = [];
        my $newSelf = $self->setParamData($paramData);
        return $newSelf->www_editParameterOptions($param);
    }
}

#-------------------------------------------------------------------
sub www_editParameterOptions {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my $session = $self->session;
    my $param = shift || $self->session->form->get('name');
    my $value = shift || $self->session->form->get('value');
    my $paramData = $self->getParamData;
    if (! exists $paramData->{$param}) {
        $self->session->errorHandler->warn('Not in param data');
        return $self->www_editParameter($param);
    }
    my $option = {};
    OPTION: foreach my $subOption (@{ $paramData->{$param} }) {
        if ($subOption->{value} eq $value) {
            $option = $subOption;
            last OPTION;
        }
    }
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    my $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "func",
        -value => "editParameterOptionSave",
    );
    $f->readOnly(
        -name       => 'name',
        -value      => $param,
    );
	$f->text(
		-name		=> 'value',
		-label		=> $i18n->get('edit option value'),
		-hoverHelp	=> $i18n->get('edit option value description'),
		-value		=> $session->form->process("value") || $option->{value},
		-maxlength	=> 64,
	);
	$f->float(
		-name		=> 'priceModifier',
		-label		=> $i18n->get('edit option price modifier'),
		-hoverHelp	=> $i18n->get('edit option price modifier description'),
		-value		=> $session->form->process("priceModifier") || $option->{priceModifier},
		-maxlength	=> 11,
	);
	$f->float(
		-name		=> 'weightModifier',
		-label		=> $i18n->get('edit option weight modifier'),
		-hoverHelp	=> $i18n->get('edit option weight modifier description'),
		-value		=> $session->form->process("weightModifier") || $option->{weightModifier},
		-maxlength	=> 7,
	);
    $f->submit;
    return $self->getAdminConsole->render($f->print, "edit option");
}

#-------------------------------------------------------------------
sub www_editParameterOptionsSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);

    my $param     = $self->session->form->get('name');
    my $value     = $self->session->form->get('value');
    my $origValue = $self->session->form->get('origValue');

}

#-------------------------------------------------------------------
sub www_editSpecification {
    my $self = shift;
    my $sid = shift || $self->session->form->process("sid");
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    my ($data, $f, $hashRef);
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    $data = $self->getCollateral("Product_specification","Product_specificationId",$sid);
    $f = WebGUI::HTMLForm->new($self->session,-action=>$self->getUrl);
    $f->hidden(
        -name => "sid",
        -value => $data->{Product_specificationId},
    );
    $f->hidden(
        -name => "func",
        -value => "editSpecificationSave",
    );
    $hashRef = $self->session->db->buildHashRef("select name,name from Product_specification order by name");
    $f->combo(
        -name => "name",
        -options => $hashRef,
        -label => $i18n->get(26),
        -hoverHelp => $i18n->get('26 description'),
        -value => [$data->{name}],
    );
    $f->text(
        -name => "value",
        -label => $i18n->get(27),
        -hoverHelp => $i18n->get('27 description'),
        -value => $data->{value},
    );
    $hashRef = $self->session->db->buildHashRef("select units,units from Product_specification order by units");
    $f->combo(
        -name => "units",
        -options => $hashRef,
        -label => $i18n->get(29),
        -hoverHelp => $i18n->get('29 description'),
        -value => [$data->{units}],
    );
    $f->yesNo(
        -name => "proceed",
        -label => $i18n->get(28),
        -hoverHelp => $i18n->get('28 description'),
    );
    $f->submit;
    return $self->getAdminConsole->render($f->print, "product specification add/edit");
}

#-------------------------------------------------------------------
sub www_editSpecificationSave {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->setCollateral("Product_specification", "Product_specificationId", {
        Product_specificationId => $self->session->form->process("sid"),
        name => $self->session->form->process("name","combo"),
        value => $self->session->form->process("value","combo"),
        units => $self->session->form->process("units","combo")
    });

    return "" unless($self->session->form->process("proceed"));
    return $self->www_editSpecification("new");
}

#-------------------------------------------------------------------
sub www_moveAccessoryDown {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralDown("Product_accessory","accessoryAssetId",$self->session->form->process("aid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveAccessoryUp {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralUp("Product_accessory","accessoryAssetId",$self->session->form->process("aid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveBenefitDown {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralDown("Product_benefit","Product_benefitId",$self->session->form->process("bid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveBenefitUp {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralUp("Product_benefit","Product_benefitId",$self->session->form->process("bid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveFeatureDown {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralDown("Product_feature","Product_featureId",$self->session->form->process("fid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveFeatureUp {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralUp("Product_feature","Product_featureId",$self->session->form->process("fid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveRelatedDown {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralDown("Product_related","relatedAssetId",$self->session->form->process("rid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveRelatedUp {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralUp("Product_related","relatedAssetId",$self->session->form->process("rid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveSpecificationDown {
    my $self = shift;
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralDown("Product_specification","Product_specificationId",$self->session->form->process("sid"));
    return "";
}

#-------------------------------------------------------------------
sub www_moveSpecificationUp {
    my $self = shift;   
    return $self->session->privilege->insufficient() unless ($self->canEdit);
    $self->moveCollateralUp("Product_specification","Product_specificationId",$self->session->form->process("sid"));
    return "";
}

#-------------------------------------------------------------------
sub view {
    my $self = shift;
    if (!$self->session->var->isAdminOn && $self->get("cacheTimeout") > 10) {
        my $out = WebGUI::Cache->new($self->session,"view_".$self->getId)->get;
        return $out if $out;
    }
    my (%data, $sth, $file, $segment, %var, @featureloop, @benefitloop, @specificationloop, @accessoryloop, @relatedloop);
    tie %data, 'Tie::CPHash';
    my $brochure = $self->get("brochure");
    my $manual   = $self->get("manual");
    my $warranty = $self->get("warranty");

    my $image1 = $self->get("image1");
    my $image2 = $self->get("image2");
    my $image3 = $self->get("image3");

    #---brochure
    my $i18n = WebGUI::International->new($self->session,'Asset_Product');
    if ($brochure) {
        $file = WebGUI::Storage->get($self->session,$brochure);
        $var{"brochure.icon"}  = $self->getFileIconUrl($file);
        $var{"brochure.label"} = $i18n->get(13);
        $var{"brochure.URL"}   = $self->getFileUrl($file);
    }
    #---manual
    if ($manual) {
        $file = WebGUI::Storage->get($self->session,$manual);
        $var{"manual.icon"}  = $self->getFileIconUrl($file);
        $var{"manual.label"} = $i18n->get(14);
        $var{"manual.URL"}   = $self->getFileUrl($file);
    }
    #---warranty
    if ($warranty) {
        $file = WebGUI::Storage->get($self->session,$warranty);
        $var{"warranty.icon"}  = $self->getFileIconUrl($file);
        $var{"warranty.label"} = $i18n->get(15);
        $var{"warranty.URL"}   = $self->getFileUrl($file);
    }
    #---image1
    if ($image1) {
        $file = WebGUI::Storage->get($self->session,$image1);
        $var{thumbnail1} = $self->getThumbnailUrl($file);
        $var{image1}     = $self->getFileUrl($file);
    }
    #---image2
    if ($image2) {
        $file = WebGUI::Storage->get($self->session,$image2);
        $var{thumbnail2} = $self->getThumbnailUrl($file);
        $var{image2}     = $self->getFileUrl($file);
    }
    #---image3
    if ($image3) {
        $file = WebGUI::Storage->get($self->session,$image3);
        $var{thumbnail3} = $self->getThumbnailUrl($file);
        $var{image3}     = $self->getFileUrl($file);
   }
   
   #---features 
   $var{"addFeature.url"} = $self->getUrl('func=editFeature&fid=new');
   $var{"addFeature.label"} = $i18n->get(34);
   $sth = $self->session->db->read("select feature,Product_featureId from Product_feature where assetId=".$self->session->db->quote($self->getId)." order by sequenceNumber");
   while (%data = $sth->hash) {
      $segment = $self->session->icon->delete('func=deleteFeatureConfirm&fid='.$data{Product_featureId},$self->get("url"),$i18n->get(3))
                 .$self->session->icon->edit('func=editFeature&fid='.$data{Product_featureId},$self->get("url"))
                 .$self->session->icon->moveUp('func=moveFeatureUp&&fid='.$data{Product_featureId},$self->get("url"))
                 .$self->session->icon->moveDown('func=moveFeatureDown&&fid='.$data{Product_featureId},$self->get("url"));
      push(@featureloop,{
                          "feature.feature"=>$data{feature},
                          "feature.controls"=>$segment
                         });
   }
   $sth->finish;
   $var{feature_loop} = \@featureloop;

   #---benefits 
   $var{"addBenefit.url"} = $self->getUrl('func=editBenefit&fid=new');
   $var{"addBenefit.label"} = $i18n->get(55);
   $sth = $self->session->db->read("select benefit,Product_benefitId from Product_benefit where assetId=".$self->session->db->quote($self->getId)." order by sequenceNumber");
   while (%data = $sth->hash) {
      $segment = $self->session->icon->delete('func=deleteBenefitConfirm&bid='.$data{Product_benefitId},$self->get("url"),$i18n->get(48))
                 .$self->session->icon->edit('func=editBenefit&bid='.$data{Product_benefitId},$self->get("url"))
                 .$self->session->icon->moveUp('func=moveBenefitUp&bid='.$data{Product_benefitId},$self->get("url"))
                 .$self->session->icon->moveDown('func=moveBenefitDown&bid='.$data{Product_benefitId},$self->get("url"));
      push(@benefitloop,{
                          "benefit.benefit"=>$data{benefit},
                          "benefit.controls"=>$segment
                         });
   }
   $sth->finish;
   $var{benefit_loop} = \@benefitloop;

    #---specifications 
    $var{"addSpecification.url"} = $self->getUrl('func=editSpecification&sid=new');
    $var{"addSpecification.label"} = $i18n->get(35);
    $sth = $self->session->db->read("select name,value,units,Product_specificationId from Product_specification where assetId=".$self->session->db->quote($self->getId)." order by sequenceNumber");
    while (%data = $sth->hash) {
        $segment = $self->session->icon->delete('func=deleteSpecificationConfirm&sid='.$data{Product_specificationId},$self->get("url"),$i18n->get(5))
                 . $self->session->icon->edit('func=editSpecification&sid='.$data{Product_specificationId},$self->get("url"))
                 . $self->session->icon->moveUp('func=moveSpecificationUp&sid='.$data{Product_specificationId},$self->get("url"))
                 . $self->session->icon->moveDown('func=moveSpecificationDown&sid='.$data{Product_specificationId},$self->get("url"));
        push(@specificationloop,{
                                   "specification.controls"      => $segment,
                                   "specification.specification" => $data{value},
                                   "specification.units"         => $data{units},
                                   "specification.label"         => $data{name},
                                });
    }
    $sth->finish;
    $var{specification_loop} = \@specificationloop;

    #---accessories 
    $var{"addaccessory.url"} = $self->getUrl('func=addAccessory');
    $var{"addaccessory.label"} = $i18n->get(36);
    $sth = $self->session->db->read("select Product_accessory.accessoryAssetId from   Product_accessory
                             where Product_accessory.assetId=".$self->session->db->quote($self->getId)." 
                             order by Product_accessory.sequenceNumber");
    while (my ($id) = $sth->array) {
        $segment = $self->session->icon->delete('func=deleteAccessoryConfirm&aid='.$id,$self->get("url"),$i18n->get(2))
                 . $self->session->icon->moveUp('func=moveAccessoryUp&aid='.$id,$self->get("url"))
                 . $self->session->icon->moveDown('func=moveAccessoryDown&aid='.$id,$self->get("url"));
        my $accessory = WebGUI::Asset->newByDynamicClass($self->session,$id);
        push(@accessoryloop,{
                           "accessory.URL"      => $accessory->getUrl,
                           "accessory.title"    => $accessory->getTitle,
                           "accessory.controls" => $segment,
                           });
    }
    $sth->finish;
    $var{accessory_loop} = \@accessoryloop;

    #---related
    $var{"addrelatedproduct.url"} = $self->getUrl('func=addRelated');
    $var{"addrelatedproduct.label"} = $i18n->get(37);
    $sth = $self->session->db->read("select Product_related.relatedAssetId 
                              from Product_related 
                              where Product_related.assetId=".$self->session->db->quote($self->getId)." 
                              order by Product_related.sequenceNumber");
    while (my ($id) = $sth->array) {
        $segment = $self->session->icon->delete('func=deleteRelatedConfirm&rid='.$id,$self->get("url"),$i18n->get(4))
                 . $self->session->icon->moveUp('func=moveRelatedUp&rid='.$id,$self->get("url"))
                 . $self->session->icon->moveDown('func=moveRelatedDown&rid='.$id,$self->get("url"));
        my $related = WebGUI::Asset->newByDynamicClass($self->session,$id);
        push(@relatedloop,{
                          "relatedproduct.URL"      => $related->getUrl,
                          "relatedproduct.title"    => $related->getTitle,
                          "relatedproduct.controls" => $segment,
                          });
    }
    $sth->finish;
    $var{relatedproduct_loop} = \@relatedloop;
    my $out = $self->processTemplate(\%var,undef,$self->{_viewTemplate});
    if (!$self->session->var->isAdminOn && $self->get("cacheTimeout") > 10) {
        WebGUI::Cache->new($self->session,"view_".$self->getId)->set($out,$self->get("cacheTimeout"));
    }
    return $out;
}

#-------------------------------------------------------------------

=head2 www_view ( )

See WebGUI::Asset::Sku::www_view() for details.

=cut

sub www_view {
    my $self = shift;
    $self->session->http->setCacheControl($self->get("cacheTimeout"));
    $self->SUPER::www_view(@_);
}

1;

