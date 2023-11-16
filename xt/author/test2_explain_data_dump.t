use strict;
use warnings;
use Test2::V0;
use Data::Dump 'dump';

my $answer = [ 42 ];

is $answer, [ 42 ], 'The answer is [ 42 ]';

note 'The answer is ', dump( $answer );

done_testing;
