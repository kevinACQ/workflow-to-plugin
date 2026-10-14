#!/usr/bin/env bash
# build_plugin_zip.sh: build the plugin zip for claude.ai "Upload plugin" (Customize > Plugins >
# Add > Upload plugin), the file a member uploads before "Publish to org".
#
# Usage: scripts/build_plugin_zip.sh [--plugin-dir DIR] [--for team|public|client]
#   --plugin-dir  folder holding .claude-plugin/plugin.json (default: the repo root)
#   --for         sweep mode for the publish gate (default: team)
#
# Output: dist/<plugin-name>-plugin.zip with .claude-plugin/plugin.json at the zip root, the
# layout claude.ai accepts. Only files git would publish go in; dist/, other zips, the repo's
# own marketplace.json, and this kit's release tooling (sweep, zip builders, checks) stay out.
# Stops on a top-level bin/ folder, because claude.ai and Cowork reject a plugin that has one
# (keep executables in scripts/).
set -eu

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$REPO_DIR"
SWEEP_MODE=team

while [ $# -gt 0 ]; do
  case "$1" in
    --plugin-dir) [ $# -ge 2 ] || { echo "--plugin-dir needs a value"; exit 2; }; PLUGIN_DIR="$(cd "$2" && pwd)"; shift 2 ;;
    --for) [ $# -ge 2 ] || { echo "--for needs a value"; exit 2; }; SWEEP_MODE="$2"; shift 2 ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
done

manifest="$PLUGIN_DIR/.claude-plugin/plugin.json"
[ -f "$manifest" ] || { echo "No .claude-plugin/plugin.json in $PLUGIN_DIR (pass --plugin-dir for a nested plugin)."; exit 1; }
name="$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -n 1)"
[ -n "$name" ] || { echo "plugin.json has no \"name\"."; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip not found (scripts/doctor.sh checks this)."; exit 1; }

if [ -d "$PLUGIN_DIR/bin" ]; then
  echo "BUILD STOPPED: the plugin has a top-level bin/ folder. claude.ai and Cowork reject the whole"
  echo "plugin when it does. Move those files to scripts/ and call them as \${CLAUDE_PLUGIN_ROOT}/scripts/<name>."
  exit 1
fi

if [ ! -f "$REPO_DIR/scripts/sweep.sh" ]; then
  echo "scripts/sweep.sh is missing. Copy it from the workflow-to-plugin kit; zips are never built without the sweep."
  exit 1
fi
if ! bash "$REPO_DIR/scripts/sweep.sh" --for "$SWEEP_MODE" "$REPO_DIR"; then
  echo
  echo "BUILD STOPPED: the sweep found something that must not ship. Fix it, then re-run."
  exit 1
fi
echo

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(cd "$PLUGIN_DIR" && git ls-files -co --exclude-standard -- . ) \
  | grep -vE '^dist/|\.zip$|(^|/)(\.DS_Store|__MACOSX)(/|$)|^\.claude-plugin/marketplace\.json$' \
  | grep -vE '^scripts/(sweep|sweep-canary|build_client_zips|build_plugin_zip|check_kit|company_route|client-lane-test|company-lane-test)\.sh$' \
  | while IFS= read -r f; do [ -f "$PLUGIN_DIR/$f" ] && printf '%s\n' "$f"; done > "$TMP/files"
grep -qx '.claude-plugin/plugin.json' "$TMP/files" || { echo "plugin.json is gitignored or untracked-and-ignored; it must ship."; exit 1; }

mkdir -p "$REPO_DIR/dist"
out="$REPO_DIR/dist/${name}-plugin.zip"
rm -f "$out"
(cd "$PLUGIN_DIR" && zip -q -X "$out" -@ < "$TMP/files")

# Check what was actually built: manifest at the root, no bin/, and it validates on its own.
mkdir -p "$TMP/unzipped"
unzip -qo "$out" -d "$TMP/unzipped"
[ -f "$TMP/unzipped/.claude-plugin/plugin.json" ] || { echo "Built zip has no .claude-plugin/plugin.json at its root."; exit 1; }
if command -v claude >/dev/null 2>&1; then
  if ! claude plugin validate "$TMP/unzipped/.claude-plugin/plugin.json" --strict > "$TMP/validate.log" 2>&1; then
    sed 's/^/  /' "$TMP/validate.log"
    echo "BUILD STOPPED: the zipped plugin doesn't validate."
    rm -f "$out"
    exit 1
  fi
else
  echo "WARN: Claude Code CLI not found, so the zip wasn't validated. Run scripts/doctor.sh."
fi

echo "built dist/$(basename "$out") ($(wc -l < "$TMP/files" | tr -d ' ') files, $(du -h "$out" | cut -f1 | tr -d ' '))"
echo "Next: upload it to YOUR OWN account first (Customize > Plugins > Add > Upload plugin), test it"
echo "in a new chat, and only then use Publish to org, with the owner's OK."
