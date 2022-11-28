use Test::More;
use Encode qw(encode_utf8 decode_utf8);
use File::Temp;
use File::Spec;
use Actions::Core::Summary;

my $fixtures = {
    "text" => "hello world 🌎",
    "code" => "func fork() {\n  for {\n    go fork()\n  }\n}",
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

sub setup {
    my $data = shift;
    my $dir = File::Temp->newdir();
    my $filepath = File::Spec->catfile($dir->dirname, "summary.md");
    $ENV{GITHUB_STEP_SUMMARY} = $filepath;
    open my $fh, ">", $filepath or die "failed to open $filepath: $!";
    if ($data) {
        $fh->print(encode_utf8($data));
    }
    close($fh);
    return $dir;
}

sub get_summary {
    local $/;
    open my $fh, "<", $ENV{GITHUB_STEP_SUMMARY} or die "failed to open $filepath: $!";
    my $data = <$fh>;
    close($fh);
    return decode_utf8($data);
}

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

subtest "appends text to summary file" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('# ');

    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text})->write();

    is get_summary(), "# $fixtures->{text}";
};

subtest "overwrites text to summary file" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('# ');

    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text})->write(overwrite => 1);

    is get_summary(), $fixtures->{text};
};

subtest "appends text with EOL to summary file" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text}, 1)->write();

    is get_summary(), $fixtures->{text} . $/;
};

subtest "chains appends text to summary file'" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_raw($fixtures->{text})
        ->add_raw($fixtures->{text})
        ->add_raw($fixtures->{text})
        ->write();

    is get_summary(), $fixtures->{text} x 3;
};

subtest "empties buffer after write" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text})->write();
    is get_summary(), $fixtures->{text};

    ok $summary->is_empty_buffer();
};

subtest "returns summary buffer as string" => sub {
    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text});
    is "$summary", $fixtures->{text};
};

subtest "return correct values for isEmptyBuffer" => sub {
    my $summary = Actions::Core::Summary->new();
    $summary->add_raw($fixtures->{text});
    ok !$summary->is_empty_buffer();

    $summary->empty_buffer();
    ok $summary->is_empty_buffer();
};

subtest "adds EOL" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_raw($fixtures->{text})
        ->add_eol()
        ->write();

    is get_summary(), $fixtures->{text} . $/;
};

subtest "adds a code block without language" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_code_block($fixtures->{code})
        ->write();

    is get_summary(), "<pre><code>func fork() {\n  for {\n    go fork()\n  }\n}</code></pre>" . $/;
};

subtest "adds a code block with a language" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_code_block($fixtures->{code}, "go")
        ->write();

    is get_summary(), "<pre lang=\"go\"><code>func fork() {\n  for {\n    go fork()\n  }\n}</code></pre>" . $/;
};

subtest "adds an unordered list" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_list($fixtures->{list})
        ->write();

    is get_summary(), '<ul><li>foo</li><li>bar</li><li>baz</li><li>💣</li></ul>' . $/;
};

subtest "adds an ordered list" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_list($fixtures->{list}, 1)
        ->write();

    is get_summary(), '<ol><li>foo</li><li>bar</li><li>baz</li><li>💣</li></ol>' . $/;
};

done_testing;
