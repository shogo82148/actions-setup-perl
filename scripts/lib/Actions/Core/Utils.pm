package Actions::Core::Utils;

use 5.8.5;
use utf8;
use warnings;
use strict;
use JSON::PP qw(encode_json);

use Exporter 'import';
our @EXPORT_OK = qw(to_command_value);

sub to_command_value {
    my $value = shift;
    if (!defined $value) {
        return "";
    }
    if (ref($value)) {
        return encode_json($value);
    }
    return "$value";
}

1;
