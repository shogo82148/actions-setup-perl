#!/bin/bash

# The release flow is the following.
#
# 1. push transpiled TypeScript files into the releases/v1 branch
# 2. create new tag v1.x.x on releases/v1 branch
# 3. trigger workflows for building Perl binaries
# 4. move v1 tag to v1.x.x
#
# ./prepare.sh does No.1 and 2, and ./release.sh does No.4
#
# 1. run `./prepare.sh 1.0.0`
# 2. wait for all actions to finish. https://github.com/shogo82148/actions-setup-perl/actions
# 3. run `./release.sh 1.0.0`
# 4. publish new release on GitHub https://github.com/shogo82148/actions-setup-perl/releases

set -uex

CURRENT=$(cd "$(dirname "$0")" && pwd)
VERSION=$1
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)
WORKING=$CURRENT/.working

: clone
ORIGIN=$(git remote get-url origin)
rm -rf "$WORKING"
git clone "$ORIGIN" "$WORKING"
cd "$WORKING"

: release the action
git checkout "v$MAJOR.$MINOR.$PATCH" || (
    : it looks that "v$MAJOR.$MINOR.$PATCH" is not tagged.
    : run ./prepare.sh "v$MAJOR.$MINOR.$PATCH" at first.
    : see the comments of ./release.sh for more details.
    exit 1
)
git tag -fa "v$MAJOR" -m "release v$MAJOR.$MINOR.$PATCH"
git push -f origin "v$MAJOR"

cd "$CURRENT"
rm -rf "$WORKING"
