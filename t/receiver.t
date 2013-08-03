use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use JSON;

use App::GitHub::Receiver;

sub test_config (@) {
    my ($config, @tests) = @_;
    my $app = App::GitHub::Receiver->new(
        access => [ allow => '127.0.0.1' ],
        config => $config
    );

    test_psgi $app, sub {
        my $cb = shift;

        while (@tests) {
            my $json = encode_json shift @tests;
            my $test = shift @tests;

            my $res = $cb->(POST '/', [ payload => $json ]);
            $test->($res->code);
        }
    };
}

# test selection of branches

my $called = 0;

test_config {
        command => sub { $called++ }
    },
    { ref => "refs/heads/master" },
    sub { is shift, 200, 'called'; is $called, 1, 'default master ref' },
    { ref => "refs/heads/foo", repository => { master_branch => 'foo' } },
    sub { is shift, 200, 'called'; is $called, 2, 'master_branch ref' },
    { ref => "refs/heads/foo" },
    sub { is shift, 202, 'not called'; is $called, 2, 'not any ref' };

test_config {
        branch  => "*",
        command => sub { $called++ }
    },
    { ref => "refs/heads/foo" },
    sub { is shift, 200, 'called'; is $called, 3, 'any branch' };

test_config {
        branch  => "master",
        command => sub { $called++ }
    },
    { ref => "refs/heads/foo", repository => { master_branch => 'foo' } },
    sub { is shift, 202, 'not called'; is $called, 3, 'specific ref' },
    { ref => "refs/heads/master" },
    sub { is shift, 200, 'called'; is $called, 4, 'specific ref' };

diag 'TODO: test selection by URL and name';

test_config {
        command => 'echo $WEBHOOK_REPO $WEBHOOK_BRANCH $WEBHOOK_REPO_URL $WEBHOOK_AFTER',
    },
    {
        after => 'ecc34b0908afce7b34525f1e1fa4ba725ff0e970',
        ref   => 'refs/head/foo',
        repository => {
            name => 'bar',
            url  => 'http://example.org/',
        }
    }, sub {
        diag "TODO: test execution of command";
        # output must be "bar master http://example.org/ ecc34b0908afce7b34525f1e1fa4ba725ff0e970";
    };

done_testing;
