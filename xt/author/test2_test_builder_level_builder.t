use strict;
use warnings;
use Test2::V0;
use Test::Builder;

my_ok( 1 );

done_testing;

sub my_ok {
    my @arg = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return ok( @arg );
}
