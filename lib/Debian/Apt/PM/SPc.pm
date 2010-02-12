package Debian::Apt::PM::SPc;

=head1 NAME

Acme::SysPath::SPc - build-time system path configuration

=cut

use warnings;
use strict;

our $VERSION = '0.02';

use File::Spec;

sub _path_types {qw(
	cachedir
)};

=head1 PATHS

=head2 prefix

=head2 cachedir

The Perl modules indexes are stored in F</var/cache/apt/apt-pm/> folder.

=cut

sub prefix     { use Sys::Path; Sys::Path->find_distribution_root(__PACKAGE__); };
sub cachedir   { File::Spec->catdir(__PACKAGE__->prefix, 'cache') };

1;


__END__

=head1 AUTHOR

Jozef Kutej

=cut
