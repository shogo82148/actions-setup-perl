package Actions::Core::FileCommand;

use 5.8.5;
use utf8;
use warnings;
use strict;

use IO::Handle;
use Encode qw(encode_utf8);
use Actions::Core::Utils qw(to_command_value);

use Exporter 'import';
our @EXPORT_OK = qw(issue_command prepare_key_value_message);

sub issue_command {
    my ($command, $message) = @_;
    my $filepath = $ENV{"GITHUB_$command"}
        or die "Unable to find environment variable for file command ${command}";

    open my $fh, ">>", $filepath or die "failed to open $filepath: $!";
    my $msg = encode_utf8(to_command_value($message));
    print $fh "$msg\n";
    close($fh);
}

1;
