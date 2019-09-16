#!/bin/bash

set -uex

VERSION=$1
MAJOR=$(echo "${VERSION#v}" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)

CURRENT=$(cd "$(dirname "$0")" && pwd)
WORKING=$CURRENT/.working

: clone
ORIGIN=$(git remote get-url origin)
rm -rf "$WORKING"
git clone "$ORIGIN" "$WORKING"
cd "$WORKING"

: build the action
git checkout -b "releases/v$MAJOR" "origin/releases/v$MAJOR"
git merge -X theirs -m "Merge branch 'master' into releases/v$MAJOR" master
npm install
npm run build

: remove development packages from node_modules
npm prune --production
perl -ne 'print unless m(^/node_modules/|/lib/$)' -i .gitignore

: publish to GitHub
git add .
git commit -m "bump up to v$MAJOR.$MINOR.$PATCH" || true
git push origin "releases/v$MAJOR"
git tag -a "v$MAJOR.$MINOR.$PATCH" -m "release v$MAJOR.$MINOR.$PATCH"
git push origin "v$MAJOR.$MINOR.$PATCH"
git tag -fa "v$MAJOR" -m "release v$MAJOR.$MINOR.$PATCH"
git push -f origin "v$MAJOR"

cd "$CURRENT"
