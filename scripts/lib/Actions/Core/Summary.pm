package Actions::Core::Summary;

use 5.8.5;
use utf8;
use warnings;
use strict;

sub new {
    my $class = shift;
    my %args = @_;
    my $self  = bless {}, $class;

    return $self;
}

sub filepath {
    my $self = shift;
    if ($self->{filepath}) {
        return $self->{filepath};
    }

    my $filepath = $ENV{GITHUB_STEP_SUMMARY}
        or die "Unable to find environment variable for \$GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries.";
    if (!(-f $filepath && -w $filepath)) {
        die "Unable to access summary file: '$filepath'. Check if the file has correct read/write permissions.";
    }

    $self->{filepath} = $filepath;
    return $filepath;
}

1;
