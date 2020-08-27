# actions-setup-perl

<p align="left">
  <a href="https://github.com/shogo82148/actions-setup-perl/actions"><img alt="GitHub Actions status" src="https://github.com/shogo82148/actions-setup-perl/workflows/Main%20workflow/badge.svg"></a>
</p>

This action sets by perl environment for use in actions by:

- optionally downloading and caching a version of perl
- registering problem matchers for error output 

# Usage

See [action.yml](action.yml)

Basic:
```yaml
steps:
- uses: actions/checkout@v2
- uses: shogo82148/actions-setup-perl@v1
  with:
    perl-version: '5.32'
- run: cpanm --installdeps .
- run: prove -lv t
```

Matrix Testing:
```yaml
jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: ['ubuntu-latest', 'macos-latest', 'windows-latest']
        perl: [ '5.32', '5.30', '5.28' ]
    name: Perl ${{ matrix.perl }} on ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v2
      - name: Set up perl
        uses: shogo82148/actions-setup-perl@v1
        with:
          perl-version: ${{ matrix.perl }}
      - run: perl -V
      - run: cpanm --installdeps .
      - run: prove -lv t
```

## Use Strawberry Perl on Windows

actions-setup-perl uses the binaries customized for GitHub Actions by default.
If you want to use [Strawberry Perl](http://strawberryperl.com/) on Windows, add `distribution: strawberry` into the "with" section.

```yaml
steps:
- uses: actions/checkout@v2
- uses: shogo82148/actions-setup-perl@v1
  with:
    perl-version: '5.30'
    distribution: strawberry
- run: cpanm --installdeps .
- run: prove -lv t
```

This option is available on Windows and falls back to the default customized binaries on other platforms.

### Action inputs

All inputs are **optional**. If not set, sensible defaults will be used.

| Name | Description | Default |
| --- | --- | --- |
| `perl-version` | Specifies the Perl version to setup. Minor version and patch level can be omitted. The action uses the latest Perl version available that matches the specified value. This defaults to 5, which results in the latest available version of Perl 5. | 5 |
| `distribution` | Specify the distribution to use, this is either `default` or `strawberry`. (The value `strawberry` is ignored on anything but Windows.) | `default` |

# License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md)
