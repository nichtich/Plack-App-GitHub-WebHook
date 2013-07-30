use Test::More;

use HTTP::Message::PSGI;
use HTTP::Request::Common;
use HTTP::Response;

use Plack::App::GitHub::WebHook;

my $app = Plack::App::GitHub::WebHook->new( hook => sub { } );

my $res = request( '/', '{ }', REMOTE_ADDR => '1.1.1.1' );
is $res->code, 403, 'Forbidden';

$res = request( '/', '{ }', REMOTE_ADDR => '204.232.175.65' );
is $res->code, 200, 'Ok';

$app->access([]);
$res = request( '/', '{ }', REMOTE_ADDR => '1.1.1.1' );
is $res->code, 200, 'empty access list';

$app->access([ deny => 'all' ]);
$res = request( '/', '{ }', REMOTE_ADDR => '204.232.175.65' );
is $res->code, 403, 'Forbidden';

done_testing;

# helper method
sub request {
    my $url     = shift;
    my $payload = shift;
    my $headers = ref $_[0] ? shift : [];
    my %psgi    = @_;

    my $env = req_to_psgi( POST $url, { payload => $payload }, @$headers );
    $env->{$_} = $psgi{$_} for keys %psgi;

    return HTTP::Response->from_psgi( $app->to_app->($env) );
}
