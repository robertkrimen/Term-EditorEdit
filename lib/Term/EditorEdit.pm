package Term::EditorEdit;
# ABSTRACT: Edit a document via an $EDITOR

=head1 SYNOPSIS

    use Term::EditorEdit;
    
    # $VISUAL or $EDITOR is invoked
    $document = Term::EditorEdit->edit( document => <<_END_ );
    Apple
    Banana
    Cherry
    _END_

With post-processing:

    $document = Term::EditorEdit->edit( document => $document, process => sub {
        my $edit = shift;
        my $document = $edit->document;
        if ( document_is_invalid ) {
            # The argument to retry inserted at the top of the document
            # The retry method will return immediately
            $edit->retry( "# Hey user, fix it!" )
        }
        # Whatever is returned from the processor will be returned via ->edit
        return $document;
    } )
    Apple
    Banana
    Cherry
    _END_
    
=cut

# Retry should not take an argument... or...

# ->retry( premable => ... )
# ->retry( print => ... )
# prompt_Yn, prompt_yN

use strict;
use warnings;

use Any::Moose;
use Carp;
use File::Temp;
use Term::EditorEdit::Edit;

sub EDITOR {
    return $ENV{VISUAL} || $ENV{EDITOR};
}

our $__singleton__;
sub __singleton__ {
    return $__singleton__ ||=__PACKAGE__->new;
}

sub edit_file {
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
    $self = $self->__singleton__ unless blessed $self;
    my %given = @_;
    # carp "Ignoring remaining arguments: @_" if @_;

    my $document = delete $given{document};
    $document = '' unless defined $document;

    my $tmp = $self->tmp;

    my $edit = Term::EditorEdit::Edit->new(
        editor => $self,
        tmp => $tmp,
        document => $document,
        %given, # process, split, ...
    ); 

    return $edit->edit;
}

sub tmp { return File::Temp->new( unlink => 1 ) }

1;
