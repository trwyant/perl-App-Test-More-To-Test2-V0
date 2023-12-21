package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;

use lib qw{ inc };

use My::Module::Test;

diag $_ for dependencies_table;

use ok 'App::Test::More::To::Test2::V0';

my $obj;
ok lives {
    $obj = App::Test::More::To::Test2::V0->new();
}, 'Can instantiate App::Test::More::To::Test2::V0';

isa_ok $obj, 'App::Test::More::To::Test2::V0';

done_testing;

1;
