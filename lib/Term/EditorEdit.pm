package Term::EditorEdit;

# document, content
# header, header_separator
# prompt_Yn, prompt_yN

use strict;
use warnings;

use Any::Moose;
use Carp;
use File::Temp;

sub EDITOR {
    return $ENV{VISUAL} || $ENV{EDITOR};
}

sub _edit_file {
    my $self = shift;
    my $file = shift;
    die "Missing editor" unless my $editor = $self->EDITOR;
    my $rc = system $editor, $file;
    unless ( $rc == 0 ) {
        my ($exit_value, $signal, $core_dump);
        $exit_value = $? >> 8;
        $signal = $? & 127;
        $core_dump = $? & 128;
        die "Error during edit ($editor): exit value($exit_value), signal($signal), core_dump($core_dump): $!";
    }
}

sub edit {
    my $self = shift;
    my %given;
    if ( ref $_[0] eq 'HASH' ) { %given = %{ &shift } }
    else {
        $given{content} = pop;
        $given{process} = shift if @_ && ref $_[0] eq 'CODE';
    }
    carp "Ignoring remaining arguments: @_" if @_;

    my $content = $given{content};
    $content = '' unless defined $content;

    my $tmp = $self->tmp;
    $tmp->print( $content );
    $tmp->autoflush( 1 );
    $self->_edit_file( $tmp->filename );
    $tmp->seek( 0, 0 ) or die "Unable to seek on tmp ($tmp): $!";

    {
        local $/;
        $content = <$tmp>;
    }

    return $content unless $given{process};

    return $content unless $given{process};

    
    
}

sub tmp { return File::Temp->new( unlink => 1 ) }

__END__

use Path::Class qw/ dir /;
use String::Util qw/ :all /;
use File::Temp;
use Text::Split;

sub file {
    return File::Temp->new;
}

sub _edit_file {
    my $file = shift;
    die "Don't know what editor" unless my $editor = _editor;
    my $rc = system @$editor, $file;
    unless ( $rc == 0 ) {
        my ($exit_value, $signal, $core_dump);
        $exit_value = $? >> 8;
        $signal = $? & 127;
        $core_dump = $? & 128;
        die "Error during edit (@$editor): exit value($exit_value), signal($signal), core_dump($core_dump): $!";
    }
}

sub edit {
    my $self = shift;
    my %given;
    if ( ref $_[0] eq 'HASH' ) { %given = %{ $_[0] } }
    else {
        my $content = pop;
        my ( @header ) = @_;
        @given{qw/ content header /} = ( $content, \@header );
    }

    my ( $content ) = map { defined $_ ? $_ : ''  } @given{qw/ content /};
    my $header = $given{header} || [];
    $header = [ map { split m/\n+/, $_ } @$header ];

#    my @signature = ( time, ( $operation ? $operation : () ) );
#
#    $workfl = $workdr->file( join '.', 'data', @signature );
#    $workfl->openw->print(
#        join "\n",
#        ( map { join ' ', '#', $_ } "> $operation", @$header),
#        $content,
#    );

    my $file = $self->file
    $file->print(
        join "\n",
        ( map { join ' ', '#', $_ } @$header ),
        $content,
    );

EDIT:
    while ( 1 ) {

        _edit_file $file;

        my ( $gt, @header, @content );
        
        @content = $workfl->slurp;

        unless ( $content[0] =~ m/\S/ ) {
            while ( 1 ) {
                print "Do you want to re-edit or abort? [E/a] ";
                my $input = <STDIN>;
                if ( $input =~ m/^\s*e(?:d(?:i(?:t)?)?)?\s*$/i ) {
                    next EDIT;
                }
                elsif ( $input =~ m/^\s*a(?:b(?:o(?:r(?:t)?)?)?)?\s*$/i ) {
                    exit 0;
                }
            }
        }

        my $content = join '', @content;
        my $split = Text::Split->new( data => $content );
        if ( $split = $split->find( qr/^[ \t]*(?!#)/m ) ) {
            @header = $split->slurp( '[]/' );
            $content = $split->remaining;
        }
        if ( $header[0] ) {
            ( $gt ) = $header[0] =~ m/\s*#\s*([\w\-\?\>]+)/;
        }
        return $content;
    }
}

1;
