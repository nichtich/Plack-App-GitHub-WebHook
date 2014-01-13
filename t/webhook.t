use strict;
use Test::More;
use GitHub::WebHook;
use Module::Loaded;

isa_ok( GitHub::WebHook->new('Filter'), 'GitHub::WebHook::Filter' );
isa_ok( GitHub::WebHook->new('GitHub::WebHook::Filter'), 'GitHub::WebHook::Filter' );
isa_ok( GitHub::WebHook->new('+GitHub::WebHook::Filter'), 'GitHub::WebHook::Filter' );
isa_ok( GitHub::WebHook::Filter->new, 'GitHub::WebHook::Filter' );

{
    package Filter;
    use parent 'GitHub::WebHook';
    sub call { $_[0]->{foo}.$_[1] };
    1;
}
mark_as_loaded('Filter');

isa_ok( GitHub::WebHook->new('+Filter'), 'Filter' );
isa_ok( Filter->new, 'Filter' );

my $hook = GitHub::WebHook->new( '+Filter', foo => 'bar', call => 'xxx' );
is($hook->call('doz'), 'bardoz', 'call');
is $hook->foo, 'bar', 'accessor';

is( GitHub::WebHook->run('bar', '+Filter', foo => 'doz'), 'dozbar', 'run' );

done_testing;
