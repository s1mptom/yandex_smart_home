#!/usr/bin/env bash
# Regenerate patches/0001-configurable-cloud.patch from the current working tree.
#
# The fork is rebuilt daily by .github/workflows/sync-upstream.yml as
# "pristine upstream tag + our patches". Anything we change by hand in
# custom_components/yandex_smart_home_fork/ therefore has to end up in that
# patch file, otherwise the next sync silently throws it away.
#
# The patch is expressed against UPSTREAM paths and the UPSTREAM domain
# (custom_components/yandex_smart_home, DOMAIN = "yandex_smart_home"), because
# the workflow applies it to the pristine tag *before* renaming the domain.
# This script does that translation for you.
#
# Usage:  scripts/make-fork-patch.sh [upstream-tag]
#         (tag defaults to the upstream tag this branch was built from)

set -euo pipefail

OLD_DOMAIN="yandex_smart_home"
NEW_DOMAIN="yandex_smart_home_fork"
PATCH="patches/0001-configurable-cloud.patch"

cd "$(dirname "$0")/.."
ROOT=$(pwd)

# Upstream tags are 3-part (v1.1.2); our fork-only tags have a 4th segment
# (v1.1.2.1) and point at already-patched commits — never use them as the base.
TAG=${1:-$(git describe --tags --abbrev=0 \
  --match 'v[0-9]*.[0-9]*.[0-9]*' --exclude 'v[0-9]*.[0-9]*.[0-9]*.[0-9]*' HEAD)}
echo "base upstream tag: $TAG"

WORKTREE=$(mktemp -d)
trap 'git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true' EXIT

git worktree add --detach "$WORKTREE" "$TAG" >/dev/null

SRC="$ROOT/custom_components/$NEW_DOMAIN"
DST="$WORKTREE/custom_components/$OLD_DOMAIN"

rm -rf "$DST"
cp -R "$SRC" "$DST"
find "$DST" -name '__pycache__' -type d -prune -exec rm -rf {} +

# Undo the fork-only renaming the workflow does with sed, so it does not show up
# in the patch (it would conflict with the workflow's own rename step).
perl -pi -e "s|^DOMAIN = \"$NEW_DOMAIN\"|DOMAIN = \"$OLD_DOMAIN\"|" "$DST/const.py"

# manifest.json / hacs.json carry only fork metadata (domain, name, version) that
# the workflow rewrites on its own — keep them out of the patch entirely.
git -C "$WORKTREE" checkout -- "custom_components/$OLD_DOMAIN/manifest.json"

git -C "$WORKTREE" add -A "custom_components/$OLD_DOMAIN"
mkdir -p "$ROOT/patches"
git -C "$WORKTREE" diff --cached --binary -- "custom_components/$OLD_DOMAIN" > "$ROOT/$PATCH"

if [ ! -s "$ROOT/$PATCH" ]; then
  echo "error: generated patch is empty — nothing differs from upstream $TAG" >&2
  exit 1
fi

echo "wrote $PATCH ($(grep -c '^diff --git' "$ROOT/$PATCH") files, $(wc -l < "$ROOT/$PATCH") lines)"
grep '^diff --git' "$ROOT/$PATCH" | sed "s|diff --git a/custom_components/$OLD_DOMAIN/||;s| b/.*||;s|^|  |"
