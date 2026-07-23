#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./finalize_docs.sh <ProjectName> [--dry-run]

Description:
  Strips the bootstrap-only scaffolding out of the Markdown docs, so a freshly
  created project does not inherit prose describing the template it came from.

  rename_project.sh deliberately leaves the English word "template" alone (see the
  comment above PERL_RENAME_PROG). That keeps prose readable, but it also means
  sentences about the template itself would survive into the new project. Anything
  that stops being true once setup.sh has run belongs in one of two markers, both
  invisible in rendered Markdown:

    <!-- template-only:start -->     The block, markers included, is deleted along
    ...                              with any blank lines directly after it. Use it
    <!-- template-only:end -->       for whole sections (e.g. "## Quick start").

    <!-- template-description -->    The marker and the paragraph below it are
    ...                              replaced by a one-line TODO naming the new
                                     project.

  Run AFTER rename_project.sh — the marker names are hyphenated, so the rename pass
  cannot touch them. Processes *.md at any depth, minus the ignored directories.

  Ignored directories (any depth):
    .git, .build, .swiftpm, .tuist, Derived, Products, Frameworks
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 1
fi

NEW_NAME="$1"
DRY_RUN="false"

if [[ $# -eq 2 ]]; then
    if [[ "$2" == "--dry-run" ]]; then
        DRY_RUN="true"
    else
        echo "Unknown option: $2" >&2
        usage
        exit 1
    fi
fi

if [[ ! "$NEW_NAME" =~ ^[A-Za-z0-9]+$ ]]; then
    echo "Error: ProjectName must contain only letters and digits." >&2
    exit 1
fi

DESCRIPTION_LINE="_TODO: one sentence on what $NEW_NAME does — replace this line._"
export DESCRIPTION_LINE

# Slurp mode (-0777): a template-only block spans lines, so the match cannot be
# line-by-line. Trailing blank lines are swallowed with the block so removing a
# section does not leave a double gap behind; the blank line *before* the start
# marker survives and becomes the separator. The description paragraph runs from
# the marker to the first blank line. Values arrive via %ENV, never as regex.
PERL_FINALIZE_PROG='
    s{^[^\n]*<!-- template-only:start -->.*?<!-- template-only:end -->[^\n]*\n(?:[ \t]*\n)*}{}gms;
    s{^[^\n]*<!-- template-description -->[^\n]*\n(?:[^\n]+\n)*}{$ENV{DESCRIPTION_LINE}\n}gm;
'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

echo "Project root: $ROOT_DIR"
echo "New name: $NEW_NAME"
echo "Mode: $( [[ "$DRY_RUN" == "true" ]] && echo "DRY RUN" || echo "APPLY" )"
echo

while IFS= read -r -d '' file; do
    if ! grep -q '<!-- template-only:start -->\|<!-- template-description -->' "$file"; then
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] would finalize: $file"
    else
        perl -0777 -i -pe "$PERL_FINALIZE_PROG" "$file"
        echo "finalized: $file"
    fi
done < <(
    find "$ROOT_DIR" \
        \( -type d \( -name .git -o -name .build -o -name .swiftpm -o -name .tuist -o -name Derived -o -name Products -o -name Frameworks \) -prune \) -o \
        -type f -name '*.md' -print0
)

echo
echo "Done."
