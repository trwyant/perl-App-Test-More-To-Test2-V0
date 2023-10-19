package main;

use 5.014;

use strict;
use warnings;

use Errno qw{ ENOENT };

use Test2::V0 -target => 'App::Test::More::To::Test2::V0';
use Test2::Plugin::NoWarnings;

{
    my $app = CLASS->new();
    my $warning;

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
EOD
        <<'EOD',
use strict;
use warnings;
EOD
        'Null conversion';
    };

    like $warning, qr{\bdoes not use Test::More\b},
        'Correct null conversion warning';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

ok 1;

done_testing;
EOD
        slurp( 't/test2_use.t' ),
        'Convert use Test::More';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More tests => 2;

ok 1;

ok 2;
EOD
        slurp( 't/test2_plan_list.t' ),
       'Convert use Test::More tests => 2';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More 'tests', 2;

ok 1;

ok 2;
EOD
        slurp( 't/test2_plan_list.t' ),
        q<Convert use Test::More 'tests', 2>;

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More ( 'tests', 2 );

ok 1;

ok 2;
EOD
        slurp( 't/test2_plan_list.t' ),
        q<Convert use Test::More ( 'tests', 2 )>;

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More

plan( tests => 2 );

ok 1;

ok 2;
EOD
        slurp( 't/test2_plan_list.t' ),
        q{Convert plan( tests => 2 )};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

plan tests => 2;

ok 1;

ok 2;
EOD
        slurp( 't/test2_plan_bare.t' ),
        q{Convert plan tests => 2};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

plan skip_all => 'Taking the day off';
EOD
        slurp( 't/test2_skip_all_bare.t' ),
        q{Convert plan skip_all => 'Taking the day off'};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

plan( 'skip_all', 'Taking the day off' );
EOD
        slurp( 't/test2_skip_all_list.t' ),
        q{Convert plan( 'skip_all', 'Taking the day off' )};

    is $app->convert( \<<'EOD' ),
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
        slurp( 't/test2_is_deeply.t' ),
        'Convert is_deeply() to is()';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

use_ok 'Text::Wrap';

done_testing;
EOD
            slurp( 't/test2_use_ok_ok.t' ),
            'Convert use_ok() using use ok ...';
    };

    like $warning, qr/\AAdded 'use ok' in\b/,
        q<Correct 'use ok' warning>;

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

require_ok 'Text::Wrap';

done_testing;
EOD
            slurp( 't/test2_require_ok.t' ),
            'Convert require_ok() using Test2::Tools::LoadModule';
    };

    like $warning, qr/\AAdded 'use Test2::Tools::LoadModule' in\b/,
        'Correct load_module_ok() warning';

    # TODO figure out how to execute t/test2_bail_out.t without
    # terminating the entire test suite.
    is $app->convert( \<<'EOD' ),
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

sub BAIL_OUT { Test2::API::context()->bail( @_ ) }

is foo(), 'bar'
    or BAIL_OUT 'Eject! Eject!';

done_testing;
EOD
   'Provide BAIL_OUT()';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

{
    local $TODO = 'Not implemented';

    ok 0, 'Unimplemented';
}

done_testing;
EOD
        slurp( 't/test2_todo.t' ),
       'Convert $TODO';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;

use Test::More;

my $bldr = Test::More->builder();
EOD
        <<'EOD',
use strict;
use warnings;

use Test2::V0;

my $bldr = Test::More->builder();
EOD
        'Warn on Test::More->builder()';
    };

    like $warning,
        qr{\bTest::More->builder\(\);@{[ CLASS->CONVERT_BY_HAND ]}},
        'Correct Test::More->builder() warning';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
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
            slurp( 't/test2_test_builder_level_builder.t' ),
            'Handle $Test::Builder::Level';
    };

    like $warning,
        qr{\bAdded 'use Test::Builder' in\b},
        'Correct $Test::Builder::Level warning';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

sub Foo::isa { return $_[1] eq 'Bar' }

isa_ok( Foo => 'Bar' );

done_testing;
EOD
        slurp( 't/test2_isa_ok_2.t' ),
        'Handle isa_ok with two arguments';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

sub Foo::isa { return $_[1] eq 'Bar' }

isa_ok( Foo => 'Bar', 'Is Foo a Bar' );

done_testing;
EOD
        slurp( 't/test2_isa_ok_2.t' ),
        'Handle isa_ok with three arguments';
}

{
    my $app = CLASS->new( load_module => 1 );

    my $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

use_ok 'Text::Wrap';

done_testing;
EOD
            slurp( 't/test2_use_ok_load_module.t' ),
            'Convert use_ok() using Test2::Tools::LoadModule';
    };

    like $warning, qr/\AAdded 'use Test2::Tools::LoadModule' in\b/,
        'Correct load_module_ok() warning';

}

{
    my $app = CLASS->new( bail_on_fail => 1 );

    # TODO figure out how to execute t/test2_bail_out_bail_on_fail.t
    # without terminating the entire test suite.
    my $warning = warning {
        is $app->convert( \<<'EOD' ),
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

    like $warning, qr/\AAdded 'use Test2::Plugin::BailOnFail' in\b/,
        'Correct Test2::Plugin::BailOnFail warning';
}

{
    my $app = CLASS->new( use_context => 1 );

    my $warning = warning {
        is $app->convert( \<<'EOD' ),
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
            slurp( 't/test2_test_builder_level_context.t' ),
            'Convert $Test::Builder::Level using context()';
    };

    like $warning, qr/\AAdded 'use Scope::Guard' in\b/,
        'Correct Scope::Guard warning';
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
        $app->convert( 't/no_such_file.t' );
    };

    local $! = ENOENT;
    like $exception, qr<\AFailed to open t/no_such_file.t: $!>,
        'Correct exception for missing file';
}

{
    my $app = CLASS->new();

    my $exception = dies {
        $app->_parse_string_for(
            'use Test2::V0;',
            'PPI::Statement::Variable',
        );
    };

    like $exception,
        qr<\ABug - Parsing 'use Test2::V0;' did not produce a PPI::Statement::Variable\b>,
    'Correct exception for bug';
}

done_testing;

sub slurp {
    my ( $name ) = @_;
    open my $fh, '<:encoding(utf-8)', $name
        or return "Unable to open $name: $!\n";
    local $/ = undef;   # slurp mode
    return <$fh>;
}

1;

# ex: set textwidth=72 expandtab :
