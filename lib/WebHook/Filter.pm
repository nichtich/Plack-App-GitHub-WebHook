package WebHook::Filter;
use strict;
use v5.10;

our $VERSION = '0.4';

use parent 'WebHook';

sub call {
    my ($self, $payload) = @_;

    foreach my $key (%$self) {

        # prepare test routine (I miss the smartmatch operator!)
        my $test = $self->{$key};

        if (!ref $test) {
            $self->{$key} = sub { $_[0] eq $test };
        } elsif (ref $test eq 'Regexp') {
            $self->{$key} = sub { $_[0] =~ $test };
        } elsif (ref $test eq 'ARRAY') {
            $self->{$key} = sub { 
                scalar (grep { $_[0] eq $_ } @$test) 
            };
        }

        # repository_url, repository_owner_name, ...
        my @parts = split /_/, $key;
        my $value = $payload->{ shift @parts };
        foreach (@parts) {
            $value = eval { $value->{$_} } or return;
        }

        return unless $self->{$key}->($value);        
    }
    
    return 1;
}

1;
__END__

=head1 NAME

WebHook::Filter - filter WebHook payload on common criteria

=head1 SYNOPSIS

    my $app = Plack::App::WebHook->new(
        hook => [
            { 
                Filter => {
                    ref            => qr/master$/,
                    repository_url => $url,
                } 
            },
            sub { ... }; # only called if filter matches 
        ];
    );

=head1 DESCRIPTION

This L<WebHook> can be used to check whether a webhook payload matches some
defined criteria.

=cut
