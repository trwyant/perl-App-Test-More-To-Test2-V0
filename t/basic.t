package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;

use ok 'App::Test::More::To::Test2::V0';

my $obj;
ok lives {
    $obj = App::Test::More::To::Test2::V0->new();
}, 'Can instantiate App::Test::More::To::Test2::V0';

isa_ok $obj, 'App::Test::More::To::Test2::V0';

done_testing;

1;
