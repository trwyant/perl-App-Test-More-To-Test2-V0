use strict;
use warnings;
use Test2::V0;
use Test2::Plugin::BailOnFail;

ok lives { require Test2::V0 }, 'require Test2::V0;' or diag <<"EOD";
    Tried to require 'Test2::V0'
    Error: $@
EOD

done_testing;
