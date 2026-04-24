#!/usr/bin/env bash
set -euo pipefail

# Parse last git commit message for version bump keyword.
# Keywords (highest precedence first):
#   Breaking:  -> major bump, minor and patch reset to 0
#   Feature:   -> minor bump, patch reset to 0
#   Core:      -> minor bump, patch reset to 0
#   Fix:       -> patch bump
# Unrecognized prefix -> print error, exit 1 (project.yml unchanged, no commit or tag)

COMMIT_MSG=$(git log -1 --format="%s")
CURRENT=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*: *//;s/"//g;s/ //g')

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

if echo "$COMMIT_MSG" | grep -qE '^Breaking:'; then
    MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
elif echo "$COMMIT_MSG" | grep -qE '^(Feature:|Core:)'; then
    MINOR=$((MINOR + 1)); PATCH=0
elif echo "$COMMIT_MSG" | grep -qE '^Fix:'; then
    PATCH=$((PATCH + 1))
else
    echo "Error: commit message prefix not recognized."
    echo "  Got: $COMMIT_MSG"
    echo "  Expected prefix: Breaking: | Feature: | Core: | Fix:"
    exit 1
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

yq eval ".targets.MDViewer.settings.base.MARKETING_VERSION = \"${NEW_VERSION}\"" -i project.yml
xcodegen generate
git add project.yml MDViewer.xcodeproj
git commit -m "chore: bump version to v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "v${NEW_VERSION}"

echo "Bumped version: ${CURRENT} -> ${NEW_VERSION} (tag: v${NEW_VERSION})"
