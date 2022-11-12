use Test::More;
use JSON::PP qw/decode_json/;

open my $fh, '<', 'perl.json' or die "$!";
my $data = do {local $/; <$fh>};
close $fh;

my $matcher = decode_json($data);
my $problem_matcher = $matcher->{problemMatcher};
my $regexp = $problem_matcher->[0]{pattern}[0]{regexp};
diag $regexp;

like 'Bareword "foobar" not allowed while "strict subs" in use at t/errors.pl line 4.', qr/$regexp/, 'systax error';
like 'some error!! at t/errors.pl line 4.', qr/$regexp/, 'die';
like 'some # error!! at t/errors.pl line 4.', qr/$regexp/, 'die';

# from: https://github.com/shogo82148/actions-setup-perl/issues/1302
unlike '    # at /home/runner/work/perlTest/perlTest/t/FHEM/98_HELLO/00_define.t line 21.', qr/$regexp/, 'issue 1302';
unlike "# at /home/runner/work/perlTest/perlTest/t/FHEM/98_HELLO/00_define.t line [22]", qr/$regexp/, 'issue 1302';
done_testing;

