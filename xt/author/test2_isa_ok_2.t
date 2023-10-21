use strict;
use warnings;
use Test2::V0;

sub Foo::isa { return $_[1] eq 'Bar' }

isa_ok( Foo => 'Bar' );

done_testing;
