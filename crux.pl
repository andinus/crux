#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

use lib::relative 'lib';
use UnsplashSource;

use IPC::Run3;
use Getopt::Long qw( GetOptions );
use Term::ANSIColor qw( :pushpop colored );

local $SIG{__WARN__} = sub { print colored( $_[0], 'yellow' ); };

my %options = ( resolution => '1920x1080' );

use constant is_OpenBSD => $^O eq "openbsd";
require OpenBSD::Unveil
    if is_OpenBSD;
sub unveil {
    if (is_OpenBSD) {
        say LOCALCOLOR GREEN "Unveil :: @_" if $options{debug};
        return OpenBSD::Unveil::unveil(@_);
    } else {
        warn "Dummy unveil :: @_\n" if $options{debug};
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
    print LOCALCOLOR GREEN "Crux:
    --help         Print this help message
    --debug        Print debugging information

Unsplash:
    --resolution   Device resolution (default: 1920x1080)

    --search=s     Search term (space seperated)
    --featured     Unsplash curated photos

    --user=s       Photos by user
    --userlikes    Photos by user from user's likes

    --collection=s Photos from collection

    --daily        Daily photo
    --weekly       Weekly photo
";
    print LOCALCOLOR CYAN "
Additional information:
    Options above are seperated by groups, no groups can be mixed. If
    you pass options from multiple groups then expect unexpected
    results.

    - user & search option can be passed with daily or weekly.
    - resolution can be passed with any group, it will be ignored if
      not applicable.
";
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

if ( $options{debug} ) {
    require Data::Printer;
    Data::Printer->import;
    p($response);
}

die "Unexpected response\n"
    unless $response->{status} == 302;

# Unveil $PATH.
foreach my $path ( split(/:/, $ENV{PATH}) ) {
    unveil( $path, "rx" )
        or die "Unable to unveil: $!\n";
}

run3 ["feh", "--bg-fill", "$response->{headers}{location}"];

# Block further unveil calls.
unveil()
    or die "Unable to lock unveil: $!\n";
