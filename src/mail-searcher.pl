#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;

use Time::Piece;
use XML::Simple;
use Encode::UTF8Mac;

use MacOSX::App::Mail::API;

sub get_candidates {
    my $keywords = shift;
    my $api      = shift;
    my @items    = [];
    my $operator = pop @$keywords;

    if ( $operator =~ /^is:/ ) {
        my $input = $';
        my @candidates = ( 'unread', 'read', 'starred' );

        for my $candidate (@candidates) {
            if ( $input eq '' or $candidate =~ /^$input/i ) {
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
    elsif ( $operator =~ /^from:/ ) {
        my $input         = $';
        my $candidates    = $api->get_addresses($input);
        my $candidate_num = @$candidates;
        my $index         = 0;

        for my $candidate (@$candidates) {
            $index++;
            my $autocomplete_string
                = $#$keywords == -1 ? "from:$candidate->{address} " : " from:$candidate->{address} ";
            my $title
                = $candidate->{comment} eq ''
                ? $candidate->{address}
                : "$candidate->{comment} <$candidate->{address}>";

            push @items,
                {
                valid        => 'no',
                autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                title        => ["from:$title"],
                subtitle     => ["Used to specify the sender. ($index/$candidate_num)"],
                icon         => ['icon.png']
                };
        }
    }
    elsif ( $operator =~ /^to:/ ) {
        my $input         = $';
        my $candidates    = $api->get_addresses($input);
        my $candidate_num = @$candidates;
        my $index         = 0;

        for my $candidate (@$candidates) {
            $index++;
            my $autocomplete_string = $#$keywords == -1 ? "to:$candidate->{address} " : " to:$candidate->{address} ";
            my $title
                = $candidate->{comment} eq ''
                ? $candidate->{address}
                : "$candidate->{comment} <$candidate->{address}>";

            push @items,
                {
                valid        => 'no',
                autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                title        => ["to:$title"],
                subtitle     => ["Used to specify the recipient. ($index/$candidate_num)"],
                icon         => ['icon.png']
                };
        }
    }
    elsif ( $operator =~ /^subject:/ ) {
        my $input         = $';
        my $candidates    = $api->get_subjects($input);
        my $candidate_num = @$candidates;
        my $index         = 0;

        for my $candidate (@$candidates) {
            $index++;
            my $autocomplete_string
                = $#$keywords == -1 ? "subject:$candidate->{subject} " : " subject:$candidate->{subject} ";

            push @items,
                {
                valid        => 'no',
                autocomplete => join( ' ', @$keywords ) . $autocomplete_string,
                title        => ["subject:$candidate->{subject}"],
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

    print XML::Simple::XMLout(
        { item => \@items },
        RootName      => 'items',
        NoSort        => 1,
        NumericEscape => 2,
        XMLDecl       => "<?xml version='1.0' standalone='yes'?>"
    );
}

sub output_items {
    my ( $messages, $keyword ) = @_;

    # Sort by sent date.
    my @items = sort { $b->{date_sent} <=> $a->{date_sent} } @$messages;

    # Itemization for Alfred.
    my $item_num = @items;
    my $index    = 0;
    for my $item (@items) {
        $index++;
        $item = {
            arg      => "$item->{account_name}:::$item->{mailbox}:::$item->{id}",
            title    => [ $item->{subject} ? $item->{subject} : 'NO TITLE' ],
            subtitle => $item->{sender} eq ''
            ? [ Time::Piece->strptime( $item->{date_sent}, '%s' ) . " - $item->{sender_address} ($index/$item_num)" ]
            : [ Time::Piece->strptime( $item->{date_sent}, '%s' )
                    . " - $item->{sender} <$item->{sender_address}> ($index/$item_num)"
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

    print XML::Simple::XMLout(
        { item => \@items },
        RootName      => 'items',
        NoSort        => 1,
        NumericEscape => 2,
        XMLDecl       => "<?xml version='1.0' standalone='yes'?>"
    );
}

my $api = MacOSX::App::Mail::API->new;

my $argv = $ARGV[0];
my @keywords = map { Encode::decode( 'utf-8-mac', $_ ) } split( /\\\s/, $argv );

# Filter completion.
if ( $keywords[$#keywords] =~ /^(is|from|to|subject):/ and $argv !~ /\s+$/ ) {
    get_candidates( \@keywords, $api );
}
elsif (@keywords) {
    my $result = $api->search(@keywords);
    output_items( $result, \@keywords );
}

$api->disconnect;

