/*
 * YUI Extensions 0.33 RC2
 * Copyright(c) 2006, Jack Slocum.
 */


YAHOO.ext.Actor=function(element,animator,selfCapture){this.el=YAHOO.ext.Element.get(element,true);YAHOO.ext.Actor.superclass.constructor.call(this,element,true);this.onCapture=new YAHOO.util.CustomEvent('Actor.onCapture');if(animator){animator.addActor(this);}
this.capturing=selfCapture;this.playlist=selfCapture?new YAHOO.ext.Animator.AnimSequence():null;};YAHOO.extendX(YAHOO.ext.Actor,YAHOO.ext.Element);YAHOO.ext.Actor.prototype.capture=function(action){if(this.playlist!=null){this.playlist.add(action);}
this.onCapture.fireDirect(this,action);return action;};YAHOO.ext.Actor.overrideAnimation=function(method,animParam,onParam){return function(){if(!this.capturing){return method.apply(this,arguments);}
var args=Array.prototype.slice.call(arguments,0);if(args[animParam]===true){return this.capture(new YAHOO.ext.Actor.AsyncAction(this,method,args,onParam));}else{return this.capture(new YAHOO.ext.Actor.Action(this,method,args));}};}
YAHOO.ext.Actor.overrideBasic=function(method){return function(){if(!this.capturing){return method.apply(this,arguments);}
var args=Array.prototype.slice.call(arguments,0);return this.capture(new YAHOO.ext.Actor.Action(this,method,args));};}
YAHOO.ext.Actor.prototype.setVisibilityMode=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setVisibilityMode);YAHOO.ext.Actor.prototype.enableDisplayMode=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.enableDisplayMode);YAHOO.ext.Actor.prototype.focus=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.focus);YAHOO.ext.Actor.prototype.addClass=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.addClass);YAHOO.ext.Actor.prototype.removeClass=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.removeClass);YAHOO.ext.Actor.prototype.replaceClass=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.replaceClass);YAHOO.ext.Actor.prototype.setStyle=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setStyle);YAHOO.ext.Actor.prototype.setLeft=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setLeft);YAHOO.ext.Actor.prototype.setTop=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setTop);YAHOO.ext.Actor.prototype.setAbsolutePositioned=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setAbsolutePositioned);YAHOO.ext.Actor.prototype.setRelativePositioned=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setRelativePositioned);YAHOO.ext.Actor.prototype.clearPositioning=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.clearPositioning);YAHOO.ext.Actor.prototype.setPositioning=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.setPositioning);YAHOO.ext.Actor.prototype.clip=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.clip);YAHOO.ext.Actor.prototype.unclip=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.unclip);YAHOO.ext.Actor.prototype.clearOpacity=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.clearOpacity);YAHOO.ext.Actor.prototype.update=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.update);YAHOO.ext.Actor.prototype.remove=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.remove);YAHOO.ext.Actor.prototype.fitToParent=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.fitToParent);YAHOO.ext.Actor.prototype.appendChild=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.appendChild);YAHOO.ext.Actor.prototype.createChild=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.createChild);YAHOO.ext.Actor.prototype.appendTo=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.appendTo);YAHOO.ext.Actor.prototype.insertBefore=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.insertBefore);YAHOO.ext.Actor.prototype.insertAfter=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.insertAfter);YAHOO.ext.Actor.prototype.wrap=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.wrap);YAHOO.ext.Actor.prototype.replace=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.replace);YAHOO.ext.Actor.prototype.insertHtml=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.insertHtml);YAHOO.ext.Actor.prototype.set=YAHOO.ext.Actor.overrideBasic(YAHOO.ext.Actor.superclass.set);YAHOO.ext.Actor.prototype.load=function(){if(!this.capturing){return YAHOO.ext.Actor.superclass.load.apply(this,arguments);}
var args=Array.prototype.slice.call(arguments,0);return this.capture(new YAHOO.ext.Actor.AsyncAction(this,YAHOO.ext.Actor.superclass.load,args,2));};YAHOO.ext.Actor.prototype.animate=function(args,duration,onComplete,easing,animType){if(!this.capturing){return YAHOO.ext.Actor.superclass.animate.apply(this,arguments);}
return this.capture(new YAHOO.ext.Actor.AsyncAction(this,YAHOO.ext.Actor.superclass.animate,[args,duration,onComplete,easing,animType],2));};YAHOO.ext.Actor.prototype.setVisible=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setVisible,1,3);YAHOO.ext.Actor.prototype.toggle=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.toggle,0,2);YAHOO.ext.Actor.prototype.setXY=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setXY,1,3);YAHOO.ext.Actor.prototype.setLocation=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setLocation,2,4);YAHOO.ext.Actor.prototype.setWidth=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setWidth,1,3);YAHOO.ext.Actor.prototype.setHeight=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setHeight,1,3);YAHOO.ext.Actor.prototype.setSize=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setSize,2,4);YAHOO.ext.Actor.prototype.setBounds=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setBounds,4,6);YAHOO.ext.Actor.prototype.setOpacity=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setOpacity,1,3);YAHOO.ext.Actor.prototype.moveTo=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.moveTo,2,4);YAHOO.ext.Actor.prototype.move=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.move,2,4);YAHOO.ext.Actor.prototype.alignTo=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.alignTo,3,5);YAHOO.ext.Actor.prototype.hide=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.hide,0,2);YAHOO.ext.Actor.prototype.show=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.show,0,2);YAHOO.ext.Actor.prototype.setBox=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setBox,2,4);YAHOO.ext.Actor.prototype.autoHeight=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.autoHeight,0,2);YAHOO.ext.Actor.prototype.setX=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setX,1,3);YAHOO.ext.Actor.prototype.setY=YAHOO.ext.Actor.overrideAnimation(YAHOO.ext.Actor.superclass.setY,1,3);YAHOO.ext.Actor.prototype.startCapture=function(){this.capturing=true;this.playlist=new YAHOO.ext.Animator.AnimSequence();};YAHOO.ext.Actor.prototype.stopCapture=function(){this.capturing=false;};YAHOO.ext.Actor.prototype.clear=function(){this.playlist=new YAHOO.ext.Animator.AnimSequence();};YAHOO.ext.Actor.prototype.play=function(oncomplete){this.capturing=false;if(this.playlist){this.playlist.play(oncomplete);}};YAHOO.ext.Actor.prototype.addCall=function(fcn,args,scope){if(!this.capturing){fcn.apply(scope||this,args||[]);}else{this.capture(new YAHOO.ext.Actor.Action(scope,fcn,args||[]));}};YAHOO.ext.Actor.prototype.addAsyncCall=function(fcn,callbackIndex,args,scope){if(!this.capturing){fcn.apply(scope||this,args||[]);}else{this.capture(new YAHOO.ext.Actor.AsyncAction(scope,fcn,args||[],callbackIndex));}},YAHOO.ext.Actor.prototype.pause=function(seconds){this.capture(new YAHOO.ext.Actor.PauseAction(seconds));};YAHOO.ext.Actor.prototype.shake=function(){this.move('left',20,true,.05);this.move('right',40,true,.05);this.move('left',40,true,.05);this.move('right',20,true,.05);};YAHOO.ext.Actor.prototype.bounce=function(){this.move('up',20,true,.05);this.move('down',40,true,.05);this.move('up',40,true,.05);this.move('down',20,true,.05);};YAHOO.ext.Actor.prototype.blindShow=function(anchor,newSize,duration,easing){var size=newSize||this.getSize();this.clip();this.setVisible(true);anchor=anchor.toLowerCase();switch(anchor){case't':case'top':this.setHeight(1);this.setHeight(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;case'l':case'left':this.setWidth(1);this.setWidth(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;}
this.unclip();return size;};YAHOO.ext.Actor.prototype.blindHide=function(anchor,duration,easing){var size=this.getSize();this.clip();anchor=anchor.toLowerCase();switch(anchor){case't':case'top':this.setSize(size.width,1,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;case'l':case'left':this.setSize(1,size.height,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;case'r':case'right':this.animate({width:{to:1},points:{by:[this.getWidth(),0]}},duration||.5,null,YAHOO.util.Easing.easeIn,YAHOO.util.Motion);this.setVisible(false);break;case'b':case'bottom':this.animate({height:{to:1},points:{by:[0,this.getHeight()]}},duration||.5,null,YAHOO.util.Easing.easeIn,YAHOO.util.Motion);this.setVisible(false);break;}
return size;};YAHOO.ext.Actor.prototype.slideShow=function(anchor,newSize,duration,easing,clearPositioning){var size=newSize||this.getSize();this.clip();var firstChild=this.dom.firstChild;if(!firstChild||(firstChild.nodeName&&"#TEXT"==firstChild.nodeName.toUpperCase())){this.blindShow(anchor,newSize,duration,easing);return;}
var child=YAHOO.ext.Element.get(firstChild,true);var pos=child.getPositioning();this.addCall(child.setAbsolutePositioned,null,child);this.setVisible(true);anchor=anchor.toLowerCase();switch(anchor){case't':case'top':this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['top',''],child);this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['bottom','0px'],child);this.setHeight(1);this.setHeight(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;case'l':case'left':this.addCall(child.setStyle,['left',''],child);this.addCall(child.setStyle,['bottom',''],child);this.addCall(child.setStyle,['right','0px'],child);this.addCall(child.setStyle,['top','0px'],child);this.setWidth(1);this.setWidth(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;case'r':case'right':this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['top','0px'],child);this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['bottom',''],child);this.setWidth(1);this.setWidth(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;case'b':case'bottom':this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['top','0px'],child);this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['bottom',''],child);this.setHeight(1);this.setHeight(newSize,true,duration||.5,null,easing||YAHOO.util.Easing.easeOut);break;}
if(clearPositioning!==false){this.addCall(child.setPositioning,[pos],child);}
this.unclip();return size;};YAHOO.ext.Actor.prototype.slideHide=function(anchor,duration,easing){var size=this.getSize();this.clip();var firstChild=this.dom.firstChild;if(!firstChild||(firstChild.nodeName&&"#TEXT"==firstChild.nodeName.toUpperCase())){this.blindHide(anchor,duration,easing);return;}
var child=YAHOO.ext.Element.get(firstChild,true);var pos=child.getPositioning();this.addCall(child.setAbsolutePositioned,null,child);anchor=anchor.toLowerCase();switch(anchor){case't':case'top':this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['top',''],child);this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['bottom','0px'],child);this.setSize(size.width,1,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;case'l':case'left':this.addCall(child.setStyle,['left',''],child);this.addCall(child.setStyle,['bottom',''],child);this.addCall(child.setStyle,['right','0px'],child);this.addCall(child.setStyle,['top','0px'],child);this.setSize(1,size.height,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;case'r':case'right':this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['bottom',''],child);this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['top','0px'],child);this.setSize(1,size.height,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;case'b':case'bottom':this.addCall(child.setStyle,['right',''],child);this.addCall(child.setStyle,['top','0px'],child);this.addCall(child.setStyle,['left','0px'],child);this.addCall(child.setStyle,['bottom',''],child);this.setSize(size.width,1,true,duration||.5,null,easing||YAHOO.util.Easing.easeIn);this.setVisible(false);break;}
this.addCall(child.setPositioning,[pos],child);return size;};YAHOO.ext.Actor.prototype.squish=function(duration){var size=this.getSize();this.clip();this.setSize(1,1,true,duration||.5);this.setVisible(false);return size;};YAHOO.ext.Actor.prototype.appear=function(duration){this.setVisible(true,true,duration);};YAHOO.ext.Actor.prototype.fade=function(duration){this.setVisible(false,true,duration);};YAHOO.ext.Actor.prototype.switchOff=function(duration){this.clip();this.setVisible(false,true,.1);this.clearOpacity();this.setVisible(true);this.animate({height:{to:1},points:{by:[0,this.getHeight()/2]}},duration||.5,null,YAHOO.util.Easing.easeOut,YAHOO.util.Motion);this.setVisible(false);};YAHOO.ext.Actor.prototype.highlight=function(color,fromColor,duration,attribute){attribute=attribute||'background-color';var original=this.getStyle(attribute);fromColor=fromColor||((original&&original!=''&&original!='transparent')?original:'#FFFFFF');var cfg={};cfg[attribute]={to:color,from:fromColor};this.setVisible(true);this.animate(cfg,duration||.5,null,YAHOO.util.Easing.bounceOut,YAHOO.util.ColorAnim);this.setStyle(attribute,original);};YAHOO.ext.Actor.prototype.pulsate=function(count,duration){count=count||3;for(var i=0;i<count;i++){this.toggle(true,duration||.25);this.toggle(true,duration||.25);}};YAHOO.ext.Actor.prototype.dropOut=function(duration){this.animate({opacity:{to:0},points:{by:[0,this.getHeight()]}},duration||.5,null,YAHOO.util.Easing.easeIn,YAHOO.util.Motion);this.setVisible(false);};YAHOO.ext.Actor.prototype.moveOut=function(anchor,duration,easing){var Y=YAHOO.util;var vw=Y.Dom.getViewportWidth();var vh=Y.Dom.getViewportHeight();var cpoints=this.getCenterXY()
var centerX=cpoints[0];var centerY=cpoints[1];var anchor=anchor.toLowerCase();var p;switch(anchor){case't':case'top':p=[centerX,-this.getHeight()];break;case'l':case'left':p=[-this.getWidth(),centerY];break;case'r':case'right':p=[vw+this.getWidth(),centerY];break;case'b':case'bottom':p=[centerX,vh+this.getHeight()];break;case'tl':case'top-left':p=[-this.getWidth(),-this.getHeight()];break;case'bl':case'bottom':p=[-this.getWidth(),vh+this.getHeight()];break;case'br':case'bottom-right':p=[vw+this.getWidth(),vh+this.getHeight()];break;case'tr':case'top-right':p=[vw+this.getWidth(),-this.getHeight()];break;}
this.moveTo(p[0],p[1],true,duration||.35,null,easing||Y.Easing.easeIn);this.setVisible(false);};YAHOO.ext.Actor.prototype.moveIn=function(anchor,to,duration,easing){to=to||this.getCenterXY();this.moveOut(anchor,.01);this.setVisible(true);this.setXY(to,true,duration||.35,null,easing||YAHOO.util.Easing.easeOut);};YAHOO.ext.Actor.prototype.frame=function(color,count,duration){color=color||"red";count=count||3;duration=duration||.5;var frameFn=function(callback){var box=this.getBox();var animFn=function(){var proxy=this.createProxy({tag:"div",style:{visbility:"hidden",position:"absolute",zIndex:this.getStyle("zIndex"),border:"0px solid "+color}});var scale=proxy.isBorderBox()?2:1;proxy.animate({top:{from:box.y,to:box.y-20},left:{from:box.x,to:box.x-20},borderWidth:{from:0,to:10},opacity:{from:1,to:0},height:{from:box.height,to:(box.height+(20*scale))},width:{from:box.width,to:(box.width+(20*scale))}},duration,function(){proxy.remove();});if(--count>0){animFn.defer((duration/2)*1000,this);}else{if(typeof callback=='function'){callback();}}}
animFn.call(this);}
this.addAsyncCall(frameFn,0,null,this);};YAHOO.ext.Actor.Action=function(actor,method,args){this.actor=actor;this.method=method;this.args=args;}
YAHOO.ext.Actor.Action.prototype={play:function(onComplete){this.method.apply(this.actor||window,this.args);onComplete();}};YAHOO.ext.Actor.AsyncAction=function(actor,method,args,onIndex){YAHOO.ext.Actor.AsyncAction.superclass.constructor.call(this,actor,method,args);this.onIndex=onIndex;this.originalCallback=this.args[onIndex];}
YAHOO.extendX(YAHOO.ext.Actor.AsyncAction,YAHOO.ext.Actor.Action);YAHOO.ext.Actor.AsyncAction.prototype.play=function(onComplete){var callbackArg=this.originalCallback?this.originalCallback.createSequence(onComplete):onComplete;this.args[this.onIndex]=callbackArg;this.method.apply(this.actor,this.args);};YAHOO.ext.Actor.PauseAction=function(seconds){this.seconds=seconds;};YAHOO.ext.Actor.PauseAction.prototype={play:function(onComplete){setTimeout(onComplete,this.seconds*1000);}};