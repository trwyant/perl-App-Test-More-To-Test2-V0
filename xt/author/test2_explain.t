use strict;
use warnings;
use Test2::V0;
use Test2::Tools::Explain;

my $answer = [ 42 ];

is $answer, [ 42 ], 'The answer is [ 42 ]';

note 'The answer is ', explain( $answer );

done_testing;
