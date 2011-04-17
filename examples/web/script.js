var cpan2deb = new Object;

$(document).ready(function() {
	$('form').submit(cpan2deb.submitForm);
});

cpan2deb.module_name = function () {
	return $('input[name="q"]').val();
}

cpan2deb.submitForm = function () {
	cpan2deb.search(cpan2deb.module_name());
	return false;
}

cpan2deb.search = function (q) {
	var md5hex = hex_md5(q).toLowerCase();
	var module_info_file = 'CPAN/'+md5hex.substring(0,2)+'.json';
	
	$.ajax({ 
		type: "GET",
   		url: module_info_file,
   		dataType: 'json',
		success: function (data) { cpan2deb.show_module_info(q, data) },
		error: function () { alert('failed to fetch module information') },
	});
}

cpan2deb.show_module_info = function (module_name, module_info) {
	var module_html = 'n/a';
	var cpan_path = 'n/a';
	var cpan_version = 'n/a';
	var debs = [];
	
	if (module_info[module_name]) {
		cpan_path    = module_info[module_name].CPAN.path;
		cpan_version = module_info[module_name].CPAN.version;
		module_html  = '<a href="http://search.cpan.org/perldoc?'+encodeURIComponent(module_name)+'">'+module_name+'</a>';
		
		for (i in module_info[module_name].Debian) {
			var deb = module_info[module_name].Debian[i];
			
			debs.push(
				'<div>'
				+'Package: <a href="http://packages.debian.org/search?searchon=names&amp;suite=all&amp;section=all&amp;keywords='+encodeURIComponent(deb.package)+'">'+deb.package+'</a><br/>'
				+'Package version: '+deb.version+'<br/>'
				+'Module version: '+deb.perl_version+'<br/>'
				+'Arch: '+deb.arch+'<br/>'
				+'Dist: '+deb.distribution+'<br/>'
				+'Component: '+deb.component+'<br/>'
				+'</div>'
			);
		}
	}
	
	$('#cpanModuleName').html(module_html);
	$('#cpanPath').text(cpan_path);
	$('#cpanVersion').text(cpan_version);

	$('#debianInfo').html('');
	for (i in debs) {
		var deb = debs[i];
		$('#debianInfo').append(deb+'<br/>');
	}
}

