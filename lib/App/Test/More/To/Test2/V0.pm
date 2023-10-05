package App::Test::More::To::Test2::V0;

use 5.014;	# For s///r

use strict;
use warnings;

use PPI::Document;
use PPIx::Utils;

our $VERSION = '0.000_001';

use constant CONVERT_BY_HAND	=> ' must be converted by hand';

# From Perl::Critic::Utils
my $MIN_PRECEDENCE_TO_TERMINATE_PARENLESS_ARG_LIST =
    PPIx::Utils::precedence_of( 'not' );

sub new {
    my ( $class, %arg ) = @_;

    {
	no warnings qw{ once };
	$Carp::verbose
	    and delete $arg{die};
    }

    my $self = bless {
	bail_on_fail	=> delete $arg{bail_on_fail},
	die		=> delete $arg{die},
	load_module	=> delete $arg{load_module},
	quiet		=> delete $arg{quiet},
    }, $class;
    keys %arg
	and $self->__croak( 'Unsupported arguments: ',
	join ', ', map { "'$_'" } sort keys %arg );
    return $self;
}

sub convert {
    my ( $self, $file ) = @_;

    local $self->{_cvt} = {};

    $self->{_cvt}{file} = $file;

    my $doc = $self->{_cvt}{doc} = PPI::Document->new ( $file )
	or $self->__croak( "Failed to open $file: $!" );

    my $rewrite = $self->_convert_use()
	    + $self->_convert_bail()
	    + $self->_convert_sub()
	    + $self->_convert_todo()
	or $self->{quiet}
	or $self->__carp( "$file does not use Test::More (or so I think)" );

    my $content = $doc->serialize();

    if ( $rewrite && ! ref $file ) {
	open my $fh, '>', $file
	    or $self->__croak( "Failed to open $file for output: $!" );
	print { $fh } $content;
	close $fh;
    }

    return $content;
}

sub _convert_bail {
    my ( $self ) = @_;

    $self->{bail_on_fail}
	or return 0;

    my $rslt = 0;

    foreach my $bail (
	@{ $self->{_cvt}{doc}->find( 'PPI::Token::Word' ) || [] }
    ) {
	$bail eq 'BAIL_OUT'
	    or next;

	my $next_sib = $bail->next_sibling();

	my $ele = $self->_delete_elements( $bail );

	state $unwanted = { map { $_ => 1 } do {
		no warnings qw{ qw };	## no critic (ProhibitNoWarnings)
		qw{ and or xor ; }
	    }
	};

	$ele
	    and $unwanted->{$ele}
	    and $self->_delete_elements( $ele );

	$ele = $next_sib;
	while ( $ele && ! $unwanted->{$ele} ) {
	    $ele = $self->_delete_elements( $ele, 1 );
	}

	$rslt++;
    }

    $rslt
	and $self->_add_use( 'Test2::Plugin::BailOnFail' );

    return $rslt;
}

sub _convert_sub {
    my ( $self ) = @_;

    my $rslt = 0;

    state $sub_map_to	= {
	BAIL_OUT	=> {
	    fixup	=> \&_convert_sub__fixup__BAIL_OUT,
	    handler	=> \&_convert_sub__nop,
	},
	builder		=> {
	    handler	=> \&_convert_sub__named__builder,
	},
	is_deeply	=> {
	    handler	=> \&_convert_sub__rename,
	    to		=> {
		name	=> 'is',
	    },
	},
	isa_ok		=> {
	    handler	=> \&_convert_sub__named__isa_ok,
	},
	plan		=> {
	    handler	=> \&_convert_sub__named__plan,
	},
	require_ok	=> {
	    fixup	=> \&_convert_sub__fixup__load_module_ok,
	    handler	=> \&_convert_sub__nop,
	},
	use_ok		=> {
	    fixup	=> \&_convert_sub__fixup__load_module_ok,
	    handler	=> \&_convert_sub__named__use_ok,
	    to		=> {
		name	=> 'load_module_ok',
	    },
	},
	'Test::Builder::Level'	=> {
	    fixup	=> \&_convert_sub__fixup__test_builder_level,
	    handler	=> \&_convert_sub__nop,
	},
    };

    my %generated;

    foreach my $from (
	(
	    map { {
		    name	=> $_->content(),
		    ele		=> $_,
		    class	=> 'PPI::Token::Word',
		    sigil	=> '',
		} }
	    grep { PPIx::Utils::is_subroutine_name( $_ ) ||
		PPIx::Utils::is_function_call( $_ ) ||
		PPIx::Utils::is_method_call( $_ ) }
	    @{ $self->{_cvt}{doc}->find( 'PPI::Token::Word' ) || [] } ),
	(
	    map { {
		    name	=> _strip_sigil( $_ ),
		    ele		=> $_,
		    class	=> 'PPI::Token::Symbol',
		    sigil	=> $_->raw_type(),
		} }
	    grep {
		_is_goto( $_ ) && $_->raw_type() eq '&' ||
		$_ =~ m/ \A [*&%\$\@] Test::Builder:: /smx
	    }
	    @{ $self->{_cvt}{doc}->find( 'PPI::Token::Symbol' ) || [] } ),
    ) {

	my $to = $sub_map_to->{ $from->{name} }
	    or next;

	$rslt++;
	$generated{ $to->{to}{name} // $from->{name} } = $to->{fixup};

	$to->{handler}->( $self, $from, $to->{to} );

    }

    foreach my $code ( values %generated ) {
	$code
	    and $code->( $self );
    }

    return $rslt;
}

sub _convert_sub__fixup__BAIL_OUT {
    my ( $self ) = @_;
    return $self->_add_code(
	'sub BAIL_OUT { Test2::API::context()->bail( @_ ) }',
    );
}

sub _convert_sub__fixup__load_module_ok {
    my ( $self ) = @_;
    my @args = 'Test2::Tools::LoadModule';
    push @args, $self->{load_module} ? ':all' : ':more';
    return $self->_add_use(
	'Test2::Tools::LoadModule',
	$self->{load_module} ? 'qw{ :all }' : 'qw{ :more }',
    );
}

sub _convert_sub__fixup__test_builder_level {
    my ( $self ) = @_;
    return $self->_add_use( 'Test::Builder', '()' );
}

sub _convert_sub__named__builder {
    my ( $self, $from ) = @_;	# $to unused
    PPIx::Utils::is_method_call( $from->{ele} )
	or return;

=begin comment

    my $sib = $from->{ele}->sprevious_sibling()
	or return;
    $sib->isa( 'PPI::Token::Operator' )
	and $sib->content() eq '->'
	or return;
    $sib = $sib->sprevious_sibling()
	or return;
    $sib->isa( 'PPI::Token::Word' )
	and $sib->content() eq 'Test::More'
	or return;

=end comment

=cut

    $self->__carp( $from->{ele}->statement(), CONVERT_BY_HAND );
    return;
}

sub _convert_sub__named__isa_ok {
    my ( $self, $from ) = @_;	# $to unused
    my @arg = PPIx::Utils::parse_arg_list( $from->{ele} );
    @arg > 2
	and $self->__carp( 'isa_ok() has more than two arguments' );
    return;
}

sub _convert_sub__named__plan {
    my ( $self, $from ) = @_;	# $to unused
    if ( $from->{ele}->isa( 'PPI::Token::Word' ) ) {
	my @arg = PPIx::Utils::parse_arg_list( $from->{ele} );

	# FIXME this is replicated
	state $sub_map = {
	    tests	=> 'plan',
	    skip_all	=> 'skip_all',
	};

	if ( @arg == 2
		and @{ $arg[0] } == 1
		and my $sub_name = $sub_map->{$arg[0][0]}
	) {

	    my $sub_arg = "@{ $arg[1] }";
	    my $next_sib = $from->{ele}->snext_sibling();
	    if ( $next_sib->isa( 'PPI::Structure::List' ) ) {
		my $doc = $self->_parse_string( "( $sub_arg )" );
		my $list = $doc->find_first( 'PPI::Structure::List' )
		    or __confess(
			"Parse of '( $sub_arg )' did not ",
			'produce a PPI::Structure::List',
		    );
		$next_sib->replace( $list->remove() );
	    } else {
		my $iter = $from->{ele};
		my $insert_after = $next_sib->previous_sibling();
		my @arg_list;
		# NOTE The following code is cribbed shamelessly from
		# PPIx::Utils::Traversal::parse_arg_list().
		while ( $iter = $iter->next_sibling() ) {
		    last if $iter->isa('PPI::Token::Structure') && $iter eq ';';
		    last if $iter->isa('PPI::Token::Operator')
			&& $MIN_PRECEDENCE_TO_TERMINATE_PARENLESS_ARG_LIST <=
			    PPIx::Utils::precedence_of( $iter );
		    push @arg_list, $iter;
		}
		# NOTE The preceding code is cribbed shamelessly from
		# PPIx::Utils::Traversal::parse_arg_list().
		shift @arg_list while @arg_list && ! $arg_list[0]->significant();
		pop @arg_list while @arg_list && ! $arg_list[-1]->significant();
		$_->delete() for @arg_list;

		my $doc = $self->_parse_string( $sub_arg );
		# FIXME __insert_after() is an encapsulation violation,
		# but insert() will not insert a PPI::Statement, at
		# least not as of 1.276
		$insert_after->__insert_after( $_->remove() )
		    for reverse $doc->children();
	    }
	    $sub_name ne $from->{name}
		and $from->{ele}->replace( PPI::Token::Word->new( $sub_name ) );

	} elsif ( @arg == 1 ) {
	    # Do nothing, because we have already been converted.
	} else {
	    $self->__carp( $from->{ele}, ' ', CONVERT_BY_HAND );
	}

    } else {
	$self->__carp( $from->{ele}, ' ', CONVERT_BY_HAND );
    }
    return;
}

sub _convert_sub__named__use_ok {
    my ( $self, $from ) = @_;	# $to unused
    $self->{load_module}
	and goto &_convert_sub__rename;
    my $from_stmt = $from->{ele}->statement();
    ( my $to_text = $from_stmt->content() ) =~ s/ \b use_ok \b /use ok/smx;
    my $doc = $self->_parse_string( $to_text );
    my $to_stmt = $doc->find_first( 'PPI::Statement::Include' )
	or $self->__confess(
	'Failed to find a PPI::Statement::Include in ',
	"'$to_text'",
    );
    $from_stmt->replace( $to_stmt->remove() );
    return;
}

sub _convert_sub__nop {
    return;
}

sub _convert_sub__rename {
    my ( undef, $from, $to ) = @_;	# Invocant unused

    # FIXME Encapsulation violation. The new() method is undocumented
    # but somewhat widely used outside PPI.
    my $to_ele = $from->{class}->new( "$from->{sigil}$to->{name}" );

    $from->{ele}->replace( $to_ele );

    return;
}

sub _convert_todo {
    my ( $self ) = @_;

    my $rslt = 0;

    foreach my $ele (
	@{ $self->{_cvt}{doc}->find( 'PPI::Statement::Variable' ) || [] }
    ) {
	my $local = $ele->schild( 0 )
	    or next;
	$local eq 'local'	# PPI::Token::Word
	    or next;
	my $symbol = $ele->schild( 1 )
	    or next;
	$symbol eq '$TODO'	# PPI::Token::Symbol
	    or next;
	my $assign = $ele->schild( 2 )
	    or next;
	$assign eq '='		# PPI::Token::Operator
	    or next;

	my $todo_doc = $self->_parse_string( 'my $todo = todo "Foo";' );
	my ( $todo_stmt ) = @{ $todo_doc->find(
	'PPI::Statement::Variable' ) || [] }
	    or $self->__confess( 'Failed to build Test2::V0 todo statement' );
	my $my = $todo_stmt->schild( 0 )
	    or $self->__confess( q{Failed to find word 'my'} );
	my $todo_sym = $todo_stmt->schild( 1 )
	    or $self->__confess( q{Failed to find symbol '$todo'} );
	my $todo_call = $todo_stmt->schild( 3 )
	    or $self->__confess( q{Failed to find word 'todo'} );
	my $space = $todo_call->previous_sibling();
	$local->replace( $my->remove() );
	$symbol->replace( $todo_sym->remove() );
	$assign->insert_after( $todo_call->remove() );
	$assign->insert_after( $space->remove() );
    }

    return $rslt;
}

sub _convert_use {
    my ( $self ) = @_;

    my $rslt = 0;

    foreach my $use (
	@{ $self->{_cvt}{doc}->find( 'PPI::Statement::Include' ) || [] }
    ) {

	( $use->module() // '' ) eq 'Test::More'
	    or next;
	my $type = $use->type();

	my $repl = $self->_parse_string( "$type Test2::V0;" );
	$self->{_cvt}{use}{'Test2::V0'} ||=
	    $use->replace( $repl->schild( 0 )->remove() );

	if ( my $start = _find_use_arg_start_point( $use ) ) {
	    my @arg = PPIx::Utils::parse_arg_list( $start );

	    if ( @arg ) {

		@arg = map { _ppi_to_string( @{ $_ } ) } @arg;
		state $sub_map = {
		    tests	=> 'plan',
		    skip_all	=> 'skip_all',
		};
		@arg == 2
		    and $sub_map->{$arg[0]}
		    or $self->__croak( "'use Test::More @arg;' unsupported" );

		$self->_add_code( "$sub_map->{$arg[0]}( $arg[1] );" );
	    }
	}

	$rslt++;

    }

    return $rslt;
}

sub _add_code {
    my ( $self, $code ) = @_;

    unless ( $self->{_cvt}{code} ) {
	my $ele = $self->_find_use( 'Test2::V0' );
	my $next;
	while ( 1 ) {
	    $next = $ele->snext_sibling()
		or last;
	    $next->isa( 'PPI::Statement::Include' )
		and next;
	    $ele = $next->previous_sibling();
	    last;

	} continue {
	    $ele = $next;
	}
	$self->{_cvt}{code} = $ele;

	$ele =~ m/ \n \z /smx
	    or substr $code, 0, 0, "\n";

	$self->{_cvt}{code_end} = '';
	$next = $ele->next_sibling()
	    and $next =~ m/ \A \n /smx
	    or $self->{_cvt}{code_end} = "\n";
    }

    $self->{_cvt}{code} =~ m/ \n \z /smx
	or substr $code, 0, 0, "\n";
    $code .= $self->{_cvt}{code_end};

    my $doc = $self->_parse_string( $code );

    my @kids = map { $_->remove() } $doc->children();

    # FIXME __insert_after() is an encapsulation violation, but insert()
    # will not insert a PPI::Statement, at least not as of 1.276
    foreach my $kid ( reverse @kids ) {
	$self->{_cvt}{code}->__insert_after( $kid );
    }

    $self->{_cvt}{code} = $kids[-1];

    return;
}

sub _add_use {
    my ( $self, $module, @arg ) = @_;

    $self->_find_use( $module )
	and return;
    my $use_test2_v0 = $self->_find_use( 'Test2::V0' )
	or $self->__croak(
	    "Unable to find 'use Test2::V0'. Can not add 'use $module'",
	);
    my $load_doc = $self->_parse_string( do {
	    local $" = ', ';
	    @arg ? "\nuse $module @arg;" : "\nuse $module;";
	}
    );
    my @kids = $load_doc->children();
    $self->{_cvt}{use}{$module} = $kids[-1];
    # FIXME __insert_after() is an encapsulation violation, but insert()
    # will not insert a PPI::Statement, at least not as of 1.276
    $use_test2_v0->__insert_after( $_->remove() )
	for reverse @kids;
    $self->__carp(
	"Added 'use $module'",
    );
    return;
}

sub _delete_elements {
    my ( undef, $ele, $forward ) = @_;
    my $method = $forward ? 'next_sibling' : 'previous_sibling';
    my $sib = $ele->$method();
    $ele->delete();
    while ( $sib ) {
	$sib->significant()
	    and return $sib;
	$ele = $sib;
	$sib = $ele->$method();
	$ele->delete();
    }
    return $sib;
}

sub _find_use {
    my ( $self, $class ) = @_;

    not wantarray
	and $self->{_cvt}{use}{$class}
	and return $self->{_cvt}{use}{$class};

    my @rslt;

    foreach my $use (
	@{ $self->{_cvt}{doc}->find( 'PPI::Statement::Include' ) || [] }
    ) {
	( $use->module() // '' ) eq $class
	    or next;

	$self->{_cvt}{use}{$class} ||= $use;

	wantarray
	    or return $use;

	push @rslt, $use;
    }

    return @rslt;
}

sub _find_use_arg_start_point {
    my ( $use ) = @_;	# A PPI::Statement::Include;

    $use->type() eq 'use'	# It's 'require ...' or 'no ...'.
	or return;

    $use->module()
	or return $use->type();	# It's 'use 5.xxx;'
    # We have to get the module name this way because $use->module()
    # returns a string, not a PPI::Element.
    my $module = $use->schild( 1 );

    my $version = $module->snext_sibling()
	or return $module;	# It's 'use Foo', unterminated
    $version->isa( 'PPI::Token::Structure' )
	and return $module;	# It's 'use Foo;'
    $version->isa( 'PPI::Token::QuoteLike::Words' )
	and return $module;	# It's 'use Foo qw{ ... }'
    $version->isa( 'PPI::Structure' )
	and return $module;	# It's 'use Foo ( ... )'

    my $next_sib = $version->snext_sibling()
	or return $version;	# It's 'use Foo version', unterminated

    $next_sib->isa( 'PPI::Token::Structure' )
	and return $version;	# It's 'use Foo version;'
    $next_sib->isa( 'PPI::Token::Operator' )
	and return $module;	# It's 'use Foo arg ...'

    return $version;		# It's 'use Foo version ...'
}

sub _is_goto {
    my ( $ele ) = @_;
    my $prev = $ele->sprevious_sibling()
	or return;
    return $prev->isa( 'PPI::Token::Word' ) && $prev eq 'goto';
}

sub _parse_string {
    my ( $self, $string ) = @_;

    my $doc = PPI::Document->new( \$string )
	or $self->__confess( "PPI can not parse '$string'" );

    return $doc;
}

sub _ppi_to_string {
    my @arg = @_;
    foreach ( @arg ) {
	my $code = $_->can( 'literal' ) || $_->can( 'string' ) || $_->(
	    'content' );
	$_ = $code->( $_ );
    }
    return "@arg";
}

sub _strip_sigil {
    my ( $symbol ) = @_;
    ( my $rslt = "$symbol" ) =~ s/ \A [*&%\$\@] //smx;
    return $rslt;
}

sub __carp {
    my ( $self, @args ) = @_;
    chomp $args[-1];
    push @args, " in file $self->{_cvt}{file}";
    if ( $self->{die} ) {
	warn @args, "\n";
    } else {
	require Carp;
	Carp::carp( @args );
    }
    return;
}

sub __confess {
    my ( undef, @args ) = @_;	# Invocant unused
    chomp $args[-1];
    require Carp;
    Carp::confess( 'Bug - ', @args );
    return;
}

sub __croak {
    my ( $self, @args ) = @_;
    if ( $self->{die} ) {
	__unchomp( $args[-1] );
	die @args;
    } else {
	chomp $args[-1];
	require Carp;
	Carp::croak( @args );
    }
    return;
}

sub __unchomp {
    rindex( $_[0], $/ ) eq length( $_[0] ) - length( $/ )
	or $_[0] .= $/;
    return;
}

1;

__END__

=head1 NAME

App::Test::More::To::Test2::V0 - Convert L<Test::More|Test::More> tests to L<Test2::V0|Test2::V0>.

=head1 SYNOPSIS

 use App::Test::More::To::Test2::V0
 
 my $app = App::Test::More::To::Test2::V0->new();
 $app->convert( 't/some_test.t' );

=head1 DESCRIPTION

This Perl class/application attempts to convert Perl test files that use
L<Test::More|Test::More> into test files that use
L<Test2::V0|Test2::V0>.

It is well-known that Perl can not be statically parsed. This code
side-steps the problem by assuming that L<PPI|PPI> can in fact do it
anyway, and then applies whatever ad-hocery seems appropriate.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $app = App::Test::More::To::Test2::V0->new();
 $app->convert( 't/foo.t' );

This static method instantiates and returns an application object. It
takes the following named arguments:

=over

=item bail_on_fail

If this Boolean argument is true, C<BAIL_OUT()> calls will be
removed, and C<use Test2::Tools::BailOnFail;> will be added.

Otherwise C<< sub BAIL_OUT { context()->bail( @_ ) >> will be added.

The default is false.

=item die

If this Boolean argument is true errors will be reported using L<warn>
or L<die> as appropriate. If false, they will be reported using
L<Carp::carp()|Carp> or L<Carp::croak()|Carp>.

B<Note> that this argument is ignored if C<$Carp::verbose> is true.

The default is false.

=item load_module

If this Boolean argument is true, C<use_ok( ... )> will be implemented
by C<Test2::Tools::LoadModule::use_ok()>. Otherwise it will be converted
to C<use ok ( ... )>.

The default is false.

=item quiet

If this Boolean argument is true warnings will be suppressed.

The default is false.

=back

=head2 convert

 $app->convert( 't/foo.t' );

This method takes as its argument the name of a test file and converts
that file from L<Test::More|Test::More> to L<Test2::V0|Test2::V0>. The
content of the converted file is returned.

B<Caveat:> This method modifies files in-place. It is your
responsibility to ensure that you have adequate back-up in case
'modifies' turns out to mean 'clobbers.'

If no modifications are made, a warning is issued and the file is not
re-written. The warning can be suppressed by specifying a true value for
the L<quiet|/quiet> argument to L<new()|/new>.

It is also possible to pass a scalar reference containing text to be
converted. In this case, of course, no file is written.

The specific modifications are:

=over

=item use Test::More ...

All occurrences of C<use Test::More;>, C<no Test::More;>, and C<require
Test::More;> are changed to use, no, or require C<Test2::V0>.

All occurrences of C<use Test::More ...;> are examined for a C<'tests'>
argument; if one is found, a call to C<plan();> is added.

All occurrences of C<use Test::More ...;> are examined for a
C<'skip_all'> argument; if one is found, a call to C<skip_all();> is
added.

=item BAIL_OUT()

If the L<bail_on_fail|/bail_on_fail> attribute is true, all calls to
C<BAIL_OUT()> will be removed, and C<use Test2::Plugin::BailOnFail;>
will be added. A warning will be generated, since this adds a
dependency. B<Note> that this involves a change in test semantics, since
B<any> test failure will now cause the entire test suite to be
abandoned.

If the L<bail_on_fail|/bail_on_fail> attribute is false or omitted,

 sub BAIL_OUT { context()->bail( @_ ) }

will be added.


=item builder()

A call to C<< Test::More->builder() >> returns the underlying
L<Test::Builder|Test::Builder> singleton. I believe the usual reason to
do this is to modify the encoding on the test output handles.

L<Test2::V0|Test2::V0> encodes output as utf-8 by default. If further
modifications are needed you need to retrieve the formatter and modify
it.

Because of these considerations, all this tool does if it finds
C<builder()> called as a method is to issue a warning saying that it
needs to be hand-converted.

=item is_deeply()

All calls to C<is_deeply()> are changed to calls to C<is()>.

=item isa_ok()

The L<Test::More|Test::More> and L<Test2::V0|Test2::V0> versions of this
test are B<almost> identical. The difference is that the
L<Test::More|Test::More> version takes two arguments and silently
ignores extras, but the L<Test2::V0|Test2::V0> version takes two or
more. This means if L<Test::More::isa_ok(...)|Test::More> is mistakenly
called with a third argument containing (say) the intended test name,
the mistake may not be found until the conversion is done.

Because the potential problem is a coding error, all this tool does is
to issue a warning if C<isa_ok()> is called with three or more
arguments.

=item plan()

This tool converts a two-argument call to C<plan()> into a
single-argument call to either C<plan()> or C<skip_all()>, depending on
the value of the first of the two arguments.

=item require_ok()

A C<use Test2::Tools::LoadModule ':more';> is added. A warning is
generated, since this adds a dependency.

=item use_ok()

If the L<load_module|/load_module> attribute is true, all calls to
C<use_ok( ... )> are changed to C<use ok ...>. A warning is generated,
since this adds a dependency on C<ok>.

If the L<load_module|/load_module> attribute is false or unspecified, a
C<use Test2::Tools::LoadModule ':more';> is added. A warning is
generated, since this adds a dependency.

=item $TODO

All instances of C<local $TODO = ...> are replaced by
C<my $TODO = todo ...>.

=item $Test::Builder::Level

If this is found, C<use Test::Builder ();> is added.

B<Note> that
L<Test2::Manual::Tooling::TestBuilder|Test2::Manual::Tooling::TestBuilder>
claims that C<$Test::Builder::Level> will be honored if set; but I have
found that just assigning it a value does not suffice, and I need to
actually load L<Test::Builder|Test::Builder> to get this behavior.

=back

=head1 SEE ALSO

L<PPI|PPI>.

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
