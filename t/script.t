package main;

use 5.010;

use strict;
use warnings;

use File::Spec;
use Test2::V0;

use lib qw{ inc };

use My::Module::Test qw{ check_for_duplicate_matches };

$ENV{AUTHOR_TEST}
    and check_for_duplicate_matches;

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
	$app = __PACKAGE__->new(
	    qw{ --dry-run },
	);
    }, 'Can instantiate script object'
	or diag $@;

    is $app, {
	_args		=> [],
	dry_run		=> 1,
	local_rc	=> DEVNULL,
	user_rc		=> 't/data/user.cfg',
	_user_rc	=> 1,
    }, 'Got expected script object';

    ok lives {
	$app->process_options();
    }, 'Processed options successfully'
	or diag $@;

    is $app, {
	bail_on_fail	=> 1,
	dry_run		=> 1,
	uncomment_use	=> 1,
	_want_files	=> [ qw{ t/basic.t t/elementary.t t/script.t inc/My/Module/Test.pm } ],
    }, 'Got expected script object';

    my $warnings;
    ok lives {
	$warnings = warnings {
	    $app->execute();
	}
    }, 'Converted files successfully'
	or diag $@;

    is $warnings, [
	( match qr/Test::More not used \(or so I think\) in\b/ ) x 4,
    ], 'Got expected warnings';
}

done_testing;

1;

# ex: set textwidth=72 :
