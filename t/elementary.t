package main;

use 5.014;

use strict;
use warnings;

use Test2::V0 -target => 'App::Test::More::To::Test2::V0';

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

done_testing;
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

done_testing;
EOD
    'Convert use Test::More';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
require Test::More;

done_testing();
EOD
    <<'EOD',
use strict;
use warnings;
require Test2::V0;

done_testing();
EOD
    'Convert require Test::More';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More tests => 42;
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

plan( 42 );
EOD
   'Convert use Test::More tests => 42';

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More 'tests', 42;
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

plan( 42 );
EOD
    q<Convert use Test::More 'tests', 42>;

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More ( 'tests', 42 );
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

plan( 42 );
EOD
    q<Convert use Test::More ( 'tests', 42 )>;

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More

plan( tests => 42 );
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

plan( 42 );
EOD
    q{Convert plan( tests => 42 )};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More

plan tests => 42;
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

plan( 42 );
EOD
    q{Convert plan tests => 42};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

plan skip_all => 'Taking the day off';
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

skip_all 'Taking the day off';
EOD
    q{Convert plan skip_all => 'Taking the day off'};

    is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

is foo(), 'bar', 'is foo bar';

is_deeply [ answer() ], [ 42 ], 'is the answer 42';

like john(), qr/\bMary\b/, 'does John like Mary';

done_testing;

sub my_deeply {
    goto &is_deeply;
}
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

is foo(), 'bar', 'is foo bar';

is [ answer() ], [ 42 ], 'is the answer 42';

like john(), qr/\bMary\b/, 'does John like Mary';

done_testing;

sub my_deeply {
    goto &is;
}
EOD
    'Convert is_deeply() to is()';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

use_ok 'Foo::Bar';

done_testing;
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;

use ok 'Foo::Bar';

done_testing;
EOD
        'Convert use_ok() using use ok ...';
    };

    like $warning, qr/\AAdded 'use ok' in\b/,
        q<Correct 'use ok' warning>;

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

require_ok 'Foo::Bar';

done_testing;
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test2::Tools::LoadModule ':more';

require_ok 'Foo::Bar';

done_testing;
EOD
        'Convert require_ok() using Test2::Tools::LoadModule';
    };

    like $warning, qr/\AAdded 'use Test2::Tools::LoadModule' in\b/,
        'Correct load_module_ok() warning';

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
}
EOD
    <<'EOD',
use strict;
use warnings;
use Test2::V0;

{
    my $todo = todo 'Not implemented';
}
EOD
   'Convert $TODO to $todo';

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

{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
}
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test::Builder ();

{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
}
EOD
        'Handle $Test::Builder::Level';
    };

    like $warning,
        qr{\bAdded 'use Test::Builder' in\b},
        'Correct $Test::Builder::Level warning';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

isa_ok( Foo => 'Bar' );
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;

isa_ok( Foo => 'Bar' );
EOD
        'Handle isa_ok with two arguments';
    };

    is $warning, undef, 'isa_ok() with two arguments: no warning';

    $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

isa_ok( Foo => 'Bar', 'Is Foo a Bar' );
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;

isa_ok( Foo => 'Bar', 'Is Foo a Bar' );
EOD
        'Handle isa_ok with three arguments';
    };

    like $warning,
        qr{\bmore than two arguments\b},
        'Correct warning from isa_ok() with three arguments';
}

{
    my $app = CLASS->new( load_module => 1 );

    my $warning = warning {
        is $app->convert( \<<'EOD' ),
use strict;
use warnings;
use Test::More;

use_ok 'Foo::Bar';

done_testing;
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Test2::Tools::LoadModule ':more';

use_ok 'Foo::Bar';

done_testing;
EOD
        'Convert use_ok() using load_module_ok()';
    };

    like $warning, qr/\AAdded 'use Test2::Tools::LoadModule' in\b/,
        'Correct load_module_ok() warning';

}

{
    my $app = CLASS->new( bail_on_fail => 1 );

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

{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
}
EOD
        <<'EOD',
use strict;
use warnings;
use Test2::V0;
use Scope::Guard;

{
    my $scope_guard = do {
        my $ctx = context();
        Scope::Guard->new( sub { $ctx->release() } );
    };
}
EOD
        'Convert $Test::Builder::Level';
    };

    like $warning, qr/\AAdded 'use Scope::Guard' in\b/,
        'Correct Scope::Guard warning';
}

done_testing;

1;

# ex: set textwidth=72 expandtab :
