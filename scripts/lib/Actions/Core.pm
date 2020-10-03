package Actions::Core;

use 5.8.5;
use utf8;
use warnings;
use strict;

use Exporter 'import';
our @EXPORT = qw(export_variable add_secret add_path get_input set_output set_command_echo set_failed is_debug debug error warning info start_group end_group group);

use IO::Handle;
use Carp 'croak';
use Actions::Core::Utils qw(to_command_value);
use Actions::Core::Command qw(issue_command issue);
use Actions::Core::FileCommand qw();

sub export_variable {
    my ($name, $val) = @_;
    my $coverted_val = to_command_value($val);

    $ENV{$name} = $coverted_val;
    my $delimiter = '_GitHubActionsFileCommandDelimeter_';
    my $value = "$name<<$delimiter\n$coverted_val\n$delimiter";
    Actions::Core::FileCommand::issue_command("ENV", $value);
}

sub add_secret {
    my ($secret) = @_;
    issue_command('add-mask', {}, $secret);
}

sub add_path {
    my ($path) = @_;
    my $del = ":";
    if ($^O eq "MSWin32") {
        $del = ";";
    }
    $ENV{PATH} = $path . $del . $ENV{PATH};
    Actions::Core::FileCommand::issue_command("PATH", $path);
}

sub get_input {
    my ($name, $options) = @_;
    $name =~ s/ /_/g;
    $name = uc $name;
    my $val = $ENV{"INPUT_$name"} || "";
    if ($options && $options->{required} && !$val) {
        croak "Input required and not supplied: ${name}";
    }
    $val =~ s/\A\s*(.*?)\s*\z/$1/;
    return $val;
}

sub set_output {
    my ($name, $value) = @_;
    issue_command('set-output', { name => $name}, $value);
}

sub set_command_echo {
    my ($enabled) = @_;
    issue('echo', $enabled ? 'on' : 'off');
}

my $exit_code = 0;

END {
    # override the exit code
    $? = 1 if $? == 0 && $exit_code != 0;
}

sub set_failed {
    my ($message) = @_;
    $exit_code = 1;
    issue('error', $message);
}

sub is_debug {
    return ($ENV{RUNNER_DEBUG} || '') eq '1';
}

sub debug {
    my ($message) = @_;
    issue('debug', $message);
}

sub error {
    my ($message) = @_;
    issue('error', $message);
}

sub warning {
    my ($message) = @_;
    issue('warning', $message);
}

sub info {
    my ($message) = @_;
    print STDOUT "$message\n";
    STDOUT->flush();
}

sub start_group {
    my ($name) = @_;
    issue('group', $name);
}

sub end_group {
    issue('endgroup');
}

sub group {
    my ($name, $sub) = @_;
    my $wantarray = wantarray;
    my @ret;
    my $failed = not eval {
        start_group($name);
        if ($wantarray) {
            @ret = $sub->();
        } elsif (defined $wantarray) {
            $ret[0] = $sub->();
        } else {
            $sub->();
        }
        return 1;
    };
    my $err = $@;
    end_group();
    die $err if $failed;
    return $wantarray ? @ret : $ret[0];
}

1;
