package App::Test::More::To::Test2::V0;

use 5.014;	# For s///r

use strict;
use warnings;

use PPI::Document;
use PPIx::Utils;

our $VERSION = '0.000_001';

use constant CONVERT_BY_HAND	=> 'must be converted by hand';

# From Perl::Critic::Utils
use constant MIN_PRECEDENCE_TO_TERMINATE_PARENLESS_ARG_LIST =>
    PPIx::Utils::precedence_of( 'not' );

sub new {
    my ( $class, %arg ) = @_;

    {
	no warnings qw{ once };
	$Carp::Verbose
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
	join ', ', sort keys %arg );
    return $self;
}

sub convert {
    my ( $self, $file ) = @_;

    local $self->{_cvt} = {};

    $self->{_cvt}{file} = $file;

    my $doc = $self->{_cvt}{doc} = PPI::Document->new ( $file )
	or $self->__croak( "Failed to open $file: $!" );

    my $rewrite = $self->_convert_use()
	    + $self->_convert_sub()
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

sub _convert_by_hand {
    my ( $self, $ele ) = @_;
    my $stmt = $ele->statement();
    $self->__carp( $stmt, ' ', CONVERT_BY_HAND );
    $stmt->insert_before( $_ )
	for $self->_parse_string_kids(
	qq<diag '\u@{[ CONVERT_BY_HAND ]} in ', __FILE__, ' line ', __LINE__; > );
    return;
}

sub _convert_sub {
    my ( $self ) = @_;

    my $rslt = 0;

    state $sub_map_to	= {
	BAIL_OUT	=> \&_convert_sub__named__BAIL_OUT,
	builder		=> \&_convert_sub__named__builder,
	is_deeply	=> sub {
	    $_[0]->_convert_sub__rename( $_[1], { name => 'is' } );
	    return;
	},
	isa_ok		=> \&_convert_sub__named__isa_ok,
	plan		=> \&_convert_sub__named__plan,
	require_ok	=> \&_convert_sub__named__require_ok,
	use_ok		=> \&_convert_sub__named__use_ok,

	'Test::Builder::Level' => \&_convert_sub__symbol__test_builder_level,
	'TODO'		=> \&_convert_sub__symbol__TODO,
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
		$_->raw_type() eq '$'
	    }
	    @{ $self->{_cvt}{doc}->find( 'PPI::Token::Symbol' ) || [] } ),
    ) {

	my $code = $sub_map_to->{ $from->{name} }
	    or next;

	$rslt++;

	my ( $key, $fixup );
	( $key, $fixup ) = $code->( $self, $from )
	    and ( $generated{$key} ||= $fixup );
    }

    $_->( $self ) for values %generated;

    return $rslt;
}

sub _convert_sub__fixup__load_module_ok {
    my ( $self ) = @_;
    return $self->_add_use(
	'Test2::Tools::LoadModule', q<':more'>,
    );
}

sub _convert_sub__named__BAIL_OUT {
    my ( $self, $from ) = @_;

    my $rslt;

    if ( $self->{bail_on_fail} ) {

	my $bail = $from->{ele};

	my $next_sib = $bail->next_sibling();

	my $ele = $self->_delete_elements( $bail );

	not _ele_is_valid_arg( $ele )
	    and $self->_delete_elements( $ele );

	$ele = $next_sib;
	while ( _ele_is_valid_arg( $ele ) ) {
	    $ele = $self->_delete_elements( $ele, 1 );
	}

	$rslt = sub { return $_[0]->_add_use( 'Test2::Plugin::BailOnFail' ) };
    } else {
	$rslt = sub {
	    return $_[0]->_add_statement(
		'sub BAIL_OUT { Test2::API::context()->bail( @_ ) }',
	    );
	};
    }

    return( BAIL_OUT => $rslt );
}

sub _convert_sub__named__builder {
    my ( $self, $from ) = @_;	# $to unused
    PPIx::Utils::is_method_call( $from->{ele} )
	or return;
    return $self->_convert_by_hand( $from->{ele} );
}

sub _convert_sub__named__isa_ok {
    my ( $self, $from ) = @_;	# $to unused
    my @arg = PPIx::Utils::parse_arg_list( $from->{ele} );
    if ( @arg > 2 ) {
	my $punc = ',';
	if ( @{ $arg[0] } == 1 && $arg[0][0]->isa( 'PPI::Token::Word' ) ) {
	    if ( $arg[0][0] =~ m/ \A \w+ \z /smx ) {
		$punc = ' =>';
	    } else {
		$arg[0][0] = "'$arg[0][0]'";
	    }
	}
	$self->_replace_sub_args( $from->{ele}, "@{ $arg[0] }$punc @{ $arg[1] }" );
    }
    return;
}

sub _convert_sub__named__plan {
    my ( $self, $from ) = @_;	# $to unused

    if ( $from->{ele}->isa( 'PPI::Token::Word' ) ) {
	my @from_arg = PPIx::Utils::parse_arg_list( $from->{ele} );

	if ( @{ $from_arg[0] } == 1
		and my $info = _map_plan_arg_to_sub( $from_arg[0][0] ) ) {
	    if ( defined( my $to_name = $info->{name} ) ) {
		$self->_replace_sub_args( $from->{ele}, $info->{has_arg}
		    ? "@{ $from_arg[1] }" : () );

		# FIXME Encapsulation violation. The new() method is
		# undocumented but somewhat widely used outside PPI.
		$to_name ne $from->{name}
		    and $from->{ele}->replace( PPI::Token::Word->new(
			$to_name ) );
	    } else {
		# FIXME this assumes that the "plan( 'no_plan' )" stands
		# on its own as a statement.
		$from->{ele}->statement()->delete();
	    }

	} elsif ( @from_arg == 1 ) {
	    # Do nothing, because we have already been converted.
	} else {
	    # We do not understand the call
	    $self->_convert_by_hand( $from->{ele} );
	}

    } else {
	$self->_convert_by_hand( $from->{ele} );
    }
    return;
}

sub _convert_sub__named__require_ok {	# TODO not used yet
    my ( $self, $from ) = @_;	# $to unused

    # TODO parallel construction. Make use_ok like this
    $self->{load_module}
	and return(
	    load_module	=> \&_convert_sub__fixup__load_module_ok,
	);

    my @arg = PPIx::Utils::parse_arg_list( $from->{ele} );

    my $module;
    if ( @{ $arg[0] } == 1 && $arg[0][0]->isa( 'PPI::Token::Quote' ) ) {
	$module = $arg[0][0]->string();
	$module =~ m/ \A \w+ (?: :: \w+ )* \z /smx
	    or $module = "@{ $arg[0] }";
    } else {
	$module = "@{ $arg[0] }";
    }

    my $ele = $from->{ele}->next_sibling();
    while ( _ele_is_valid_arg( $ele ) ) {
	$ele = $self->_delete_elements( $ele, 1 );
    }

    my $repl_string = " lives { require $module }, 'require $module;'";
    if ( $ele ) {
	if ( $ele->isa( 'PPI::Token::Structure' ) && $ele eq ';' ||
	    # NOTE this is not quite right, because it assumes that
	    # diag() returns a false value. It in fact does as of
	    # Test2::V0 0.000156, but unlike Test::More, this fact is
	    # not documented.
	    $ele->isa( 'PPI::Token::Operator' ) && $ele eq 'or'
	) {
	    $repl_string .= <<"END_OF_DATA";
 or diag <<"EOD"
    Tried to require '$module'
    Error: \$@
EOD
END_OF_DATA
	} else {
	    $repl_string .= ' ';
	}
    }

    my @repl = $self->_parse_string_parts( $repl_string );

    $repl[-1]->isa( 'PPI::Token::Whitespace' )
	and $repl[-1] eq "\n"
	and pop @repl;

    $from->{ele}->insert_after( $_ ) for reverse @repl;

    # FIXME Encapsulation violation. The new() method is undocumented
    # but somewhat widely used outside PPI.
    $from->{ele}->replace( PPI::Token::Word->new( 'ok' ) );

    return;
}

sub _convert_sub__named__use_ok {
    my ( $self, $from ) = @_;	# $to unused

    $self->{load_module}
	and return(
	    load_module	=> \&_convert_sub__fixup__load_module_ok,
	);

    my $from_stmt = $from->{ele}->statement();
    ( my $to_text = $from_stmt->content() ) =~ s/ \b use_ok \b /use ok/smx;

    my $to_stmt = $self->_parse_string_for(
	$to_text, 'PPI::Statement::Include',
    );

    $from_stmt->replace( $to_stmt );
    return(
	use_ok => sub {
	    $self->__carp(
		"Added 'use ok'",
	    );
	},
    );
}

sub _convert_sub__rename {
    my ( undef, $from, $to ) = @_;	# Invocant unused

    # FIXME Encapsulation violation. The new() method is undocumented
    # but somewhat widely used outside PPI.
    $from->{ele}->replace(
	$from->{class}->new( "$from->{sigil}$to->{name}" )
    );

    return;
}

sub _convert_sub__symbol__TODO {
    my ( $self, $from ) = @_;

    my $stmt = $from->{ele}->statement()
	or return;
    $stmt->isa( 'PPI::Statement::Variable' )
	or return;

    my $local = $stmt->schild( 0 )
	or return;
    $local eq 'local'
	or return;

    my $assign = $stmt->schild( 2 )
	or return;
    $assign->isa( 'PPI::Token::Operator' )
	and $assign eq '='
	or return;

    my $rhs = $assign->next_sibling()
	or return;
    my $todo = $rhs->isa( 'PPI::Token::Whitespace' ) ? ' todo' : ' todo ';

    # FIXME Encapsulation violation. The new() method is undocumented
    # but somewhat widely used outside PPI.
    $local->replace( PPI::Token::Word->new( 'my' ) );

    $assign->insert_after( $_ ) for reverse $self->_parse_string_parts(
	$todo );

    return;
}

sub _convert_sub__symbol__test_builder_level {
    # my ( $self ) = @_;	# $self, $from, $to unused

    return(
	'Test::Builder::Level',
	sub {
	    my ( $self ) = @_;
	    return $self->_add_use( 'Test::Builder' );
	},
    );
}

sub _convert_use {
    my ( $self ) = @_;

    my $rslt = 0;

    foreach my $use (
	@{ $self->{_cvt}{doc}->find( 'PPI::Statement::Include' ) || [] }
    ) {

	# Keys:
	#   to: Module to convert to; required.
	#   quiet: True to suppress warnings; optional.
	#   handler: Code to call after conversion done; optional.
	#   arg: Arguments to add to new 'use' or 'no'; optional.
	state $use_map	= {
	    'Test::More'	=> {
		to	=> 'Test2::V0',
		quiet	=> 1,
		handler	=> \&_convert_use__module__test_more,
	    },
	    'Test::Warnings'	=> {
		to	=> 'Test2::Plugin::NoWarnings',
		arg	=> 'echo => 1',
	    },
	};

	my $info = $use_map->{ $use->module() // '' }
	    or next;

	my $type = $use->type();
	
	# True if a given PPI::Statement::Include type takes arguments.
	state $arg_allowed = { map { $_ => 1 } qw{ use no } };

	my $repl_text = "$type $info->{to}";
	if ( defined $info->{arg} ) {
	    if ( $arg_allowed->{$type} ) {
		$repl_text .= " $info->{arg}";
	    } else {
		my $prefix;
		my $prev_sib;
		if ( $prev_sib = $use->previous_sibling()
			and $prev_sib->isa( 'PPI::Token::Whitespace' ) ) {
		    ( $prefix = $prev_sib->content() ) =~ s/ .* \n //smx;
		    substr $prefix, 0, 0, "\n";
		} else {
		    $prefix = ' ';
		}
		$use->insert_after( $_ )
		    for reverse $self->_parse_string_kids(
			"$prefix$info->{to}->import( $info->{arg} );" );
	    }
	}
	$repl_text .= ';';

	my $repl = $self->_parse_string_for(
	    $repl_text,
	    'PPI::Statement::Include',
	);
	$use->replace( $repl );
	$self->{_cvt}{use}{$info->{to}} ||= $repl;

	$info->{quiet}
	    or $self->__carp( "Replaced '$use' with '$repl_text'" );

	$info->{handler}
	    and $info->{handler}->( $self, $use );

	$rslt++;
    }

    return $rslt;
}

sub _convert_use__module__test_more {
    my ( $self, $use ) = @_;

    if ( my $start = _find_use_arg_start_point( $use ) ) {
	my @arg = PPIx::Utils::parse_arg_list( $start );

	if ( @arg ) {

	    $DB::single = 1;

	    @arg = map { _ppi_to_string( @{ $_ } ) } @arg;

	    if ( my $info = _map_plan_arg_to_sub( $arg[0] ) ) {
		if ( defined( my $to_name = $info->{name} ) ) {
		    $self->_add_statement(
			$info->{has_arg} ? "$to_name( $arg[1] );" :
			"$to_name();" );
		}
	    } else {
		$self->__croak( "'use test::more @arg;' unsupported" );
	    }

	}
    }

    return 1;
}

sub _add_statement {
    my ( $self, $statement ) = @_;

    $statement =~ s/ \s+ \z //smx;
    $statement =~ s/ \A \s* /\n/smx;
    unless ( $self->{_cvt}{statement} ) {
	my $use = $self->_find_use( 'Test2::V0' );
	while ( 1 ) {
	    my $next = $use->snext_sibling()
		or last;
	    $next->isa( 'PPI::Statement::Include' )
		or last;
	    $use = $next;
	}
	$self->{_cvt}{statement} = $use;
	$statement = "\n$statement";
    }
    my @add = $self->_parse_string_kids( $statement );
    $self->{_cvt}{statement}->insert_after( $_ ) for reverse @add;
    foreach ( reverse @add ) {
	$_->isa( 'PPI::Statement' )
	    or next;
	$self->{_cvt}{statement} = $_;
	last;
    }
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
    my @kids = $self->_parse_string_kids( do {
	    local $" = ', ';
	    @arg ? "\nuse $module @arg;" : "\nuse $module;";
	}
    );
    $self->{_cvt}{use}{$module} = $kids[-1];
    $use_test2_v0->insert_after( $_ )
	for reverse @kids;
    $self->__carp(
	"Added 'use $module'",
    );
    return;
}

# Given an element and a direction (next if $forward is true, else
# previous), delete the given element and all insignificant siblings
# adjacent in the given direction. The first undeleted sibling is
# returned, or a false value if no significant sibling in the given
# direction.
sub _delete_elements {
    my ( undef, $ele, $forward ) = @_;
    $ele
	or return $ele;
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

# Support for _replace_sub_args
sub _ele_is_valid_arg {
    my ( $ele ) = @_;
    $ele
	or return 0;
    my $content = $ele->content();
    $ele->isa( 'PPI::Token::Structure' )
	and $content eq ';'
	and return 0;
    $ele->isa( 'PPI::Token::Operator' )
	and PPIx::Utils::precedence_of( $ele ) >=
	    MIN_PRECEDENCE_TO_TERMINATE_PARENLESS_ARG_LIST
	and return 0;
    return $ele;
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

sub _map_plan_arg_to_sub {
    my ( $arg ) = @_;
    my $key = ( ref $arg && $arg->isa( 'PPI::Token::Quote' ) ) ?
	$arg->string() :
	"$arg";
    state $sub_map = {
	no_plan		=> {
	},
	skip_all	=> {
	    has_arg	=> 1,
	    name	=> 'skip_all',
	},
	tests		=> {
	    has_arg	=> 1,
	    name	=> 'plan',
	},
    };
    return $sub_map->{$key};
}

sub _parse_string {
    my ( $self, $string ) = @_;

    my $doc = PPI::Document->new( \$string )
	or $self->__confess( "PPI can not parse '$string'" );

    return $doc;
}

sub _parse_string_for {
    my ( $self, $string, $class ) = @_;
    $class //= 'PPI::Statement';
    my $doc = $self->_parse_string( $string );
    my $rslt = $doc->find_first( $class )
	or $self->__confess( "Parsing '$string' did not produce a $class" );
    return $rslt->remove();
}

sub _parse_string_kids {
    my ( $self, $string ) = @_;
    my $doc = $self->_parse_string( $string );
    my @kids = $doc->children()
	or return;
    wantarray
	and return( map { $_->remove() } @kids );
    return $kids[0]->remove();
}

sub _parse_string_parts {
    my ( $self, $string ) = @_;
    my $doc = $self->_parse_string( $string );
    return(
	map { $_->remove() }
	map { $_->isa( 'PPI::Statement' ) ? $_->children() : $_ }
	$doc->children()
    );
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

# $self->_replace_sub_args( $ele, $string )
sub _replace_sub_args {
    my ( $self, $ele, $string ) = @_;

    $ele
	or $self->__croak( 'No subroutine name supplied' );

    my @pad;

    if ( my $arg = _ele_is_valid_arg( $ele->snext_sibling() ) ) {
	{
	    my $sib = $ele;
	    while ( $sib = $sib->next_sibling() and not
		$sib->significant() ) {
		push @pad, $sib->remove();
	    }
	}
	if ( $arg->isa( 'PPI::Structure::List' ) ) {
	    $arg->delete();
	    defined $string
		and $string = "( $string )";
	} else {
	    while ( 1 ) {
		my $sib = $arg->next_sibling();
		$arg->delete();
		$arg = _ele_is_valid_arg( $sib )
		    or last;
	    }
	}
    }

    defined $string
	and push @pad, $self->_parse_string_parts( $string );

    # NOTE I consider this fragile. PPI tries to enforce consistency
    # under modification by restricting the inserts after a PPI::Token
    # (which we are working with here) or a PPI::Structure.
    $ele->insert_after( $_ ) for reverse @pad;

    return;
}

sub _strip_sigil {
    my ( $symbol ) = @_;
    ( my $rslt = "$symbol" ) =~ s/ \A [*&%\$\@] //smx;
    return $rslt;
}

sub __carp {	## no critic (RequireArgUnpacking)
    my ( $self, @args ) = @_;
    chomp $args[-1];
    push @args, " in file $self->{_cvt}{file}";
    if ( $self->{die} ) {
	warn @args, "\n";
    } else {
	require Carp;
	@_ = @args;
	goto &Carp::carp;
    }
    return;
}

sub __confess {	## no critic (RequireArgUnpacking)
    my ( undef, @args ) = @_;	# Invocant unused
    chomp $args[-1];
    require Carp;
    @_ = ( 'Bug - ', @args );
    goto &Carp::confess;
}

sub __croak {	## no critic (RequireArgUnpacking)
    my ( $self, @args ) = @_;
    chomp $args[-1];
    if ( $self->{die} ) {
	die @args, "\n";
    } else {
	chomp $args[-1];
	require Carp;
	@_ = @args;
	goto &Carp::croak;
    }
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

B<Note> that this argument is ignored if C<$Carp::Verbose> is true.

The default is false.

=item load_module

If this Boolean argument is true, C<use_ok( ... )> will be implemented
by C<Test2::Tools::LoadModule::use_ok()>. Otherwise it will be converted
to C<use ok ( ... )>.

The default is false.

=item quiet

If this Boolean argument is true some warnings will be suppressed.

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

All occurrences of C<use Test::More;>, C<no Test::More;>, and
C<require Test::More;> are changed to use, no, or require C<Test2::V0>.

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
abandoned, not just those that originally called C<BAIL_OUT()> on
failure.

If the L<bail_on_fail|/bail_on_fail> attribute is false or omitted,

 sub BAIL_OUT { context()->bail( @_ ) }

will be added.

=item builder()

A call to C<< Test::More->builder() >> returns the underlying
L<Test::Builder|Test::Builder> singleton.

Because there is nothing in C<Test2-Suite> corresponding to this object,
all this tool does if it finds C<builder()> called as a method is to
issue a warning saying that it needs to be hand-converted, and insert a
diagnostic into the code.

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

This tool eliminates all arguments after the second.

=item plan()

This tool converts a two-argument call to C<plan()> into a
single-argument call to either C<plan()> or C<skip_all()>, depending on
the value of the first of the two arguments.

It removes the statement C<plan( 'no_plan' );>.

=item require_ok()

If the L<load_module|/load_module> attribute is false or unspecified,
all calls to C<require_ok( $module )> are changed to

 ok lives { require $module }, "require $module";

If the call to C<require_ok()> was followed by a semicolon (C<;>) or an
C<or>,

 or diag <<"EOD"
     Tried to require '$module'
     Error: \$@
 EOD

is appended to the generated code. B<Note> that the above is
pseudo-code; the actual module specification will appear in place of
C<$module>.

If the L<load_module|/load_module> attribute is true, a
C<use Test2::Tools::LoadModule ':more';> is added. A warning is
generated, since this adds a dependency.

=item use_ok()

If the L<load_module|/load_module> attribute is false or unspecified,
all calls to C<use_ok( ... )> are changed to C<use ok ...>. A warning is
generated, since this adds a dependency on C<ok>.

If the L<load_module|/load_module> attribute is true, a
C<use Test2::Tools::LoadModule ':more';> is added. A warning is
generated, since this adds a dependency.

=item $TODO

All instances of C<local $TODO = ...> are replaced by
C<my $TODO = todo ...>.

=item $Test::Builder::Level

If a reference to C<$Test::Builder::Level> is found, C<use Test::Builder;> is added.

B<Note> that
L<Test2::Manual::Tooling::TestBuilder|Test2::Manual::Tooling::TestBuilder>
claims that C<$Test::Builder::Level> will be honored if set; but I have
found that just assigning it a value does not suffice, and I need to
actually load L<Test::Builder|Test::Builder> to get this behavior.

B<Note further> that
L<Test2::Manual::Tooling::Nesting|Test2::Manual::Tooling::Nesting> says
that the idiomatic way to accomplish this is to acquire a context object
by C<my $ctx = context()> and then call C<< $ctx->release() >> when done
with it. But automating this means finding B<every> code path where it
needs to be done. Using something like L<Scope::Guard|Scope::Guard> is
not an option, because exceptions raised in a C<DESTROY()> method do not
propagate out of it, which breaks at least
L<Test2::Plugin::BailOnFail|Test2::Plugin::BailOnFail>.

=back

=head1 SEE ALSO

L<PPI|PPI>.

L<Test::More|Test::More>

L<Test2::V0|Test2::V0>

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
