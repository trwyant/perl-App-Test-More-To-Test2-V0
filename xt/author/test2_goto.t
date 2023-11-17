use strict;
use warnings;

use Test2::V0;

sub my_is_deeply {
    goto &is;
}

my $answer = [ 42 ];

my_is_deeply $answer, [ 42 ], 'The answer is [ 42 ]';

done_testing;
