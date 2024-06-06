#!/bin/bash

# bundle OpenSSL for better reproducibility.

set -e

OPENSSL_VERSION=3.3.1
ROOT=$(cd "$(dirname "$0")" && pwd)
: "${RUNNER_TEMP:=$ROOT/working}"
: "${RUNNER_TOOL_CACHE:=$RUNNER_TEMP/dist}"
PERL_DIR=$PERL_VERSION
if [[ "x$PERL_MULTI_THREAD" != "x" ]]; then
    PERL_DIR="$PERL_DIR-thr"
fi
PREFIX=$RUNNER_TOOL_CACHE/perl/$PERL_DIR/x64

# detect the number of CPU Core
JOBS=$(nproc)

mkdir -p "$RUNNER_TEMP"
cd "$RUNNER_TEMP"

echo "::group::download OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    curl --retry 3 -sSL "https://github.com/openssl/openssl/archive/refs/tags/openssl-$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
)
echo "::endgroup::"

echo "::group::extract OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    tar zxvf openssl.tar.gz
)
echo "::endgroup::"

echo "::group::build OpenSSL"
(
    set -eux
    cd "$RUNNER_TEMP/openssl-openssl-$OPENSSL_VERSION"
    ./Configure --prefix="$PREFIX" --openssldir="$PREFIX" "-Wl,-rpath,\$(LIBRPATH)"
    make "-j$JOBS" build_sw
    make install_sw
)
echo "::endgroup::"

# configure for building Net::SSLeay
cat <<__END__  >> "$GITHUB_ENV"
OPENSSL_PREFIX=$PREFIX
__END__
