package App::GitHub::Receiver;

use strict;
use parent 'Plack::App::GitHub::WebHook';
use Plack::Util::Accessor qw(config);

sub init {
    my $self = shift;

    $self->config([]) unless $self->config;
    if (!ref $self->config) {
        # TODO: load config file
    }

    if (ref $self->config eq 'HASH') {
        $self->config([ $self->config ]);
    }

    # initialize actions
    foreach my $c (@{$self->config}) {
        $c->{branch} = "*master" unless $c->{branch};
    }

}

sub receive {
    my ($self, $payload) = @_;

    my $ref   = $payload->{ref};
    my $after = $payload->{after};

    foreach my $r ( @{ $self->config } ) {
        next unless check_action( $r, $payload );

        my $command = $r->{command};
        if ((ref($command) // '') eq 'CODE') {
            $command->($payload);
        }
    }
#    $self->{config}->...
}

sub check_action {
    my ($c, $p) = @_;
     # TODO: check branch and url
    my $branch = $c->{branch};

    my $ref = $p->{ref} || '' ;
    $ref =~ s{^refs/heads/}{};

    unless( $branch eq '*' or $branch eq $ref or
            ($branch eq '*master' and
                $ref eq ($p->{repository}->{master_branch} || 'master')
            )
    ) {
        return;
    }

    return 1;
}

1;
