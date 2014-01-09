use strict;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Plack::App::GitHub::WebHook;

sub test_hook(@) { ##no critic
    my ($hook, $payload, $res) = @_;
    test_psgi
        app => Plack::App::GitHub::WebHook->new(
            access => [ allow => 'any' ],
            hook   => $hook
        ),
        client => sub {
            $res = $_[0]->(POST '/', [ payload => $payload ]);
        };
    return $res->code;
}

my $ok;

is test_hook( sub { $ok = 1 }, '{}' ), 200;
is $ok, 1, 'hook called';

my $hook = [
    sub { $_[0]->{repository}{name} eq 'foo' },
    sub { $ok = 2; }
];
is test_hook( $hook, '{"repository":{"name":"bar"}}' ), 202, 'hook accepted';
is $ok, 1, 'hook not fully called';
  
is test_hook( $hook, '{"repository":{"name":"foo"}}' ), 200, 'hook ok';
is $ok, 1, 'hook fully called';

done_testing;
