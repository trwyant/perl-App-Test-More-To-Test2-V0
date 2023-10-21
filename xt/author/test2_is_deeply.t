use strict;
use warnings;
use Test2::V0;

my %data = (
    foo => 'bar',
    answer      => [ 42 ],
    john        => 'John likes Mary',
);

is $data{foo}, 'bar', 'is foo bar';

is $data{answer}, [ 42 ], 'is the answer 42';

like $data{john}, qr/\bMary\b/, 'does John like Mary';

done_testing;
