package WebGUI::Forum::Web;

use strict qw(vars subs);
use WebGUI::DateTime;
use WebGUI::Form;
use WebGUI::Forum;
use WebGUI::Forum::Post;
use WebGUI::Forum::Thread;
use WebGUI::HTML;
use WebGUI::Session;
use WebGUI::Template;


sub _chopSubject {
	return substr(_formatSubject($_[0]),0,30);
}

sub _formatApprovePostURL {
	return WebGUI::URL::append($_[0],"forumOp=approvePost&amp;forumPostId=".$_[1]."&amp;mlog=".$session{form}{mlog});
}

sub _formatDeletePostURL {
	return WebGUI::URL::append($_[0],"forumOp=deletePost&amp;forumPostId=".$_[1]);
}

sub _formatDenyPostURL {
	return WebGUI::URL::append($_[0],"forumOp=denyPost&amp;forumPostId=".$_[1]."&amp;mlog=".$session{form}{mlog});
}

sub _formatEditPostURL {
	return WebGUI::URL::append($_[0],"forumOp=post&amp;forumPostId=".$_[1]);
}

sub _formatLeavePostPendingURL {
	return WebGUI::URL::page("op=viewMessageLog");
}

sub _formatNextThreadURL {
	return WebGUI::URL::append($_[0],"forumOp=nextThread&amp;forumThreadId=".$_[1]);
}

sub _formatNewThreadURL {
	return WebGUI::URL::append($_[0],"forumOp=post&amp;forumId=".$_[1]);
}

sub _formatPostDate {
	return WebGUI::DateTime::epochToHuman($_[0],"%z");
}

sub _formatPostTime {
	return WebGUI::DateTime::epochToHuman($_[0],"%Z");
}

sub _formatPreviousThreadURL {
	return WebGUI::URL::append($_[0],"forumOp=previousThread&amp;forumThreadId=".$_[1]);
}

sub _formatReplyPostURL {
	return WebGUI::URL::append($_[0],"forumOp=post&amp;parentId=".$_[1]);
}

sub _formatSubject {
	return WebGUI::HTML::filter($_[0],"all");
}

sub _formatStatus {
        if ($_[0] eq "approved") {
                return WebGUI::International::get(560);
        } elsif ($_[0] eq "denied") {
                return WebGUI::International::get(561);
        } elsif ($_[0] eq "pending") {
                return WebGUI::International::get(562);
        }
}

sub _formatThreadURL {
	return WebGUI::URL::append($_[0],"forumOp=viewThread&amp;forumPostId=".$_[1]."#".$_[1]);
}

sub _formatUserProfileURL {
	return WebGUI::URL::page("op=viewProfile&amp;uid=".$_[0]);
}

sub _getPostTemplateVars {
        my ($post, $thread, $forum, $callback, $var) = @_;
	$var->{'post.subject.label'} = WebGUI::International::get(237);
        $var->{'post.subject'} = WebGUI::HTML::filter($post->get("subject"),"none");
        $var->{'post.message'} = WebGUI::HTML::filter($post->get("message"),$forum->get("filterPosts"));
        if ($forum->get("allowReplacements")) {
                my $sth = WebGUI::SQL->read("select pattern,replaceWith from forumReplacement");
                while (my ($pattern,$replaceWith) = $sth->array) {
                        $var->{'post.message'} =~ s/\Q$pattern/$replaceWith/g;
                }
                $sth->finish;
        }
        $var->{'post.date'} = _formatPostDate($post->get("dateOfPost"));
	$var->{'post.date.label'} = WebGUI::International::get(239);
        $var->{'post.time'} = _formatPostTime($post->get("dateOfPost"));
	$var->{'post.views'} = $post->get("views");
	$var->{'post.views.label'} = WebGUI::International::get(514);
	$var->{'post.status'} = _formatStatus($post->get("status"));
	$var->{'post.status.label'} = WebGUI::International::get(553);
	$var->{'post.isLocked'} = $thread->isLocked;
	$var->{'post.isModerator'} = $forum->isModerator;
	$var->{'post.user.label'} = WebGUI::International::get(238);
	$var->{'post.username'} = $post->get("username");
	$var->{'post.userId'} = $post->get("userId");
	$var->{'post.userProfile'} = _formatUserProfileURL($post->get("userId"));
	$var->{'post.id'} = $post->get("forumPostId");
	$var->{'post.full'} = WebGUI::Template::process(WebGUI::Template::get(1,"Forum/Post"), $var); 
	$var->{'post.reply.label'} = WebGUI::International::get(577);
	$var->{'post.reply.url'} = _formatReplyPostURL($callback,$post->get("forumPostId"));
	$var->{'post.edit.label'} = WebGUI::International::get(575);
	$var->{'post.edit.url'} = _formatEditPostURL($callback,$post->get("forumPostId"));
	$var->{'post.delete.label'} = WebGUI::International::get(576);
	$var->{'post.delete.url'} = _formatDeletePostURL($callback,$post->get("forumPostId"));
	$var->{'post.approve.label'} = WebGUI::International::get(572);
	$var->{'post.approve.url'} = _formatApprovePostURL($callback,$post->get("forumPostId"));
	$var->{'post.deny.label'} = WebGUI::International::get(574);
	$var->{'post.deny.url'} = _formatDenyPostURL($callback,$post->get("forumPostId"));
	$var->{'post.pending.label'} = WebGUI::International::get(573);
	$var->{'post.pending.url'} = _formatLeavePostPendingURL();
	$var->{'post.tools.label'} = WebGUI::International::get(238);
	return $var;
}

sub _recurseThread {
	my ($post, $thread, $forum, $depth, $callback) = @_;
	my @depth_loop;
	for (my $i=0; $i<$depth; $i++) {
		push(@depth_loop,"");
	}
	my @post_loop;
	push (@post_loop, _getPostTemplateVars($post, $thread, $forum, $callback, {'indent_loop'=>\@depth_loop}));
	my $replies = $post->getReplies;
	foreach my $reply (@{$replies}) {
		@post_loop = (@post_loop,@{_recurseThread($reply, $thread, $forum, $depth+1, $callback)});
	}	
	return \@post_loop;
}

sub forumOp {
	my ($callback) = @_;
	my $cmd = "www_".$session{form}{forumOp};
        return &$cmd($callback);
}

sub viewForum {
	my ($callback, $forumId) = @_;
	my (%var, @thread_loop);
	$var{'thread.new.url'} = _formatNewThreadURL($callback,$forumId);
	$var{'thread.new.label'} = 'Post a new thread.';
	my $p = WebGUI::Paginator->new($callback);
	$p->setDataByQuery("select * from forumThread where forumId=".$forumId." order by isSticky desc, lastPostDate desc");
	my $threads = $p->getPageData;
	foreach my $thread (@$threads) {
		my $root = WebGUI::Forum::Post->new($thread->{rootPostId});
		my $last;
		if ($thread->{rootPostId} == $thread->{lastPostId}) { #saves the lookup if it's the same id
			$last = $root;
		} else {
			$last = WebGUI::Forum::Post->new($thread->{lastPostId});
		}
		push(@thread_loop,{
			'thread.views'=>$thread->{views},
			'thread.replies'=>$thread->{replies},
			'thread.isSticky'=>$thread->{isSticky},
			'thread.isLocked'=>$thread->{isLocked},
			'thread.root.subject'=>_chopSubject($root->get("subject")),
			'thread.root.url'=>_formatThreadURL($callback,$root->get("forumPostId")),
			'thread.root.epoch'=>$root->get("dateOfPost"),
			'thread.root.date'=>_formatPostDate($root->get("dateOfPost")),
			'thread.root.time'=>_formatPostTime($root->get("dateOfPost")),
			'thread.root.user.profile'=>_formatUserProfileURL($root->get("userId")),
			'thread.root.user.name'=>$root->get("username"),
			'thread.root.user.id'=>$root->get("userId"),
			'thread.root.status'=>_formatStatus($root->get("status")),
			'thread.last.subject'=>_chopSubject($last->get("subject")),
			'thread.last.url'=>_formatThreadURL($callback,$last->get("forumPostId")),
			'thread.last.epoch'=>$last->get("dateOfPost"),
			'thread.last.date'=>_formatPostDate($last->get("dateOfPost")),
			'thread.last.time'=>_formatPostTime($last->get("dateOfPost")),
			'thread.last.user.profile'=>_formatUserProfileURL($last->get("userId")),
			'thread.last.user.name'=>$last->get("username"),
			'thread.last.user.id'=>$last->get("userId"),
			'thread.last.status'=>_formatStatus($last->get("status"))
			});
	}
	$var{thread_loop} = \@thread_loop;
	return WebGUI::Template::process(WebGUI::Template::get(1,"Forum"), \%var); 
}	

sub www_nextThread {
	my ($callback) = @_;
	my $thread = WebGUI::Forum::Thread->new($session{form}{forumThreadId});
	return www_viewThread($callback,$thread->getNextThread->get("rootPostId"));
}

sub www_post {
	my ($callback) = @_;
	my ($subject, $message, $forum);
	my $var;
	$var->{header} = 'Post a Message';
	$var->{isNewThread} = ($session{form}{forumId} ne "");
	$var->{isReply} = ($session{form}{parentId} ne "");
	$var->{isEdit} = ($session{form}{forumPostId} ne "");
	$var->{isVisitor} = ($session{user}{userId} == 1);
	$var->{isNewMessage} = ($var->{isNewThread} || $var->{isReply});
	$var->{'form.begin'} = WebGUI::Form::formHeader({
		action=>$callback
		});
	if ($var->{isReply}) {
		my $reply = WebGUI::Forum::Post->new($session{form}{parentId});
		$var->{'form.begin'} .= WebGUI::Form::hidden({
			name=>'parentId',
			value=>$reply->get("forumPostId")
			});
		$forum = $reply->getThread->getForum;
		$var = _getPostTemplateVars($reply, $reply->getThread, $forum, $callback, $var);

		$subject = $reply->get("subject");
		$subject = "Re: ".$subject unless ($subject =~ /^Re:/);
		$var->{'subscribe.form'} = WebGUI::Form::yesNo({
			name=>'subscribe',
			value=>0
			});
	}
	if ($var->{isNewThread}) {
		$var->{'form.begin'} .= WebGUI::Form::hidden({
			name=>'forumId',
			value=>$session{form}{forumId}
			});
		$forum = WebGUI::Forum->new($session{form}{forumId});
		if ($forum->isModerator) {
			$var->{'sticky.label'} = WebGUI::International::get(1013);
			$var->{'sticky.form'} = WebGUI::Form::yesNo({
				name=>'isSticky',
				value=>0
				});
		}
		$var->{'subscribe.form'} = WebGUI::Form::yesNo({
			name=>'subscribe',
			value=>1
			});
	}
	if ($var->{isNewMessage}) {
		$var->{'subscribe.label'} = WebGUI::International::get(873);
		if ($forum->isModerator) {
			$var->{'lock.label'} = WebGUI::International::get(1012);
			$var->{'lock.form'} = WebGUI::Form::yesNo({
				name=>'isLocked',
				value=>0
				});
		}
	}
	if ($var->{isEdit}) {
		my $post = WebGUI::Forum::Post->new($session{form}{forumPostId});
		$subject = $post->get("subject");
		$message = $post->get("message");
		$forum = $post->getThread->getForum;
	}
	$var->{'contentType.label'} = WebGUI::International::get(1007);
	$var->{'contentType.form'} = WebGUI::Form::contentType({
		name=>'contentType'
		});
	$var->{isModerator} = $forum->isModerator;
	$var->{allowReplacements} = $forum->get("allowReplacements");
	if ($forum->get("allowRichEdit")) {
		$var->{'message.form'} = WebGUI::Form::HTMLArea({
			name=>'message',
			value=>$message
			});
	} else {
		$var->{'message.form'} = WebGUI::Form::textarea({
			name=>'message',
			value=>$message
			});
	}
	$var->{'message.label'} = WebGUI::International::get(230);
	if ($var->{isVisitor}) {
		$var->{'visitorName.label'} = WebGUI::International::get(438);
		$var->{'visitorName.form'} = WebGUI::Form::text({
			name=>'visitorName'
			});
	}
	$var->{'form.begin'} .= WebGUI::Form::hidden({
		name=>'forumOp',
		value=>'postSave'
		});
	$var->{'form.submit'} = WebGUI::Form::submit();
	$var->{'subject.label'} = WebGUI::International::get(229);
	$var->{'subject.form'} = WebGUI::Form::text({
		name=>'subject',
		value=>$subject
		});
	$var->{'form.end'} = '</form>';
	return WebGUI::Template::process(WebGUI::Template::get(1,"Forum/PostForm"), $var); 
}

sub www_postSave {
	my ($callback) = @_;
	my $forumId = $session{form}{forumId};
	my $threadId = $session{form}{forumThreadId};
	my $postId = $session{form}{forumPostId};
	my $thread;
	if ($session{form}{parentId} > 0) {
		my $parentPost = WebGUI::Forum::Post->new($session{form}{parentId});
		$forumId = $parentPost->getThread->get("forumId");
		$threadId = $parentPost->get("forumThreadId");
		return www_viewThread($callback,$postId);
	}
	if ($forumId) {
		$thread = WebGUI::Forum::Thread->create({
			forumId=>$forumId,
			isSticky=>$session{form}{isSticky},
			isLocked=>$session{form}{isLocked}
			}, {
			subject=>$session{form}{subject},
			message=>$session{form}{message},
			userId=>$session{user}{userId},
			username=>($session{form}{visitorName} || $session{user}{alias}),
			contentType=>$session{form}{contentType}
			});
		$thread->subscribe($session{user}{userId}) if ($session{form}{subscribe});
		return viewForum($callback, $forumId);
	}
}

sub www_previousThread {
	my ($callback) = @_;
	my $thread = WebGUI::Forum::Thread->new($session{form}{forumThreadId});
	return www_viewThread($callback,$thread->getPreviousThread->get("rootPostId"));
}

sub www_viewThread {
	my ($callback, $postId) = @_;
	$postId = $session{form}{forumPostId} unless ($postId);
	my $post = WebGUI::Forum::Post->new($postId);
	my $thread = $post->getThread;
	my $forum = $thread->getForum;
	my $var = _getPostTemplateVars($post, $thread, $forum, $callback);
	my $root = WebGUI::Forum::Post->new($thread->get("rootPostId"));
	$var->{post_loop} = _recurseThread($root, $thread, $forum, 0, $callback);
	$var->{'thread.layout.isFlat'} = ($session{user}{discussionLayout} eq "flat");
	$var->{'thread.layout.isThreaded'} = ($session{user}{discussionLayout} eq "threaded");
	$var->{'thread.layout.isNested'} = ($session{user}{discussionLayout} eq "nested");
	$var->{'thread.new.url'} = '';
	$var->{'thread.new.label'} = WebGUI::International::get(0);
	$var->{'thread.previous.url'} = _formatPreviousThreadURL($callback,$thread->get("forumThreadId"));
	$var->{'thread.previous.label'} = WebGUI::International::get(513);
	$var->{'thread.next.url'} = _formatNextThreadURL($callback,$thread->get("forumThreadId"));
	$var->{'thread.next.label'} = WebGUI::International::get(512);
	$var->{'thread.list.url'} = '';
	$var->{'thread.list.label'} = WebGUI::International::get(0);
	return WebGUI::Template::process(WebGUI::Template::get(1,"Forum/Thread"), $var); 
}


1;

