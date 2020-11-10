#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use lib::relative 'lib';
use UnsplashSource;

use IPC::Run3;
use Getopt::Long qw( GetOptions );
use Data::Dumper;

my %options = ( resolution => '1920x1080' );

use constant is_OpenBSD => $^O eq "openbsd";
require OpenBSD::Unveil if is_OpenBSD;
sub unveil {
    if (is_OpenBSD) {
        say "Unveil :: @_" if $options{debug};
        return OpenBSD::Unveil::unveil(@_);
    } else {
        warn "Dummy Unveil :: @_\n" if $options{debug};
        return 1;
    }
}

# Unveil @INC.
foreach my $path (@INC) {
    unveil( $path, 'rx' )
        or die "Unable to unveil: $!\n";
}

GetOptions(
    "resolution=s" => \$options{resolution},

    "search=s{1,}" => \@{$options{search}},
    "featured" => \$options{featured},

    "user=s" => \$options{user},
    "userlikes|user-likes" => \$options{user_likes},

    "collection=s" => \$options{collection_id},

    "daily" => \$options{daily},
    "weekly" => \$options{weekly},

    "debug" => \$options{debug},
    "help|h|?" => sub { HelpMessage() },
) or die "Error in command line arguments\n";

sub HelpMessage {
    say "Crux:
    --help         Print this help message
    --debug        Print debugging information

Unsplash Source:
    --resolution   Device resolution (default: $options{resolution})

    --search=s     Search term (space seperated)
    --featured     Unsplash curated photos

    --user=s       Photos by user
    --userlikes    Photos by user from user's likes

    --collection=s Photos from collection

    --daily        Daily photo
    --weekly       Weekly photo";
    exit;
}

# %unveil contains list of paths to unveil with their permissions.
my %unveil = (
    "/usr" => "rx",
    "/var" => "rx",
    "/etc" => "rx",
    "/dev" => "rx",
);

# Unveil each path from %unveil. We use sort because otherwise keys is
# random order everytime.
foreach my $path ( sort keys %unveil ) {
    unveil( $path, $unveil{$path} )
        or die "Unable to unveil: $!\n";
}

my $response = UnsplashSource::get( %options );
print Dumper($response) if $options{debug};

die "Unexpected response\n"
    unless $response->{status} == 302;

# Unveil $PATH.
foreach my $path ( split(/:/, $ENV{PATH}) ) {
    unveil( $path, "rx" )
        or ($! eq "No such file or directory"
            # Don't die if the file/directory doesn't exist.
            ? next
            : die "Unable to unveil: $! :: $path\n");
}

# Block further unveil calls.
unveil() or die "Unable to lock unveil: $!\n";

run3 ["feh", "--bg-fill", "$response->{headers}{location}"];
