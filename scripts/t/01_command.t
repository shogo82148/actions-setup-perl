use Test::More;

use Actions::Core::Command;

my $cmd;

$cmd = Actions::Core::Command->new("some-command", {}, "");
is "$cmd", "::some-command::", "command only";

$cmd = Actions::Core::Command->new(
    "some-command",
    {},
    "percent % percent % cr \r cr \r lf \n lf \n",
);
is "$cmd", "::some-command::percent %25 percent %25 cr %0D cr %0D lf %0A lf %0A", "command escapes message";

$cmd = Actions::Core::Command->new(
    "some-command",
    {},
    "%25 %25 %0D %0D %0A %0A",
);
is "$cmd", "::some-command::%2525 %2525 %250D %250D %250A %250A", "Verify literal escape sequences";

$cmd = Actions::Core::Command->new(
    "some-command",
    { name => "percent % percent % cr \r cr \r lf \n lf \n colon : colon : comma , comma ," },
    "",
);
is "$cmd",
    "::some-command name=percent %25 percent %25 cr %0D cr %0D lf %0A lf %0A colon %3A colon %3A comma %2C comma %2C::",
    "command escapes property";

$cmd = Actions::Core::Command->new(
    "some-command",
    { name => "%25 %25 %0D %0D %0A %0A %3A %3A %2C %2C" },
    "",
);
is "$cmd",
    "::some-command name=%2525 %2525 %250D %250D %250A %250A %253A %253A %252C %252C::",
    "command escapes property";

$cmd = Actions::Core::Command->new(
    "some-command",
    {},
    "some message",
);
is "$cmd",
    "::some-command::some message",
    "command with message";

$cmd = Actions::Core::Command->new(
    "some-command",
    { prop1 => 'value 1', prop2 => 'value 2' },
    "some message",
);
is "$cmd",
    "::some-command prop1=value 1,prop2=value 2::some message",
    "command with message and properties";

$cmd = Actions::Core::Command->new(
    "some-command",
    {
        prop1 => { test => "object" },
        prop2 => 123,
        prop3 => \1,
    },
    { test => "object" },
);
is "$cmd",
    '::some-command prop1={"test"%3A"object"},prop2=123,prop3=true::{"test":"object"}',
    "should handle issuing commands for non-string objects";

done_testing;
