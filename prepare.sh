#!/bin/bash

# This scripts prepares for next release.
# See the comments of ./release.sh for more details.

set -uex

CURRENT=$(cd "$(dirname "$0")" && pwd)
VERSION=${1#v}
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)
WORKING=$CURRENT/.working

: clone
ORIGIN=$(git remote get-url origin)
rm -rf "$WORKING"
git clone "$ORIGIN" "$WORKING"
cd "$WORKING"

: checkout releases branch
git checkout -b "releases/v$MAJOR" "origin/releases/v$MAJOR" || git checkout -b "releases/v$MAJOR" main
git merge -X theirs --no-ff -m "Merge branch 'main' into releases/v$MAJOR" main || true

: update the version of package.json
git checkout main -- package.json package-lock.json
jq ".version=\"$MAJOR.$MINOR.$PATCH\"" < package.json > .tmp.json
mv .tmp.json package.json
jq ".version=\"$MAJOR.$MINOR.$PATCH\"" < package-lock.json > .tmp.json
mv .tmp.json package-lock.json
git add package.json package-lock.json
git commit -m "bump up to v$MAJOR.$MINOR.$PATCH"
git push origin main

: publish to GitHub
git add .
git commit -m "build v$MAJOR.$MINOR.$PATCH" || true
git push origin "releases/v$MAJOR"
gh release create "v$MAJOR.$MINOR.$PATCH" \
    --draft --target "$(git rev-parse HEAD)" --title "v$MAJOR.$MINOR.$PATCH" --generate-notes

cd "$CURRENT"
rm -rf "$WORKING"
