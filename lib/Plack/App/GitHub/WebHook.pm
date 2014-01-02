package Plack::App::GitHub::WebHook;
#ABSTRACT: GitHub WebHook receiver as Plack application

use strict;
use v5.10;
use JSON qw(decode_json);

use parent 'Plack::Component';
use Plack::Util::Accessor qw(hook access app);
use Plack::Request;
use Plack::Middleware::Access;
use Carp qw(croak);

sub prepare_app {
    my $self = shift;

    if ($self->hook and (!ref $self->hook or ref $self->hook ne 'CODE')) {
        croak "hook must be a CODEREF"
    }

    $self->access([
        allow => "204.232.175.64/27",
        allow => "192.30.252.0/22",
        deny  => "all"
    ]) unless $self->access;

    $self->app(
        Plack::Middleware::Access->wrap(
            sub { $self->call_granted(shift) },
            rules => $self->access
        )
    );

    $self->init;
}

sub init { }

sub call {
    my ($self, $env) = @_;
    $self->app->($env);
}

sub call_granted {
    my ($self, $env) = @_;

    if ( $env->{REQUEST_METHOD} ne 'POST' ) {
        return [405,['Content-Type'=>'text/plain','Content-Length'=>18],['Method Not Allowed']];
    }

    my $req = Plack::Request->new($env);

    my $json = eval { decode_json $req->body_parameters->{payload} };

    if (!$json) {
        return [400,['Content-Type'=>'text/plain','Content-Length'=>11],['Bad Request']];
    }

    if ( $self->receive($json) ) {
        return [200,['Content-Type'=>'text/plain','Content-Length'=>2],['OK']];
    } else {
        return [202,['Content-Type'=>'text/plain','Content-Length'=>2],['Accepted']];
    }
}

sub receive {
    my ($self, $payload) = @_;

    if ($self->{hook}) {
        return $self->{hook}->($payload);
    } else {
        return;
    }
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

    # this is equivalent to
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

If access was not granted (for instance because it did not origin from GitHub).

=item HTTP 405 Method Not Allowed

If the request was no HTTP POST.

=item HTTP 400 Bad Request

If the payload was no well-formed JSON. A later version of this module may add
further validation.

=item HTTP 200 OK

Otherwise, if the hook was called and returned a true value.

=item HTTP 202 Accepted

Otherwise, if the hook was called and returned a false value.

=back

This module requires at least Perl 5.10.

=head1 CONFIGURATION

=over 4

=item hook

A code reference that gets passed the encoded payload. Alternatively derive a
subclass from Plack::App::GitHub::WebHook and implement the method C<receive>
instead. The hook or receive method is expected to return a true value. If it
returns a false value, the application will return HTTP status code 202 instead
of 200. One can use this mechanism for instance to detect hooks that were
called successfully but failed to execute for some reason.


=item access

Access restrictions, as passed to L<Plack::Middleware::Access>. See SYNOPSIS
for the default value. A recent list of official GitHub WebHook IPs is vailable
at L<https://api.github.com/meta>. One should only set the access value on
instantiation, or manually call C<prepare_app> after modification.

=back

=head1 SEE ALSO

L<WWW::GitHub::PostReceiveHook> uses L<Web::Simple> to receive GitHub web
hooks. L<Net::GitHub> and L<Pithub> provide access to GitHub APIs.

=encoding utf8

=cut

1;
