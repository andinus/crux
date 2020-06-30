#!/usr/bin/perl

package UnsplashSource;

use strict;
use warnings;

use URI;
use HTTP::Tiny;
use Carp qw( croak carp );

my $api = "https://source.unsplash.com";
my $http = HTTP::Tiny->new(
    agent => "crux - UnsplashSource.pm - HTTP::Tiny",
    max_redirect => 0,
    verify_SSL => 1,
    timeout => 60,

);

sub get {
    my ( %options ) = @_;

    if ( $options{daily} or $options{weekly} ) {
        return fixed( %options );
    } elsif ( $options{user} ) {
        return user_random( %options );
    } elsif ( ( scalar @{$options{search}} > 0 )
                  or $options{featured} ) {
        return random_search( %options );
    } elsif ( $options{collection_id} ) {
        return collection( %options );
    } else {
        return get_random( %options );
    }
}

sub get_random {
    my ( %options ) = @_;
    my $url = "$api/random/$options{resolution}";
    return $http->head($url);
}

sub random_search {
    my ( %options ) = @_;

    my $url = URI->new($api);

    my @segments;
    push @segments, "featured" if $options{featured};
    push @segments, $options{resolution};
    $url->path_segments( @segments );

    $url->query_keywords( join(',', @{$options{search}}) );

    return $http->head($url);
}

sub user_random {
    my ( %options ) = @_;

    my $url = URI->new($api);

    my @segments;
    push @segments, "user";
    push @segments, $options{user};
    push @segments, "likes" if $options{user_likes};
    push @segments, $options{resolution};
    $url->path_segments( @segments );

    return $http->head($url);
}

sub collection {
    my ( %options ) = @_;
    my $url = "$api/collection/$options{collection_id}/";
    $url .= $options{resolution};
    return $http->head($url);
}

sub fixed {
    my ( %options ) = @_;

    croak "Cannot use daily & weekly together"
        if $options{daily} and $options{weekly};

    my $url = URI->new($api);

    my @segments;
    push @segments, "user/$options{user}" if $options{user};
    push @segments, "daily" if $options{daily};
    push @segments, "weekly" if $options{weekly};
    $url->path_segments( @segments );

    $url->query_keywords( join(',', @{$options{search}}) );

    return $http->head($url);
}

1;
