# NAME

Plack::App::GitHub::WebHook - GitHub WebHook receiver as Plack application

# SYNOPSIS

## Basic usage

    use Plack::App::GitHub::WebHook;

    Plack::App::GitHub::WebHook->new(
        hook => sub {
            my $payload = shift;
            ...
        }
    )->to_app;

## Multiple task hooks

A hook can consist of multiple tasks, given by an array reference. The tasks
are called one by one until a task returns a false value.

    use Plack::App::GitHub::WebHook;
    use IPC::Run3;

    Plack::App::GitHub::WebHook->new(
        hook => [
            sub { $_[0]->{repository}{name} eq 'foo' }, # filter
            { Filter => { repository_name => 'foo' } }, # equivalent filter
            sub { my ($payload) = @_; ...  }, # some action
            sub { run3 \@cmd ... }, # some more action
        ]
    )->to_app;

## Access restriction    

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

# DESCRIPTION

This [PSGI](https://metacpan.org/pod/PSGI) application receives HTTP POST requests with body parameter
`payload` set to a JSON object. The default use case is to receive 
[GitHub WebHooks](http://developer.github.com/webhooks/), for instance
[PushEvents](http://developer.github.com/v3/activity/events/types/#pushevent).

The response of a HTTP request to this application is one of:

- HTTP 403 Forbidden

    If access was not granted (for instance because it did not origin from GitHub).

- HTTP 405 Method Not Allowed

    If the request was no HTTP POST.

- HTTP 400 Bad Request

    If the payload was no well-formed JSON or the `X-GitHub-Event` header did not
    match configured events.

- HTTP 200 OK

    Otherwise, if the hook was called and returned a true value.

- HTTP 202 Accepted

    Otherwise, if the hook was called and returned a false value.

This module requires at least Perl 5.10.

# CONFIGURATION

- hook

    The hook can be any of a code reference, an array reference, or a hash
    reference.

    Each task gets passed the encoded payload. If the task returns a true value,
    next the task is called or HTTP status code 200 is returned. Information can be
    passed from one task to the next by modifying the payload. 

    If a task fails or no task was given, HTTP status code 202 is returned
    immediately. This mechanism can be used for conditional hooks or to detect
    hooks that were called successfully but failed to execute for some reason.

- access

    Access restrictions, as passed to [Plack::Middleware::Access](https://metacpan.org/pod/Plack::Middleware::Access). See SYNOPSIS
    for the default value. A recent list of official GitHub WebHook IPs is vailable
    at [https://api.github.com/meta](https://api.github.com/meta). One should only set the access value on
    instantiation, or manually call `prepare_app` after modification.

- events

    A list of [event types](http://developer.github.com/v3/activity/events/types/)
    expected to be send with the `X-GitHub-Event` header (e.g. `['pull']`).

# SEE ALSO

- [WebHook](https://metacpan.org/pod/WebHook) and [WebHook::Filter](https://metacpan.org/pod/WebHook::Filter)
- GitHub WebHooks are documented at [http://developer.github.com/webhooks/](http://developer.github.com/webhooks/).
- GitHub does not include webhook event types in the payload but as HTTP request
header `X-GitHub-Event`. To only handle selected event types, use a
conditional middleware:

        build {
            enable_if { ($_[0]->{HTTP_X_GITHUB_EVENT} // '') eq 'push' } 
                Plack::App::GitHub::WebHook->new( hook => $push_hook );
            enable_if { ($_[0]->{HTTP_X_GITHUB_EVENT} // '') eq 'issue' } 
                Plack::App::GitHub::WebHook->new( hook => $issue_hook );
            ...
        };

- [WWW::GitHub::PostReceiveHook](https://metacpan.org/pod/WWW::GitHub::PostReceiveHook) uses [Web::Simple](https://metacpan.org/pod/Web::Simple) to receive GitHub web
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

- [Net::GitHub](https://metacpan.org/pod/Net::GitHub) and [Pithub](https://metacpan.org/pod/Pithub) provide access to GitHub APIs.
- [App::GitHubWebhooks2Ikachan](https://metacpan.org/pod/App::GitHubWebhooks2Ikachan) is an application that also receives GitHub WebHooks.

# STATUS

[![Build Status](https://travis-ci.org/nichtich/Plack-App-GitHub-WebHook.png)](https://travis-ci.org/nichtich/Plack-App-GitHub-WebHook)
[![Coverage Status](https://coveralls.io/repos/nichtich/Plack-App-GitHub-WebHook/badge.png?branch=master)](https://coveralls.io/r/nichtich/Plack-App-GitHub-WebHook?branch=master)

# AUTHOR

Jakob Voss `<jakob.voss@gbv.de>`

# LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
