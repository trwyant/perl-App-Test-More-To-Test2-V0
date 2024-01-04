use strict;
use warnings;
use Test2::V0;

is dies { require Test2::V0 }, undef, 'require Test2::V0;' or bail_out 'Can not continue';

done_testing;
