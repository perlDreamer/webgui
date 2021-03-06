/*global Survey, YAHOO */
if (typeof Survey === "undefined") {
    var Survey = {};
}

Survey.Data = (function(){

    var lastDataSet = {};
    var focus;
    var lastId = -1;
	
	// Keep references to widgets here so that we can destory any instances before
	// creating new ones (to avoid memory leaks)
	var autoComplete;
	var sButton, qButton, aButton;

    return {
        dragDrop: function(did){

            YAHOO.log('In drag drop');
			var type = did.className.match("section")  ? 'section'
                     : did.className.match("question") ? 'question'
                     :                                   'answer';

            var first = {
                id: did.id, // pre-drag index of item
                type: type
            };
			var before = YAHOO.util.Dom.getPreviousSiblingBy( document.getElementById(did.id), function(node){
				return node.id; // true iff node has a non-empty id
			});

            var data = {
                id: '',
                type: ''
            };

            if (before) {
                type = before.className.match("section")  ? 'section'
                     : before.className.match("question") ? 'question'
                     :                                      'answer';
                data = {
                    id: before.id,
                    type: type
                };
            }
            YAHOO.log(first.id + ' ' + data.id);
            Survey.Comm.dragDrop(first, data);
        },

        clicked: function(){
            Survey.Comm.loadSurvey(this.id);
        },

        loadData: function(d){
            focus = d.address;//What is the current highlighted item.
            var showEdit = 1;
            if (lastId.toString() === d.address.toString()) {
                showEdit = 0;
                lastId = -1;
            }
            else {
                lastId = d.address;
            }

			// First purge any event handlers bound to sections node..
			YAHOO.util.Event.purgeElement('sections', true);

			// Now we can re-write its innerHTML without fear of memory leaks
            document.getElementById('sections').innerHTML = d.ddhtml;

            //add event handlers for if a tag is clicked
            for (var x in d.ids) {
				if (YAHOO.lang.hasOwnProperty(d.ids, x)) {
	                YAHOO.log('adding handler for ' + d.ids[x]);
	                YAHOO.util.Event.addListener(d.ids[x], "click", this.clicked);
	                var _s = new Survey.DDList(d.ids[x], "sections");
				}
            }

			sButton && sButton.destroy();
			sButton = new YAHOO.widget.Button({
                label: "Add Section",
                id: "addsection",
                container: "addSection"
            });
            sButton.on("click", this.addSection);

			qButton && qButton.destroy();
            qButton = new YAHOO.widget.Button({
                label: "Add Question",
                id: "addquestion",
                container: "addQuestion"
            });
            qButton.on("click", this.addQuestion, d.buttons.question);

            if (d.buttons.answer) {
				aButton && aButton.destroy();
                aButton = new YAHOO.widget.Button({
                    label: "Add Answer",
                    id: "addanswer",
                    container: "addAnswer"
                });
                aButton.on("click", this.addAnswer, d.buttons.answer);
            }

            if (showEdit == 1) {
                this.loadObjectEdit(d.edithtml, d.type);

                // build the goto auto-complete widget
                if (d.gotoTargets && document.getElementById('goto')) {
                    var ds =  new YAHOO.util.LocalDataSource(d.gotoTargets);
                    autoComplete = new YAHOO.widget.AutoComplete('goto', 'goto-yui-ac-container', ds);
                }
            }
            else {
				Survey.ObjectTemplate.unloadObject();
				if (autoComplete) {
					autoComplete.destroy();
					autoComplete = null;
				}
            }
            lastDataSet = d;
        },

        addSection: function(){
            Survey.Comm.newSection();
        },

        addQuestion: function(e, id){
            Survey.Comm.newQuestion(id);
        },

        addAnswer: function(e, id){
            Survey.Comm.newAnswer(id);
        },

        loadObjectEdit: function(edit, type){
            if (edit) {
                Survey.ObjectTemplate.loadObject(edit, type);
            }
        },

        loadLast: function(){
            this.loadData(lastDataSet);
        }
    };
})();

//  Initialize survey
YAHOO.util.Event.onDOMReady(function(){
	var ddTarget = new YAHOO.util.DDTarget("sections", "sections");
    Survey.Comm.loadSurvey();
});
