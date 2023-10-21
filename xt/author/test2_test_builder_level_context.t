use strict;
use warnings;
use Test2::V0;
use Scope::Guard;

my_ok( 1 );

done_testing;

sub my_ok {
    my @arg = @_;
    my $scope_guard = do {
        my $ctx = context();
        Scope::Guard->new( sub { $ctx->release() } );
    };
    return ok( @arg );
}
