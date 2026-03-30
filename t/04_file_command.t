use Test::More;

use Actions::Core::Utils qw(prepare_key_value_message);
use Actions::Core::FileCommand qw(issue_command);

my $msg1 = prepare_key_value_message("test", "foobar");
like $msg1, qr(\Atest<<ghadelimiter_[0-9a-f]+\nfoobar\nghadelimiter_[0-9a-f]+\Z);

$msg1 =~ qr(\Atest<<(ghadelimiter_[0-9a-f]+)\nfoobar\n(ghadelimiter_[0-9a-f]+)\Z);
is $1, $2, 'delimiters are match';

my $msg2 = prepare_key_value_message("test", "foobar");
isnt $msg1, $msg2, 'prepare_key_value_message generates another delimiter';

done_testing;
