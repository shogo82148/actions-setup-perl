#!/bin/bash

CURRENT=$(cd "$(dirname "$0")" && pwd)
cd "$CURRENT"

set -eu
OPENSSL_VERSION=$(gh api --jq 'map(select(.ref | test("/openssl-[0-9]+[.][0-9]+[.][0-9]+$"))) | last.ref | sub("refs/tags/openssl-"; "")' /repos/openssl/openssl/git/matching-refs/tags/openssl-3.)
export OPENSSL_VERSION
perl -i -pe 's/^OPENSSL_VERSION=.*$/OPENSSL_VERSION=$ENV{OPENSSL_VERSION}/' build-openssl-darwin.sh
perl -i -pe 's/^OPENSSL_VERSION=.*$/OPENSSL_VERSION=$ENV{OPENSSL_VERSION}/' build-openssl-linux.sh
perl -i -pe 's/^OPENSSL_VERSION=.*$/OPENSSL_VERSION=$ENV{OPENSSL_VERSION}/' build-openssl-win32.sh
