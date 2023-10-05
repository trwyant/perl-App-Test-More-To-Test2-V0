package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;
use Test2::Tools::LoadModule;

load_module_ok 'App::Test::More::To::Test2::V0';

my $ms = eval { App::Test::More::To::Test2::V0->new() };
isa_ok $ms, 'App::Test::More::To::Test2::V0';

done_testing;

1;
