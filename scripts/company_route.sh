#!/usr/bin/env bash
# company_route.sh: which way into the company's Claude plugin catalog? Read-only: it checks
# access and prints the steps. It never opens a PR, uploads, or publishes anything.
#
# Usage: <kit>/scripts/company_route.sh [--config FILE] [--catalog owner/repo] [--plugin-repo owner/repo]
#                                       [--upload-missing] [--assume-access yes|no] [REPO_DIR]
#   REPO_DIR          the packaged plugin's repo (default: current folder)
#   --config          company settings (default: ~/.config/workflow-to-plugin/company.conf;
#                     template: skills/workflow-to-plugin/templates/company/company.example.conf)
#   --catalog         the repo the company catalog syncs from (overrides CATALOG_REPO)
#   --plugin-repo     this plugin's repo, owner/repo (default: the origin remote)
#   --upload-missing  the user's Claude shows no "Upload plugin" or no "Publish to org"
#   --assume-access   skip the GitHub check (yes = can push to the catalog repo, no = can't)
#
# Route A: you can push to the catalog repo -> add one entry to its marketplace.json, open a PR.
# Route B: you can't -> upload the plugin zip to your own account, test, then Publish to org.
# Route C: Upload plugin or Publish to org is turned off -> ask the catalog owner (draft printed).
set -u

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR=""
CONFIG="${HOME}/.config/workflow-to-plugin/company.conf"
CATALOG_ARG=""; PLUGIN_REPO=""; UPLOAD_MISSING=0; ASSUME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --config) [ $# -ge 2 ] || { echo "--config needs a value"; exit 2; }; CONFIG="$2"; shift 2 ;;
    --catalog) [ $# -ge 2 ] || { echo "--catalog needs a value"; exit 2; }; CATALOG_ARG="$2"; shift 2 ;;
    --plugin-repo) [ $# -ge 2 ] || { echo "--plugin-repo needs a value"; exit 2; }; PLUGIN_REPO="$2"; shift 2 ;;
    --upload-missing) UPLOAD_MISSING=1; shift ;;
    --assume-access) [ $# -ge 2 ] || { echo "--assume-access needs yes or no"; exit 2; }; ASSUME="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown option: $1"; exit 2 ;;
    *) REPO_DIR="$1"; shift ;;
  esac
done
REPO_DIR="$(cd "${REPO_DIR:-.}" 2>/dev/null && pwd)" || { echo "repo folder not found"; exit 2; }

COMPANY_NAME=""; GITHUB_ORG=""; CATALOG_REPO=""; CATALOG_OWNER_CONTACT=""
# shellcheck disable=SC1090  # the owner's own local settings file, outside every repo
[ -f "$CONFIG" ] && . "$CONFIG"
[ -n "$CATALOG_ARG" ] && CATALOG_REPO="$CATALOG_ARG"

if [ -z "$PLUGIN_REPO" ]; then
  PLUGIN_REPO="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##')"
fi
manifest="$REPO_DIR/.claude-plugin/plugin.json"
pname="$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" 2>/dev/null | head -n 1)"
pdesc="$(sed -n 's/^[[:space:]]*"description"[[:space:]]*:[[:space:]]*"\(.*\)",\{0,1\}[[:space:]]*$/\1/p' "$manifest" 2>/dev/null | head -n 1)"

echo "Company catalog route"
echo "  company settings: $([ -f "$CONFIG" ] && echo "$CONFIG" || echo "none found at $CONFIG")"
echo "  catalog repo:     ${CATALOG_REPO:-unknown}"
echo "  plugin repo:      ${PLUGIN_REPO:-not on GitHub yet}"
echo "  plugin:           ${pname:-unknown}"
echo

# A catalog can list a PRIVATE plugin repo only when both repos have the same GitHub owner.
if [ -n "$CATALOG_REPO" ] && [ -n "$PLUGIN_REPO" ] && [ "${CATALOG_REPO%%/*}" != "${PLUGIN_REPO%%/*}" ]; then
  echo "WARN: the plugin repo's owner (${PLUGIN_REPO%%/*}) differs from the catalog's (${CATALOG_REPO%%/*})."
  echo "      The company catalog can only list a private plugin repo with the same owner. Create the"
  echo "      repo under ${CATALOG_REPO%%/*} (private), or use route B, which uploads the zip instead."
  echo
fi

route=B
if [ "$UPLOAD_MISSING" = 1 ]; then
  route=C
elif [ "$ASSUME" = yes ]; then
  route=A
elif [ "$ASSUME" = no ] || [ -z "$CATALOG_REPO" ]; then
  route=B
else
  push="$(gh api "repos/$CATALOG_REPO" --jq '.permissions.push' 2>/dev/null || true)"
  case "$push" in
    true) route=A ;;
    false) echo "You can read $CATALOG_REPO but not change it." ;;
    *) echo "You can't open $CATALOG_REPO on GitHub (no access, or it doesn't exist)." ;;
  esac
fi

case "$route" in
  A)
    echo "ROUTE A: you can change the catalog repo ($CATALOG_REPO)."
    echo "  1. In a fresh clone of $CATALOG_REPO, add this entry to .claude-plugin/marketplace.json \"plugins\":"
    printf '       {"name": "%s", "source": {"source": "github", "repo": "%s"}, "description": "%s"}\n' \
      "${pname:-PLUGIN-NAME}" "${PLUGIN_REPO:-OWNER/REPO}" "${pdesc:-ONE LINE}"
    echo "  2. Validate it: claude plugin validate <clone> --strict"
    echo "  3. With the owner's OK, open a pull request. When it merges, the catalog syncs and a Claude"
    echo "     Owner sets who gets it (Available to install / Installed by default / Required)."
    ;;
  B)
    echo "ROUTE B: upload the plugin yourself, then publish it to the company."
    echo "  1. Build it:   bash scripts/build_plugin_zip.sh   (inside the plugin repo)"
    echo "  2. Pilot it:   claude.ai > Customize > Plugins > Add > Upload plugin > pick dist/${pname:-<name>}-plugin.zip"
    echo "                 (this adds it to YOUR account only)"
    echo "  3. Test it:    open a new chat and use it once for real."
    echo "  4. Publish it: only with the owner's OK and a fresh sweep, open the plugin and click"
    echo "                 Publish to org. Team plans publish at once after a scan; Enterprise waits for review."
    echo "  If Upload plugin or Publish to org isn't there, re-run with --upload-missing."
    ;;
  C)
    echo "ROUTE C: your Claude can't add plugins to the company, so ask the catalog owner. Draft:"
    echo
    tpl="$KIT_DIR/skills/workflow-to-plugin/templates/company/catalog-request.md"
    if [ -f "$tpl" ]; then
      sed -e "s#{{CATALOG OWNER}}#${CATALOG_OWNER_CONTACT:-the Claude catalog owner}#g" \
          -e "s#{{PLUGIN NAME}}#${pname:-this plugin}#g" \
          -e "s#{{PLUGIN DESCRIPTION}}#${pdesc:-what it does}#g" \
          -e "s#{{REPO LINK}}#https://github.com/${PLUGIN_REPO:-OWNER/REPO}#g" \
          -e "s#{{CATALOG REPO}}#${CATALOG_REPO:-the company catalog}#g" \
          -e "s#{{PLUGIN REPO}}#${PLUGIN_REPO:-OWNER/REPO}#g" \
          -e "s#{{COMPANY}}#${COMPANY_NAME:-the company}#g" "$tpl" | sed 's/^/    /'
    else
      echo "    (template missing: templates/company/catalog-request.md)"
    fi
    ;;
esac
echo
echo "ROUTE: $route"
