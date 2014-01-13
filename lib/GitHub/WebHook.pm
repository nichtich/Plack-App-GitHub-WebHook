use strict;
package GitHub::WebHook;
#ABSTRACT: GitHub WebHook receiver
#VERSION
use v5.10;
use Module::Load;
use Module::Loaded;

sub new {
    my ($class, %config);

    if ($_[0] eq 'GitHub::WebHook') {
        (undef, $class, %config) = @_;
    
        unless ($class =~ s/^\+// || $class =~ /^GitHub::WebHook/) {
            $class = "GitHub::WebHook\::$class";
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

sub call { ...  }

sub run {
    my ($self, $payload, @config) = @_;
    $self->new(@config)->call($payload);
}

=head1 SYNOPSIS
    
    # create a hook (both lines are equivalent):
    $hook = GitHub::WebHook->new( 'Pull', work_tree => $dir );
    $hook = GitHub::WebHook::Pull->new( work_tree => $dir );

    # call a hook
    $hook->call( $payload );
    
    # create and call a hook (both lines are equivalent):
    GitHub::WebHook->new( $hook, %config )->call( $payload );
    GitHub::WebHook->run( $payload, $hook, %config );

    # constructor defines accessor methods (unless already defined)
    $hook = GitHub::WebHook::Foo->new( bar => 'doz' );
    $hook->bar; # doz

=head1 DESCRIPTION

Subclasses of GitHub::WebHook are expected to implement a B<call> method. The
method gets passed a payload as Perl data structure and it is expected to
return a true value on success. 

The constructor expects the name of a subclass. The prefix "GitHub::WebHook::"
is prepended unless the name starts with "+".

=head1 SEE ALSO

GitHub WebHooks are documented at
L<https://help.github.com/articles/post-receive-hooks>.

=encoding utf8

=cut

1;
