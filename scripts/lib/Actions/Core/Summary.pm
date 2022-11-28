package Actions::Core::Summary;

use 5.8.5;
use utf8;
use warnings;
use strict;

use Encode qw(encode_utf8 decode_utf8);
use Carp qw(croak);

sub new {
    my $class = shift;
    my %args = @_;
    my $self  = bless {}, $class;

    $self->{buffer} = "";
    return $self;
}

sub filepath {
    my $self = shift;
    if ($self->{filepath}) {
        return $self->{filepath};
    }

    my $filepath = $ENV{GITHUB_STEP_SUMMARY}
        or croak "Unable to find environment variable for \$GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries.";
    if (!(-f $filepath && -w $filepath)) {
        croak "Unable to access summary file: '$filepath'. Check if the file has correct read/write permissions.";
    }

    $self->{filepath} = $filepath;
    return $filepath;
}

sub add_raw {
    my $self = shift;
    my ($text, $eol) = @_;
    $self->{buffer} .= $text;
    if ($eol && $/) {
        $self->{buffer} .= $/;
    }
    return $self;
}

sub write {
    my ($self, %args) = @_;
    my $filepath = $self->filepath();
    my $mode = $args{overwrite} ? ">" : ">>";
    open my $fh, $mode, $filepath or croak "failed to open $filepath: $!";
    $fh->print(encode_utf8($self->{buffer}));
    close $fh or croak "failed to close";
    return $self->empty_buffer;
}

sub is_empty_buffer {
    my $self = shift;
    return $self->{buffer} eq '';
}

sub empty_buffer {
    my $self = shift;
    $self->{buffer} = '';
    return $self;
}


1;
