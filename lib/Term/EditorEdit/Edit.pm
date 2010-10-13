package Term::EditorEdit::Edit;

use strict;
use warnings;

use Any::Moose;
use Text::Clip;
use Try::Tiny;

our $EDITOR = 'Term::EditorEdit';
our $RETRY = "__Term_EditorEdit_retry__\n";
our $Test_edit;

#has editor => qw/ is ro required 1 weak_ref 1 /;
has process => qw/ is ro isa Maybe[CodeRef] /;
has separator => qw/ is rw /;
has tmp => qw/ is ro required 1 /;

has document => qw/ is rw isa Str required 1 /;
has $_ => reader => $_, writer => "_$_", isa => 'Str' for qw/ initial_document /;

has preamble => qw/ is rw isa Maybe[Str] /;
has $_ => reader => $_, writer => "_$_", isa => 'Maybe[Str]' for qw/ initial_preamble /;

has content => qw/ is rw isa Str /;
has $_ => reader => $_, writer => "_$_", isa => 'Str' for qw/ initial_content /;

sub BUILD {
    my $self = shift;

    my $document = $self->document;
    $self->_initial_document( $document );

    my ( $preamble, $content ) = $self->split( $document );

    $self->preamble( $preamble );
    $self->_initial_preamble( $preamble );

    $self->content( $content );
    $self->_initial_content( $content );
}

sub edit {
    my $self = shift;

    my $tmp = $self->tmp;
    $tmp->autoflush( 1 );
    
    while ( 1 ) {
        $tmp->seek( 0, 0 ) or die "Unable to seek on tmp ($tmp): $!";
        $tmp->truncate( 0 ) or die "Unable to truncate on tmp ($tmp): $!";
        $tmp->print( $self->join( $self->preamble, $self->content ) );

        if ( $Test_edit ) {
            $Test_edit->( $tmp );
        }
        else {
            $EDITOR->edit_file( $tmp->filename );
        }

        my $document;
        if ( 1 ) { # I think this is safer?
            my $tmpr = IO::File->new( $tmp->filename, 'r' );
            $document = join '', <$tmpr>;
            $tmpr->close;
            undef $tmpr;
        }
        else {
            $tmp->seek( 0, 0 ) or die "Unable to seek on tmp ($tmp): $!";
            $document = join '', <$tmp>;
        }

        $self->document( $document );
        my ( $preamble, $content ) = $self->split( $document );
        $self->preamble( $preamble );
        $self->content( $content );

        if ( my $process = $self->process ) {
            my ( @result, $retry );
            try {
                @result = $process->( $self );
            }
            catch {
                die $_ unless $_ eq $RETRY;
                $retry = 1;
            };

            next if $retry;

            return $result[0] if defined $result[0];
        }

        return $content;
    }
    
}

sub first_line_blank {
    my $self = shift;
    return $self->document =~ m/\A\s*$/m;
}
sub line0_blank { return $_[0]->first_line_blank }

sub preamble_from_initial {
    my $self = shift;
    my @preamble;
    for my $part ( "$_[0]", $self->initial_preamble ) {
        next unless defined $part;
        chomp $part;
        push @preamble, $part;
    }
    $self->preamble( join "\n", @preamble, '' ) if @preamble;
}

sub retry {
    my $self = shift;
    die $RETRY;
}

sub split {
    my $self = shift;
    my $document = shift;

    return ( undef, $document ) unless my $separator = $self->separator;

    die "Invalid separator ($separator)" if ref $separator;

    if ( my $mark = Text::Clip->new( data => $document )->find( qr/^\s*$separator\s*$/m ) ) {
        return ( $mark->preceding, $mark->remaining );
    }

    return ( undef, $document );
}

sub join {
    my $self = shift;
    my $preamble = shift;
    my $content = shift;

    return $content unless defined $preamble;
    chomp $preamble;

    my $separator = $self->separator;
    unless ( defined $separator ) {
        return $content unless length $preamble;
        return join "\n", $preamble, $content;
    }
    return join "\n", $separator, $content unless length $preamble;
    return join "\n", $preamble, $separator, $content;
}

1;
