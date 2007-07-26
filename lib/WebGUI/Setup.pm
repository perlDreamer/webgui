package WebGUI::Setup;

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
use Digest::MD5;
use WebGUI::Asset;
use WebGUI::HTMLForm;
use WebGUI::International;
use WebGUI::Storage::Image;
use WebGUI::VersionTag;
use WebGUI::Utility;

=head1 NAME

Package WebGUI::Setup

=head1 DESCRIPTION

Initializes a new WebGUI install.

=head1 SYNOPSIS

 use WebGUI::Setup;
 WebGUI::Setup::setup();

=head1 SUBROUTINES

These subroutines are available from this package:

=cut




#-------------------------------------------------------------------

=head2 addAsset ( parent, properties ) 

A helper to add assets with less code.

=head3 parent

The parent asset to add to.

=head3 properties

A hash ref of properties to attach to the asset. One must be className.

=cut

sub addAsset {
    my $parent = shift;
    my $properties = shift;
    $properties->{url} = $parent->get("url")."/".$properties->{title};
    $properties->{groupIdEdit} = $parent->get("groupIdEdit");
    $properties->{groupIdView} = $parent->get("groupIdView");
    $properties->{ownerUserId} = $parent->get("ownerUserId");
    $properties->{styleTemplateId} = $parent->get("styleTemplateId");
    $properties->{printableStyleTemplateId} = $parent->get("styleTemplateId");
    return $parent->addChild($properties);
}



#-------------------------------------------------------------------

=head2 addPage ( parent, title ) 

Adds a page to a parent page.

=head3 parent

A parent page asset.

=head3 title

The title of the new page.

=cut

sub addPage {
    my $parent = shift;
    my $title = shift;
    return addAsset($parent, {title=>$title, className => "WebGUI::Asset::Wobject::Layout", displayTitle=>0});
}

#-------------------------------------------------------------------

=head2 setup ( session )

Handles a specialState: "setup"

=head3 session

The current WebGUI::Session object.

=cut

sub setup {
	my $session = shift;
	my $i18n = WebGUI::International->new($session, "WebGUI");
    my ($output,$legend) = "";
	if ($session->form->process("step") eq "2") {
		$legend = 'Company Information';
		my $u = WebGUI::User->new($session,"3");
		$u->username($session->form->process("username","text","Admin"));
		$u->profileField("email",$session->form->email("email"));
		$u->identifier(Digest::MD5::md5_base64($session->form->process("identifier","password","123qwe")));
		my $f = WebGUI::HTMLForm->new($session,action=>$session->url->gateway());
		$f->hidden( name=>"step", value=>"3");
		$f->text(
			name=>"companyName",
			value=>$session->setting->get("companyName"),
			label=>$i18n->get(125),
			hoverHelp=>$i18n->get('125 description'),
			);
		$f->email(
			name=>"companyEmail",
			value=>$session->setting->get("companyEmail"),
			label=>$i18n->get(126),
			hoverHelp=>$i18n->get('126 description'),
			);
		$f->url(
			name=>"companyURL",
			value=>$session->setting->get("companyURL"),
			label=>$i18n->get(127),
			hoverHelp=>$i18n->get('127 description'),
			);
		$f->submit;
		$output .= $f->print;
	} 
    elsif ($session->form->process("step") eq "3") {
        my $form = $session->form;
		$session->setting->set('companyName',$form->text("companyName")) if ($form->get("companyName"));
		$session->setting->set('companyURL',$form->url("companyURL")) if ($form->get("companyURL"));
		$session->setting->set('companyEmail',$form->email("companyEmail")) if ($form->get("companyEmail"));
        $legend = "Site Starter";
        $output .= ' <p>Do you wish to use the WebGUI Site Starter, which will lead you through options to create a custom
            look and feel for your site, and set up some basic content areas?</p>
            <p><a href="'.$session->url->gateway(undef, "step=7").'">No, thanks.</a> &nbsp; &nbsp; &nbsp;
                <a href="'.$session->url->gateway(undef,"step=4").'">Yes, please!</a></p>
            ';
	} 
    elsif ($session->form->process("step") eq "4") {
		my $f = WebGUI::HTMLForm->new($session,action=>$session->url->gateway());
		$f->hidden( name=>"step", value=>"5",);
		$f->file(name=>"logo", label=>"Logo");
		$f->submit;
        $legend = "Upload Your Logo";
		$output .= $f->print;
	} 
    elsif ($session->form->process("step") eq "5") {
        my $storageId = $session->form->process("logo","image");
        my $url = $session->url;
        my $logoUrl = $url->extras("plainblack.gif");
        if (defined $storageId) {
            my $storage = WebGUI::Storage::Image->get($session, $storageId);
            my $importNode = WebGUI::Asset->getImportNode($session);
            my $logo = addAsset($importNode, {
                title       => $storage->getFiles->[0],
                filename    => $storage->getFiles->[0],
                isHidden    => 1,
                storageId   => $storageId,
                className   => "WebGUI::Asset::File::Image",
                parameters  => 'alt="'.$storage->getFiles->[0].'"'
                });
            $logoUrl = $logo->getStorageLocation->getUrl($logo->get("filename"));
        }
        my $style = $session->style;
	    $style->setScript($url->extras('/yui/build/yahoo/yahoo-min.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/yui/build/event/event-min.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/yui/build/dom/dom-min.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/yui/build/dragdrop/dragdrop-min.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/yui/build/animation/animation-min.js'),{ type=>'text/javascript' });
	    $style->setLink($url->extras('/colorpicker/colorpicker.css'),{ type=>'text/css', rel=>"stylesheet" });
	    $style->setScript($url->extras('/colorpicker/color.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/colorpicker/key.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/yui/build/slider/slider-min.js'),{ type=>'text/javascript' });
	    $style->setScript($url->extras('/colorpicker/colorpicker.js'),{ type=>'text/javascript' });
        $style->setScript($url->extras("/styleDesigner/styleDesigner.js"), {type=>"text/javascript"});
        $style->setLink($url->extras("/styleDesigner/styleDesigner.css"), {rel=>"stylesheet", type=>"text/css"});
        $legend = "Style Designer";
        $output .= '
            <form method="post">
            <input type="submit" value="Save">
            <input type="hidden" name="step" value="6" />
            <input type="hidden" name="logoUrl" value="'.$logoUrl.'" />
            <script type="text/javascript">
            document.write(WebguiStyleDesigner.draw("^c;","'.$logoUrl.'","'.$storageId.'"));
            </script>
            <input type="submit" value="Save">
            </form>
            ';
	} 
    elsif ($session->form->process("step") eq "6") {
            my $importNode = WebGUI::Asset->getImportNode($session);
            my $form = $session->form;
            my $snippet = '/* auto generated by WebGUI '.$WebGUI::VERSION.' */
.clearFloat { clear: both; }
body { background-color: '.$form->get("pageBackgroundColor").'; color: '.$form->get("contentTextColor").'}
a { color: '.$form->get("linkColor").';}
a:visited { color: '.$form->get("visitedLinkColor").'; }
#editToggleContainer { padding: 1px; }
#utilityLinksContainer { float: right; padding: 1px; }
#pageUtilityContainer { font-size: 9pt; background-color: '.$form->get("utilityBackgroundColor").'; color: '.$form->get("utilityTextColor").'; }
#pageHeaderContainer { background-color: '.$form->get("headerBackgroundColor").'; color: '.$form->get("headerTextColor").'; }
#pageHeaderLogoContainer { float: left; padding: 5px; background-color: '.$form->get("headerBackgroundColor").';}
#logo { border: 0px; max-width: 300px; }
#companyNameContainer { float: right; padding: 5px; font-size: 16pt; }
#pageBodyContainer { background-color: '.$form->get("contentBackgroundColor").'; color: '.$form->get("contentTextColor").'; }
#mainNavigationContainer { min-height: 300px; padding: 5px; float: left; width: 180px; font-size: 10pt; background-color: '.$form->get("navigationBackgroundColor").'; }
#mainNavigationContainer A, #mainNavigationContainer A:link { color: '.$form->get("navigationTextColor").'; }
#mainBodyContentContainer { padding: 5px; margin-left: 200px; font-family: serif, times new roman; font-size: 12pt; }
#pageFooterContainer { text-align: center; background-color: '.$form->get("footerBackgroundColor").'; color: '.$form->get("footerTextColor").'; }
#copyrightContainer { font-size: 8pt; }
#pageWidthContainer { margin-left: 10%; margin-right: 10%; font-family: sans-serif, helvetica, arial; border: 3px solid black; }
';
           my $css = addAsset($importNode, {
                title       => "my-style.css",
                className   => "WebGUI::Asset::Snippet",
                snippet     => $snippet,
                isHidden    => 1,
                mimeType    => "text/css",
                });
    my $styleTemplate = '<html> 
<head>
<title>^Page(title); - ^c;</title>
<link type="text/css" href="'.$css->getUrl.'" rel="stylesheet" />
<tmpl_var head.tags>
</head>
<body>
^AdminBar;
<div id="pageWidthContainer">
    <div id="pageUtilityContainer">
        <div id="utilityLinksContainer">^a(^@;); :: ^LoginToggle; :: ^r(Print!);</div>
        <div id="editToggleContainer">^AdminToggle;</div>
        <div class="clearFloat"></div>
    </div>
    <div id="pageHeaderContainer">
        <div id="companyNameContainer">^c;</div>
        <div id="pageHeaderLogoContainer"><a href="^H(linkonly);"><img src="'.$form->get("logoUrl").'" id="logo" alt="logo" /></a></div>
        <div class="clearFloat"></div>
    </div>
    <div id="pageBodyContainer">
        <div id="mainNavigationContainer"><p>^AssetProxy("flexmenu");</p></div>
        <div id="mainBodyContentContainer">
        <tmpl_var body.content>
        </div>
        <div class="clearFloat"></div>
    </div>
    <div id="pageFooterContainer">
        <div id="copyrightContainer">&copy;^D(%y); ^c;. All Rights Reserved.</div>
        <div class="clearFloat"></div>
    </div>
</div>



</body>
</html>';
        my $style = addAsset($importNode, {
                className   => "WebGUI::Asset::Template",
                title       => "My Style",
                isHidden    => 1,
                namespace   => "style",
                template    => $styleTemplate
            });
        $session->setting->set("userFunctionStyleId",$style->getId);

        # collect new page info
        my $f = WebGUI::HTMLForm->new($session,action=>$session->url->gateway());
        $f->hidden(name=>"step", value=>"7");
        $f->hidden(name=>"styleTemplateId", value=>$style->getId);
        $f->yesNo(name=>"contactUs",label=>"Contact Us");
        $f->yesNo(name=>"calendar",label=>"Calendar");
        $f->yesNo(name=>"wiki",label=>"Wiki");
        $f->yesNo(name=>"search",label=>"Search");
        $f->yesNo(name=>"aboutUs",label=>"About Us");
        $f->HTMLArea(name=>"aboutUsContent", richEditId=>"PBrichedit000000000002", 
            value=>"Put your about us content here.");
        if (isIn("WebGUI::Asset::Wobject::Collaboration", @{$session->config->get("assets")})) {
            $f->yesNo(name=>"news",label=>"News");
            $f->yesNo(name=>"forums",label=>"Forums");
            $f->textarea(name=>"forumNames",subtext=>"One forum name per line", 
                value=>"Support\nGeneral Discussion");
        }
        $f->submit;
        $legend = "Initial Pages";
        $output .= $f->print;
	} 
    elsif ($session->form->process("step") eq "7") {
        my $home = WebGUI::Asset->getDefault($session);
        my $form = $session->form;

        # update default site style
        foreach my $asset (@{$home->getLineage(["self","descendants"], {returnObjects=>1})}) {
            if (defined $asset) {
                  $asset->update({styleTemplateId=>$form->get("styleTemplateId")});
            }
        }

        # add new pages
        if ($form->get("aboutUs")) {
            my $page = addPage($home, "About Us");
            addAsset($page, {
                title               => "About Us",
                isHidden            => 1,
                className           => "WebGUI::Asset::Wobject::Article",
                description         => $form->get("aboutUsContent"),
                });
        }

        # add forums
        if ($form->get("forums")) {
            my $page = addPage($home, "Forums");
            my $board = addAsset($page, {
                title               => "Forums",
                isHidden            => 1,
                className           => "WebGUI::Asset::Wobject::MessageBoard",
                description         => "Discuss your ideas and get help from our community.",
                });
            my $forumNames = $form->get("forumNames");
            $forumNames =~ s/\r//g;
            foreach my $forumName (split "\n", $forumNames) {
                next if $forumName eq "";
                addAsset($board, {
                    title       => $forumName,
                    isHidden    => 1, 
                    className   => "WebGUI::Asset::Wobject::Collaboration"
                    });
            }
        }

        # add news 
        if ($form->get("news")) {
            my $page = addPage($home, "News");
            addAsset($page, {
                title                   => "News",
                isHidden                => 1,
                className               => "WebGUI::Asset::Wobject::Collaboration",
                collaborationTemplateId => "PBtmpl0000000000000112",
                allowReplies            => 0,
                attachmentsPerPost      => 5,
                postFormTemplateId      => "PBtmpl0000000000000068",
                threadTemplateId        => "PBtmpl0000000000000067",
                description             => "All the news you need to know.",
                });
        }

        # add wiki
        if ($form->get("wiki")) {
            my $page = addPage($home, "Wiki");
            addAsset($page, {
                title               => "Wiki",
                isHidden            => 1,
                allowAttachments    => 5,
                className           => "WebGUI::Asset::Wobject::WikiMaster",
                description         => "Welcome to our wiki. Here you can help us keep information up to date.",
                });
        }

        # add calendar
        if ($form->get("calendar")) {
            my $page = addPage($home, "Calendar");
            addAsset($page, {
                title               => "Calendar",
                isHidden            => 1,
                className           => "WebGUI::Asset::Wobject::Calendar",
                description         => "Check out what's going on.",
                });
        }

        # add contact us
        if ($form->get("contactUs")) {
            my $page = addPage($home, "Contact Us");
            my $i18n = WebGUI::International->new($session, "Asset_DataForm");
            my $dataForm = addAsset($page, {
                title               => "Contact Us",
                isHidden            => 1,
                className           => "WebGUI::Asset::Wobject::DataForm",
                description         => "We welcome your feedback.",
                acknowledgement     => "Thanks for for your interest in ^c;. We'll review your message shortly.",
                mailData            => 1,
                });
		    $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
			    DataForm_fieldId=>"new",
			    DataForm_tabId=>0,
			    name=>"from",
			    label=>"Your Email Address",
			    status=>"required",
			    isMailField=>1,
			    width=>0,
			    type=>"email"
			    });
		    $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
			    DataForm_fieldId=>"new",
			    DataForm_tabId=>0,
			    name=>"to",
			    label=>$i18n->get(11),
			    status=>"hidden",
			    isMailField=>1,
			    width=>0,
			    type=>"email",
			    defaultValue=>$session->setting->get("companyEmail")
			    });
		    $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
			    DataForm_fieldId=>"new",
			    DataForm_tabId=>0,
			    name=>"cc",
			    label=>$i18n->get(12),
			    status=>"hidden",
			    isMailField=>1,
			    width=>0,
			    type=>"email"
			    });
		    $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
			    DataForm_fieldId=>"new",
			    DataForm_tabId=>0,
			    name=>"bcc",
			    label=>$i18n->get(13),
			    status=>"hidden",
			    isMailField=>1,
			    width=>0,
			    type=>"email"
			    });
		    $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
			    DataForm_fieldId=>"new",
			    DataForm_tabId=>0,
			    name=>"subject",
			    label=>$i18n->get(14),
			    status=>"hidden",
			    isMailField=>1,
			    width=>0,
			    type=>"text",
			    defaultValue=>"Contact Us",
			    });
            $dataForm->setCollateral("DataForm_field","DataForm_fieldId",{
                DataForm_fieldId    =>"new",
                width               => "",
                name                => "comments",
                label               => "Comments",
                DataForm_tabId      => 0,
                status              => "required",
                type                => "textarea",
                possibleValues      => undef,
                defaultValue        => undef,
                subtext             => "Tell us how we can assist you.",
                rows                => undef,
                vertical            => undef,
                extras              => undef,
                }, "1","1", undef);
        }

        # add search
        if ($form->get("search")) {
            my $page = addPage($home, "Search");
            addAsset($page, {
                title               => "Search",
                isHidden            => 1,
                className           => "WebGUI::Asset::Wobject::Search",
                description         => "Can't find what you're looking for? Try our search.",
                searchRoot          => $home->getId,
                });
        }

        # commit the working tag
        my $working = WebGUI::VersionTag->getWorking($session);
        $working->set({name=>"Initial Site Setup"});
        $working->commit;

        # remove init state
		$session->setting->remove('specialState');
		$session->http->setRedirect($session->url->gateway());
		return undef;
	} 
    else {
        $legend = "Admin Acccount";
		my $u = WebGUI::User->new($session,'3');
		my $f = WebGUI::HTMLForm->new($session,action=>$session->url->gateway());
		$f->hidden( -name=>"step", -value=>"2");
		$f->text(
			-name=>"username",
			-value=>$u->username,
			-label=>$i18n->get(50),
			-hoverHelp=>$i18n->get('50 setup description'),
			);
		$f->text(
			-name=>"identifier",
			-value=>"123qwe",
			-label=>$i18n->get(51),
			-hoverHelp=>$i18n->get('51 description'),
			-subtext=>'<div style=\"font-size: 10px;\">('.$i18n->get("password clear text").')</div>'
			);
		$f->email(
			-name=>"email",
			-value=>$u->profileField("email"),
			-label=>$i18n->get(56),
			-hoverHelp=>$i18n->get('56 description'),
			);
		$f->submit;
		$output .= $f->print; 
	}
	my $page  = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>WebGUI Initial Configuration :: '.$legend.'</title>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <script type="text/javascript">
function getWebguiProperty (propName) {
var props = new Array();
props["extrasURL"] = "'.$session->url->extras().'";
props["pageURL"] = "'.$session->url->page(undef, undef, 1).'";
return props[propName];
}
</script>'. $session->style->generateAdditionalHeadTags .'
		<style type="text/css">';
    if ($session->form->process("step") != 5) {
        $page .= ' #initBox {
            font-family: georgia, helvetica, arial, sans-serif; color: white; z-index: 10; 
            top: 5%; left: 10%; position: absolute;
            }
            #initBoxSleeve {
                width: 770px;
                height: 475px;
            }
		a { color: black; }
		a:visited { color: black;}
        body { margin: 0; }
            ';
    }
    else {
        $page .= '
            #initBox {
                font-family: georgia, helvetica, arial, sans-serif; color: white; z-index: 10; width: 98%; 
                 height: 98%; top: 10; left: 10; position: absolute;
        }
        ';
    }
    $page .= ' </style> </head> <body> 
            <div id="initBox"><h1>'.$legend.'</h1><div id="initBoxSleeve"> '.$output.'</div></div>
         <img src="'.$session->url->extras('background.jpg').'" style="border-style:none;position: absolute; top: 0; left: 0; width: 100%; height: 1000px; z-index: 1;" />
	</body> </html>';
	$session->http->setCacheControl("none");
	$session->http->setMimeType("text/html");
    return $page;
}

1;

