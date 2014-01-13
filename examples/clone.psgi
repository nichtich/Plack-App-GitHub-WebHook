use strict;
#PODNAME: clone
#ABSTRACT: Clone and checkout the master branch from a repository
#VERSION

use Git::Repository;
use Plack::App::GitHub::WebHook;
use Cwd;
use File::Path;

my $dir = getcwd().'/checkout';
File::Path::make_path($dir);

Plack::App::GitHub::WebHook->new(
    hook => [
        sub {
            $_[0]->{ref} =~ qr{^refs/heads/master}
        },
        sub {
            my ($payload) = @_;

            my $url = $payload->{repository}{url};

            if ( chdir $dir and -d '.git' ) {
                my $remote = Git::Repository->run(qw(config --get remote.origin.url));
                return unless $remote eq $url;
                Git::Repository->run(qw(pull origin master --quiet));
            } else {
                Git::Repository->run( clone => $url, $dir );
            }
        }
    ],
    access => [ allow => 'all' ], # for testing only!
)->to_app;

=head1 DESCRIPTION

Listens for L<https://help.github.com/articles/post-receive-hooks|webhooks>
with branch `master` and clones or pulls it a given directory.

=head1 TODO

Logging and error handling is not implemented yet. Probably use
L<Git::Repository::Command> and `psgix.logger`.

=cut
