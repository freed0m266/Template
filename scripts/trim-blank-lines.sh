#!/usr/bin/env bash
# Strips trailing whitespace from otherwise-blank lines in all tracked .swift files.
# Operates only on git-tracked files so dependencies under .build/, Derived/, etc. are skipped.

set -euo pipefail

cd "$(dirname "$0")/.."

count=$(git ls-files '*.swift' | wc -l | tr -d ' ')
echo "Scanning ${count} Swift file(s)…"

git ls-files -z '*.swift' | xargs -0 sed -i '' 's/^[[:space:]]\{1,\}$//'

echo "Done."
