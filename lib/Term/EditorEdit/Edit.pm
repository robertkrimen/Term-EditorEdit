package Term::EditorEdit::Edit;

use strict;
use warnings;

use Any::Moose;
use Text::Clip;
use Try::Tiny;

our $EDITOR = 'Term::EditorEdit';
our $RETRY = "__Term_EditorEdit_retry__\n";

#has editor => qw/ is ro required 1 weak_ref 1 /;
has tmp => qw/ is ro required 1 /;
has document => qw/ is rw isa Str required 1 /;
has process => qw/ is ro isa Maybe[CodeRef] /;
has split => qw/ accessor separator /;

has [qw/ preamble preamble0 /] => qw/ is rw isa Maybe[Str] /;
has [qw/ content content0 /] => qw/ is rw isa Str /;

sub BUILD {
    my $self = shift;

    my ( $preamble, $content ) = $self->split( $self->document );
    $self->preamble( $preamble );
    $self->preamble0( $preamble );
    $self->content( $content );
    $self->content0( $content );
}

sub edit {
    my $self = shift;

    my $tmp = $self->tmp;
    $tmp->autoflush( 1 );
    
    while ( 1 ) {
        $tmp->seek( 0, 0 ) or die "Unable to seek on tmp ($tmp): $!";
        $tmp->truncate( 0 ) or die "Unable to truncate on tmp ($tmp): $!";
        $tmp->print( $self->join( $self->preamble, $self->content ) );

        $EDITOR->edit_file( $tmp->filename );

        $tmp->seek( 0, 0 ) or die "Unable to seek on tmp ($tmp): $!";
        my $document = join '', <$tmp>;
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

sub retry {
    my $self = shift;
    if ( defined $_[0] ) {
        my $preamble = $_[0];
        chomp $preamble;
        $self->preamble( join "\n", $preamble, map { defined $_ ? $_ : '' } $self->preamble0 );
    }
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
    return join "\n", $preamble, $content unless my $separator = $self->separator;
    return join "\n", $preamble, $separator, $content;
}

1;
