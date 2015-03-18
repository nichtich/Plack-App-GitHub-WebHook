use strict;
use warnings;
use Test::More;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Plack::App::GitHub::WebHook;

my $app = Plack::App::GitHub::WebHook->new( 
    access => [ allow => 'all' ],
    hook   => sub {
        my ($payload, $event, $delivery, $logger) = @_;
        foreach my $level (qw(debug info warn error fatal)) {
            $logger->{$level}->($delivery);
            $logger->log( $level, "$delivery\n" );
        }
        $logger->fatal($payload->{answer});
    }
)->to_app;

my $logfile = [];
my $env = req_to_psgi( POST '/', Content => '{"answer":42}', 
    'X-GitHub-Event' => 'ping', 
    'X-Github-Delivery' => '12345'
);
my $res = $app->($env); 
is_deeply $logfile, [], "don't die without logger";

$env->{'psgix.logger'} = sub {
    push @$logfile, $_[0]->{level}, $_[0]->{message};
};
$res = $app->($env); 

is_deeply $logfile, [
    debug => '12345',
    debug => '12345',
    info  => '12345',
    info  => '12345',
    warn  => '12345',
    warn  => '12345',
    error => '12345',
    error => '12345',
    fatal => '12345',
    fatal => '12345',
    fatal => '42',
];

done_testing;
