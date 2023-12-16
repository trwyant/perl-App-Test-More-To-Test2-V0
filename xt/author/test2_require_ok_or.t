use strict;
use warnings;
use Test2::V0;

ok lives { require Test2::V0 }, 'require Test2::V0;' or diag <<"EOD" or bail_out 'Can not continue';
    Tried to require 'Test2::V0'
    Error: $@
EOD

done_testing;
