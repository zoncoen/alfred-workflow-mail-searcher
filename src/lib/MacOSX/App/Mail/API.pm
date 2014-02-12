package MacOSX::App::Mail::API;
our $VERSION = '0.01';

use strict;
use warnings;
use utf8;
use 5.010000;

use Carp;
use DBI;
use URI::URL;
use URI::Escape;
use Encode::UTF8Mac;
use Mac::PropertyList qw/ :all /;

sub new {
    my $class = shift;
    my $filename = @_ == 1 ? $_[0] : $ENV{"HOME"} . "/Library/Mail/V2/MailData/Envelope\ Index";

    my $self = bless { data_file => $filename, }, $class;

    $self->connect;
    return $self;
}

sub connect {
    my $self = shift;
    $self->{dbh} = DBI->connect("dbi:SQLite:dbname=$self->{data_file}")
        or Carp::croak "Can not connect to database: " . DBI->errstr;
}

sub disconnect {
    my $self = shift;
    $self->{dbh}->disconnect
        or Carp::croak "Can not disconnect to database: " . DBI->errstr;
}

sub _prepare {
    my ( $self, $sql ) = @_;
    return $self->{dbh}->prepare($sql)
        or Carp::Croak( "Can not prepare statement: " . DBI->errstr );
}

sub _execute {
    my $self = shift;
    my $sth  = shift;
    my @bind = @_;
    if ( @bind == 0 ) {
        return $sth->execute()
            or Carp::Croak( "Can not prepare statement: " . DBI->errstr );
    }
    else {
        return $sth->execute(@bind)
            or Carp::Croak( "Can not prepare statement: " . DBI->errstr );
    }
}

sub _create_where_clause {
    my $self     = shift;
    my @keywords = @_;
    my @where    = ();

    foreach my $keyword (@keywords) {
        if ( $keyword =~ /^from:/ ) {
            $keyword = $self->{dbh}->quote( "%" . $' . "%" );
            push( @where,
                "( sender IN ( SELECT ROWID from addresses WHERE address LIKE $keyword OR comment LIKE $keyword ) )" );
        }
        elsif ( $keyword =~ /^to:/ ) {
            $keyword = $self->{dbh}->quote( "%" . $' . "%" );
            push( @where,
                "( ROWID IN ( SELECT message_id FROM recipients WHERE address_id IN ( SELECT ROWID from addresses WHERE address LIKE $keyword OR comment LIKE $keyword ) ) )"
            );
        }
        elsif ( $keyword =~ /^subject:/ ) {
            $keyword = $self->{dbh}->quote( "%" . $' . "%" );
            push( @where, "( subject IN ( SELECT ROWID from subjects WHERE subject LIKE $keyword ) )" );
        }
        elsif ( $keyword =~ /^is:/ ) {
            if ( $' =~ /^unread$/ ) {
                push( @where, "read = '0'" );
            }
            elsif ( $' =~ /^read$/ ) {
                push( @where, "read = '1'" );
            }
            elsif ( $' =~ /^starred$/ ) {
                push( @where, "flagged = '1'" );
            }
        }
        else {
            $keyword = $self->{dbh}->quote( "%" . $keyword . "%" );
            push( @where,
                "( snippet LIKE $keyword OR subject IN ( SELECT ROWID from subjects WHERE subject LIKE $keyword ))" );
        }
    }
    return @where;
}

sub _get_value {
    my ( $self, $result ) = @_;

    my $subject = $self->_prepare("SELECT subject FROM subjects WHERE ROWID = ?");
    my $sender  = $self->_prepare("SELECT address, comment FROM addresses WHERE ROWID = ?");
    my $reciever
        = $self->_prepare(
        "SELECT address, comment FROM addresses WHERE ROWID = (SELECT address_id FROM recipients WHERE message_id = ?)"
        );
    my $url = $self->_prepare("SELECT url FROM mailboxes WHERE ROWID = ?");

    my $accounts
        = parse_plist_file( $ENV{"HOME"} . '/Library/Mail/V2/MailData/Accounts.plist' )->as_perl->{MailAccounts};

    my @messages = ();
    while ( my $row = $result->fetch() ) {
        $self->_execute( $subject,  $row->[1] );
        $self->_execute( $sender,   $row->[3] );
        $self->_execute( $reciever, $row->[0] );
        $self->_execute( $url,      $row->[5] );

        my $subject_array  = $subject->fetch();
        my $sender_array   = $sender->fetch();
        my $reciever_array = $reciever->fetch();
        my $url_array      = $url->fetch();

        my $url          = URI::URL->new( $url_array->[0] );
        my $account_uri  = $url->netloc;
        my $account_name = '';

        # Get account name from Accounts.plist.
        for my $account (@$accounts) {
            if ( $account->{AccountPath} =~ /$account_uri/ ) {
                $account_name = $account->{AccountName};
            }
        }

        push @messages,
            {
            id               => $row->[0],
            subject          => $subject_array->[0],
            snippet          => $row->[2],
            sender_address   => $sender_array->[0],
            sender           => $sender_array->[1],
            reciever_address => $reciever_array->[0],
            reciever         => $reciever_array->[1],
            date_sent        => $row->[4],
            account_uri      => $account_uri,
            account_name     => $account_name,
            mailbox          => uri_unescape( substr( $url->path, 1 ) ),
            };
    }
    return \@messages;
}

sub get_addresses {
    my $self      = shift;
    my $input     = shift;
    my @addresses = ();

    $input = $self->{dbh}->quote( "%" . $input . "%" );
    my $addresses
        = $self->_prepare("SELECT address, comment FROM addresses WHERE address LIKE $input OR comment LIKE $input");
    $self->_execute($addresses);

    while ( my $row = $addresses->fetch() ) {
        push @addresses,
            {
            address => $row->[0],
            comment => Encode::decode( 'utf-8-mac', $row->[1] ),
            };
    }

    return \@addresses;
}

sub get_subjects {
    my $self     = shift;
    my $input    = shift;
    my @subjects = ();

    $input = $self->{dbh}->quote( "%" . $input . "%" );
    my $subjects = $self->_prepare("SELECT subject FROM subjects WHERE subject LIKE $input");
    $self->_execute($subjects);

    while ( my $row = $subjects->fetch() ) {
        push @subjects, { subject => Encode::decode( 'utf-8-mac', $row->[0] ), };
    }

    return \@subjects;
}

sub search {
    my $self     = shift;
    my @keywords = @_;
    my $messages = [];

    if (@keywords) {
        my $pattern = join( " AND ", $self->_create_where_clause(@keywords) );
        $pattern = 'WHERE ' . $pattern if $pattern;

        my $result
            = $self->_prepare("SELECT ROWID, subject, snippet, sender, date_sent, mailbox FROM messages $pattern");
        $self->_execute($result);
        $messages = $self->_get_value($result);
    }
    return $messages;
}

