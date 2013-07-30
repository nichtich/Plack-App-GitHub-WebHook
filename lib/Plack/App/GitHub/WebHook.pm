package Plack::App::GitHub::WebHook;
#ABSTRACT: GitHub WebHook receiver as Plack application

use v5.10;
use JSON qw(decode_json);

use parent 'Plack::Component';
use Plack::Util::Accessor qw(hook access app);
use Plack::Request;
use Plack::Middleware::Access;
use Carp qw(croak);

sub prepare_app {
    my $self = shift;

    croak "hook must be a CODEREF" 
        unless (ref($self->hook) // '') eq 'CODE';

    $self->access([
        allow => "204.232.175.64/27",
        allow => "192.30.252.0/22",
        deny  => "all"
    ]) unless $self->access;

    $self->app(
        Plack::Middleware::Access->wrap(
            sub { $self->receive(shift) },
            rules => $self->access
        )
    );
}

sub call {
    my ($self, $env) = @_;
    $self->app->($env);
}

sub receive {
    my ($self, $env) = @_;

    if ( $env->{REQUEST_METHOD} ne 'POST' ) {
        return [405,['Content-Type'=>'text/plain','Content-Length'=>18],['Method Not Allowed']];
    }

    my $req = Plack::Request->new($env);

    my $json = eval { decode_json $req->body_parameters->{payload} };

    if (!$json) {
        return [400,['Content-Type'=>'text/plain','Content-Length'=>11],['Bad Request']];
    }

    # should this be catched?
    $self->{hook}->($json) if $self->{hook};

    return [200,['Content-Type'=>'text/plain','Content-Length'=>2],['OK']];
}

=head1 SYNOPSIS

    use Plack::App::GitHub::WebHook;

    Plack::App::GitHub::WebHook->new(
        hook => sub {
            my $payload = shift;

            return unless $payload->{repository}->{name} eq 'foo-bar';

            foreach (@{$payload->{commits}}) {
                ...
            }
    );


    # access restriction, as enabled by default
    Plack::App::GitHub::WebHook->new(
        hook => sub { ... },
        access => [
            allow => "204.232.175.64/27",
            allow => "192.30.252.0/22",
            deny  => 'all'
        ]
    );


    # alternatively
    use Plack::Builder;

    builder {
        mount 'notify' => builder {
            enable 'Access', rules => [
                allow => "204.232.175.64/27",
                allow => "192.30.252.0/22",
                deny  => 'all'
            ]
            Plack::App::GitHub::WebHook->new(
                hook => sub { ... }
            );
        }
    };

=head1 DESCRIPTION

This L<PSGI> application receives HTTP POST requests with body parameter
C<payload> set to a JSON object. The default use case is to receive
L<GitHub WebHooks|https://help.github.com/articles/post-receive-hooks>.

The response of a HTTP request to this application is one of:

=over 4

=item HTTP 403 Forbidden

If access was not granted.

=item HTTP 405 Method Not Allowed

If the request was no HTTP POST.

=item HTTP 400 Bad Request

If the payload was no well-formed JSON. A later version of this module may add
further validation.

=item HTTP 200 OK

Otherwise. The hook is only called in this case. The hook should not die; a
later version of this module may also catch errors.

=back

This module requires at least Perl 5.10.

=head1 CONFIGURATION

=over 4

=item hook

A code reference that gets passed the encoded payload.

=item access

Access restrictions, as passed to L<Plack::Middleware::Access>. See SYNOPSIS
for the default value. A recent list of official GitHub WebHook IPs is vailable
at L<https://api.github.com/meta>. One should only set the access value on
instantiation, or manually call C<prepare_app> after modification.

=back

=encoding utf8

=cut

1;
