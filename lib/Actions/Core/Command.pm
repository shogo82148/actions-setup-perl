package Actions::Core::Command;

use 5.8.5;
use utf8;
use warnings;
use strict;

use IO::Handle;
use Encode qw(encode_utf8);

use Exporter 'import';
our @EXPORT_OK = qw(issue_command issue);

sub issue_command {
    my $cmd = Actions::Core::Command->new(@_);
    print encode_utf8("$cmd\n");
    STDOUT->flush();
}

sub issue {
    my ($command, $message) = @_;
    issue_command($command, {}, $message);
}

use Actions::Core::Utils qw(to_command_value);
use constant CMD_STRING => "::";
use overload '""' => \&stringify;

sub new {
    my ($class, $command, $properties, $message) = @_;
    $command ||= "missing.command";
    return bless {
        command => $command,
        properties => $properties,
        message => $message,
    }, $class;
}

sub command {
    my $self = shift;
    return $self->{command};
}

sub properties {
    my $self = shift;
    return $self->{properties};
}

sub message {
    my $self = shift;
    return $self->{message};
}

sub stringify {
    my $self = shift;
    my $cmdstr = CMD_STRING . $self->command;

    my $properties = $self->properties;
    if ($properties && scalar(keys %$properties) > 0) {
        $cmdstr .= " ";
        my $first = 1;
        for my $key (sort keys %$properties) {
            my $val = $properties->{$key} or continue;
            if ($first) {
                $first = 0;
            } else {
                $cmdstr .= ",";
            }
            $cmdstr .= $key . "=" . escape_property($val);
        }
    }

    $cmdstr .= CMD_STRING . escape_data($self->message);
    return $cmdstr;
}

sub escape_data {
    my $s = shift;
    $s = to_command_value($s);
    $s =~ s/%/%25/g;
    $s =~ s/\r/%0D/g;
    $s =~ s/\n/%0A/g;
    return $s;
}

sub escape_property {
    my $s = shift;
    $s = to_command_value($s);
    $s =~ s/%/%25/g;
    $s =~ s/\r/%0D/g;
    $s =~ s/\n/%0A/g;
    $s =~ s/:/%3A/g;
    $s =~ s/,/%2C/g;
    return $s;
}

1;
