package main;

use 5.014;

use strict;
use warnings;

use Test2::V0;

ok ! diag( 'Ignore this diagnostic' ), 'diag() returns a false value';

done_testing;

1;

# ex: set textwidth=72 :
