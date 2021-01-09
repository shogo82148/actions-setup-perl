#!/bin/bash

# bundle OpenSSL for better reproducibility.

set -e

OPENSSL_VERSION=1_1_1i
ROOT=$(cd "$(dirname "$0")" && pwd)
: "${RUNNER_TEMP:=$ROOT/working}"
: "${RUNNER_TOOL_CACHE:=$RUNNER_TEMP/dist}"
PERL_DIR=perl
if [[ "x$PERL_MULTI_THREAD" != "x" ]]; then
    PERL_DIR="$PERL_DIR-thr"
fi
PREFIX=$RUNNER_TOOL_CACHE/$PERL_DIR/$PERL_VERSION/x64

# detect the number of CPU Core
JOBS=$(sysctl -n hw.logicalcpu_max)

mkdir -p "$RUNNER_TEMP"
cd "$RUNNER_TEMP"

# system SSL/TLS library is too old. so we use custom build.
echo "::group::download OpenSSL source"
(
    set -eux
    cd "$RUNNER_TEMP"
    curl --retry 3 -sSL "https://github.com/openssl/openssl/archive/OpenSSL_$OPENSSL_VERSION.tar.gz" -o openssl.tar.gz
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
    cd "$RUNNER_TEMP/openssl-OpenSSL_$OPENSSL_VERSION"
    ./Configure --prefix="$PREFIX" darwin64-x86_64-cc
    make "-j$JOBS"
    make install_sw install_ssldirs
)
echo "::endgroup::"

# configure for building Net::SSLeay
cat <<__END__  >> "$GITHUB_ENV"
OPENSSL_PREFIX=$PREFIX
DYLD_LIBRARY_PATH=$PREFIX/lib:$DYLD_LIBRARY_PATH
__END__
