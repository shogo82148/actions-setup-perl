package Actions::Core::Summary;

use 5.8.5;
use utf8;
use warnings;
use strict;

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
    $self->{buffer} .= $text . $\;
    return $self;
}

sub write {
    my $self = shift;
    my $filepath = $self->filepath();
    open my $fh, ">", $filepath or croak "failed to open $filepath: $!";
    # TODO: implement me
    close $fh or croak "failed to close";
}

1;
