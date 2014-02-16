#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.014000;
use autodie;

use Time::Piece;
use XML::Simple;
use Encode::UTF8Mac;
use Cache::FileCache;

use MacOSX::App::Mail::API;

sub get_candidates {
    my $keywords = shift;
    my $api      = shift;
    my @items    = [];
    my $filter = pop @$keywords;

    if ( $filter =~ /^is:/ ) {
        my $keyword = $';
        my @candidates = ( 'unread', 'read', 'starred' );

        for my $candidate (@candidates) {
            if ( $keyword eq '' or $candidate =~ /^$keyword/i ) {
                my $autocomplete_string = $#$keywords == -1 ? "is:$candidate " : " is:$candidate ";
                push @items,
                    {
                    valid        => 'no',
                    autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                    title        => ["is:$candidate"],
                    subtitle     => ["Search for messages that are $candidate."],
                    icon         => ['icon.png']
                    };
            }
        }
    }
    elsif ( $filter =~ /^(from|to):/ ) {
        my $operator = $&;
        my $keyword         = $';
        my $candidates    = $api->get_addresses($keyword);
        my $candidate_num = @$candidates;
        my $index         = 0;

        for my $candidate (@$candidates) {
            $index++;
            my $address             = $candidate->{address};
            my $sender              = $candidate->{comment} ? Encode::decode( 'utf-8-mac', $candidate->{comment} ) : '';
            my $autocomplete_string = $#$keywords == -1 ? "$operator$address " : " $operator$address ";
            my $title
                = $sender eq ''
                ? $address
                : "$sender <$address>";

            push @items,
                {
                valid        => 'no',
                autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                title        => ["$operator$title"],
                subtitle     => ["Used to specify the sender. ($index/$candidate_num)"],
                icon         => ['icon.png']
                };
        }
    }
    elsif ( $filter =~ /^subject:/ ) {
        my $keyword         = $';
        my $candidates    = $api->get_subjects($keyword);
        my $candidate_num = @$candidates;
        my $index         = 0;

        for my $candidate (@$candidates) {
            $index++;
            my $subject = Encode::decode( 'utf-8-mac', $candidate->{subject} );
            my $autocomplete_string = $#$keywords == -1 ? "subject:$subject " : " subject:$subject ";

            push @items,
                {
                valid        => 'no',
                autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                title        => ["subject:$subject"],
                subtitle     => ["Search for words in the subject line. ($index/$candidate_num)"],
                icon         => ['icon.png']
                };
        }
    }

    # Output a notification if no items.
    if ( $#items == 0 ) {
        @items = {
            valid    => 'no',
            title    => ['Did not match any emails.'],
            subtitle => ['Try different keywords.'],
            icon     => ['icon.png']
        };
    }

    return XML::Simple::XMLout(
        { item => \@items },
        RootName      => 'items',
        NoSort        => 1,
        NumericEscape => 2,
        XMLDecl       => "<?xml version='1.0' standalone='yes'?>"
    );
}

sub get_items {
    my ( $messages, $keyword ) = @_;

    # Sort by sent date.
    my @items = sort { $b->{date_sent} <=> $a->{date_sent} } @$messages;

    # Itemization for Alfred.
    my $item_num = @items;
    my $index    = 0;
    for my $item (@items) {
        $index++;
        my $account_name = Encode::decode( 'utf-8-mac', $item->{account_name} );
        my $mailbox      = Encode::decode( 'utf-8-mac', $item->{mailbox} );
        my $subject = $item->{subject} ? Encode::decode( 'utf-8-mac', $item->{subject} ) : 'NO TITLE';
        my $sender  = $item->{sender}  ? Encode::decode( 'utf-8-mac', $item->{sender} )  : '';
        $item = {
            arg      => "${account_name}:::${mailbox}:::$item->{id}",
            title    => [$subject],
            subtitle => [
                $item->{sender} eq ''
                ? Time::Piece->strptime( $item->{date_sent}, '%s' ) . " - $item->{sender_address} ($index/$item_num)"
                : Time::Piece->strptime( $item->{date_sent}, '%s' )
                    . " - $sender <$item->{sender_address}> ($index/$item_num)"
            ],
            icon => ['icon.png']
        };
    }

    # Output a notification if no items.
    if ( $item_num == 0 ) {
        if ( join( '', @$keyword ) eq 'is:unread' ) {
            @items = {
                valid    => 'no',
                title    => ['No unread emails.'],
                subtitle => ['Good job!'],
                icon     => ['icon.png']
            };
        }
        else {
            @items = {
                valid    => 'no',
                title    => ['Did not match any emails.'],
                subtitle => ['Try different keywords.'],
                icon     => ['icon.png']
            };
        }
    }

    return XML::Simple::XMLout(
        { item => \@items },
        RootName      => 'items',
        NoSort        => 1,
        NumericEscape => 2,
        XMLDecl       => "<?xml version='1.0' standalone='yes'?>"
    );
}

# Arguments required.
if ( !defined( $ARGV[0] ) ) {
    exit;
}

my $argv = $ARGV[0];
my $completion = $argv !~ /\s+$/ ? 1 : 0;
my @keywords = map { Encode::decode( 'utf-8-mac', $_ ) } split( /\s/, $argv =~ s/\\\s*$//r );

my $api = MacOSX::App::Mail::API->new;

my $cache = Cache::FileCache->new(
    {   cache_root         => '/tmp',
        namespace          => 'AlfredWorkflowMailSearcher',
        default_expires_in => '5minutes',
        auto_purge_on_set  => 1,
        auto_purge_on_get  => 1,
    }
);

# Try to fetch the data from the cache.
my $cache_data = $cache->get($argv);

if ( defined($cache_data) ) {
    print $cache_data;
}
else {
    # Advanced search operator completion.
    if ( $keywords[$#keywords] =~ /^(is|from|to|subject):/ and $completion ) {
        my $candidates = get_candidates( \@keywords, $api );
        print $candidates;
        $cache->set( $argv, $candidates );
    }
    else {
        my $result = $api->search(@keywords);
        my $items = get_items( $result, \@keywords );
        print $items;
        $cache->set( $argv, $items );
    }
}

$api->disconnect;

