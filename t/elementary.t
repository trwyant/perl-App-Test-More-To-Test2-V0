package main;

use 5.010;

use strict;
use warnings;

use Errno qw{ ENOENT };
use File::Temp;

use Test2::V0 -target => 'App::Test::More::To::Test2::V0';
use Test2::Plugin::NoWarnings echo => 1;

use lib qw{ inc };

use My::Module::Test qw{ check_for_duplicate_matches };

use constant EXPLAIN_TEST       => \<<'EOD';
use strict;
use warnings;
use Test::More;

my $answer = [ 42 ];

is_deeply $answer, [ 42 ], 'The answer is [ 42 ]';

note 'The answer is ', explain( $answer );

done_testing;
EOD

use constant REQUIRE_OK         => \<<'EOD';
use strict;
use warnings;
use Test::More;

require_ok 'Test2::V0';

done_testing;
EOD

use constant MATCH_ADD_USE_BAIL =>
    match qr/\AAdded 'use Test2::Plugin::BailOnFail' in\b/;
use constant MATCH_ADD_USE_EXPLAIN      =>
    match qr/\AAdded 'use Test2::Tools::Explain' in\b/;
use constant MATCH_ADD_USE_OK   => match qr/\AAdded 'use ok' in\b/;

$ENV{AUTHOR_TESTING}
    and check_for_duplicate_matches;

{
    my $app = CLASS->new();
    my $warning;

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
EOD
        <<'EOD',
use strict;
use warnings;
EOD
        'Null conversion';
    };

    is $warning, [
        match qr{\ATest::More not used \(or so I think\) in\b},
    ], 'Correct null conversion warning';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

ok 1;

done_testing;
EOD
        slurp( 'xt/author/test2_use.t' ),
        'Convert use Test::More';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More tests => 2;

ok 1;

ok 2;
EOD
        slurp( 'xt/author/test2_plan_list.t' ),
       'Convert use Test::More tests => 2';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More tests => 2;

ok 1;

ok 2;

sub check {}
EOD
        slurp( 'xt/author/test2_plan_list_with_collision.t' ),
       'Convert use Test::More tests => 2, with collision';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More 'tests', 2;

ok 1;

ok 2;
EOD
        slurp( 'xt/author/test2_plan_list.t' ),
        q<Convert use Test::More 'tests', 2>;

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More ( 'tests', 2 );

ok 1;

ok 2;
EOD
        slurp( 'xt/author/test2_plan_list.t' ),
        q<Convert use Test::More ( 'tests', 2 )>;

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More

plan( tests => 2 );

ok 1;

ok 2;
EOD
        slurp( 'xt/author/test2_plan_list.t' ),
        q{Convert plan( tests => 2 )};

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

plan tests => 2;

ok 1;

ok 2;
EOD
        slurp( 'xt/author/test2_plan_bare.t' ),
        q{Convert plan tests => 2};

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

plan 'no_plan';

pass 'Copacetic';

done_testing;
EOD
        slurp( 'xt/author/test2_no_plan_bare.t' ),
        q{Convert plan 'no_plan'};

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

plan skip_all => 'Taking the day off';
EOD
        slurp( 'xt/author/test2_skip_all_bare.t' ),
        q{Convert plan skip_all => 'Taking the day off'};

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

plan( 'skip_all', 'Taking the day off' );
EOD
        slurp( 'xt/author/test2_skip_all_list.t' ),
        q{Convert plan( 'skip_all', 'Taking the day off' )};

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

my %data = (
    foo => 'bar',
    answer      => [ 42 ],
    john        => 'John likes Mary',
);

is $data{foo}, 'bar', 'is foo bar';

is_deeply $data{answer}, [ 42 ], 'is the answer 42';

like $data{john}, qr/\bMary\b/, 'does John like Mary';

done_testing;
EOD
        slurp( 'xt/author/test2_is_deeply.t' ),
        'Convert is_deeply() to is()';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;

use Test::More;

sub my_is_deeply {
    goto &is_deeply;
}

my $answer = [ 42 ];

my_is_deeply $answer, [ 42 ], 'The answer is [ 42 ]';

done_testing;
EOD
        slurp( 'xt/author/test2_goto.t' ),
        q/Convert 'goto &is_deeply' to 'goto &is'/;

    $warning = warnings {
        is $app->convert( EXPLAIN_TEST )->content(),
            slurp( 'xt/author/test2_explain.t' ),
            'Convert explain()';
    };

    is $warning, [
        MATCH_ADD_USE_EXPLAIN,
    ], q<Correct 'use Test2::Tools::Explain' warning>;

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

use_ok 'Test2::V0';

done_testing;
EOD
            slurp( 'xt/author/test2_use_ok_ok.t' ),
            'Convert use_ok() using use ok ...';
    };

    is $warning, [
        MATCH_ADD_USE_OK,
    ], q<Correct 'use ok' warning>;

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

use_ok 'Test2::V0' or BAIL_OUT;

done_testing;
EOD
            slurp( 'xt/author/test2_use_ok_or.t' ),
            'Convert use_ok() using use ok ...';
    };

    is $warning, [
        match qr/\ADeleted ' or BAIL_OUT' after 'use ok \.\.\.'/,
        MATCH_ADD_USE_OK
    ], q/Correct use_ok() warnings/;

    is $app->convert( REQUIRE_OK )->content(),
        slurp( 'xt/author/test2_require_ok.t' ),
        'Convert require_ok() using ok lives { require ... }';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

require_ok 'Test2::V0'
    or BAIL_OUT 'Can not continue';

done_testing;
EOD
        slurp( 'xt/author/test2_require_ok_or.t' ),
        'Convert require_ok() or ... using ok lives { ... } or';

    # TODO figure out how to execute xt/author/test2_bail_out.t without
    # terminating the entire test suite.
    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

is foo(), 'bar'
    or BAIL_OUT 'Eject! Eject!';

done_testing;
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

is foo(), 'bar'
    or bail_out 'Eject! Eject!';

done_testing;
EOD
   'Provide BAIL_OUT()';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

{
    local $TODO = 'Not implemented';

    ok 0, 'Unimplemented';
}

done_testing;
EOD
        slurp( 'xt/author/test2_todo.t' ),
       'Convert $TODO';

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;

use Test::More;

my $bldr = Test::More->builder();
EOD
        <<'EOD',
use strict;
use warnings;

use Test2::V0;

diag 'Must be converted by hand in ', __FILE__, ' line ', __LINE__; my $bldr = Test::More->builder();
EOD
        'Warn on Test::More->builder()';
    };

    is $warning, [
        match qr{\bTest::More->builder\(\); @{[ CLASS->CONVERT_BY_HAND ]}},
    ], 'Correct Test::More->builder() warning';

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

my_ok( 1 );

done_testing;

sub my_ok {
    my @arg = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return ok( @arg );
}
EOD
            slurp( 'xt/author/test2_test_builder_level_builder.t' ),
            'Handle $Test::Builder::Level';
    };

    is $warning, [
        match qr{\bAdded 'use Test::Builder' in\b},
    ], 'Correct $Test::Builder::Level warning';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

sub Foo::isa { return $_[1] eq 'Bar' }

isa_ok( Foo => 'Bar' );

done_testing;
EOD
        slurp( 'xt/author/test2_isa_ok_2.t' ),
        'Handle isa_ok with two arguments';

    is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

sub Foo::isa { return $_[1] eq 'Bar' }

isa_ok( Foo => 'Bar', 'Is Foo a Bar' );

done_testing;
EOD
        slurp( 'xt/author/test2_isa_ok_2.t' ),
        'Handle isa_ok with three arguments';

    # NOTE this does not compare the output to a working test file
    # because Test2::Plugin::NoWarnings is not part of Test2-Suite, so
    # we do not know it is available.
    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;
use Test::Warnings;

ok 1, 'Copacetic';

done_testing();
EOD
            <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test2::Plugin::NoWarnings echo => 1;

ok 1, 'Copacetic';

done_testing();
EOD
            'Handle Test::Warnings';
    };

    is $warning, [
        match qr/\AReplaced 'use Test::Warnings;' with 'use Test2::Plugin::NoWarnings echo => 1;'/,
    ], 'Got correct warning from handling Test::Warnings';
}

{
    my $app = CLASS->new( load_module => 1 );
    my $warning;

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

require_ok 'Test2::V0';

done_testing;
EOD
            slurp( 'xt/author/test2_require_ok_load_module.t' ),
            'Convert require_ok() using Test2::Tools::LoadModule';
    };

    is $warning, [
        match qr/\AAdded 'use Test2::Tools::LoadModule' in\b/,
    ], 'Correct load_module_ok() warning';

}

{
    my $app = CLASS->new( bail_on_fail => 1 );
    my $warning;

    # TODO figure out how to execute xt/author/test2_bail_out_bail_on_fail.t
    # without terminating the entire test suite.
    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

is foo(), 'bar'
    or BAIL_OUT 'Eject! Eject!';

done_testing;
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test2::Plugin::BailOnFail;

is foo(), 'bar';

done_testing;
EOD
        'Use Test2::Plugin::BailOnFail instead of BAIL_OUT()';
    };

    is $warning, [
        MATCH_ADD_USE_BAIL,
    ], 'Correct Test2::Plugin::BailOnFail warning';

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

require_ok 'Test2::V0'
    or BAIL_OUT();

done_testing;
EOD
        slurp( 'xt/author/test2_require_ok_bail.t' ),
        'Convert require_ok() or BAIL_OUT using ok lives { require ... }';
    };

    is $warning, [
        MATCH_ADD_USE_BAIL,
    ], 'Correct Test2::Plugin::BailOnFail warning';

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More;

use_ok 'Test2::V0' or BAIL_OUT();

done_testing;
EOD
            <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test2::Plugin::BailOnFail;

use ok 'Test2::V0';

done_testing;
EOD
            q/Convert 'use_ok or BAIL_OUT()' using 'use ok' and BailOnFail/;
    };

    is $warning, [
        MATCH_ADD_USE_OK, 
        MATCH_ADD_USE_BAIL,
    ], q/Correct warnings for 'use ok or BAIL_OUT'/;
}

{
    my $exception = dies {
        my $app = CLASS->new( the_answer => 42 );
    };

    like $exception, qr/\AUnsupported arguments: the_answer\b/,
        'Correct unsupported argument exception';
}

{
    my $app = CLASS->new();

    my $exception = dies {
        $app->convert( 'xt/author/no_such_file.t' )->content();
    };

    local $! = ENOENT;
    like $exception, qr<\AFailed to open xt/author/no_such_file.t: $!>,
        'Correct exception for missing file';
}

{
    my $app = CLASS->new( explain => 'Data::Dumper=Dumper' );
    my $warning;

    $warning = warnings {
        is $app->convert( EXPLAIN_TEST )->content(),
            slurp( 'xt/author/test2_explain_data_dumper.t' ),
            'Convert explain() to Data::Dumper::Dumper()';
    };

    is $warning, [
        match qr/\AAdded 'use Data::Dumper' in\b/,
    ], q<Correct 'use Data::Dumper' warning>;
}

{
    my $app = CLASS->new( explain => 'Data::Dump=dump' );
    my $warning;

    $warning = warnings {
        is $app->convert( EXPLAIN_TEST )->content(),
            slurp( 'xt/author/test2_explain_data_dump.t' ),
            'Convert explain() to Data::Dump::Dumper()';
    };

    is $warning, [
        match qr/\AAdded 'use Data::Dump' in\b/,
    ], q<Correct 'use Data::Dump' warning>;
}

{
    my $app = CLASS->new();
    my $exception;
    my $warning;

    $exception = dies {
        $app->_parse_string_for(
            'use Test2::V0;',
            'PPI::Statement::Variable',
        );
    };

    like $exception,
        qr<\ABug - Parsing 'use Test2::V0;' did not produce a PPI::Statement::Variable\b>,
    'Correct exception for bug';

    my $dir = File::Temp->newdir();

    spew( "$dir/foo.t", <<'EOD' );
use strict;
use warnings;
use Test::More;

pass 'Copacetic';

done_testing;
EOD

    $warning = warnings {
        $app->convert( "$dir/foo.t" );
    };

    is slurp( "$dir/foo.t" ), <<'EOD', 'Rewrote correct conversion';
use strict;
use warnings;
use Test2::V0;

pass 'Copacetic';

done_testing;
EOD

    is $warning, [], 'Got no warnings';
}

{
    my $app = CLASS->new( suffix => '.bak' );
    my $warning;

    my $dir = File::Temp->newdir();

    my $data = <<'EOD';
use strict;
use warnings;
use Test::More;

pass 'Copacetic';

done_testing;
EOD

    spew( "$dir/foo.t", $data );

    $warning = warnings {
        $app->convert( "$dir/foo.t" );
    };

    is slurp( "$dir/foo.t.bak" ), $data, 'Is the backup file correct';

    is slurp( "$dir/foo.t" ), <<'EOD', 'Is the rewritten file correct';
use strict;
use warnings;
use Test2::V0;

pass 'Copacetic';

done_testing;
EOD

    is $warning, [], 'Got no warnings';
}

{
    my $app = CLASS->new(
        uncomment_use   => 1,
    );
    my $warning;

    note <<'EOD';
We are not realy interested in explain() here, we're just re-using a
handy manifest constant. The real goal is to test the uncomment_use
functionality.
EOD
    $warning = warnings {
        is $app->convert( EXPLAIN_TEST )->content(),
            slurp( 'xt/author/test2_explain.t' ),
            'Convert explain()';
    };

    is $warning, [
        MATCH_ADD_USE_EXPLAIN,
    ], q<Correct 'use Test2::Tools::Explain' warning>;

    $warning = warnings {
        is $app->convert( \<<'EOD' )->content(),
use strict;
use warnings;
use Test::More 0.88;    # Because of done_testing()

my $answer = [ 42 ];

is_deeply $answer, [ 42 ], 'The answer is [ 42 ]';

note 'The answer is ', explain( $answer );

done_testing;
EOD
            slurp( 'xt/author/test2_explain.t' ),
            'Convert explain()';
    };

    is $warning, [
        MATCH_ADD_USE_EXPLAIN,
    ], q<Correct 'use Test2::Tools::Explain' warning>;
}

{
    my $app = CLASS->new(
        require_to_use  => 1,
    );
    my $warning;

    $warning = warnings {
        is $app->convert( REQUIRE_OK )->content(),
            slurp( 'xt/author/test2_use_ok_ok.t' ),
            q/Convert require_ok() using 'use ok .../;
    };

    is $warning, [
        MATCH_ADD_USE_OK,
    ], q/Correct 'require_ok()' warning under require_to_use => 1/;
}

{
    my $app = CLASS->new(
        load_module     => 1,
        require_to_use  => 1,
    );
    my $warning;

    $warning = warnings {
        is $app->convert( REQUIRE_OK )->content(),
            slurp( 'xt/author/test2_use_ok_load_module.t' ),
            q/Convert require_ok() using Test2::Tools::LoadModule/;
    };

    is $warning, [
        match qr/\AAdded 'use Test2::Tools::LoadModule' in \b/,
    ], q/Correct 'require_ok()' warning under require_to_use => 1/;
}

done_testing;

sub slurp {
    my ( $name ) = @_;
    open my $fh, '<:encoding(utf-8)', $name
        or return "Unable to open $name: $!\n";
    local $/ = undef;   # slurp mode
    return <$fh>;
}

sub spew {
    my ( $name, $data ) = @_;
    open my $fh, '>:encoding(utf-8)', $name
        or return diag "Unable to open $name for output: $!";   # False
    print { $fh } $data;
    close $fh;
    return 1;
}

1;

# ex: set textwidth=72 expandtab :
