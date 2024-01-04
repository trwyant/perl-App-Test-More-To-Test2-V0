use strict;
use warnings;
use Test2::V0;
use Test2::Plugin::BailOnFail;

is dies { require Test2::V0 }, undef, 'require Test2::V0;';

done_testing;
