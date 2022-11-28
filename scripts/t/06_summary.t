use Test::More;
use File::Temp;
use File::Spec;
use Actions::Core::Summary;

my $fixtures = {
    "text" => "hello world 🌎",
    "code" => "func fork() {\n    for {\n      go fork()\n    }\n}\n",
    "list" => ['foo', 'bar', 'baz', '💣'],
    "table" => [
        [
            {
                data => 'foo',
                header => 1,
            },
            {
                data => 'bar',
                header => 1
            },
            {
                data => 'baz',
                header => 1,
            },
            {
                data => 'tall',
                rowspan => '3',
            }
        ],
        ['one', 'two', 'three'],
        [
            {
                data => 'wide',
                colspan => '3',
            }
        ],
    ],
    "details" => {},
    "img" => {
        "src" => "https://github.com/actions.png",
        "alt" => "actions logo",
        "options" => {
            width => "32",
            height => "32",
        },
    },
    "quote" => {
        "text" => "here the world builds software",
        "cite" => "https://github.com/about",
    },
    "link" => {
        "text" => "GitHub",
        "href" => "https://github.com/"
    },
};

subtest "throws if summary env var is undefined" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    eval {
        my $summary = Actions::Core::Summary->new();
        $summary->add_raw($fixtures->{text})->write();
    };
    my $err = $@;
    diag $err;
    ok $@;
};

subtest "throws if summary file does not exist" => sub {
    my $dir = File::Temp->newdir();
    my $filepath = File::Spec->catfile($dir->dirname, "not_found.md");

    local $ENV{GITHUB_STEP_SUMMARY} = $filepath;
    eval {
        my $summary = Actions::Core::Summary->new();
        $summary->add_raw($fixtures->{text})->write();
    };
    my $err = $@;
    diag $err;
    ok $@;
};

done_testing;
