package Actions::Core::Utils;

use 5.8.5;
use utf8;
use warnings;
use strict;
use JSON::PP qw(encode_json);

use Exporter 'import';
our @EXPORT_OK = qw(to_command_value prepare_key_value_message);

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

sub prepare_key_value_message {
    my ($key, $value) = @_;
    my $delimiter = "ghadelimiter_" . _random_string();
    my $convertedValue = to_command_value($value);

    if (index($key, $delimiter) >= 0) {
        die "Unexpected input: name should not contain the delimiter $delimiter";
    }
    if (index($convertedValue, $delimiter) >= 0) {
        die "Unexpected input: value should not contain the delimiter $delimiter";
    }
    return "$key<<$delimiter\n$convertedValue\n$delimiter";
}

INIT {
    # use Net::SSLey
    eval {
        require "Net/SSLeay.pm";
        Net::SSLeay->import();
        *_random_string = sub {
            my $n = 32;
            my $buf;
            if (Net::SSLeay::RAND_bytes($buf, $n) != 1) {
                my $rv = Net::SSLeay::ERR_get_error();
                die "failed to RAND_bytes: $rv";
            }
            return unpack 'H*', $buf;
        };
    };
    return unless $@;

    if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
        eval {
            require "Win32/API.pm";
            Win32::API->import();

            # based on https://metacpan.org/release/MKANAT/Crypt-Random-Source-Strong-Win32-0.07/source/lib/Crypt/Random/Source/Strong/Win32.pm
            my $func = Win32::API->new('advapi32', <<EOF) or die "Could not import SystemFunction036: $^E";
INT SytemFunction036(
    PVOID RandomBuffer,
    ULONG RandomBufferLength
)
EOF
            *_random_string = sub {
                my $n = 32;
                my $buf = "\0" x $n;
                $func->Call($buf, $n) or die "RtlGenRand failed: $^E";
                return unpack 'H*', $buf;
            };
        };
        return unless $@;
    }

    # fallback to /dev/urandom
    *_random_string = sub {
        my $n = 32;
        my $buf;
        open my $fh, '<', '/dev/urandom' or die "failed to open /dev/urandom: $!";
        read $fh, $buf, $n or die "failed to read /dev/urandom: $!";
        close $fh or die "failed to close /dev/urandom: $!";
        return unpack 'H*', $buf;
    };
}

1;
