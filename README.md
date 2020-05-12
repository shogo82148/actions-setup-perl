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
- uses: shogo82148/actions-setup-perl@v1.3.0
  with:
    perl-version: '5.30'
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
        perl: [ '5.30', '5.28' ]
    name: Perl ${{ matrix.perl }} on ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v2
      - name: Set up perl
        uses: shogo82148/actions-setup-perl@v1.3.0
        with:
          perl-version: ${{ matrix.perl }}
      - run: perl -V
      - run: cpanm --installdeps .
      - run: prove -lv t
```

# License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md)
