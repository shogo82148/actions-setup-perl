#!/bin/bash

ROOT=$(cd "$(dirname "$0")" && pwd)

cpanm --notest --force --local-lib "$ROOT" Mozilla::CA
