// WebGUI Specific javascript functions for TinyMCE

function tinyMCE_WebGUI_URLConvertor(url, node, on_save) {
	// The next line would have tried formatting the URL, but we don't want it to
        url = tinyMCE.convertURL(url, node, on_save);
        // Do custom WebUI convertion, replace back ^();
        url = url.replace(new RegExp("%5E", "g"), "^");
        url = url.replace(new RegExp("%3B", "g"), ";");
        url = url.replace(new RegExp("%28", "g"), "(");
        url = url.replace(new RegExp("%29", "g"), ")");
	url = url.replace(/^\/\^/,"^");
	url = url.replace(/http:\/\/\//,"/");
	url = url.replace(/^.*(\^\/\;.*)$/,"$1");
	url = url.replace(/^.*(\^FileUrl\(.*\)\;.*)$/,"$1");
        return url;
}

function tinyMCE_WebGUI_Cleanup(type,value) {
//	alert(value);
//	return value;
	if (value != "[object HTMLBodyElement]" && value != "[object]") {
		value = value.replace(new RegExp("&quot;", "g"),"\"");
	}
	return value;
}

