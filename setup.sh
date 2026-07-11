#!/usr/bin/env bash

# One-shot project bootstrap for the Template repository.
# Renames Template → <ProjectName>, asks for the Apple Developer Team ID (optional), resolves
# and generates the Xcode project via Tuist, then removes the bootstrap artefacts
# (rename script + template git history + this script).
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
    2. Asks for your Apple Developer Team ID and wires it into code signing (Enter to skip)
    3. Installs Tuist dependencies (`tuist install`) and generates the Xcode project (`tuist generate`)
    4. Removes template git history and bootstrap scripts (rename_project.sh + this script)

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

# Optionally replace the empty `TeamID.placeholder` with a real, named Apple Developer team so
# the generated project has DEVELOPMENT_TEAM set from day one. Skippable — the template builds
# fine unsigned (see TeamID.swift).
echo
echo "==> Configuring code signing..."
TEAM_ID=""
if [[ -t 0 ]]; then
	while true; do
		read -r -p "Apple Developer Team ID (Enter to skip): " TEAM_ID
		if [[ -z "$TEAM_ID" || "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
			break
		fi
		echo "Invalid Team ID: expected 10 uppercase letters/digits, e.g. DSKL7YS6PW." >&2
	done
else
	echo "Non-interactive shell — skipping Team ID setup."
fi

if [[ -z "$TEAM_ID" ]]; then
	echo "Signing left unconfigured (TeamID.placeholder); set it later in Tuist/ProjectDescriptionHelpers/TeamID.swift."
else
	while true; do
		read -r -p "Swift constant name for the team (e.g. freedomMartin): " TEAM_CONSTANT
		if [[ "$TEAM_CONSTANT" =~ ^[a-z][A-Za-z0-9]*$ ]]; then
			break
		fi
		echo "Invalid name: must be a lowerCamelCase Swift identifier (letters/digits, lowercase first)." >&2
	done

	cat > Tuist/ProjectDescriptionHelpers/TeamID.swift <<EOF
import Foundation

/// The Apple Developer team identifier, wrapped in a value type so signing settings read as
/// \`.$TEAM_CONSTANT\` rather than a bare string. \`ExpressibleByStringInterpolation\` lets the raw ID
/// be interpolated straight into a \`SettingsDictionary\` value.
public struct TeamID: ExpressibleByStringInterpolation, CustomStringConvertible, Sendable {
	public static let $TEAM_CONSTANT: Self = "$TEAM_ID"

	public let description: String

	public init(stringLiteral value: String) {
		description = value
	}
}
EOF

	TEAM_CONSTANT="$TEAM_CONSTANT" perl -i -pe 's/\{ \.placeholder \}/{ .$ENV{TEAM_CONSTANT} }/' \
		Tuist/ProjectDescriptionHelpers/Environment/AppSetup.swift
	echo "Set DEVELOPMENT_TEAM to $TEAM_ID (TeamID.$TEAM_CONSTANT)."
fi

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
