use strict;
use Test::More;
use Plack::Test;
use Plack::Util;
use HTTP::Request::Common;

unless ( eval { require Git::Repository; 1; } ) {
    plan(skip_all => 'Git::Repository required for this test');
}

my $app = eval { Plack::Util::load_psgi('examples/clone.psgi') };
ok $app, 'loaded example';

my $url = 'git@github.com:nichtich/Plack-App-GitHub-WebHook.git';

# use File::Temp;
# use Cwd;
# diag getcwd;
my $skip = 1; # don't checkout live

test_psgi $app, sub {
    my $cb = shift;
    
    my $payload = '{"ref":"refs/heads/master","repository":{"url":"'.$url.'"}}';
    my $res = $cb->(POST '/', [ payload => $payload ]);

    is $res->code, 200;

    # TODO
    
} unless $skip;

done_testing;
