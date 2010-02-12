package Debian::Apt::PM;

=head1 NAME

Debian::Apt::PM - locate Perl Modules in Debian repositories

=head1 NOTE

EXPERIMENTAL => "use at your own risk";    # you have bin warned

=head1 SYNOPSIS

Cmd-line:

	apt-pm update
	apt-pm find Moose
	dpkg-scanpmpackages /path/to/debian/repository

Module:

	my $aptpm = Debian::Apt::PM->new(sources => [ 'PerlPackages.bz2' ])
	$aptpm->update;
	my %moose_locations = $aptpm->find('Moose');

=head1 USAGE

=head2 COMMAND-LINE USAGE

Add sources for Debian s and components. Here is the complete list
that can be reduced just to the wanted ones:

	cat >> /etc/apt/sources.list << __END__
	# for apt-pm
	deb http://dbedia.com/Debian/mirror/ etch    main contrib non-free
	deb http://dbedia.com/Debian/mirror/ lenny   main contrib non-free
	deb http://dbedia.com/Debian/mirror/ sid     main contrib non-free
	deb http://dbedia.com/Debian/mirror/ squeeze main contrib non-free
	__END__

Fetch the indexes:

	apt-pm update

Look for the CPAN modules:

	apt-pm find Moose
	# libmoose-perl_0.17-1_all: Moose 0.17
	# libmoose-perl_0.94-1_i386: Moose 0.94
	# libmoose-perl_0.97-1_i386: Moose 0.97
	# libmoose-perl_0.54-1_all: Moose 0.54

Look for the non-CPAN modules:
	
	apt-pm find Purple        
	# libpurple0_2.4.3-4lenny5_i386: Purple 0.01
	
	apt-pm find Dpkg::Version
	# dpkg-dev_1.14.28_all: Dpkg::Version 0

=cut

use warnings;
use strict;

our $VERSION = '0.02';

use 5.010;

use Moose;
use IO::Uncompress::Bunzip2 qw(bunzip2 $Bunzip2Error) ;
use IO::Any;
use Parse::Deb::Control 0.03;
use Dpkg::Version 'version_compare';
use AptPkg::Config '$_config';
use LWP::Simple 'mirror', 'RC_OK';
use Carp 'croak';
use JSON::Util;

use Debian::Apt::PM::SPc;


=head1 PROPERTIES

=cut

has 'sources'         => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub { [ glob($_[0]->cachedir.'/*.json') ] });
has '_modules_index'  => (is => 'rw', isa => 'HashRef', lazy => 1, default => sub { $_[0]->_create_modules_index });
has '_apt_config'     => (is => 'rw', lazy => 1, default => sub { $AptPkg::Config::_config->init; $AptPkg::Config::_config; });
has 'cachedir'        => (is => 'ro', lazy => 1, default => sub { Debian::Apt::PM::SPc->cachedir.'/apt/apt-pm' } );


=head1 METHODS

=head2 new()

Object constructor.

=head2 find($module_name)

Returns hash with Perl versions as key and hash value having Debian version
and package name. Example:

	{
		'0.94' => {
			'version' => '0.94-1',
			'package' => 'libmoose-perl'
			'arch'    => 'i386'
		},
		'0.97' => {
			'version' => '0.97-1',
			'package' => 'libmoose-perl'
			'arch'    => 'i386'
		},
		'0.54' => {
			'version' => '0.54-1',
			'package' => 'libmoose-perl'
			'arch'    => 'i386'
		},
	};

=cut

sub find {
	my $self = shift;
	my $module = shift;
	
	return $self->_modules_index()->{$module};
}

=head2 update

Scans the F</etc/apt/sources.list> and F</etc/apt/sources.list.d/*.list>
repositories for F<PerlPackages.bz2> and prepares them to be used for find.
All F<PerlPackages.bz2> are stored to F</var/cache/apt/apt-pm/>.

=cut

sub update {
	my $self = shift;
	
	my @existing = glob($self->cachedir.'/*.bz2');
	foreach my $url ($self->_etc_apt_sources) {
		my $filename = $url;
		$filename =~ s/[^a-zA-Z0-9\-\.]/_/gxms;
		$filename = $self->cachedir.'/'.$filename;
		@existing = grep { $_ ne $filename } @existing;
		if (mirror($url, $filename) == RC_OK) {
			my $json_filename = $filename; $json_filename =~ s/\.bz2$/.json/;
			my $content;
			my $bz_content = IO::Any->slurp($filename);
			bunzip2 \$bz_content => \$content or die "bunzip2 failed: $Bunzip2Error\n";
			JSON::Util->encode([$self->_parse_perlpackages_content($content)], $json_filename);
		}
	}
	
	# remove no longer wanted indexes
	foreach my $old_filename (@existing) {
		my $json_filename = $old_filename; $json_filename =~ s/\.bz2$/.json/;
		unlink($old_filename, $json_filename);
	}
}

sub _etc_apt_sources {
	my $self = shift;

	my $apt_config = $self->_apt_config;
	my @sources_files = (
		$self->_apt_config->get_file('Dir::Etc::sourcelist'),
		glob( $self->_apt_config->get_dir('Dir::Etc::sourceparts') . '/*.list' ),
    );
    
    my $sources_text = join(
    	"\n",
    	map {
			eval { IO::Any->slurp($_) }
		} @sources_files
    );

	my $arch = $apt_config->get('APT::Architecture');
	my @urls;
	foreach my $line (split("\n", $sources_text)) {
		given ($line) {
			when (/^\s*$/) {};          # skip empty lines
			when (/^\s*#/) {};          # skip comments
			when (/^\s*deb-src/) {};    # skip source
			when (/^ \s* deb \s+ ([^ ]+) \s+ ([^ ]+) \s+ (.+) $/xms) {
				my ($url, $path, $components_string) = ($1, $2, $3);
				my @components = grep { $_ } split(/\s+/, $components_string);
				
				if ($url !~ m{^(:? http:// | ftp:// | file://)}xms) {
					warn 'unsupported schema - '.$url;
					next;
				}
				
				push @urls, map {
					$url.'dists/'.$path.'/'.$_.'/binary-'.$arch.'/PerlPackages.bz2'
				} @components;
			};
			default { warn 'unknown sources.list line - '.$line };
		}
	}
	
	return @urls;
}

sub _parse_perlpackages_content {
	my $self    = shift;
	my $content = shift;
	
	my @content_list;
	my $idx = Parse::Deb::Control->new($content);
	foreach my $entry ($idx->get_keys('Perl-Modules')) {
		my %modules = _parse_perl_modules($entry->{'para'}->{'Perl-Modules'});
		
		my %deb = (
			'version' => _trim($entry->{'para'}->{'Version'}),
			'package' => _trim($entry->{'para'}->{'Package'}),
			'arch'    => _trim($entry->{'para'}->{'Architecture'}),
		);
		
		push @content_list, { modules => \%modules, deb => \%deb };
	}
	
	return @content_list;
}

sub _create_modules_index {
	my $self = shift;
	my @sources = @{$self->sources};
	
	return {}
		if not @sources;
	
	my %modules_index;
	foreach my $src (@sources) {
		my @content_list;
		given ($src) {
			when (m/\.bz2$/) {
				my $content;
				my $bz_content = IO::Any->slurp($src);
				bunzip2 \$bz_content => \$content or die "bunzip2 failed: $Bunzip2Error\n";
				@content_list = $self->_parse_perlpackages_content($content);
			}
			when (m/\.json$/) {
				@content_list = @{JSON::Util->decode([$src])};
			}
			default { @content_list = $self->_parse_perlpackages_content(IO::Any->slurp($src)); }
		}
		
		foreach my $entry (@content_list) {
			my %modules = %{$entry->{'modules'}};
			my %deb     = %{$entry->{'deb'}};
			while (my ($module_name, $version) = each %modules) {
				# resolve conflicts when two packages has the module with the same version
				if (exists $modules_index{$module_name}->{$version}) {
					my $old_version = $modules_index{$module_name}->{$version}->{'version'};
					my $new_version = $entry->{'deb'}->{'version'};
					
					# will not overwrite if the current package has older Debian version
					next
						if version_compare($old_version, $new_version) == -1;
				}
					
				$modules_index{$module_name}->{$version} =\%deb;
			}
		}
	}
	
	return \%modules_index;
}

sub _parse_perl_modules {
	my $text = shift || '';
	
	return
		map  { m/^(.+)\s+ \( \s* ([^\(]+) \s* \)/xms ? ( $1 => $2 ) : () }
		grep { $_ }                       # remove empty lines
		map { s/^\s*//; s/\s*$//; $_ }    # trim
		split("\n", $text)                # split on new lines
	;
}

sub _trim {
	my $text = shift;
	croak 'too much argauments' if @_;
	
	$text =~ s/^\s+//xms;
	$text =~ s/\s+$//xms;
	
	return $text;
}

1;


__END__

=head1 AUTHOR

jozef@kutej.net, C<< <jkutej at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-debian-apt-pm at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Debian-Apt-PM>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Debian::Apt::PM


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Debian-Apt-PM>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Debian-Apt-PM>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Debian-Apt-PM>

=item * Search CPAN

L<http://search.cpan.org/dist/Debian-Apt-PM/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 jkutej@cpan.org.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
