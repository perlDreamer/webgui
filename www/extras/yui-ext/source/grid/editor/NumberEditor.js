/*
 * YUI Extensions
 * Copyright(c) 2006, Jack Slocum.
 * 
 * This code is licensed under BSD license. 
 * http://www.opensource.org/licenses/bsd-license.php
 */

YAHOO.ext.grid.NumberEditor = function(config){
    var element = document.createElement('input');
    element.type = 'text';
    element.className = 'ygrid-editor ygrid-num-editor';
    element.setAttribute('autocomplete', 'off');
    document.body.appendChild(element);
    YAHOO.ext.grid.NumberEditor.superclass.constructor.call(this, element);
    YAHOO.ext.util.Config.apply(this, config);
};
YAHOO.extendX(YAHOO.ext.grid.NumberEditor, YAHOO.ext.grid.CellEditor);

YAHOO.ext.grid.NumberEditor.prototype.initEvents = function(){
    var stopOnEnter = function(e){
        if(e.browserEvent.keyCode == e.RETURN){
            this.stopEditing(true);
        }
    };
    
    var allowed = "0123456789";
    if(this.allowDecimals){
        allowed += this.decimalSeparator;
    }
    if(this.allowNegative){
        allowed += '-';
    }
    var keyPress = function(e){
        var c = e.getCharCode();
        if(c != e.BACKSPACE && allowed.indexOf(String.fromCharCode(c)) === -1){
            e.stopEvent();
        }
    };
    this.element.mon('keydown', stopOnEnter, this, true);
    var vtask = new YAHOO.ext.util.DelayedTask(this.validate, this);
    this.element.mon('keyup', vtask.delay.createDelegate(vtask, [this.validationDelay]));
    this.element.mon('keypress', keyPress, this, true);
    this.element.on('blur', this.stopEditing, this, true);
};

YAHOO.ext.grid.NumberEditor.prototype.validate = function(){
    var dom = this.element.dom;
    var value = dom.value;
    if(value.length < 1){ // if it's blank
         if(this.allowBlank){
             dom.title = '';
             this.element.removeClass('ygrid-editor-invalid');
             return true;
         }else{
             dom.title = this.blankText;
             this.element.addClass('ygrid-editor-invalid');
             return false;
         }
    }
    if(value.search(/\d+/) === -1){
        dom.title = this.nanText.replace('%0', value);
        this.element.addClass('ygrid-editor-invalid');
        return false;
    }
    var num = this.parseValue(value);
    if(num < this.minValue){
        dom.title = this.minText.replace('%0', this.minValue);
        this.element.addClass('ygrid-editor-invalid');
        return false;
    }
    if(num > this.maxValue){
        dom.title = this.maxText.replace('%0', this.maxValue);
        this.element.addClass('ygrid-editor-invalid');
        return false;
    }
    var msg = this.validator(value);
    if(msg !== true){
        dom.title = msg;
        this.element.addClass('ygrid-editor-invalid');
        return false;
    }
    dom.title = '';
    this.element.removeClass('ygrid-editor-invalid');
    return true;
};

YAHOO.ext.grid.NumberEditor.prototype.show = function(){
    this.element.dom.title = '';
    YAHOO.ext.grid.NumberEditor.superclass.show.call(this);
    if(this.selectOnFocus){
        try{
            this.element.dom.select();
        }catch(e){}
    }
    this.validate(this.element.dom.value);
};

YAHOO.ext.grid.NumberEditor.prototype.getValue = function(){
   if(!this.validate()){
       return this.originalValue;
   }else{
       var value = this.element.dom.value;
       if(value.length < 1){
           return value;
       } else{
           return this.fixPrecision(this.parseValue(value));
       }
   }   
};
YAHOO.ext.grid.NumberEditor.prototype.parseValue = function(value){
    return parseFloat(new String(value).replace(this.decimalSeparator, '.'));
};

YAHOO.ext.grid.NumberEditor.prototype.fixPrecision = function(value){
   if(!this.allowDecimals || this.decimalPrecision == -1 || isNaN(value) || value == 0 || !value){
       return value;
   }
   // this should work but doesn't due to precision error in JS
   // var scale = Math.pow(10, this.decimalPrecision);
   // var fixed = this.decimalPrecisionFcn(value * scale);
   // return fixed / scale;
   //
   // so here's our workaround:
   var scale = Math.pow(10, this.decimalPrecision+1);
   var fixed = this.decimalPrecisionFcn(value * scale);
   fixed = this.decimalPrecisionFcn(fixed/10);
   return fixed / (scale/10);
};

YAHOO.ext.grid.NumberEditor.prototype.allowBlank = true;
YAHOO.ext.grid.NumberEditor.prototype.allowDecimals = true;
YAHOO.ext.grid.NumberEditor.prototype.decimalSeparator = '.';
YAHOO.ext.grid.NumberEditor.prototype.decimalPrecision = 2;
YAHOO.ext.grid.NumberEditor.prototype.decimalPrecisionFcn = Math.floor;
YAHOO.ext.grid.NumberEditor.prototype.allowNegative = true;
YAHOO.ext.grid.NumberEditor.prototype.selectOnFocus = true;
YAHOO.ext.grid.NumberEditor.prototype.minValue = Number.NEGATIVE_INFINITY;
YAHOO.ext.grid.NumberEditor.prototype.maxValue = Number.MAX_VALUE;
YAHOO.ext.grid.NumberEditor.prototype.minText = 'The minimum value for this field is %0';
YAHOO.ext.grid.NumberEditor.prototype.maxText = 'The maximum value for this field is %0';
YAHOO.ext.grid.NumberEditor.prototype.blankText = 'This field cannot be blank';
YAHOO.ext.grid.NumberEditor.prototype.nanText = '%0 is not a valid number';
YAHOO.ext.grid.NumberEditor.prototype.validationDelay = 100;
YAHOO.ext.grid.NumberEditor.prototype.validator = function(){return true;};