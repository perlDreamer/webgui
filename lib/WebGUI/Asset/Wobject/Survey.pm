package WebGUI::Asset::Wobject::Survey;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2006 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use WebGUI::DateTime;
use WebGUI::Grouping;
use WebGUI::HTMLForm;
use WebGUI::HTTP;
use WebGUI::Icon;
use WebGUI::Id;
use WebGUI::Style;
use WebGUI::International;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::URL;
use WebGUI::Utility;
use WebGUI::Asset::Wobject;
use Digest::MD5 qw(md5_hex);

our @ISA = qw(WebGUI::Asset::Wobject);

#-------------------------------------------------------------------
sub addAnswer {
	$_[0]->setCollateral("Survey_answer","Survey_answerId",{
		Survey_id=>$_[0]->get("Survey_id"),
		Survey_questionId=>$_[2],
		Survey_answerId=>"new",
		answer=>WebGUI::International::get($_[1],'Asset_Survey')
		},1,0,"Survey_id");
}

#-------------------------------------------------------------------
sub addSection {
	$_[0]->setCollateral("Survey_section","Survey_sectionId",{
		Survey_id=>$_[0]->get("Survey_id"),
		Survey_sectionId=>"new",
		sectionName=>$_[1]
		},1,0,"Survey_id");
}

#-------------------------------------------------------------------
sub completeResponse {
	my $self = shift;
	my $responseId = shift;
	$self->session->db->setRow("Survey_response","Survey_responseId",{
		'Survey_responseId'=>$responseId,
		isComplete=>1
		});
	$self->session->scratch->delete($self->getResponseIdString);
}

#-------------------------------------------------------------------
sub definition {
        my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
		assetName=>WebGUI::International::get('assetName','Asset_Survey'),
		uiLevel => 5,
		icon=>'survey.gif',
		tableName	=> 'Survey',
		className	=> 'WebGUI::Asset::Wobject::Survey',
                properties	=> {
			templateId => {
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000061'
				},
			Survey_id => {
				fieldType	=> 'text',
				defaultValue	=> undef
				}, 
			questionOrder => {
				fieldType	=> 'text',
				defaultValue	=> 'sequential'
				}, 
			groupToTakeSurvey => {
				fieldType	=> 'group',
				defaultValue	=> 2
				}, 
			groupToViewReports => {
				fieldType	=> 'group',
				defaultValue	=> 4
				},
			mode => {
				fieldType 	=> 'text',
				defaultValue	=> 'survey'
				},
			anonymous=>{
				fieldType	=> 'yesNo',
				defaultValue	=> 0
				},
			maxResponsesPerUser=>{
				fieldType	=> 'integer',
				defaultValue	=> 1
				},
			questionsPerResponse=>{
				fieldType	=> 'integer',
				defaultValue	=>99999
				},
			questionsPerPage=>{
				fieldType	=> 'integer',
				defaultValue	=> 1
				},
			overviewTemplateId=>{
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000063'
				},
			gradebookTemplateId => {
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000062'
				},
			responseTemplateId => {
				fieldType	=> 'template',
				defaultValue	=> 'PBtmpl0000000000000064'
				},
			}
		});
	return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub duplicate {
	my ($self, $newAsset, $newSurveyId, $qdata, $adata, $rdata, $sdata, $oldSectionId);
	
	$self = shift;
	
	$newAsset = $self->SUPER::duplicate(shift);
	$newSurveyId = WebGUI::Id::generate();
	$newAsset->update({
		Survey_id=>$newSurveyId
		});
		
	my $section = $self->session->db->read("select * from Survey_section where Survey_id=".$self->session->db->quote($self->get("Survey_id"))
			." order by sequenceNumber");
	while ($sdata = $section->hashRef) {
		$oldSectionId = $sdata->{Survey_sectionId};
		$sdata->{Survey_sectionId} = "new";
		$sdata->{Survey_Id} = $newSurveyId;
		$sdata->{Survey_sectionId} = $newAsset->setCollateral("Survey_section", "Survey_sectionId",$sdata,1,0, "Survey_id");
	
	  my $questions = $self->session->db->read("select * from Survey_question where Survey_id=".$self->session->db->quote($self->get("Survey_id"))
			." and Survey_sectionId=".$self->session->db->quote($oldSectionId)." order by sequenceNumber");
	  while ($qdata = $questions->hashRef) {
		my $answers = $self->session->db->read("select * from Survey_answer where Survey_questionId=".$self->session->db->quote($qdata->{Survey_questionId})
			." order by sequenceNumber");
		$qdata->{Survey_questionId} = "new";
		$qdata->{Survey_id} = $newSurveyId;
		$qdata->{Survey_sectionId} = $sdata->{Survey_sectionId};
		$qdata->{Survey_questionId} = $newAsset->setCollateral("Survey_question","Survey_questionId",$qdata,1,0,"Survey_id");
		while ($adata = $answers->hashRef) {
			my $responses = $self->session->db->read("select * from Survey_questionResponse where Survey_answerId=".$self->session->db->quote($adata->{Survey_answerId}));
			$adata->{Survey_answerId} = "new";
			$adata->{Survey_questionId} = $qdata->{Survey_questionId};
			$adata->{Survey_id} = $newSurveyId;
			$adata->{Survey_answerId} = $newAsset->setCollateral("Survey_answer", "Survey_answerId", $adata, 
				1, 0, "Survey_Id");
			while ($rdata = $responses->hashRef) {
				$rdata->{Survey_responseId} = "new";
				$rdata->{Survey_answerId} = $adata->{Survey_answerId};
				$rdata->{Survey_id} = $newSurveyId;
				$rdata->{Survey_questionId} = $qdata->{Survey_questionId};
				$newAsset->setCollateral("Survey_response","Survey_responseId",$rdata,0,0);
			}
			$responses->finish;
		}
		$answers->finish;
	  }
	  $questions->finish;
	
	}
	$section->finish;
	
	return $newAsset;
}

#-------------------------------------------------------------------
sub generateResponseId {
	my $self = shift;
	my $varname = $self->getResponseIdString;
	if ($session{scratch}{$varname}) {
		$self->completeResponse;
	}
	my $ipAddress = $self->getIp; 
	my $userId = $self->getUserId; 
	my $responseId = $self->session->db->setRow("Survey_response","Survey_responseId",{
		'Survey_responseId'=>"new",
		userId=>$userId,
		ipAddress=>$ipAddress,
		username=>$self->session->user->profileField("username"),
		startDate=>$self->session->datetime->time(),
		'Survey_id'=>$self->get("Survey_id")
		});
	$self->session->scratch->set($varname,$responseId);
	return $responseId;
}

#-------------------------------------------------------------------
sub getEditForm {
	my $self = shift;
	my $tabform = $self->SUPER::getEditForm;

	$tabform->getTab('properties')->hidden(
		-name => "Survey_id",
		-value => ($self->get("Survey_id") || WebGUI::Id::generate())
	);
	$tabform->getTab('display')->template(
		-name		=> 'templateId',
		-label		=> WebGUI::International::get('view template', 'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('view template description', 'Asset_Survey'),
		-value		=> $self->getValue('templateId'),
		-namespace	=> 'Survey',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'responseTemplateId',
		-label		=> WebGUI::International::get('response template', 'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('response template description', 'Asset_Survey'),
		-value		=> $self->getValue('responseTemplateId'),
		-namespace	=> 'Survey/Response',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'gradebookTemplateId',
		-label		=> WebGUI::International::get('gradebook template', 'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('gradebook template description', 'Asset_Survey'),
		-value		=> $self->getValue('gradebookTemplateId'),
		-namespace	=> 'Survey/Gradebook',
		-afterEdit	=> 'func=edit'
		);
	$tabform->getTab('display')->template(
		-name		=> 'overviewTemplateId',
		-label		=> WebGUI::International::get('overview template', 'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('overview template description', 'Asset_Survey'),
		-value		=> $self->getValue('overviewTemplateId'),
		-namespace	=> 'Survey/Overview',
		-afterEdit	=> 'func=edit'
		);

	$tabform->getTab('display')->selectBox(
		-name		=> "questionOrder",
		-options	=> {
			sequential => WebGUI::International::get(5,'Asset_Survey'),
                	random => WebGUI::International::get(6,'Asset_Survey'),
                	response => WebGUI::International::get(7,'Asset_Survey'),
                	section => WebGUI::International::get(106, 'Asset_Survey')
			},
		-label		=> WebGUI::International::get(8,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('8 description','Asset_Survey'),
		-value		=> [$self->getValue("questionOrder")]
		);
	$tabform->getTab('display')->integer(
		-name		=> "questionsPerPage",
		-value		=> $self->getValue("questionsPerPage"),
		-label		=> WebGUI::International::get(83,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('83 description','Asset_Survey')
		);
        $tabform->getTab('properties')->selectBox(
                -name	=> "mode",
                -options	=> {
			survey => WebGUI::International::get(9,'Asset_Survey'),
                	quiz => WebGUI::International::get(10,'Asset_Survey')
			},
                -label		=> WebGUI::International::get(11,'Asset_Survey'),
                -hoverHelp	=> WebGUI::International::get('11 description','Asset_Survey'),
                -value		=> [$self->getValue("mode")]
                );
	$tabform->getTab('properties')->yesNo(
		-name		=> "anonymous",
               	-value		=> $self->getValue("anonymous"),
               	-label		=> WebGUI::International::get(81,'Asset_Survey'),
               	-hoverHelp	=> WebGUI::International::get('81 description','Asset_Survey')
               	);
	$tabform->getTab('properties')->integer(
		-name		=> "maxResponsesPerUser",
		-value		=> $self->getValue("maxResponsesPerUser"),
		-label		=> WebGUI::International::get(84,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('84 description','Asset_Survey')
		);
	$tabform->getTab('properties')->integer(
		-name		=> "questionsPerResponse",
		-value		=> $self->getValue("questionsPerResponse"),
		-label		=> WebGUI::International::get(85,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('85 description','Asset_Survey')
		);	
	$tabform->getTab('security')->group(
		-name		=> "groupToTakeSurvey",
		-value		=> [$self->getValue("groupToTakeSurvey")],
		-label		=> WebGUI::International::get(12,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('12 description','Asset_Survey')
		);
        $tabform->getTab('security')->group(
                -name		=> "groupToViewReports",
                -label		=> WebGUI::International::get(13,'Asset_Survey'),
                -hoverHelp	=> WebGUI::International::get('13 description','Asset_Survey'),
                -value		=> [$self->getValue("groupToViewReports")]
                );
	if ($self->get("assetId") eq "new") {
		$tabform->getTab('properties')->whatNext(
			-options=>{
				editQuestion=>WebGUI::International::get(28,'Asset_Survey'),
				viewParent=>WebGUI::International::get(745,'Asset_Survey')
				},
			-value=>"editQuestion",
                        -hoverHelp	=> WebGUI::International::get('what next description','Asset_Survey'),
			);
	}

	return $tabform;
}

#-------------------------------------------------------------------
sub getIp {
	my $self = shift;
	my $ip = ($self->get("anonymous")) ? substr(md5_hex($self->session->env->get("REMOTE_ADDR")),0,8) : $self->session->env->get("REMOTE_ADDR");
	return $ip;
}

#-------------------------------------------------------------------
sub getMenuVars {
	my $self = shift;
	my %var;
	$var{'user.canViewReports'} = ($self->session->user->isInGroup($self->get("groupToViewReports")));
	$var{'delete.all.responses.url'} = $self->getUrl('func=deleteAllResponses');
	$var{'delete.all.responses.label'} = WebGUI::International::get(73,'Asset_Survey');
	$var{'export.answers.url'} = $self->getUrl('func=exportAnswers');
	$var{'export.answers.label'} = WebGUI::International::get(62,'Asset_Survey');
	$var{'export.questions.url'} = $self->getUrl('func=exportQuestions');
	$var{'export.questions.label'} = WebGUI::International::get(63,'Asset_Survey');
	$var{'export.responses.url'} = $self->getUrl('func=exportResponses');
	$var{'export.responses.label'} = WebGUI::International::get(64,'Asset_Survey');
	$var{'export.composite.url'} = $self->getUrl('func=exportComposite');
	$var{'export.composite.label'} = WebGUI::International::get(65,'Asset_Survey');
	$var{'report.gradebook.url'} = $self->getUrl('func=viewGradebook');
	$var{'report.gradebook.label'} = WebGUI::International::get(61,'Asset_Survey');
	$var{'report.overview.url'} = $self->getUrl('func=viewStatisticalOverview');
	$var{'report.overview.label'} = WebGUI::International::get(59,'Asset_Survey');
        $var{'survey.url'} = $self->getUrl;
	$var{'survey.label'} = WebGUI::International::get(60,'Asset_Survey');
	return \%var;
}

#-------------------------------------------------------------------
sub getQuestionCount {
	my $self = shift;
	my ($count) = $self->session->db->quickArray("select count(*) from Survey_question where Survey_id=".$self->session->db->quote($self->get("Survey_id")));
	return ($count < $self->getValue("questionsPerResponse")) ? $count : $self->getValue("questionsPerResponse");
}

#-------------------------------------------------------------------
sub getQuestionsLoop {
	my $self = shift;
	my $responseId = shift;
	my @ids;
	if ($self->get("questionOrder") eq "sequential") {
		@ids = $self->getSequentialQuestionIds($responseId);
	} elsif ($self->get("questionOrder") eq "response") {
		@ids = $self->getResponseDrivenQuestionIds($responseId);
	} elsif ($self->get("questionOrder") eq "section") {
		@ids = $self->getSectionDrivenQuestionIds($responseId);
	} else {
		@ids = $self->getRandomQuestionIds($responseId);
	}
	my $length = scalar(@ids);
	my $i = 1;
	my @loop;
	
	#Ignore questions per page when using sections, return all questions for current section
	if ($self->get("questionOrder") eq "section") {
	  while ($i <= $length) {
	  	push(@loop,$self->getQuestionVars($ids[($i-1)]));
	  	$i++;
	  }
	  return \@loop;
	}
	
	my $questionResponseCount = $self->getQuestionResponseCount($responseId);
	while ($i <= $length && $i<= $self->get("questionsPerPage") && ($questionResponseCount + $i) <= $self->getValue("questionsPerResponse")) {
		push(@loop,$self->getQuestionVars($ids[($i-1)]));
		$i++;
	}
	return \@loop;
}


#-------------------------------------------------------------------
sub getQuestionResponseCount {
	my $self = shift;
	my $responseId = shift;
	my ($count) = $self->session->db->quickArray("select count(*) from Survey_questionResponse where Survey_responseId=".$self->session->db->quote($responseId));
	return $count;
}

#-------------------------------------------------------------------
sub getQuestionVars {
	my $self = shift;
	my $questionId = shift;
	my %var;
	my $question = $self->session->db->getRow("Survey_question","Survey_questionId",$questionId);
	$var{'question.question'} = $question->{question};
	$var{'question.allowComment'} = $question->{allowComment};
	$var{'question.id'} = $question->{Survey_questionId};
	$var{'question.comment.field'} = WebGUI::Form::textarea({
		name=>'comment_'.$questionId
		});
	$var{'question.comment.label'} = WebGUI::International::get(51,'Asset_Survey');

	my $answer;
	($answer) = $self->session->db->quickArray("select Survey_answerId from Survey_answer where Survey_questionId=".$self->session->db->quote($question->{Survey_questionId}));
	$var{'question.answer.field'} = WebGUI::Form::hidden({
			name=>'answerId_'.$questionId,
			value=>$answer
			});
	if ($question->{answerFieldType} eq "text") {
		$var{'question.answer.field'} .= WebGUI::Form::text({
			name=>'textResponse_'.$questionId
			});
	} elsif ($question->{answerFieldType} eq "HTMLArea") {
		$var{'question.answer.field'} .= WebGUI::Form::HTMLArea({
			name=>'textResponse_'.$questionId
			});
	} elsif ($question->{answerFieldType} eq "textArea") {
		$var{'question.answer.field'} .= WebGUI::Form::textarea({
			name=>'textResponse_'.$questionId
			});
	} else {
		my $answer = $self->session->db->buildHashRef("select Survey_answerId,answer from Survey_answer where Survey_questionId=".$self->session->db->quote($question->{Survey_questionId})." order by sequenceNumber");
		if ($question->{randomizeAnswers}) {
			$answer = randomizeHash($answer);
		}
		$var{'question.answer.field'} = WebGUI::Form::radioList({
			options=>$answer,
			name=>"answerId_".$questionId,
			vertical=>1
			});
	}
	return \%var;
}

#-------------------------------------------------------------------
sub getRandomQuestionIds {
	my $self = shift;
	my $responseId = shift;
	my @usedQuestionIds = $self->session->db->buildArray("select Survey_questionId from Survey_questionResponse where Survey_responseId=".$self->session->db->quote($responseId));
	my $where = " where Survey_id=".$self->session->db->quote($self->get("Survey_id"));
	if ($#usedQuestionIds+1 > 0) {
		$where .= " and Survey_questionId not in (".$self->session->db->quoteAndJoin(\@usedQuestionIds).")";
	}
	my @questions = $self->session->db->buildArray("select Survey_questionId from Survey_question".$where);
	randomizeArray(\@questions);
	return @questions;
}

#-------------------------------------------------------------------
sub getResponseCount {
	my $self = shift;
	my $ipAddress = $self->getIp;
	my $userId = $self->getUserId;
	my ($count) = $self->session->db->quickArray("select count(*) from Survey_response where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." and 
		((userId<>'1' and userId=".$self->session->db->quote($userId).") or ( userId='1' and ipAddress=".$self->session->db->quote($ipAddress)."))");
	return $count;
}


#-------------------------------------------------------------------
sub getResponseDrivenQuestionIds {
	my $self = shift;
	my $responseId = shift;
        my $previousResponse = $self->session->db->quickHashRef("select Survey_questionId, Survey_answerId from Survey_questionResponse 
		where Survey_responseId=".$self->session->db->quote($responseId)." order by dateOfResponse desc");
	my $questionId;
	my @questions;
	if ($previousResponse->{Survey_answerId}) {
	        ($questionId) = $self->session->db->quickArray("select gotoQuestion from Survey_answer where 
			Survey_answerId=".$self->session->db->quote($previousResponse->{Survey_answerId}));
	        unless ($questionId) { 
			($questionId) = $self->session->db->quickArray("select gotoQuestion from Survey_question where 
				Survey_questionId=".$self->session->db->quote($previousResponse->{Survey_questionId}));
		}
		unless ($questionId) { # terminate survey
			$self->completeResponse($responseId);	
			return ();
		}
	} else {
		($questionId) = $self->session->db->quickArray("select Survey_questionId from Survey_question where Survey_id=".$self->session->db->quote($self->getValue("Survey_id"))."
			order by sequenceNumber");
	}
	push(@questions,$questionId);
	return @questions;
}

#-------------------------------------------------------------------
sub getSectionDrivenQuestionIds {
	my $self = shift;
	my $responseId = shift;
	my @usedQuestionIds = $self->session->db->buildArray("select Survey_questionId from Survey_questionResponse where Survey_responseId=".$self->session->db->quote($responseId));
	my @questions;
	my $where = " where Survey_question.Survey_id=".$self->session->db->quote($self->get("Survey_id"));
	$where .= " and Survey_question.Survey_sectionId=Survey_section.Survey_sectionId";	
	
	if ($#usedQuestionIds+1 > 0) {
		$where .= " and Survey_questionId not in (".$self->session->db->quoteAndJoin(\@usedQuestionIds).")";
	}
		
	my $sth = $self->session->db->read("select Survey_questionId, Survey_question.Survey_sectionId from Survey_question,
			Survey_section $where order by Survey_section.sequenceNumber, Survey_question.sequenceNumber");

	my $loopCount=0;
	my $currentSection;
	while (my $hashRef = $sth->hashRef) {
	  if ($loopCount == 0){ $currentSection = $hashRef->{Survey_sectionId}; }
	  if ($currentSection eq $hashRef->{Survey_sectionId}) {
	    push (@questions, $hashRef->{Survey_questionId});
	  }
	  $loopCount++;
	}
	$sth->finish;
	return @questions;
}



#-------------------------------------------------------------------
sub getResponseId {
	my $self = shift;
	return $session{scratch}{$self->getResponseIdString};
}

#-------------------------------------------------------------------
sub getResponseIdString {
	my $self = shift;
	return "Survey-".$self->get("Survey_id")."-ResponseId";
}


#-------------------------------------------------------------------
sub getSequentialQuestionIds {
	my $self = shift;
	my $responseId = shift;
	my @usedQuestionIds = $self->session->db->buildArray("select Survey_questionId from Survey_questionResponse where Survey_responseId=".$self->session->db->quote($responseId));
	my $where = " where Survey_id=".$self->session->db->quote($self->get("Survey_id"));
	if ($#usedQuestionIds+1 > 0) {
		$where .= " and Survey_questionId not in (".$self->session->db->quoteAndJoin(\@usedQuestionIds).")";
	}
	my @questions = $self->session->db->buildArray("select Survey_questionId from Survey_question $where order by sequenceNumber");
	return @questions;
}

#-------------------------------------------------------------------
sub getUserId {
	my $self = shift;
	my $userId = ($self->get("anonymous") && $self->session->user->profileField("userId") != 1) ? substr(md5_hex($self->session->user->profileField("userId")),0,8) : $self->session->user->profileField("userId");
	return $userId;
}

#-------------------------------------------------------------------
sub processPropertiesFromFormPost {
	my $self = shift;
	$self->SUPER::processPropertiesFromFormPost;
	if ($self->session->form->process("assetId") eq "new") {
	  $self->addSection(WebGUI::International::get(107, 'Asset_Survey'));
	}
	
}
#-------------------------------------------------------------------
sub purge {
	my ($count) = $self->session->db->quickArray("select count(*) from Survey where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
	if ($count < 2) { ### Check for other wobjects using this survey.
        	$self->session->db->write("delete from Survey_question where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
        	$self->session->db->write("delete from Survey_answer where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
        	$self->session->db->write("delete from Survey_response where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
        	$self->session->db->write("delete from Survey_section where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
	}
        $_[0]->SUPER::purge();
}


#-------------------------------------------------------------------
sub responseIsComplete {
	my $self = shift;
	my $responseId = shift;
	my $response = $self->session->db->getRow("Survey_response","Survey_responseId",$responseId);
	return $response->{isComplete};
}


#-------------------------------------------------------------------
sub setAnswerType {
	$_[0]->setCollateral("Survey_question","Survey_questionId",{
		Survey_questionId=>$_[2],
		Survey_id=>$_[0]->get("Survey_id"),
		answerFieldType=>$_[1]
		},1,0,"Survey_id");
}

#-------------------------------------------------------------------
sub view {
	my $self = shift;
	$self->logView() if ($self->session->setting->get("passiveProfilingEnabled"));
	my $var = $self->getMenuVars;
	$var->{'question.add.url'} = $self->getUrl('func=editQuestion;qid=new');
	$var->{'question.add.label'} = WebGUI::International::get(30,'Asset_Survey');
	$var->{'section.add.url'} = $self->getUrl('func=editSection;sid=new');
	$var->{'section.add.label'} = WebGUI::International::get(104,'Asset_Survey');
	my @sectionEdit;
	
	# Get Sections
	my $sth = $self->session->db->read("select Survey_sectionId,sectionName from Survey_section where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
	while (my %sectionData = $sth->hash) {
		my @edit;
		
		# Get Questions for this section
		my $sth2 = $self->session->db->read("select Survey_questionId,question from Survey_question 
		   where Survey_id=".$self->session->db->quote($self->get("Survey_id"))."
		   and Survey_sectionId=".$self->session->db->quote($sectionData{Survey_sectionId})." order by sequenceNumber");
		while (my %data = $sth2->hash) {
		  push(@edit,{
			'question.edit.controls'=>
				deleteIcon('func=deleteQuestionConfirm;qid='.$data{Survey_questionId}, $self->get("url"), WebGUI::International::get(44,'Asset_Survey')).
				editIcon('func=editQuestion;qid='.$data{Survey_questionId}, $self->get("url")).
				moveUpIcon('func=moveQuestionUp;qid='.$data{Survey_questionId}, $self->get("url")).
				moveDownIcon('func=moveQuestionDown;qid='.$data{Survey_questionId}, $self->get("url")),
			'question.edit.question'=>$data{question},
			'question.edit.id'=>$data{Survey_questionId}
		  });
		}
		$sth2->finish;
	
		push(@sectionEdit,{
			'section.edit.controls'=>
				deleteIcon('func=deleteSectionConfirm;sid='.$sectionData{Survey_sectionId}, $self->get("url"), WebGUI::International::get(105,'Asset_Survey')).
				editIcon('func=editSection;sid='.$sectionData{Survey_sectionId}, $self->get("url")).
				moveUpIcon('func=moveSectionUp;sid='.$sectionData{Survey_sectionId}, $self->get("url")).
				moveDownIcon('func=moveSectionDown;sid='.$sectionData{Survey_sectionId}, $self->get("url")),
			'section.edit.sectionName'=>$sectionData{sectionName},
			'section.edit.id'=>$sectionData{Survey_sectionId},
			'section.questions_loop'=>\@edit
			});
		$var->{'section.edit_loop'} = \@sectionEdit;
		
	}
	$sth->finish;
		
	$var->{'user.canTakeSurvey'} = $self->session->user->isInGroup($self->get("groupToTakeSurvey"));
	if ($var->{'user.canTakeSurvey'}) {
		$var->{'response.Id'} = $self->getResponseId();
		$var->{'response.Count'} = $self->getResponseCount;
		$var->{'user.isFirstResponse'} = ($var->{'response.Count'} == 0 && !(exists $var->{'response.id'}));
		$var->{'user.canRespondAgain'} = ($var->{'response.Count'} < $self->get("maxResponsesPerUser"));
		if (($var->{'user.isFirstResponse'}) || ($self->session->form->process("startNew") && $var->{'user.canRespondAgain'})) {
			$var->{'response.Id'} = $self->generateResponseId;
		}
		if ($var->{'response.Id'}) {
			$var->{'questions.soFar.count'} = $self->getQuestionResponseCount($var->{'response.Id'});
			($var->{'questions.correct.count'}) = $self->session->db->quickArray("select count(*) from Survey_questionResponse a, Survey_answer b where a.Survey_responseId="
				.$self->session->db->quote($var->{'response.Id'})." and a.Survey_answerId=b.Survey_answerId and b.isCorrect=1");
			if ($var->{'questions.soFar.count'} > 0) {
				$var->{'questions.correct.percent'} = round(($var->{'questions.correct.count'}/$var->{'questions.soFar.count'})*100)
			}
			$var->{'response.isComplete'} = $self->responseIsComplete($var->{'response.Id'});
			$var->{question_loop} = $self->getQuestionsLoop($var->{'response.Id'});
		}
	}
	$var->{'form.header'} = WebGUI::Form::formHeader($self->session,{action=>$self->getUrl})
		.WebGUI::Form::hidden({
			name=>'func',
			value=>'respond'
			});
	$var->{'form.footer'} = WebGUI::Form::formFooter($self->session,);
	$var->{'form.submit'} = WebGUI::Form::submit({
			value=>WebGUI::International::get(50,'Asset_Survey')
			});
	$var->{'questions.sofar.label'} = WebGUI::International::get(86,'Asset_Survey');
	$var->{'start.newResponse.label'} = WebGUI::International::get(87,'Asset_Survey');
	$var->{'start.newResponse.url'} = $self->getUrl("func=view;startNew=1"); 
	$var->{'thanks.survey.label'} = WebGUI::International::get(46,'Asset_Survey');
	$var->{'thanks.quiz.label'} = WebGUI::International::get(47,'Asset_Survey');
	$var->{'questions.total'} = $self->getQuestionCount;
	$var->{'questions.correct.count.label'} = WebGUI::International::get(52,'Asset_Survey');
	$var->{'questions.correct.percent.label'} = WebGUI::International::get(54,'Asset_Survey');
	$var->{'mode.isSurvey'} = ($self->get("mode") eq "survey");
	$var->{'survey.noprivs.label'} = WebGUI::International::get(48,'Asset_Survey');
	$var->{'quiz.noprivs.label'} = WebGUI::International::get(49,'Asset_Survey');
	return $self->processTemplate($var, $self->get("templateId"));
}

#-------------------------------------------------------------------
sub www_deleteAnswerConfirm {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        my ($answerCount) = $self->session->db->quickArray("select count(*) from Survey_answer where Survey_questionId=".$self->session->db->quote($self->session->form->process("qid")));
	return $_[0]->i18n("cannot delete the last answer") unless($answerCount);
        $self->session->db->write("delete from Survey_questionResponse where Survey_answerId=".$self->session->db->quote($self->session->form->process("aid")));
        $_[0]->deleteCollateral("Survey_answer","Survey_answerId",$self->session->form->process("aid"));
        $_[0]->reorderCollateral("Survey_answer","Survey_answerId","Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_deleteQuestionConfirm {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
	$self->session->db->write("delete from Survey_answer where Survey_questionId=".$self->session->db->quote($self->session->form->process("qid")));
	$self->session->db->write("delete from Survey_questionResponse where Survey_questionId=".$self->session->db->quote($self->session->form->process("qid")));
        $_[0]->deleteCollateral("Survey_question","Survey_questionId",$self->session->form->process("qid"));
        $_[0]->reorderCollateral("Survey_question","Survey_questionId","Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_deleteSectionConfirm {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        my $none = WebGUI::International::get(107, 'Asset_Survey');
        my ($sectionName) = $self->session->db->quickArray("select sectionName from Survey_section where Survey_sectionId="
        		.$self->session->db->quote($self->session->form->process("sid")));
        if ($sectionName =~ /$none/) {
	  return $self->session->privilege->vitalComponent();
	}
        
	$self->session->db->write("delete from Survey_section where Survey_sectionId=".$self->session->db->quote($self->session->form->process("sid")));
        $_[0]->deleteCollateral("Survey_section","Survey_sectionId",$self->session->form->process("sid"));
        $_[0]->reorderCollateral("Survey_section","Survey_sectionId","Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_deleteResponse {
	return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
        return $self->session->style->process($_[0]->confirm(WebGUI::International::get(72,'Asset_Survey'),
                $_[0]->getUrl('func=deleteResponseConfirm;responseId='.$self->session->form->process("responseId"))),$_[0]->getValue("styleTemplateId"));
}

#-------------------------------------------------------------------
sub www_deleteResponseConfirm {
	return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
        $self->session->db->write("delete from Survey_response where Survey_responseId=".$self->session->db->quote($self->session->form->process("responseId")));
        $self->session->db->write("delete from Survey_questionResponse where Survey_responseId=".$self->session->db->quote($self->session->form->process("responseId")));
        return $_[0]->www_viewGradebook;
}

#-------------------------------------------------------------------
sub www_deleteAllResponses {
	return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
	return $self->session->style->process($_[0]->confirm(WebGUI::International::get(74,'Asset_Survey'),$_[0]->getUrl('func=deleteAllResponsesConfirm')),$_[0]->getValue("styleTemplateId"));
}

#-------------------------------------------------------------------
sub www_deleteAllResponsesConfirm {
	return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
        $self->session->db->write("delete from Survey_response where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id"))); 
        $self->session->db->write("delete from Survey_questionResponse where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id"))); 
        return "";
}

#-------------------------------------------------------------------
sub www_editSave {
	return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
	my $output = $_[0]->SUPER::www_editSave(); 
	if ($self->session->form->process("proceed") eq "addQuestion") {
		$self->session->form->process("qid") = "new";
		return $_[0]->www_editQuestion;
	}
	return $output;
}

#-------------------------------------------------------------------
sub www_editAnswer {
        my ($question, $f, $answer, $self);
	$self = shift;
	
        return $self->session->privilege->insufficient() unless ($self->canEdit);
        
	$answer = $self->getCollateral("Survey_answer","Survey_answerId",$self->session->form->process("aid"));
        $f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
        $f->hidden(
		-name => "assetId",
		-value => $self->session->form->process("assetId")
	);
        $f->hidden(
		-name => "func",
		-value => "editAnswerSave"
	);
        $f->hidden(
		-name => "qid",
		-value => $self->session->form->process("qid")
	);
        $f->hidden(
		-name => "aid",
		-value => $answer->{Survey_answerId}
	);
        $f->text(
                -name=>"answer",
                -value=>$answer->{answer},
                -label=>WebGUI::International::get(19,'Asset_Survey'),
                -hoverHelp=>WebGUI::International::get('19 description','Asset_Survey')
                );
	if ($self->get("mode") eq "quiz") {
        	$f->yesNo(
                	-name=>"isCorrect",
                	-value=>$answer->{isCorrect},
                	-label=>WebGUI::International::get(20,'Asset_Survey'),
                	-hoverHelp=>WebGUI::International::get('20 description','Asset_Survey')
                	);
	} else {
		$f->hidden(
			-name => "isCorrect",
			-value => 0
		);
	}
	if ($self->get("questionOrder") eq "response") {
		$question = $self->session->db->buildHashRef("select Survey_questionId,question 
			from Survey_question where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
		$question = { ('-1' => WebGUI::International::get(82,'Asset_Survey'),%$question) };
		$f->selectBox(
			-name=>"gotoQuestion",
			-options=>$question,
			-value=>[$answer->{gotoQuestion}],
			-label=>WebGUI::International::get(21,'Asset_Survey'),
			-hoverHelp=>WebGUI::International::get('21 description','Asset_Survey')
			);
	}
	if ($answer->{Survey_answerId} eq "new") {
                my %options;
                tie %options, 'Tie::IxHash';
                %options = (
                        "addAnswer"=>WebGUI::International::get(24,'Asset_Survey'),
                        "addQuestion"=>WebGUI::International::get(28,'Asset_Survey'),
                        "editQuestion"=>WebGUI::International::get(75,'Asset_Survey'),
                        "backToPage"=>WebGUI::International::get(745,'Asset_Survey')
                        );
                $f->whatNext(
                        -options=>\%options,
                        -value=>"addAnswer",
			-hoverHelp=>WebGUI::International::get('what next answer description','Asset_Survey')
                        );
        }
        $f->submit;

#	$self->getAdminConsole->setHelp("answer add/edit","Asset_Survey");
	return $self->getAdminConsole->render($f->print, WebGUI::International::get(18,'Asset_Survey'));

}

#-------------------------------------------------------------------
sub www_editAnswerSave {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->setCollateral("Survey_answer", "Survey_answerId", {
                Survey_answerId => $self->session->form->process("aid"),
                Survey_questionId => $self->session->form->process("qid"),
                answer => $self->session->form->process("answer"),
                isCorrect => $self->session->form->process("isCorrect"),
		Survey_id=>$_[0]->get("Survey_id"),
                gotoQuestion => $self->session->form->process("gotoQuestion")
                },1,0,"Survey_Id");
	if ($self->session->form->process("proceed") eq "addQuestion") {
                $self->session->form->process("qid") = "new";
	} elsif ($self->session->form->process("proceed") eq "addAnswer") {
		$self->session->form->process("aid") = "new";
		return $_[0]->www_editAnswer();
	} elsif ($self->session->form->process("proceed") eq "backToPage") {
		return "";
        }
        return $_[0]->www_editQuestion();
}

#-------------------------------------------------------------------
sub www_editQuestion {
	my ($f, $question, $answerFieldType, $sth, %data, $self);
	$self = shift;

	return $self->session->privilege->insufficient() unless ($self->canEdit);

	tie %data, 'Tie::CPHash';
	$question = $self->getCollateral("Survey_question","Survey_questionId",$self->session->form->process("qid"));
	$answerFieldType = $question->{answerFieldType} || "radioList";
	
	$f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
	$f->hidden(
		-name => "assetId",
		-value => $self->get("assetId")
	);
	$f->hidden(
		-name => "func",
		-value => "editQuestionSave"
	);
	$f->hidden(
		-name => "qid",
		-value => $question->{Survey_questionId}
	);
	$f->hidden(
		-name => "answerFieldType",
		-value => $answerFieldType
	);
	$f->HTMLArea(
		-name	=> "question",
		-value	=> $question->{question},
		-label	=> WebGUI::International::get(14,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('14 description','Asset_Survey')
		);
	$f->yesNo(
		-name	=> "allowComment",
		-value	=> $question->{allowComment},
		-label	=> WebGUI::International::get(15,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('15 description','Asset_Survey')
		);
	$f->yesNo(
		-name	=> "randomizeAnswers",
		-value	=> $question->{randomizeAnswers},
		-label	=> WebGUI::International::get(16,'Asset_Survey'),
		-hoverHelp	=> WebGUI::International::get('16 description','Asset_Survey')
		);
	
	my $sectionList = $self->session->db->buildHashRef("select Survey_sectionId,sectionName
			  from Survey_section where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
			  
	$f->selectBox(
			-name	=> "section",
			-options=> $sectionList,
			-value	=> [$question->{Survey_sectionId}],
			-label	=> WebGUI::International::get(106, 'Asset_Survey')
		      );
			
	if ($self->get("questionOrder") eq "response") {
		my $ql = $self->session->db->buildHashRef("select Survey_questionId,question 
			from Survey_question where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
		$ql = { ('-1' => WebGUI::International::get(82,'Asset_Survey'),%$ql) };
		$f->selectBox(
			-name	=> "gotoQuestion",
			-options=> $ql,
			-value	=> [$question->{gotoQuestion}],
			-label	=> WebGUI::International::get(21,'Asset_Survey'),
			-hoverHelp	=> WebGUI::International::get('21 description','Asset_Survey')
			);
	}
	
	if ($question->{Survey_questionId} eq "new") {
		my %options;
		tie %options, 'Tie::IxHash';
		%options = (
			"addMultipleChoiceAnswer"	=> WebGUI::International::get(24,'Asset_Survey'),
                        "addTextAnswer"			=> WebGUI::International::get(29,'Asset_Survey'),
                        "addBooleanAnswer"		=> WebGUI::International::get(25,'Asset_Survey'),
                        "addFrequencyAnswer"		=> WebGUI::International::get(26,'Asset_Survey'),
                        "addOpinionAnswer"		=> WebGUI::International::get(27,'Asset_Survey'),
                        "addHTMLAreaAnswer"		=> WebGUI::International::get(100,'Asset_Survey'),
                        "addTextAreaAnswer"		=> WebGUI::International::get(101,'Asset_Survey'),
			#"addQuestion"			=> WebGUI::International::get(28,'Asset_Survey'),
                        "backToPage"			=> WebGUI::International::get(745,'Asset_Survey')
			);
        	$f->whatNext(
                	-options=> \%options,
                	-value	=> "addMultipleChoiceAnswer",
			-hoverHelp	=> WebGUI::International::get('what next question description','Asset_Survey')
                	);
	}
	$f->submit;
	my $output = $f->print;
	if ($question->{Survey_questionId} ne "new" 
	   && $question->{answerFieldType} ne "text" 
	   && $question->{answerFieldType} ne "HTMLArea"
	   && $question->{answerFieldType} ne "textArea"
	) {
		$output .= '<a href="'.$self->getUrl('func=editAnswer;aid=new;qid='
			.$question->{Survey_questionId}).'">'.WebGUI::International::get(23,'Asset_Survey').'</a><p />';
		$sth = $self->session->db->read("select Survey_answerId,answer from Survey_answer 
			where Survey_questionId=".$self->session->db->quote($question->{Survey_questionId})." order by sequenceNumber");
		while (%data = $sth->hash) {
			$output .= 
				deleteIcon('func=deleteAnswerConfirm;qid='.$question->{Survey_questionId}.';aid='.$data{Survey_answerId}, 
					$self->get("url"),WebGUI::International::get(45,'Asset_Survey')).
                                editIcon('func=editAnswer;qid='.$question->{Survey_questionId}.';aid='.$data{Survey_answerId}, $self->get("url")).
                                moveUpIcon('func=moveAnswerUp'.';qid='.$question->{Survey_questionId}.';aid='.$data{Survey_answerId}, $self->get("url")).
                                moveDownIcon('func=moveAnswerDown;qid='.$question->{Survey_questionId}.';aid='.$data{Survey_answerId}, $self->get("url")).
                                ' '.$data{answer}.'<br />';
		}
		$sth->finish;
	}
	$self->getAdminConsole->setHelp("question add/edit","Asset_Survey");
	return $self->getAdminConsole->render($output, WebGUI::International::get(17,'Asset_Survey'));
}

#-------------------------------------------------------------------
sub www_editQuestionSave {
	return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
		
	$self->session->form->process("qid") = $_[0]->setCollateral("Survey_question", "Survey_questionId", {
                question=>$self->session->form->process("question"),
        	Survey_questionId=>$self->session->form->process("qid"),
		Survey_id=>$_[0]->get("Survey_id"),
                allowComment=>$self->session->form->process("allowComment"),
		gotoQuestion=>$self->session->form->process("gotoQuestion"),
		answerFieldType=>$self->session->form->process("answerFieldType"),
                randomizeAnswers=>$self->session->form->process("randomizeAnswers"),
                Survey_sectionId=>$self->session->form->process("section")
                },1,0,"Survey_id");
        if ($self->session->form->process("proceed") eq "addMultipleChoiceAnswer") {
        	$self->session->form->process("aid") = "new";
                return $_[0]->www_editAnswer();
	} elsif ($self->session->form->process("proceed") eq "addTextAnswer") {
                $_[0]->setAnswerType("text",$self->session->form->process("qid"));
        	$_[0]->addAnswer(0,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addBooleanAnswer") {
        	$_[0]->addAnswer(31,$self->session->form->process("qid"));
        	$_[0]->addAnswer(32,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addOpinionAnswer") {
                $_[0]->addAnswer(33,$self->session->form->process("qid"));
                $_[0]->addAnswer(34,$self->session->form->process("qid"));
                $_[0]->addAnswer(35,$self->session->form->process("qid"));
                $_[0]->addAnswer(36,$self->session->form->process("qid"));
                $_[0]->addAnswer(37,$self->session->form->process("qid"));
                $_[0]->addAnswer(38,$self->session->form->process("qid"));
                $_[0]->addAnswer(39,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addFrequencyAnswer") {
                $_[0]->addAnswer(40,$self->session->form->process("qid"));
                $_[0]->addAnswer(41,$self->session->form->process("qid"));
                $_[0]->addAnswer(42,$self->session->form->process("qid"));
                $_[0]->addAnswer(43,$self->session->form->process("qid"));
                $_[0]->addAnswer(39,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addHTMLAreaAnswer") {
		$_[0]->setAnswerType("HTMLArea",$self->session->form->process("qid"));
		$_[0]->addAnswer(0,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addTextAreaAnswer") {
		$_[0]->setAnswerType("textArea",$self->session->form->process("qid"));
		$_[0]->addAnswer(0,$self->session->form->process("qid"));
	} elsif ($self->session->form->process("proceed") eq "addQuestion") {
		$self->session->form->process("qid") = "new";
                return $_[0]->www_editQuestion();
	}
        return "";
}

#-------------------------------------------------------------------
sub www_editSection {
	my ($f, $section, $sectionName, $self);
	$self = shift;
	my $none = WebGUI::International::get(107, 'Asset_Survey');
	return $self->session->privilege->insufficient() unless ($self->canEdit);
	$section = $self->getCollateral("Survey_section","Survey_sectionId",$self->session->form->process("sid"));
	
	if ($section->{sectionName} =~ /$none/) {
	  return $self->session->privilege->vitalComponent;
	}
	
	$f = WebGUI::HTMLForm->new(-action=>$self->getUrl);
	$f->hidden(
		-name => "assetId",
		-value => $self->get("assetId")
	);
	$f->hidden(
		-name => "func",
		-value => "editSectionSave"
	);
	$f->hidden(
		-name => "sid",
		-value => $section->{Survey_sectionId}
	);

	$f->text(
		-name	=> "sectionName",
		-value	=> $section->{sectionName},
		-label	=> WebGUI::International::get(102,'Asset_Survey')
	);
	$f->submit;
	my $output = $f->print;
	return $self->getAdminConsole->render($output, WebGUI::International::get(103,'Asset_Survey'));
}

#-------------------------------------------------------------------
sub www_editSectionSave {
	return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
	$self->session->form->process("sid") = $_[0]->setCollateral("Survey_section", "Survey_sectionId", {
                sectionName => $self->session->form->process("sectionName"),
        	Survey_sectionId=>$self->session->form->process("sid"),
		Survey_id=>$_[0]->get("Survey_id"),
                },1,0,"Survey_id");
	return "";
}

#-------------------------------------------------------------------
sub www_exportAnswers {
        return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename($self->session->url->escape($_[0]->get("title")."_answers.tab"),"text/tab");
        return $self->session->db->quickTab("select * from Survey_answer where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_exportComposite {
	return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename($self->session->url->escape($_[0]->get("title")."_composite.tab"),"text/tab");
	return $self->session->db->quickTab("select b.question, c.response, a.userId, a.username, a.ipAddress, c.comment, c.dateOfResponse from Survey_response a 
		left join Survey_questionResponse c on a.Survey_responseId=c.Survey_responseId 
		left join Survey_question b on c.Survey_questionId=b.Survey_questionId 
		where a.Survey_id=".$self->session->db->quote($_[0]->get("Survey_id"))." order by a.userId, a.ipAddress, b.sequenceNumber");
}

#-------------------------------------------------------------------
sub www_exportQuestions {
        return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename($self->session->url->escape($_[0]->get("title")."_questions.tab"),"text/tab");
        return $self->session->db->quickTab("select * from Survey_question where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_exportResponses {
        return "" unless ($self->session->user->isInGroup($_[0]->get("groupToViewReports")));
	WebGUI::HTTP::setFilename($self->session->url->escape($_[0]->get("title")."_responses.tab"),"text/tab");
        return $self->session->db->quickTab("select * from Survey_response where Survey_id=".$self->session->db->quote($_[0]->get("Survey_id")));
}

#-------------------------------------------------------------------
sub www_moveAnswerDown {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralDown("Survey_answer","Survey_answerId",$self->session->form->process("aid"),"Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_moveAnswerUp {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralUp("Survey_answer","Survey_answerId",$self->session->form->process("aid"),"Survey_id");
        return $_[0]->www_editQuestion;
}

#-------------------------------------------------------------------
sub www_moveQuestionDown {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralDown("Survey_question","Survey_questionId",$self->session->form->process("qid"),"Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_moveQuestionUp {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralUp("Survey_question","Survey_questionId",$self->session->form->process("qid"),"Survey_id");
        return ""; 
}

#-------------------------------------------------------------------
sub www_moveSectionDown {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralDown("Survey_section","Survey_sectionId",$self->session->form->process("sid"),"Survey_id");
        return "";
}

#-------------------------------------------------------------------
sub www_moveSectionUp {
        return $self->session->privilege->insufficient() unless ($_[0]->canEdit);
        $_[0]->moveCollateralUp("Survey_section","Survey_sectionId",$self->session->form->process("sid"),"Survey_id");
        return ""; 
}

#-------------------------------------------------------------------
sub www_respond {
	my $self = shift;
	return "" unless ($self->session->user->isInGroup($self->get("groupToTakeSurvey")));
	my $varname = $self->getResponseIdString;
	return "" unless ($session{scratch}{$varname});
	my $userId = ($self->get("anonymous")) ? substr(md5_hex($self->session->user->profileField("userId")),0,8) : $self->session->user->profileField("userId");
	my $terminate = 0;
	foreach my $key (keys %{$session{form}}) {
		if ($key =~ /^answerId_(.+)$/) {
			my $id = $1;
			my ($previousResponse) = $self->session->db->quickArray("select count(*) from Survey_questionResponse
				where Survey_answerId=".$self->session->db->quote($session{form}{"answerId_".$id})." and Survey_responseId=".$self->session->db->quote($session{scratch}{$varname}));
			next if ($previousResponse);
			my $answer = $self->getCollateral("Survey_answer","Survey_answerId",$session{form}{"answerId_".$id});
			if ($self->get("questionOrder") eq "response" && $answer->{gotoQuestion} eq "") {
				$terminate = 1;
			}
			my $response = $session{form}{"textResponse_".$id} || $answer->{answer};
			$self->session->db->write("insert into Survey_questionResponse (Survey_answerId,Survey_questionId,Survey_responseId,Survey_id,comment,response,dateOfResponse) values (
				".$self->session->db->quote($answer->{Survey_answerId}).", ".$self->session->db->quote($answer->{Survey_questionId}).", ".$self->session->db->quote($session{scratch}{$varname}).", ".$self->session->db->quote($answer->{Survey_id}).",
				".$self->session->db->quote($session{form}{"comment_".$id}).", ".$self->session->db->quote($response).", ".$self->session->datetime->time().")");
		}
	}
	my $responseCount = $self->getQuestionResponseCount($session{scratch}{$varname}); 
	if ($terminate || $responseCount >= $self->getValue("questionsPerResponse") || $responseCount >= $self->getQuestionCount) {
		$self->session->db->setRow("Survey_response","Survey_responseId",{
			isComplete=>1,
			endDate=>$self->session->datetime->time(),
			Survey_responseId=>$session{scratch}{$varname}
			});
	}
	$self->logView() if ($self->session->setting->get("passiveProfilingEnabled"));
	return "";
}


#-------------------------------------------------------------------
=head2 www_view ( )

Overwrite www_view method and call the superclass object, passing in a 1 to disable cache

=cut

sub www_view {
   my $self = shift;
   $self->SUPER::www_view(1);
}

#-------------------------------------------------------------------
sub www_viewGradebook {
	my $self = shift;
        return "" unless ($self->session->user->isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($self->session->setting->get("passiveProfilingEnabled"));
	my $var = $self->getMenuVars;
	$var->{title} = WebGUI::International::get(71,'Asset_Survey');
	my $p = WebGUI::Paginator->new($self->getUrl('func=viewGradebook'));
	$p->setDataByQuery("select userId,username,ipAddress,Survey_responseId,startDate,endDate from Survey_response 
		where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by username,ipAddress,startDate");
	my $users = $p->getPageData;
	($var->{'question.count'}) = $self->session->db->quickArray("select count(*) from Survey_question where Survey_id=".$self->session->db->quote($self->get("Survey_id")));
	if ($var->{'question.count'} > $self->get("questionsPerResponse")) {
		$var->{'question.count'} = $self->get("questionsPerResponse");
	}
	$var->{'response.user.label'} = WebGUI::International::get(67,'Asset_Survey');
	$var->{'response.count.label'} = WebGUI::International::get(52,'Asset_Survey');
	$var->{'response.percent.label'} = WebGUI::International::get(54,'Asset_Survey');
	my @responseloop;
	foreach my $user (@$users) {
		my ($correctCount) = $self->session->db->quickArray("select count(*) from Survey_questionResponse a left join
                	Survey_answer b on a.Survey_answerId=b.Survey_answerId where a.Survey_responseId=".$self->session->db->quote($user->{Survey_responseId})
			." and b.isCorrect=1");
		push(@responseloop, {
			'response.url'=>$self->getUrl('func=viewIndividualSurvey;responseId='.$user->{Survey_responseId}),
			'response.user.name'=>($user->{userId} eq '1') ? $user->{ipAddress} : $user->{username},
			'response.count.correct' => $correctCount,
			'response.percent' => round(($correctCount/$var->{'question.count'})*100)
			});
	}
	$var->{response_loop} = \@responseloop;
	$p->appendTemplateVars($var);
	return $self->session->style->process($self->processTemplate($var,$self->getValue("gradebookTemplateId")),$self->getValue("styleTemplateId"));
#	return $self->processTemplate($self->getValue("gradebookTemplateId"),$var,"Survey/Gradebook");
}


#-------------------------------------------------------------------
sub www_viewIndividualSurvey {
	my $self = shift;
        return "" unless ($self->session->user->isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($self->session->setting->get("passiveProfilingEnabled"));
	my $var = $self->getMenuVars;
	$var->{'title'} = WebGUI::International::get(70,'Asset_Survey');
	$var->{'delete.url'} = $self->getUrl('func=deleteResponse;responseId='.$self->session->form->process("responseId"));
	$var->{'delete.label'} = WebGUI::International::get(69,'Asset_Survey');
	my $response = $self->session->db->getRow("Survey_response","Survey_responseId",$self->session->form->process("responseId"));
	$var->{'start.date.label'} = WebGUI::International::get(76,'Asset_Survey');
	$var->{'start.date.epoch'} = $response->{startDate};
	$var->{'start.date.human'} =$self->session->datetime->epochToHuman($response->{startDate},"%z");
	$var->{'start.time.human'} =$self->session->datetime->epochToHuman($response->{startDate},"%Z");
	$var->{'end.date.label'} = WebGUI::International::get(77,'Asset_Survey');
	$var->{'end.date.epoch'} = $response->{endDate};
	$var->{'end.date.human'} =$self->session->datetime->epochToHuman($response->{endDate},"%z");
	$var->{'end.time.human'} =$self->session->datetime->epochToHuman($response->{endDate},"%Z");
	$var->{'duration.label'} = WebGUI::International::get(78,'Asset_Survey');
	$var->{'duration.minutes'} = int(($response->{end} - $response->{start})/60);
	$var->{'duration.minutes.label'} = WebGUI::International::get(79,'Asset_Survey');
	$var->{'duration.seconds'} = (($response->{endDate} - $response->{start})%60);
	$var->{'duration.seconds.label'} = WebGUI::International::get(80,'Asset_Survey');
	$var->{'answer.label'} = WebGUI::International::get(19,'Asset_Survey');
	$var->{'response.label'} = WebGUI::International::get(66,'Asset_Survey');
	$var->{'comment.label'} = WebGUI::International::get(57,'Asset_Survey');
	my $questions = $self->session->db->read("select Survey_questionId,question,answerFieldType from Survey_question 
		where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
	my @questionloop;
	while (my $qdata = $questions->hashRef) {
		my @aid;
		my @answer;
		if ($qdata->{answerFieldType} eq "radioList") {
			my $sth = $self->session->db->read("select Survey_answerId,answer from Survey_answer 
				where Survey_questionId=".$self->session->db->quote($qdata->{Survey_questionId})." and isCorrect=1 order by sequenceNumber");
			while (my $adata = $sth->hashRef) {
				push(@aid,$adata->{Survey_answerId});
				push(@answer,$adata->{answer});
			}
			$sth->finish;
		}
		my $rdata = $self->session->db->quickHashRef("select Survey_answerId,response,comment from Survey_questionResponse 
			where Survey_questionId=".$self->session->db->quote($qdata->{Survey_questionId})." and Survey_responseId=".$self->session->db->quote($self->session->form->process("responseId")));
		push(@questionloop,{
			question => $qdata->{question},
			'question.id'=>$qdata->{Survey_questionId},
			'question.isRadioList' => ($qdata->{answerFieldType} eq "radioList"),
			'question.response' => $rdata->{response},
			'question.comment' => $rdata->{comment},
			'question.isCorrect' => isIn($rdata->{Survey_answerId}, @aid),
			'question.answer' => join(", ",@answer),
			});
	}
	$questions->finish;
	$var->{question_loop} = \@questionloop;
	return $self->session->style->process($self->processTemplate($var, $self->getValue("responseTemplateId")),$self->getValue("styleTemplateId"));
#	return $self->processTemplate($self->getValue("responseTemplateId"),$var,"Survey/Response");
}

#-------------------------------------------------------------------
sub www_viewStatisticalOverview {
	my $self = shift;
        return "" unless ($self->session->user->isInGroup($self->get("groupToViewReports")));
	$self->logView() if ($self->session->setting->get("passiveProfilingEnabled"));
	my $var = $self->getMenuVars;
	$var->{title} = WebGUI::International::get(58,'Asset_Survey');
	my $p = WebGUI::Paginator->new($self->getUrl('func=viewStatisticalOverview'));
	$p->setDataByQuery("select Survey_questionId,question,answerFieldType,allowComment from Survey_question 
		where Survey_id=".$self->session->db->quote($self->get("Survey_id"))." order by sequenceNumber");
	my $questions = $p->getPageData;
	my @questionloop;
	$var->{'answer.label'} = WebGUI::International::get(19,'Asset_Survey');
	$var->{'response.count.label'} = WebGUI::International::get(53,'Asset_Survey');
	$var->{'response.percent.label'} = WebGUI::International::get(54,'Asset_Survey');
	$var->{'show.responses.label'} = WebGUI::International::get(55,'Asset_Survey');
	$var->{'show.comments.label'} = WebGUI::International::get(56,'Asset_Survey');
	foreach my $question (@$questions) {
		my @answerloop;
		my ($totalResponses) = $self->session->db->quickArray("select count(*) from Survey_questionResponse where Survey_questionId=".$self->session->db->quote($question->{Survey_questionId}));
		if ($question->{answerFieldType} eq "radioList") {
			my $sth = $self->session->db->read("select Survey_answerId,answer,isCorrect from Survey_answer where
				Survey_questionId=".$self->session->db->quote($question->{Survey_questionId})." order by sequenceNumber");
			while (my $answer = $sth->hashRef) {
				my ($numResponses) = $self->session->db->quickArray("select count(*) from Survey_questionResponse where Survey_answerId=".$self->session->db->quote($answer->{Survey_answerId}));
				my $responsePercent;
				if ($totalResponses) {
					$responsePercent = round(($numResponses/$totalResponses)*100);
				} else {
					$responsePercent = 0;
				}
				my @commentloop;
				my $sth2 = $self->session->db->read("select comment from Survey_questionResponse where Survey_answerId=".$self->session->db->quote($answer->{Survey_answerId}));
				while (my ($comment) = $sth2->array) {
					push(@commentloop,{
						'answer.comment'=>$comment
						});
				}
				$sth2->finish;
				push(@answerloop,{
					'answer.isCorrect'=>$answer->{isCorrect},
					'answer' => $answer->{answer},
					'answer.response.count' =>$numResponses,
					'answer.response.percent' =>$responsePercent,
					'comment_loop'=>\@commentloop
					});
			}
			$sth->finish;
		} else {
			my $sth = $self->session->db->read("select response,comment from Survey_questionResponse where Survey_questionId=".$self->session->db->quote($question->{Survey_questionId}));
			while (my $response = $sth->hashRef) {
				push(@answerloop,{
					'answer.response'=>$response->{response},
					'answer.comment'=>$response->{comment}
					});
			}
			$sth->finish;
		}
		push(@questionloop,{
			question=>$question->{question},
			'question.id'=>$question->{Survey_questionId},
			'question.isRadioList' => ($question->{answerFieldType} eq "radioList"),
			'question.response.total' => $totalResponses,
			'answer_loop'=>\@answerloop,
			'question.allowComment'=>$question->{allowComment}
			});
	}
	$var->{question_loop} = \@questionloop;
	$p->appendTemplateVars($var);

	return $self->session->style->process($self->processTemplate($var, $self->getValue("overviewTemplateId")),$self->getValue("styleTemplateId"));
}

1;

