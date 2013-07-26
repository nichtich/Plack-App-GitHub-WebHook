use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Plack::App::GitHub::WebHook;

my $payload = undef;
my $app = Plack::App::GitHub::WebHook->new(
    hook   => sub { $payload = shift; },
    access => [ allow => 'all' ]
);

test_psgi $app, sub {
    my $cb = shift;

    my $res = $cb->(GET '/');
    is $res->code, 405, 'HTTP method must be POST';

    $res = $cb->(POST '/');
    is $res->code, 400, 'payload expected';

    is $payload, undef;

    $res = $cb->(POST '/', [ payload => '{}' ]);
    is $res->code, 200, 'ok';
    is_deeply $payload, { }, 'payload received';
};

done_testing;
