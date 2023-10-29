package main;

use 5.010;

use strict;
use warnings;

# NOTE we have to do it this way because Test::Builder, if loaded at
# all, must be loaded before Test2::V0;
my $test_builder;
BEGIN {
    $test_builder = eval { require Test::Builder; 1 };
}

use Test2::V0;

diag 'Modules needed for author testing';

ok lives { require ok },
    'require ok';

ok $test_builder,
    'require Test::Builder';

ok lives { require Test2::Tools::LoadModule },
    'require Test2::Tools::LoadModule';

done_testing;

1;

# ex: set textwidth=72 :
