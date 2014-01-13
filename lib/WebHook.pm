use strict;
package WebHook;
#ABSTRACT: WebHook receiver
#VERSION
use v5.10;
use Module::Load;
use Module::Loaded;

sub new {
    my ($class, %config);

    if ($_[0] eq 'WebHook') {
        (undef, $class, %config) = @_;
    
        unless ($class =~ s/^\+// || $class =~ /^WebHook/) {
            $class = "WebHook\::$class";
        }
    } else {
        ($class, %config) = @_;
    }

    load $class unless is_loaded($class);

    foreach my $field (keys %config) {
        no strict 'refs'; ## no critic
        *{"$class\::$field"} = sub { $_[0]->{$field} }
            unless defined &{"$class\::$field"};
    }

    bless \%config, $class;
}

sub call { 
    ref $_[0] . "::call is not implemented!\n";
}

sub run {
    my ($self, $payload, @config) = @_;
    $self->new(@config)->call($payload);
}

=head1 SYNOPSIS
    
    # create a hook (both lines are equivalent):
    $hook = WebHook->new( 'Git::Pull', work_tree => $dir );
    $hook = WebHook::Git::Pull->new( work_tree => $dir );

    # call a hook
    $hook->call( $payload );
    
    # create and call a hook (both lines are equivalent):
    WebHook->new( $hook, %config )->call( $payload );
    WebHook->run( $payload, $hook, %config );

    # constructor defines accessor methods (unless already defined)
    $hook = WebHook::Filter->new( ref => 'refs/origin/master' );
    $hook->ref; # refs/origin/master

=head1 DESCRIPTION

A WebHook is a method that is called via web on selected events. The webhook
receives some payload, typically send as JSON via HTTP POST. For an example see
L<https://help.github.com/articles/post-receive-hooks|GitHub WebHooks>.  This
module provides a superclass to implement webhooks receivers. Each webhook
receiver class is expected to implement a B<call> method. The method gets
passed a payload as Perl data structure and it is expected to return a true
value on success. 

The constructor expects the name of a webhook subclass. The prefix "WebHook::"
is prepended unless the name starts with "+".

=head1 INCLUDED WEBHOOKS

=over

=item

L<WebHook::Filter> - filter WebHook payload on common criteria

=back

=head1 SEE ALSO

See L<Message::Passing::Output::WebHooks> for a CPAN module to call webhooks.

See L<Plack::App::GitHub::WebHook> for a web application that receives
GitHub webhooks.

=encoding utf8

=cut

1;
