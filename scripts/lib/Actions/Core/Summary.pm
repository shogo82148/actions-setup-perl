package Actions::Core::Summary;

use 5.8.5;
use utf8;
use warnings;
use strict;

use overload
    '""' => \&stringify
    ;
use Encode qw(encode_utf8 decode_utf8);
use Carp qw(croak);

sub new {
    my $class = shift;
    my %args = @_;
    my $self  = bless {}, $class;

    $self->{buffer} = "";
    return $self;
}

sub filepath {
    my $self = shift;
    if ($self->{filepath}) {
        return $self->{filepath};
    }

    my $filepath = $ENV{GITHUB_STEP_SUMMARY}
        or croak "Unable to find environment variable for \$GITHUB_STEP_SUMMARY. Check if your runtime environment supports job summaries.";
    if (!(-f $filepath && -w $filepath)) {
        croak "Unable to access summary file: '$filepath'. Check if the file has correct read/write permissions.";
    }

    $self->{filepath} = $filepath;
    return $filepath;
}

sub _wrap {
    my ($self, $tag, $content, $attrs) = @_;
    my $html_attrs = join '', map { " $_=\"$attrs->{$_}\"" } sort keys %$attrs;
    if (!$content) {
        return "<${tag}${html_attrs}>";
    }
    return "<${tag}${html_attrs}>$content</${tag}>";
}

sub add_raw {
    my $self = shift;
    my ($text, $eol) = @_;
    $self->{buffer} .= $text;
    if ($eol && $/) {
        $self->{buffer} .= $/;
    }
    return $self;
}

sub add_eol {
    my $self = shift;
    $self->{buffer} .= $/;
    return $self;
}

sub write {
    my ($self, %args) = @_;
    my $filepath = $self->filepath();
    my $mode = $args{overwrite} ? ">" : ">>";
    open my $fh, $mode, $filepath or croak "failed to open $filepath: $!";
    $fh->print(encode_utf8($self->{buffer}));
    close $fh or croak "failed to close";
    return $self->empty_buffer;
}

sub is_empty_buffer {
    my $self = shift;
    return $self->{buffer} eq '';
}

sub empty_buffer {
    my $self = shift;
    $self->{buffer} = '';
    return $self;
}

sub stringify {
    my $self = shift;
    return $self->{buffer};
}

sub add_code_block {
    my ($self, $code, $lang) = @_;
    my $attrs = {};
    if ($lang) {
        $attrs->{lang} = $lang;
    }
    my $element = $self->_wrap('pre', $self->_wrap('code', $code), $attrs);
    return $self->add_raw($element)->add_eol();
}

sub add_list {
    my ($self, $items, $ordered) = @_;
    my $tag = $ordered ? 'ol' : 'ul';
    my $list_items = join '', map { $self->_wrap('li', $_) } @$items;
    my $element = $self->_wrap($tag, $list_items);
    return $self->add_raw($element)->add_eol();
}

sub add_table {
    my ($self, $rows) = @_;
    my $tableBody = '';
    for my $row (@$rows) {
        my $cells = '';
        for my $cell (@$row) {
            if (!ref($cell)) {
                $cells .= $self->_wrap('td', $cell);
                next;
            }
            my $tag = $cell->{header} ? 'th' : 'td';
            my $attrs = {
                $cell->{colspan} ? (colspan => $cell->{colspan}) : (),
                $cell->{rowspan} ? (rowspan => $cell->{rowspan}) : (),
            };
            $cells .= $self->_wrap($tag, $cell->{data}, $attrs);
        }
        $tableBody .= $self->_wrap('tr',$cells);
    }
    my $element = $self->_wrap('table', $tableBody);
    return $self->add_raw($element)->add_eol();
}

sub add_details {
    my ($self, $label, $content) = @_;
    my $element = $self->_wrap('details', $self->_wrap('summary', $label) . $content);
    return $self->add_raw($element)->add_eol();
}

sub add_image {
    my ($self, $src, $alt, $options) = @_;
    my $width = $options && $options->{width};
    my $height = $options && $options->{height};
    my $attrs = {
        src => $src,
        alt => $alt,
        $width ? (width => $width) : (),
        $height ? (height => $height) : (),
    };
    my $element = $self->_wrap('img', undef, $attrs);
    return $self->add_raw($element)->add_eol();
}

sub add_heading {
    my ($self, $text, $level) = @_;
    $level ||= 1;
    my $tag = "h$level";
    if ($tag !~ /^h[1-6]$/) {
        $tag = "h1";
    }
    my $element = $self->_wrap($tag, $text);
    return $self->add_raw($element)->add_eol();
}

sub add_separator {
    my ($self) = @_;
    my $element = $self->_wrap('hr', undef);
    return $self->add_raw($element)->add_eol();
}

sub add_break {
    my ($self) = @_;
    my $element = $self->_wrap('br', undef);
    return $self->add_raw($element)->add_eol();
}

sub add_quote {
    my ($self, $text, $cite) = @_;
    my $attrs = {
        $cite ? (cite => $cite) : (),
    };
    my $element = $self->_wrap('blockquote', $text);
    return $self->add_raw($element)->add_eol();
}

1;
