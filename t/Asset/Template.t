#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2008 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use FindBin;
use strict;
use lib "$FindBin::Bin/../lib";

use WebGUI::Test;
use WebGUI::Session;
use WebGUI::Asset::Template;
use Test::More tests => 15; # increment this value for each test you create
use Test::Deep;

my $session = WebGUI::Test->session;

my $list = WebGUI::Asset::Template->getList($session);
cmp_deeply($list, {}, 'getList with no classname returns an empty hashref');

my $tmplText = " <tmpl_var variable> <tmpl_if conditional>true</tmpl_if> <tmpl_loop loop>XY</tmpl_loop> ";
my %var = (
	variable=>"AAAAA",
	conditional=>1,
	loop=>[{},{},{},{},{}]
	);
my $output = WebGUI::Asset::Template->processRaw($session,$tmplText,\%var);
ok($output =~ m/\bAAAAA\b/, "processRaw() - variables");
ok($output =~ m/true/, "processRaw() - conditionals");
ok($output =~ m/\s(?:XY){5}\s/, "processRaw() - loops");

my $importNode = WebGUI::Asset::Template->getImportNode($session);
my $template = $importNode->addChild({className=>"WebGUI::Asset::Template", title=>"test", url=>"testingtemplates", template=>$tmplText, namespace=>'WebGUI Test Template'});
isa_ok($template, 'WebGUI::Asset::Template', "creating a template");

is($template->get('parser'), 'WebGUI::Asset::Template::HTMLTemplate', 'default parser is HTMLTemplate');

$var{variable} = "BBBBB";
$output = $template->process(\%var);
ok($output =~ m/\bBBBBB\b/, "process() - variables");
ok($output =~ m/true/, "process() - conditionals");
ok($output =~ m/\s(?:XY){5}\s/, "process() - loops");

my $newList = WebGUI::Asset::Template->getList($session, 'WebGUI Test Template');
ok(exists $newList->{$template->getId}, 'Uncommitted template exists returned from getList');

my $newList2 = WebGUI::Asset::Template->getList($session, 'WebGUI Test Template', "assetData.status='approved'");
ok(!exists $newList2->{$template->getId}, 'extra clause to getList prevents uncommitted template from being displayed');

$template->update({isDefault=>1});
is($template->get('isDefault'), 1, 'isDefault set to 1');
my $templateCopy = $template->duplicate();
is($templateCopy->get('isDefault'), 0, 'isDefault set to 0 on copy');

my $template3 = $importNode->addChild({
    className => "WebGUI::Asset::Template",
    title     => 'headBlock test',
    headBlock => "tag1 tag2 tag3",
    template  => "this is a template",
});

ok(!$template3->get('headBlock'),    'headBlock is empty');
is($template3->get('extraHeadTags'), 'tag1 tag2 tag3', 'extraHeadTags contains headBlock info');

$template->purge;
$templateCopy->purge;
$template3->purge;
WebGUI::VersionTag->getWorking($session)->rollback;

