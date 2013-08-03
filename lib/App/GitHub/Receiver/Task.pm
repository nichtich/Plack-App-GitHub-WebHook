package App::GitHub::Receiver::Task;

use strict;
use Moo;

has branch => (
    is      => 'rw',
    default => sub { "*master" }
);

has command => (
    is      => 'rw'
);

sub execute {
    my ($self, $payload) = @_;

    my $ref   = $payload->{ref};
    my $after = $payload->{after};

    if ((ref($self->command) // '') eq 'CODE') {
        $self->command->($payload);
    }
}

sub check {
    my ($self, $payload) = @_;

    my $branch = $self->branch;

    my $ref = $payload->{ref} || '' ;
    $ref =~ s{^refs/heads/}{};

    my $repo = $payload->{repository};

    unless( $branch eq '*' or $branch eq $ref or
            ($branch eq '*master' and
                $ref eq ($repo->{master_branch} || 'master')
            )
    ) {
        return;
    }

    return 1;
}


1;
