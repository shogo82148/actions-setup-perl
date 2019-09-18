# actions-setup-perl

<p align="left">
  <a href="https://github.com/shogo82148/actions-setup-perl"><img alt="GitHub Actions status" src="https://github.com/shogo82148/actions-setup-perl/workflows/Main%20workflow/badge.svg"></a>
</p>

This action sets by perl environment for use in actions by:

- optionally downloading and caching a version of perl
- registering problem matchers for error output 

# Usage

See [action.yml](action.yml)

Basic:
```yaml
steps:
- uses: actions/checkout@master
- uses: shogo82148/actions-setup-perl@v1
  with:
    perl-version: '5.30'
- run: carton install
- run: prove -lv t
```

Matrix Testing:
```yaml
jobs:
  build:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: ['ubuntu-18.04', 'macOS-10.14', 'windows-2019']
        perl: [ '5.30', '5.28' ]
    name: Node ${{ matrix.perl }} sample
    steps:
      - uses: actions/checkout@v1
      - name: Setup node
        uses: shogo82148/actions-setup-perl@v1
        with:
          perl-version: ${{ matrix.node }}
      - run: carton install
      - run: prove -lv t
```

# License

The scripts and documentation in this project are released under the [MIT License](LICENSE.md)
