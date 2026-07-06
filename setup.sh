#!/usr/bin/env bash

# One-shot project bootstrap for the Template repository.
# Renames Template → <ProjectName>, resolves and generates the Xcode project via Tuist,
# then removes the bootstrap artefacts (rename script + template git history + this script).
#
# Run exactly ONCE, immediately after cloning the template.

set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  ./setup.sh <ProjectName>

Description:
  One-shot bootstrap. Run exactly once right after cloning the template:
    1. Renames Template → <ProjectName> across files, directories, and project root
    2. Installs Tuist dependencies (`tuist install`) and generates the Xcode project (`tuist generate`)
    3. Removes template git history and bootstrap scripts (rename_project.sh + this script)

  Arguments:
    <ProjectName>   Must start with a letter; letters and digits only. E.g. "Keymoji".

  After it finishes, initialize fresh source control:
    git init && git add . && git commit -m "🎉 Create a project"
EOF
}

if [[ $# -ne 1 ]]; then
	usage
	exit 1
fi

NEW_NAME="$1"
if [[ ! "$NEW_NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
	echo "Error: ProjectName must start with a letter and contain only letters and digits." >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
NEW_PROJECT_DIR="$PARENT_DIR/$NEW_NAME"

cd "$SCRIPT_DIR"

if [[ -e "$NEW_PROJECT_DIR" && "$NEW_PROJECT_DIR" != "$SCRIPT_DIR" ]]; then
	echo "Error: target directory already exists: $NEW_PROJECT_DIR" >&2
	exit 1
fi

if ! command -v tuist >/dev/null 2>&1; then
	echo "Error: tuist is not installed. Install via: curl -Ls https://install.tuist.io | bash" >&2
	exit 1
fi

if [[ ! -f scripts/rename_project.sh ]]; then
	echo "Error: scripts/rename_project.sh not found — has setup already run?" >&2
	exit 1
fi

# rename_project.sh derives the project root from its own location, so we move it from
# scripts/ to the project root for the rename pass. (Leaving it in scripts/ would only
# rename files inside that subdirectory.)
mv scripts/rename_project.sh ./rename_project.sh

echo "==> Renaming Template -> $NEW_NAME..."
./rename_project.sh "$NEW_NAME"

# rename_project.sh renamed the project root itself. Our cwd path string is now stale —
# the file descriptor still resolves, but explicit `cd` to the new path keeps relative
# commands sane for the rest of the script.
cd "$NEW_PROJECT_DIR"

echo
echo "==> Installing Tuist dependencies..."
tuist install

echo
echo "==> Generating Xcode project..."
tuist generate

echo
echo "==> Cleaning up bootstrap files..."
rm -f ./rename_project.sh
rm -rf .git

echo "==> Removing setup.sh itself..."
rm -- "$NEW_PROJECT_DIR/setup.sh"

cat <<EOF

✅ Done. Project bootstrapped at:
   $NEW_PROJECT_DIR

Next steps:
   cd "$NEW_PROJECT_DIR"
   git init && git add . && git commit -m "🎉 Create a project"
   open $NEW_NAME.xcworkspace
EOF
