use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use Encode;

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

    is $payload, undef, 'hook not called';

    $res = $cb->(POST '/', [ payload => '{"repository":{"name":"忍者"}}' ]);
    is $res->code, 200, 'ok';
    is_deeply $payload, {repository=>{name=>decode_utf8 '忍者'}}, 'payload';
};

eval { Plack::App::GitHub::WebHook->new( hook => 1 )->prepare_app; };
ok $@, "bad constructor";

done_testing;
