package WebGUI::Asset::Wobject::Article;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2005 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::IxHash;
use WebGUI::DateTime;
use WebGUI::International;
use WebGUI::Paginator;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::Asset::Wobject;

our @ISA = qw(WebGUI::Asset::Wobject);


#-------------------------------------------------------------------
sub definition {
	my $class = shift;
	my $definition = shift;
	my %properties;
	tie %properties, 'Tie::IxHash';
	%properties = (
			templateId =>{
				fieldType=>"template",
				defaultValue=>'PBtmpl0000000000000002',	
				tab=>"display",
				namespace=>"Article",
                		hoverHelp=>WebGUI::International::get('article template description','Asset_Article'),
                		label=>WebGUI::International::get(72,"Asset_Article")
				},
			linkURL=>{
				tab=>"properties",
				fieldType=>'url',
				defaultValue=>undef,
				label=>WebGUI::International::get(8,"Asset_Article"),
                		hoverHelp=>WebGUI::International::get('link url description','Asset_Article'),
                		uiLevel=>3
				},
			linkTitle=>{
				tab=>"properties",
				fieldType=>'text',
				defaultValue=>undef,
				label=>WebGUI::International::get(7,"Asset_Article"),
                		hoverHelp=>WebGUI::International::get('link title description','Asset_Article'),
                		uiLevel=>3
				},
			convertCarriageReturns=>{
				tab=>"display",
				fieldType=>'yesNo',
				defaultValue=>0,
				label=>WebGUI::International::get(10,"Asset_Article"),
                		subtext=>' &nbsp; <span style="font-size: 8pt;">'.WebGUI::International::get(11,"Asset_Article").'</span>',
                		hoverHelp=>WebGUI::International::get('carriage return description','Asset_Article'),
                		uiLevel=>5
				}
		);
	push(@{$definition}, {
		assetName=>WebGUI::International::get('assetName',"Asset_Article"),
		icon=>'article.gif',
		autoGenerateForms=>1,
		tableName=>'Article',
		className=>'WebGUI::Asset::Wobject::Article',
		properties=>\%properties
		});
        return $class->SUPER::definition($definition);
}



#-------------------------------------------------------------------
sub getIndexerParams {
        my $self = shift;
        my $now = shift;
        return {
                Article => {
                        sql => "select Article.assetId,
					Article.linkTitle,
					Article.linkURL,
					assetData.title,
					assetData.menuTitle,
					assetData.url,
					asset.className,
					assetData.ownerUserId,
					assetData.groupIdView,
					assetData.synopsis,
					wobject.description
				from asset, Article
				left join wobject on wobject.assetId = asset.assetId
				left join assetData asset.assetId=assetData.assetId
				where asset.assetId = Article.assetId
                                        and assetData.startDate < $now
                                        and assetData.endDate > $now",
                        fieldsToIndex => ["linkTitle" ,"linkURL","title","menuTitle","url","synopsis","description" ],
                        contentType => 'content',
                        url => 'WebGUI::URL::gateway($data{url})',
                        headerShortcut => 'select title from asset where assetId = \'$data{assetId}\'',
                        bodyShortcut => 'select description from wobject where assetId = \'$data{assetId}\'',
                }

        };
}



#-------------------------------------------------------------------
sub view {
	my $self = shift;
	my %var;
	my $children = $self->getLineage(["children"],{returnObjects=>1,includeOnlyClasses=>["WebGUI::Asset::File","WebGUI::Asset::File::Image"]});
	foreach my $child (@{$children}) {
		if (ref $child eq "WebGUI::Asset::File") {
			$var{"attachment.box"} = $child->getBox;
			$var{"attachment.icon"} = $child->getFileIconUrl;
			$var{"attachment.url"} = $child->getFileUrl;
			$var{"attachment.name"} = $child->get("filename");
		} elsif (ref $child eq "WebGUI::Asset::File::Image") {
			$var{"image.url"} = $child->getFileUrl;
			$var{"image.thumbnail"} = $child->getThumbnailUrl; 
		}
	}
        $var{description} = $self->get("description");
	if ($self->get("convertCarriageReturns")) {
		$var{description} =~ s/\n/\<br\>\n/g;
	}
	$var{"new.template"} = $self->getUrl.";overrideTemplateId=";
	$var{"description.full"} = $var{description};
	$var{"description.full"} =~ s/\^\-\;//g;
	$var{"description.first.100words"} = $var{"description.full"};
	$var{"description.first.100words"} =~ s/(((\S+)\s+){100}).*/$1/s;
	$var{"description.first.75words"} = $var{"description.first.100words"};
	$var{"description.first.75words"} =~ s/(((\S+)\s+){75}).*/$1/s;
	$var{"description.first.50words"} = $var{"description.first.75words"};
	$var{"description.first.50words"} =~ s/(((\S+)\s+){50}).*/$1/s;
	$var{"description.first.25words"} = $var{"description.first.50words"};
	$var{"description.first.25words"} =~ s/(((\S+)\s+){25}).*/$1/s;
	$var{"description.first.10words"} = $var{"description.first.25words"};
	$var{"description.first.10words"} =~ s/(((\S+)\s+){10}).*/$1/s;
	$var{"description.first.2paragraphs"} = $var{"description.full"};
	$var{"description.first.2paragraphs"} =~ s/^((.*?\n){2}).*/$1/s;
	$var{"description.first.paragraph"} = $var{"description.first.2paragraphs"};
	$var{"description.first.paragraph"} =~ s/^(.*?\n).*/$1/s;
	$var{"description.first.4sentences"} = $var{"description.full"};
	$var{"description.first.4sentences"} =~ s/^((.*?\.){4}).*/$1/s;
	$var{"description.first.3sentences"} = $var{"description.first.4sentences"};
	$var{"description.first.3sentences"} =~ s/^((.*?\.){3}).*/$1/s;
	$var{"description.first.2sentences"} = $var{"description.first.3sentences"};
	$var{"description.first.2sentences"} =~ s/^((.*?\.){2}).*/$1/s;
	$var{"description.first.sentence"} = $var{"description.first.2sentences"};
	$var{"description.first.sentence"} =~ s/^(.*?\.).*/$1/s;
	my $p = WebGUI::Paginator->new($self->getUrl,1);
	if ($session{form}{makePrintable} || $var{description} eq "") {
		$var{description} =~ s/\^\-\;//g;
		$p->setDataByArrayRef([$var{description}]);
	} else {
		my @pages = split(/\^\-\;/,$var{description});
		$p->setDataByArrayRef(\@pages);
		$var{description} = $p->getPage;
	}
	$p->appendTemplateVars(\%var);
	my $templateId = $self->get("templateId");
        if ($session{form}{overrideTemplateId} ne "") {
                $templateId = $session{form}{overrideTemplateId};
        }
	return $self->processTemplate(\%var, $templateId);
}

1;

