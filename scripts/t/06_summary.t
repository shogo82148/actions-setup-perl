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
    "details" => {
        "label" => 'open me',
        "content" => '🎉 surprise',
    },
    "img" => {
        "src" => "https://github.com/actions.png",
        "alt" => "actions logo",
        "options" => {
            width => "32",
            height => "32",
        },
    },
    "quote" => {
        "text" => "Where the world builds software",
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

subtest "adds a table" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_table($fixtures->{table})
        ->write();

    is get_summary(), '<table><tr><th>foo</th><th>bar</th><th>baz</th><td rowspan="3">tall</td></tr><tr><td>one</td><td>two</td><td>three</td></tr><tr><td colspan="3">wide</td></tr></table>' . $/;
};

subtest "adds a details element" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_details($fixtures->{details}{label}, $fixtures->{details}{content})
        ->write();

    is get_summary(), '<details><summary>open me</summary>🎉 surprise</details>' . $/;
};

subtest "adds an image with alt text" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_image($fixtures->{img}{src}, $fixtures->{img}{alt})
        ->write();

    is get_summary(), '<img alt="actions logo" src="https://github.com/actions.png">' . $/;
};

subtest "adds an image with custom dimensions" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_image($fixtures->{img}{src}, $fixtures->{img}{alt}, $fixtures->{img}{options})
        ->write();

    is get_summary(), '<img alt="actions logo" height="32" src="https://github.com/actions.png" width="32">' . $/;
};

subtest "adds headings h1...h6" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    for $i (1..6) {
        $summary->add_heading('heading', $i);
    }
    $summary->write();

    is get_summary(), "<h1>heading</h1>$/<h2>heading</h2>$/<h3>heading</h3>$/<h4>heading</h4>$/<h5>heading</h5>$/<h6>heading</h6>$/";
};

subtest "adds h1 if heading level not specified" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary->add_heading('heading')->write();

    is get_summary(), "<h1>heading</h1>$/";
};

subtest "uses h1 if heading level is garbage or out of range" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_heading('heading', 'foobar')
        ->add_heading('heading', 1337)
        ->add_heading('heading', -1)
        ->write();

    is get_summary(), "<h1>heading</h1>$/<h1>heading</h1>$/<h1>heading</h1>$/";
};

subtest "adds a separator" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_separator()
        ->write();

    is get_summary(), "<hr>$/";
};

subtest "adds a break" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_break()
        ->write();

    is get_summary(), "<br>$/";
};

subtest "adds a quote" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_quote($fixtures->{quote}{text})
        ->write();

    is get_summary(), "<blockquote>Where the world builds software</blockquote>$/";
};

subtest "adds a quote with citation" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_quote($fixtures->{quote}{text}, $fixtures->{quote}{cite})
        ->write();

    is get_summary(), "<blockquote cite=\"https://github.com/about\">Where the world builds software</blockquote>$/";
};

subtest "adds a link with href" => sub {
    local $ENV{GITHUB_STEP_SUMMARY};
    my $tmp = setup('');

    my $summary = Actions::Core::Summary->new();
    $summary
        ->add_link($fixtures->{link}{text}, $fixtures->{link}{href})
        ->write();

    is get_summary(), '<a href="https://github.com/">GitHub</a>' . $/;
};

done_testing;
