#!/usr/bin/env bash
# build_client_zips.sh: build the zip files paying clients upload to claude.ai, one per skill.
# Copy this file, check_kit.sh, and sweep.sh into a client kit's scripts/ folder.
#
# Usage: scripts/build_client_zips.sh [--skills a,b,c] [--prefix Name-Skill-]
#   Defaults come from client/kit.conf (SKILLS, ZIP_PREFIX); with no config, every folder in
#   skills/ that has a SKILL.md ships and zips are named dist/<skill>.zip.
#
# Each zip holds <skill>/SKILL.md (plus that skill's other files) at the top level, the layout
# claude.ai's "Upload skill" accepts. Only files git would publish go in (tracked or new, never
# .gitignore'd), so a private config.json inside a skill folder can't ride along.
# The publish gate runs first: any never-ship word in skills/ or client/ stops the build.
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS=""
ZIP_PREFIX=""
# shellcheck disable=SC1091  # owner's own kit config: SKILLS="a b c", ZIP_PREFIX="Name-"
[ -f "$REPO_DIR/client/kit.conf" ] && . "$REPO_DIR/client/kit.conf"

while [ $# -gt 0 ]; do
  case "$1" in
    --skills) [ $# -ge 2 ] || { echo "--skills needs a value"; exit 2; }; SKILLS="$(printf '%s' "$2" | tr ',' ' ')"; shift 2 ;;
    --prefix) [ $# -ge 2 ] || { echo "--prefix needs a value"; exit 2; }; ZIP_PREFIX="$2"; shift 2 ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
done

if [ -z "$SKILLS" ]; then
  for d in "$REPO_DIR"/skills/*/; do [ -f "$d/SKILL.md" ] && SKILLS="$SKILLS $(basename "$d")"; done
fi
[ -n "$SKILLS" ] || { echo "No skills found in skills/. Nothing to build."; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip not found (scripts/doctor.sh checks this)."; exit 1; }

# Gate: never build client zips from a kit that fails the client sweep.
if [ ! -f "$REPO_DIR/scripts/sweep.sh" ]; then
  echo "scripts/sweep.sh is missing. Copy it from the workflow-to-plugin kit; zips are never built without the sweep."
  exit 1
fi
if ! bash "$REPO_DIR/scripts/sweep.sh" --for client "$REPO_DIR"; then
  echo
  echo "BUILD STOPPED: the sweep found something that must not reach clients. Fix it, then re-run."
  exit 1
fi
echo

mkdir -p "$REPO_DIR/dist"
for s in $SKILLS; do
  [ -f "$REPO_DIR/skills/$s/SKILL.md" ] || { echo "skills/$s/SKILL.md not found"; exit 1; }
  out="$REPO_DIR/dist/${ZIP_PREFIX}${s}.zip"
  rm -f "$out"
  (cd "$REPO_DIR/skills" && git ls-files -co --exclude-standard -- "$s" \
     | grep -vE '(^|/)(\.DS_Store|__MACOSX)(/|$)' \
     | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done \
     | zip -q -X "$out" -@)
  echo "built dist/$(basename "$out") ($(du -h "$out" | cut -f1 | tr -d ' '))"
done

echo
echo "Next: scripts/check_kit.sh must print ALL CHECKS GREEN. Then replace the SAME download"
echo "files clients already have (new version of the same file, never a new upload), so every"
echo "install prompt already sent keeps working."
