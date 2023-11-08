use strict;
use warnings;
use Test2::V0;

sub BAIL_OUT { Test2::API::context()->bail( @_ ) }

ok lives { require Test2::V0 }, 'require Test2::V0;' or diag <<"EOD" or BAIL_OUT 'Can not continue';
    Tried to require 'Test2::V0'
    Error: $@
EOD

done_testing;
