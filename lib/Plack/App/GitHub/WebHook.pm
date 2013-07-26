package Plack::App::GitHub::WebHook;
#ABSTRACT: GitHub WebHook receiver as Plack application

use v5.14.1;
use JSON::PP qw(decode_json); # core module

use parent 'Plack::Component';
use Plack::Util::Accessor qw(hook access);
use Plack::Middleware::Access;
use Carp qw(croak);

sub prepare_app {
    my $self = shift;

    croak "hook must be a CODEREF" if (ref($self->hook) // '') ne 'CODE';

    $self->access([
        allow => "204.232.175.64/27",
        allow => "192.30.252.0/22",
        deny => 'all'
    ]) unless $self->access;

    $self->app(
        Plack::Middleware::Access->wrap(
            sub { $self->receive(shift) },
            $self->access
        )
    );
}

sub call {
    my ($self, $env) = @_;
    $self->app($env);
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

=head1 CONFIGURATION

=over 4

=item hook

A code reference that gets passed the encoded payload.

=item access

Access restrictions, as passed to L<Plack::Middleware::Access>. See SYNOPSIS
for the default value. A recent list of official GitHub WebHook IPs is vailable
at L<https://api.github.com/meta>.

=back

=encoding utf8

=cut

1;
