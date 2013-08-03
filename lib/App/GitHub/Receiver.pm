package App::GitHub::Receiver;

use strict;
use parent 'Plack::App::GitHub::WebHook';
use Plack::Util::Accessor qw(config tasks);

use App::GitHub::Receiver::Task;

sub init {
    my $self = shift;

    $self->config([]) unless $self->config;
    if (!ref $self->config) {
        # TODO: load config file
    }

    if (ref $self->config eq 'HASH') {
        $self->config([ $self->config ]);
    }

    $self->tasks([]);
    foreach my $c (@{$self->config}) {
        push @{ $self->tasks }, App::GitHub::Receiver::Task->new($c);
    }
}

sub receive {
    my ($self, $payload) = @_;

    # TODO: log_trace payload

    my $called = 0;

    foreach my $task ( @{ $self->tasks } ) {
        next unless $task->check( $payload );
        $called = 1;
        $task->execute( $payload );
    }

    return $called;
}

1;

=head1 DESCRIPTION

...

=head1 LOGGING

=over 4

=item the web hook was called

Log each call to the web hook, where it came from, what
payload was passed, and how the call was responded to.

Webserver log and C</var/log/github-receiver/access.log>?

=item an action was executed

The receiver executed an action in response to call to the web hook.

C</var/log/github-receiver/.log>?


=item stdout and stderr of an action

One file per execution/job

C</var/log/github-receiver/jobs/JOBID.log>

=back

=cut
