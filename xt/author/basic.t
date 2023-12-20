package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;

diag 'Modules needed for author testing';

use ok 'Module::Metadata';

use ok 'Test::Builder';

use ok 'Test2::Tools::LoadModule';

done_testing;

1;

# ex: set textwidth=72 :
