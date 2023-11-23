package main;

use 5.010;

use strict;
use warnings;

use File::Spec;
use Test2::V0;

use constant DEVNULL	=> File::Spec->devnull();

ok lives {
    require 'script/test-more-to-test2-v0';
}, 'Script compiles';

{
    note <<'EOD';

Test script with no configuration
EOD

    my $app;

    ok lives {
	$app = __PACKAGE__->new(
	    '--user-rc'		=> DEVNULL,
	    '--local-rc'	=> DEVNULL,
	);
    }, 'Can instantiate script object'
	or diag $@;

    is $app, {
	_args		=> [],
	local_rc	=> DEVNULL,
	_local_rc	=> 1,
	user_rc		=> DEVNULL,
	_user_rc	=> 1,
    }, 'Got expected script object';

    ok lives {
	$app->process_options();
    }, 'Processed options successfully'
	or diag $@;

    is $app, {
	_want_files	=> [ qw{ t/basic.t t/elementary.t t/script.t } ],
    }, 'Got expected script object';
}

{
    note <<'EOD';

Test script with configuration specified by environment variable
EOD

    my $app;

    local $ENV{TEST_MORE_TO_TEST2_V0_USER_RC} = 't/data/user.cfg';
    local $ENV{TEST_MORE_TO_TEST2_V0_LOCAL_RC} = DEVNULL;

    ok lives {
	$app = __PACKAGE__->new();
    }, 'Can instantiate script object';

    is $app, {
	_args		=> [],
	local_rc	=> DEVNULL,
	user_rc		=> 't/data/user.cfg',
	_user_rc	=> 1,
    }, 'Got expected script object';

    ok lives {
	$app->process_options();
    }, 'Processed options successfully';

    is $app, {
	bail_on_fail	=> 1,
	uncomment_use	=> 1,
	_want_files	=> [ qw{ t/basic.t t/elementary.t t/script.t } ],
    }, 'Got expected script object';
}

done_testing;

1;

# ex: set textwidth=72 :