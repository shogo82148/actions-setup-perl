#!/usr/bin/env bash

set -uex
set -o pipefail

CURRENT=$(cd "$(dirname "$0")" && pwd)
VERSION=${1#v}
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)

cd "$CURRENT"

# update "v$MAJOR" tag
git tag -sfa "v$MAJOR" -m "release v$MAJOR.$MINOR.$PATCH"
git push -f origin "v$MAJOR"

# update "v$MAJOR.$MINOR.$PATCH" tag
gh release create "v$MAJOR.$MINOR.$PATCH" \
    --target "$(git rev-parse HEAD)" --title "v$MAJOR.$MINOR.$PATCH" --generate-notes
