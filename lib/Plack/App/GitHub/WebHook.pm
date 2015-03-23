package Plack::App::GitHub::WebHook;
use strict;
use warnings;
use v5.10;

use parent 'Plack::Component';
use Plack::Util::Accessor qw(hook access app events safe secret);
use Plack::Request;
use Plack::Builder;
use Plack::Middleware::Access;
use Carp qw(croak);
use JSON qw(decode_json);

our $VERSION = '0.7';

sub to_app {
    my $self = shift;

    if ( (ref $self->hook // '') ne 'ARRAY' ) {
        $self->hook( [ $self->hook // () ] );
    }

    foreach my $task (@{$self->hook}) {
        if ( (ref $task // '') ne 'CODE') {
            croak "hook must be a CODE or ARRAY of CODEs";
        }
    }
    
    $self->access([
        allow => "204.232.175.64/27",
        allow => "192.30.252.0/22",
        deny  => "all"
    ]) unless $self->access;

    my $app = builder {
        enable 'Access', rules => $self->access;
        enable 'HTTPExceptions';
        sub { $self->call_granted($_[0]) }
    };

    if ($self->secret) {
        require Plack::Middleware::HubSignature;
        $app = Plack::Middleware::HubSignature->wrap($app,
            secret => $self->secret
        );
    }

    $app;
}

sub call_granted {
    my ($self, $env) = @_;

    if ( $env->{REQUEST_METHOD} ne 'POST' ) {
        return [405,['Content-Type'=>'text/plain','Content-Length'=>18],['Method Not Allowed']];
    }

    my $req = Plack::Request->new($env);
    my $event = $env->{'HTTP_X_GITHUB_EVENT'} // '';
    my $delivery = $env->{'HTTP_X_GITHUB_DELIVERY'} // '';
    my $payload;
    my ($status, $message);
    
    if ( !$self->events or grep { $event eq $_ } @{$self->events} ) {
        $payload = eval { decode_json $req->content };
    }

    if (!$payload) {
        return [400,['Content-Type'=>'text/plain','Content-Length'=>11],['Bad Request']];
    }
    
    my $logger = Plack::App::GitHub::WebHook::Logger->new(
        $env->{'psgix.logger'} || sub { }
    );

    if ( $self->receive( [ $payload, $event, $delivery, $logger ], $env->{'psgi.errors'} ) ) {
        ($status, $message) = (200,"OK");
    } else {
        ($status, $message) = (202,"Accepted");
    }

    $message = ucfirst($event)." $message" if $self->events;

    return [ 
        $status,
        [ 'Content-Type' => 'text/plain', 'Content-Length' => length $message ],
        [ $message ] 
    ];
}

sub receive {
    my ($self, $args, $error) = @_;

    foreach my $hook (@{$self->{hook}}) {
        if ( !eval { $hook->(@$args) } || $@ ) {
            if ( $@ ) {
                if ($self->safe) {
                    $error->print($@);
                } else {
                    die Plack::App::GitHub::WebHook::Exception->new( 500, $@ );
                }
            }
            return;
        }
    } 

    return scalar @{$self->{hook}};
}

{
    package Plack::App::GitHub::WebHook::Logger;
    sub new {
        my $self = bless { logger => $_[1] }, $_[0];
        foreach my $level (qw(debug info warn error fatal)) {
            $self->{$level} = sub { $self->log( $level => $_[0] ) }
        }
        $self;
    }
    sub log {
        my ($self, $level, $message) = @_;
        chomp $message;
        $self->{logger}->({ level => $level, message => $message });
        1;
    }
    sub debug { $_[0]->log(debug => $_[1]) }
    sub info  { $_[0]->log(info  => $_[1]) }
    sub warn  { $_[0]->log(warn  => $_[1]) }
    sub error { $_[0]->log(error => $_[1]) }
    sub fatal { $_[0]->log(fatal => $_[1]) }
}

{
    package Plack::App::GitHub::WebHook::Exception;
    use overload  '""' => sub { $_[0]->{message} };
    sub new { bless { code => $_[1], message => $_[2] }, $_[0]; }
    sub code { $_[0]->{code} }
}

1;
__END__

=head1 NAME

Plack::App::GitHub::WebHook - GitHub WebHook receiver as Plack application

=begin markdown

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Plack-App-GitHub-WebHook.png)](https://travis-ci.org/nichtich/Plack-App-GitHub-WebHook)
[![Coverage Status](https://coveralls.io/repos/nichtich/Plack-App-GitHub-WebHook/badge.png?branch=master)](https://coveralls.io/r/nichtich/Plack-App-GitHub-WebHook?branch=master)
[![Kwalitee Score](http://cpants.cpanauthors.org/dist/Plack-App-GitHub-WebHook.png)](http://cpants.cpanauthors.org/dist/Plack-App-GitHub-WebHook)

=end markdown

=head1 SYNOPSIS

=head2 Basic usage

    use Plack::App::GitHub::WebHook;

    Plack::App::GitHub::WebHook->new(
        hook => sub {
            my ($payload, $event, $delivery, $logger) = @_;
            ...
        }
    )->to_app;

=head2 Multiple task hooks

A hook can consist of multiple tasks, given by an array reference. The tasks
are called one by one until a task returns a false value.

    use Plack::App::GitHub::WebHook;
    use IPC::Run3;

    Plack::App::GitHub::WebHook->new(
        hook => [
            sub { $_[0]->{repository}{name} eq 'foo' }, # filter
            sub { # action
                my ($payload, $event, $delivery, $logger) = @_;
                run3 \@cmd, undef, $logger->{info}, $logger->{error}; 
            },
            sub { ...  }, # some more action
        ]
    )->to_app;

=head2 Access restriction    

By default access is restricted to known GitHub WebHook IPs.

    Plack::App::GitHub::WebHook->new(
        hook => sub { ... },
        access => [
            allow => "204.232.175.64/27",
            allow => "192.30.252.0/22",
            deny  => 'all'
        ]
    )->to_app;

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

=head2 Synchronize with a GitHub repository

The following application automatically pulls the master branch of a GitHub
repository into a local working directory.

    use Plack::App::GitHub::WebHook;
    use IPC::Run3;

    my $branch = "master;
    my $work_tree = "/some/path";

    Plack::App::GitHub::WebHook->new(
        events => ['push','ping'],
        hook => [
            sub { 
                my ($payload, $event, $delivery, $log) = @_;
                $log->info("$event $delivery");
                $event eq 'ping' or $payload->{ref} eq "refs/heads/$branch";
            },
            sub {
                my ($payload, $event, $delivery, $log) = @_;
                my $origin = $payload->{repository}->{clone_url} 
                           or die "missing clone_url\n";
                my $cmd;
                if ( -d "$work_tree/.git") {
                    chdir $work_tree;
                    $cmd = ['git','pull',$origin,$branch];
                } else {
                    $cmd = ['git','clone',$origin,'-b',$branch,$work_tree];
                }
                $log->info(join ' ', '$', @$cmd);
                run3 $cmd, undef, $log->{info}, $log->{error};
                1;
            },
            # sub { ...optional action after each pull... } 
        ],
    )->to_app;

=head1 DESCRIPTION

This L<PSGI> application receives HTTP POST requests with body parameter
C<payload> set to a JSON object. The default use case is to receive 
L<GitHub WebHooks|http://developer.github.com/webhooks/>, for instance
L<PushEvents|http://developer.github.com/v3/activity/events/types/#pushevent>.

The response of a HTTP request to this application is one of:

=over 4

=item HTTP 403 Forbidden

If access was not granted (for instance because it did not origin from GitHub).

=item HTTP 405 Method Not Allowed

If the request was no HTTP POST.

=item HTTP 400 Bad Request

If the payload was no well-formed JSON or the C<X-GitHub-Event> header did not
match configured events.

=item HTTP 200 OK

Otherwise, if the hook was called and returned a true value.

=item HTTP 202 Accepted

Otherwise, if the hook was called and returned a false value.

=item HTTP 500 Internal Server Error

If a hook died with an exception, the error is returned as content body.                

=back

This module requires at least Perl 5.10.

=head1 CONFIGURATION

=over 4

=item hook

A code reference or an array of code references with tasks that are executed on
an incoming webhook.  Each task gets passed the encoded payload, the
L<event|https://developer.github.com/webhooks/#events> and the unique delivery
ID, and a L<logger object|/LOGGING>.  If the task returns a true value, next
the task is called or HTTP status code 200 is returned.  Information can be
passed from one task to the next by modifying the payload. 

If a task returns a false value or if no task was given, HTTP status code 202
is returned immediately. This mechanism can be used for conditional hooks or to
detect hooks that were called successfully but failed to execute for some
reason.

=item safe

Wrap all hook tasks in C<< eval { ... } >> blocks to catch exceptions.  Error
messages are send to the PSGI error stream C<psgi.errors>.  A dying task in
safe mode is equivalent to a task that returns a false value, so it will result
in a HTTP 202 response.

Plack::Middleware::HTTPExceptions

If you want errors to result in a HTTP 500 response,
wrap the application in an eval block such as this:

    sub {
        eval { $app->(@_) } || do {
            my $msg = $@ || 'Server Error';
            [ 500, [ 'Content-Length' => length $msg ], [ $msg ] ];
        };
    };

=item secret

Secret token set at github Webhook setting to validate payload.  See
L<https://developer.github.com/webhooks/securing/> for details. Requires
L<Plack::Middleware::HubSignature>.

=item access

Access restrictions, as passed to L<Plack::Middleware::Access>. See SYNOPSIS
for the default value. A recent list of official GitHub WebHook IPs is vailable
at L<https://api.github.com/meta>. One should only set the access value on
instantiation, or manually call C<prepare_app> after modification.

=item events

A list of L<event types|http://developer.github.com/v3/activity/events/types/>
expected to be send with the C<X-GitHub-Event> header (e.g. C<['pull']>).

=cut

=back

=head1 LOGGING

Each hook is passed a logging object as fourth parameter. It provides logging
methods for each log level and a general log method:

    sub sample_hook {
        my ($payload, $event, $delivery, $log) = @_;

        $log->debug('message');  $log->{debug}->('message');
        $log->info('message');   $log->{info}->('message');
        $log->warn('message');   $log->{warn}->('message');
        $log->error('message');  $log->{error}->('message');
        $log->fatal('message');  $log->{fatal}->('message');

        $log->log( warn => 'message' );

        run3 \@system_command, undef,
            $log->{info},   # STDOUT to log level info
            $log->{error};  # STDERR to log level error
    }

Trailing newlines on log messages are trimmed.

=head1 DEPLOYMENT

Many deployment methods exist. An easy option might be to use Apache webserver
with mod_cgi and L<Plack::Handler::CGI>. First install Apache, Plack and
Plack::App::GitHub::WebHook:

    sudo apt-get install apache2
    sudo apt-get install cpanminus libplack-perl
    sudo cpanm Plack::App::GitHub::WebHook

Then add this section to C</etc/apache2/sites-enabled/default> (or another host
configuration) and restart Apache.

    <Directory /var/www/webhooks>
       Options +ExecCGI -Indexes +SymLinksIfOwnerMatch
       AddHandler cgi-script .cgi
    </Directory>

You can now put webhook applications in directory C</var/www/webhooks> as long
as they are executable, have file extension C<.cgi> and shebang line
C<#!/usr/bin/env plackup>. You might further want to run webhooks scripts as
another user instead of C<www-data> by using Apache module SuExec.

=head1 SEE ALSO

=over

=item

GitHub WebHooks are documented at L<http://developer.github.com/webhooks/>.

=item

L<WWW::GitHub::PostReceiveHook> uses L<Web::Simple> to receive GitHub web
hooks. A listener as exemplified by the module can also be created like this:

    use Plack::App::GitHub::WebHook;
    use Plack::Builder;
    build {
        mount '/myProject' => 
            Plack::App::GitHub::WebHook->new(
                hook => sub { my $payload = shift; }
            );
        mount '/myOtherProject' => 
            Plack::App::GitHub::WebHook->new(
                hook => sub { run3 \@cmd ... }
            );
    };

=item

L<Net::GitHub> and L<Pithub> provide access to GitHub APIs.

=item

L<App::GitHubWebhooks2Ikachan> is an application that also receives GitHub WebHooks.

=back

=head1 COPYRIGHT AND LICENSE

Copyright Jakob Voss, 2014-

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
