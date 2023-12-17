package My::Module::Test;

use 5.010;

use strict;
use warnings;

use Exporter qw{ import };
use Test2::V0;
use Test2::API qw{ context_do };

our $VERSION = '0.000_001';

our @EXPORT_OK = qw{ check_for_duplicate_matches };
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

Copyright (C) 2023 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
