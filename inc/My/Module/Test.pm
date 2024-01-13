package My::Module::Test;

use 5.010;

use strict;
use warnings;

use Exporter qw{ import };
use Test2::V0;
use Test2::API qw{ context_do };
use Test2::Util::Table qw{ table };

our $VERSION = '0.000_001';

our @EXPORT_OK = qw{ check_for_duplicate_matches dependencies_table };
our @EXPORT = @EXPORT_OK;

sub check_for_duplicate_matches {
    my $caller = caller;
    state $orig;
    $orig
	and return;	# Don't call more than once.
    $orig = $caller->can( 'match' )
	or return;
    my %matches;

    # FIXME I can't use Test2::Mock::before() here because match() has
    # prototype '($)', and Test2::Mock has no way to preserve this.
    my $name = "${caller}::match";
    {
	no strict qw{ refs };
	no warnings qw{ redefine };
	*$name = sub ($) { $matches{$_[0]}++; goto $orig; };
    }

    context_do {
	my ( $ctx ) = @_;
	$ctx->hub->follow_up( sub {
		is [ grep { $matches{$_} > 1 } sort keys %matches ], [],
		    'All multiply-used matches are manifest constants';
	    },
	);
    };

    return;
}

sub dependencies_table {
    require My::Module::Meta;
    my @tables = ( '' );

    {
	my @perls = ( My::Module::Meta->requires_perl(), $] );
	foreach ( @perls ) {
	    $_ = sprintf '%.6f', $_;
	    $_ =~ s/ (?= ... \z ) /./smx;
	    $_ =~ s/ (?<= \. ) 00? //smxg;
	}
	push @tables, table(
	    header	=> [ qw{ PERL REQUIRED INSTALLED } ],
	    rows	=> [ [ perl => @perls ] ],
	);
    }

    foreach my $kind ( qw{
	configure_requires build_requires test_requires requires optionals }
    ) {
	my $code = My::Module::Meta->can( $kind )
	    or next;
	my $req = $code->();
	my @rows;
	foreach my $module ( sort keys %{ $req } ) {
	    ( my $file = "$module.pm" ) =~ s| :: |/|smxg;
	    # NOTE that an alternative implementation here is to use
	    # Module::Load::Conditional (core since 5.10.0) to find the
	    # installed modules, and then MM->parse_version() (from
	    # ExtUtils::MakeMaker) to find the version without actually
	    # loading the module.
	    my $installed;
	    eval {
		require $file;
		$installed = $module->VERSION() // 'undef';
		1;
	    } or $installed = 'not installed';
	    push @rows, [ $module, $req->{$module}, $installed ];
	}
	state $kind_hdr = {
	    configure_requires	=> 'CONFIGURE REQUIRES',
	    build_requires		=> 'BUILD REQUIRES',
	    test_requires		=> 'TEST REQUIRES',
	    requires		=> 'RUNTIME REQUIRES',
	    optionals		=> 'OPTIONAL MODULES',
	};
	push @tables, table(
	    header	=> [ $kind_hdr->{$kind} // uc $kind, 'REQUIRED', 'INSTALLED' ],
	    rows	=> \@rows,
	);
    }

    return @tables;
}

1;

__END__

=head1 NAME

My::Module::Test - Testing support for App-Test-More-To-Test2-V0

=head1 SYNOPSIS

 use lib qw{ inc };
 use My::Module::Test;

=head1 DESCRIPTION

This Perl module provides testing support for the
C<App-Test-More-To-Test2-V0> distribution. It is private to that
distribution, and may be changed or retracted without notice.
Documentation is for the benefit of the author. I<Caveat coder.>

=head1 SUBROUTINES

This package provides the following package-private subroutines, which
are exported by default.

=head2 check_for_duplicate_matches

 check_for_duplicate_matches;

If you call this subroutine it arranges to track the arguments to all
subsequent calls to C<match()>. At the end of the test script, a test is
generated which fails if any argument appears more than once.

If this subroutine is called more than once it does nothing. That means
there is no way to turn off the tracking.

The heavy lifting is done by C<< context->hub->follow_up() >>.

=head2 dependencies_table

 diag $_ for dependencies_table;

This subroutine builds and returns depencency tables. The heavy lifting
is done by C<table()> in L<Test2::Util::Table|Test2::Util::Table>. The
return is pretty much raw output from the C<table()> subroutine -- that
is, lines of text without terminating C<"\n"> characters.

B<Note> that this subroutine does not initialize C<Test2>. This is
important because it may load C<Test::Builder|Test::Builder> at some
point. If it does this after C<Test2> has been initialized, C<Test2>
will complain.

=head1 SEE ALSO

L<Test2::API|Test2::API>

L<Test2::Hub|Test2::Hub>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-Test-More-To-Test2-V0>,
L<https://github.com/trwyant/perl-App-Test-More-To-Test2-V0/issues/>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2023-2024 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
