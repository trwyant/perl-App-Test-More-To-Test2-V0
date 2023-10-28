package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;

ok lives {
    require App::Test::More::To::Test2::V0;
}, 'require App::Test::More::To::Test2::V0' or diag <<"EOD";
    Tried to require 'App::Test::More::To::Test2::V0'
    Error: $@
EOD

my $obj;
ok lives {
    $obj = App::Test::More::To::Test2::V0->new();
}, 'Can instantiate App::Test::More::To::Test2::V0';

isa_ok $obj, 'App::Test::More::To::Test2::V0';

done_testing;

1;
