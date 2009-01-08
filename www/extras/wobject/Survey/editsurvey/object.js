if (typeof Survey == "undefined") {
    var Survey = {};
}

Survey.ObjectTemplate = new function(){

    this.loadObject = function(html,type){

        document.getElementById('edit').innerHTML = html;

	var myTextarea;

	var handleSubmit = function(){
		myTextarea.saveHTML(); 
		this.submit();
	}

        var butts = [ 
                { text:"Submit", handler:handleSubmit, isDefault:true }, 
                { text:"Copy", handler:function(){document.getElementById('copy').value = 1; this.submit();}},
                { text:"Cancel", handler:function(){this.cancel();}}, 
                { text:"Delete", handler:function(){document.getElementById('delete').value = 1; this.submit();}}
            ];

        var form = new YAHOO.widget.Dialog(type,
           { 
             width : "600px",
			 context: [document.body, 'tr', 'tr'],
             visible : false,
             constraintoviewport : true,
             buttons : butts
           } );

        form.callback = Survey.Comm.callback;
        form.render();
	
	var textareaId = type+'Text';
	var textarea = YAHOO.util.Dom.get(textareaId);
	
	var height = YAHOO.util.Dom.getStyle(textarea,'height');
	if (height == ''){
 		height = '300px';
	}
	myTextarea = new YAHOO.widget.SimpleEditor(textareaId, {
		height: height,
		width: '100%',
		dompath: false //Turns on the bar at the bottom
	});
	
	if (myTextarea.get('toolbar')) {
		myTextarea.get('toolbar').titlebar = false;
	}
	myTextarea.render();	

        form.show();
    }
}();

