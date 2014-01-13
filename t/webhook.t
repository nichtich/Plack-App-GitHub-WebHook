use strict;
use Test::More;
use WebHook;
use Module::Loaded;

isa_ok( WebHook->new('Filter'), 'WebHook::Filter' );
isa_ok( WebHook->new('WebHook::Filter'), 'WebHook::Filter' );
isa_ok( WebHook->new('+WebHook::Filter'), 'WebHook::Filter' );
isa_ok( WebHook::Filter->new, 'WebHook::Filter' );

{
    package Filter;
    use parent 'WebHook';
    sub call { $_[0]->{foo}.$_[1] };
    1;
}
mark_as_loaded('Filter');

isa_ok( WebHook->new('+Filter'), 'Filter' );
isa_ok( Filter->new, 'Filter' );

my $hook = WebHook->new( '+Filter', foo => 'bar', call => 'xxx' );
is($hook->call('doz'), 'bardoz', 'call');
is $hook->foo, 'bar', 'accessor';

is( WebHook->run('bar', '+Filter', foo => 'doz'), 'dozbar', 'run' );

done_testing;
