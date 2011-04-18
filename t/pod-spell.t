use Test::More;

if (!$ENV{TEST_SPELLING}) {
    plan skip_all => 
      "Set the environment variable TEST_SPELLING to enable this test.";
}

eval 'use Test::Spelling;';

plan skip_all => "Test::Spelling required for testing POD spelling"
    if $@;

add_stopwords(qw(
	Jozef Kutej
	OFC
	API
	JSON
	TBD
	html
	RT
	CPAN
	AnnoCPAN
	http
	pm
	lenny
	cowbuilder
	backport
	SettingUpBuildSystem
	cachedir
	sharedstatedir
	dh
	PerlPackages
	dpkg
	scanpmpackages
	json
	TODO
	pbuilder
));
all_pod_files_spelling_ok();
