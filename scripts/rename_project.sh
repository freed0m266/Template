#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./rename_project.sh <ProjectName> [--dry-run]

Description:
  Renames project keyword variants in source/config text files and renames
  files/directories that contain the keyword in their names.

  Replacements are case-sensitive:
    Template -> <ProjectName>
    template -> <projectname-lowercase>
    TEMPLATE -> <PROJECTNAME-UPPERCASE>

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

OLD_NAME="Template"
OLD_NAME_LOWER="template"
OLD_NAME_UPPER="TEMPLATE"
NEW_NAME_LOWER="$(printf '%s' "$NEW_NAME" | tr '[:upper:]' '[:lower:]')"
NEW_NAME_UPPER="$(printf '%s' "$NEW_NAME" | tr '[:lower:]' '[:upper:]')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

transform_string() {
    local input="$1"
    input="${input//${OLD_NAME}/${NEW_NAME}}"
    input="${input//${OLD_NAME_LOWER}/${NEW_NAME_LOWER}}"
    input="${input//${OLD_NAME_UPPER}/${NEW_NAME_UPPER}}"
    printf '%s' "$input"
}

contains_old_tokens() {
    local input="$1"
    [[ "$input" == *"$OLD_NAME"* || "$input" == *"$OLD_NAME_LOWER"* || "$input" == *"$OLD_NAME_UPPER"* ]]
}

is_ignored_path() {
    local input="$1"
    case "$input" in
        */.git|*/.git/*|*/.build|*/.build/*|*/.swiftpm|*/.swiftpm/*|*/.tuist|*/.tuist/*|*/Derived|*/Derived/*|*/Products|*/Products/*|*/Frameworks|*/Frameworks/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

echo "Project root: $ROOT_DIR"
echo "New name: $NEW_NAME"
echo "Mode: $( [[ "$DRY_RUN" == "true" ]] && echo "DRY RUN" || echo "APPLY" )"
echo

echo "Step 1/3: Replacing text in files..."
while IFS= read -r -d '' file; do
    if is_ignored_path "$file"; then
        continue
    fi

    if ! grep -Iq . "$file"; then
        continue
    fi

    if ! grep -qE 'Template|template|TEMPLATE' "$file"; then
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] would update text: $file"
    else
        perl -i -pe \
            "s/${OLD_NAME}/${NEW_NAME}/g; s/${OLD_NAME_LOWER}/${NEW_NAME_LOWER}/g; s/${OLD_NAME_UPPER}/${NEW_NAME_UPPER}/g" \
            "$file"
        echo "updated text: $file"
    fi
done < <(
    find "$ROOT_DIR" \
        \( -type d \( -name .git -o -name .build -o -name .swiftpm -o -name .tuist -o -name Derived -o -name Products -o -name Frameworks \) -prune \) -o \
        -type f -print0
)

echo
echo "Step 2/3: Renaming files and directories (except root)..."
while IFS= read -r -d '' path; do
    if is_ignored_path "$path"; then
        continue
    fi

    base_name="$(basename "$path")"
    if ! contains_old_tokens "$base_name"; then
        continue
    fi

    new_base_name="$(transform_string "$base_name")"
    if [[ "$new_base_name" == "$base_name" ]]; then
        continue
    fi

    dir_name="$(dirname "$path")"
    new_path="$dir_name/$new_base_name"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] would rename: $path -> $new_path"
    else
        if [[ -e "$new_path" ]]; then
            echo "Error: target path already exists: $new_path" >&2
            exit 1
        fi
        mv "$path" "$new_path"
        echo "renamed: $path -> $new_path"
    fi
done < <(
    find "$ROOT_DIR" \
        \( -type d \( -name .git -o -name .build -o -name .swiftpm -o -name .tuist -o -name Derived -o -name Products -o -name Frameworks \) -prune \) -o \
        -mindepth 1 -depth -print0
)

echo
echo "Step 3/3: Renaming root directory..."
root_parent="$(dirname "$ROOT_DIR")"
root_name="$(basename "$ROOT_DIR")"
new_root_name="$(transform_string "$root_name")"

if [[ "$new_root_name" == "$root_name" ]]; then
    echo "root directory does not contain rename token, skipping."
else
    new_root_path="$root_parent/$new_root_name"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] would rename root: $ROOT_DIR -> $new_root_path"
    else
        if [[ -e "$new_root_path" ]]; then
            echo "Error: target root path already exists: $new_root_path" >&2
            exit 1
        fi
        cd "$root_parent"
        mv "$root_name" "$new_root_name"
        echo "renamed root: $ROOT_DIR -> $new_root_path"
        echo "next: cd \"$new_root_path\""
    fi
fi

echo
echo "Done."
