use strict;
use Test::More;
use WebHook;

my $hook = WebHook->new('Filter', ref => qr/master$/);
ok $hook->call({ ref => 'master' });
ok !$hook->call({ });

$hook = WebHook->new('Filter', ref => 'xxx', foo_bar => [qw(2 3)]);
ok $hook->call({ foo => { bar => 2 } , ref => 'xxx'});

done_testing;
