use strict;
use warnings;
use Module::Build::SysPath;

use 5.010;

my $builder = Module::Build::SysPath->new(
    module_name       => 'Debian::Apt::PM',
    license           => 'perl',
    dist_author       => 'Jozef Kutej <jkutej@cpan.org>',
    dist_version_from => 'lib/Debian/Apt/PM.pm',
    
    configure_requires => {
        'Module::Build::SysPath' => 0.13,
    },
    build_requires => {
        'Module::Build::SysPath' => 0.13,
        'Test::More'             => 0,
        'Test::Differences'      => 0,
        'Test::Exception'        => 0,
    },
    requires => {
        'Moose'                   => 0,
        'IO::Uncompress::Bunzip2' => 0,
        'IO::Any'                 => 0,
        'Parse::Deb::Control'     => 0.03,
        'Dpkg::Version'           => 0,
        'AptPkg::Config'          => 0,
        'LWP::Simple'             => 0,
        'Carp'                    => 0,
        'JSON::Util'              => 0,
        'Getopt::Long'            => 0,
        'Pod::Usage'              => 0,
        'List::MoreUtils'         => 0,
        'File::Find::Rule'        => 0,
        'File::Basename'          => 0,
        'Module::Build::ModuleInfo' => 0,
        'File::Temp'              => 0,
        'File::Path'              => 2.01,
        'CPAN::Version'           => 0,
        'Storable'                => 0,
        'File::HomeDir'           => 0,
        'File::Copy'              => 0,
        'CPAN'                    => 0,
        'File::is'                => 0,
    },
    script_files => [
        'script/apt-pm',
        'script/dpkg-scanpmpackages',
        'script/dh-make-pm',
    ],
    add_to_cleanup => [ 'Debian-Apt-PM-*' ],
    create_readme  => 1,
    sign           => 1,
    meta_merge => {
        resources => {
            repository => 'git://github.com/jozef/Debian-Apt-PM.git',
            bugtracker => 'http://github.com/jozef/Debian-Apt-PM/issues',
        },
        keywords => [ qw/ debian perl modules / ],
    },
);

$builder->create_build_script();
