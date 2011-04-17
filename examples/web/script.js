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

	$('input[type="submit"]').hide();
	$('.load').show();
	
	$.ajax({ 
		type: "GET",
   		url: module_info_file,
   		dataType: 'json',
		success: function (data) { cpan2deb.show_module_info(q, data); cpan2deb.searchFinish(); },
		error: function () { alert('failed to fetch module information'); cpan2deb.searchFinish(); },
	});
}

cpan2deb.searchFinish = function () {
	$('.load').hide();
	$('input[type="submit"]').show();
}

cpan2deb.show_module_info = function (module_name, module_info) {
	var module_html    = module_name;
	var cpan_path_html = 'n/a';
	var cpan_version   = 'n/a';
	var debs = [
		'This module is not packaged for Debian.<br/>'
		+'There are 2 ways to fix this:<br/>'
		+'<ul>'
		+' <li>use `reportbug` and <a href="http://pkg-perl.alioth.debian.org/howto/RFP.html">fill-in RTP</a></li>'
		+' <li><a href="http://pkg-perl.alioth.debian.org/">join Debian Perl Group</a> and help with packaging</li>'
		+'</ul>'
	];
	
	if (module_info[module_name]) {
		cpan_path_html = '<a href="http://search.cpan.org/CPAN/authors/id/'+module_info[module_name].CPAN.path+'">'+module_info[module_name].CPAN.path+'</a>';
		cpan_version   = module_info[module_name].CPAN.version;
		module_html    = '<a href="http://search.cpan.org/perldoc?'+encodeURIComponent(module_name)+'">'+module_name+'</a>';
		
		if (module_info[module_name].Debian.length != 0) {
			debs = [];
		}
		
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
	$('#cpanPath').html(cpan_path_html);
	$('#cpanVersion').text(cpan_version);

	$('#debianInfo').html('');
	for (i in debs) {
		var deb = debs[i];
		$('#debianInfo').append(deb+'<br/>');
	}
}

