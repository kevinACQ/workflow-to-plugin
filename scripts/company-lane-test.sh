#!/usr/bin/env bash
# company-lane-test.sh: proves the company lane works end to end on a throwaway sample plugin.
# Builds a small plugin repo from the templates, then checks: the skill zip and the claude.ai
# plugin zip build and pass the kit checks, a top-level bin/ folder is caught, an unfilled README
# is caught, a plugin-root path in a skill gets a warning, and the catalog route checker picks
# route A, B, or C correctly. No network, no GitHub, nothing outside a temp folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$HERE/.." && pwd)"
TPL="$KIT/skills/workflow-to-plugin/templates/company"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SWEEP_DENYLIST="$TMP/never-ship.txt"
printf 'Fictional Partner Co\n' > "$SWEEP_DENYLIST"

bad=0
ran=0
check() { # check NAME EXPECT(0|1) OUTPUT_REGEX -- command...
  local name="$1" want="$2" re="$3" out rc; shift 4
  out="$("$@" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && rc=1
  ran=$((ran + 1))
  if [ "$rc" = "$want" ] && printf '%s\n' "$out" | grep -qE "$re"; then
    printf '  ok    %s\n' "$name"
  else
    bad=$((bad + 1))
    printf '  WRONG %s (exit %s, wanted %s)\n' "$name" "$rc" "$want"
    printf '%s\n' "$out" | sed 's/^/          | /' | tail -25
  fi
}

C="$TMP/kit"
mkdir -p "$C/.claude-plugin" "$C/scripts" "$C/skills/weekly-digest"
cp "$HERE/sweep.sh" "$HERE/build_client_zips.sh" "$HERE/build_plugin_zip.sh" "$HERE/check_kit.sh" "$C/scripts/"
cat > "$C/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "weekly-digest",
  "displayName": "Weekly Digest",
  "description": "Turns this week's notes into a five-bullet team digest",
  "version": "1.0.0",
  "author": {"name": "Sample Owner"}
}
EOF
cat > "$C/.claude-plugin/marketplace.json" <<'EOF'
{"name": "weekly-digest-marketplace", "description": "Sample", "owner": {"name": "Sample Owner"},
 "plugins": [{"name": "weekly-digest", "source": "./", "description": "Sample"}]}
EOF
printf -- '---\nname: weekly-digest\ndescription: Turns this week'"'"'s notes into a five-bullet team digest when the user asks for the weekly digest.\n---\n\n# Weekly digest\n\nRead the notes, write five bullets, end with one ask.\n' \
  > "$C/skills/weekly-digest/SKILL.md"
sed -e 's/{{PLUGIN DISPLAY NAME}}/Weekly Digest/g' -e "s/{{ONE SENTENCE: what it does and who it's for}}/Five-bullet team digest from this week's notes./" \
    -e 's/{{TRIGGER PHRASE}}/make the weekly digest/g' -e 's/{{SKILL ZIP NAME}}/weekly-digest.zip/g' \
    -e 's/{{GITHUB OWNER}}/sample-org/g' -e 's/{{REPO NAME}}/weekly-digest/g' -e 's/{{PLUGIN NAME}}/weekly-digest/g' \
    -e 's/{{MARKETPLACE NAME}}/weekly-digest-marketplace/g' -e 's/{{OWNER CONTACT}}/help@sample.example.com/g' \
    -e 's/{{OWNER}}/Sample Owner/g' "$TPL/README-pick-your-app.md" > "$C/README.md"
git init -q "$C" && git -C "$C" add -A && git -C "$C" -c user.name=T -c user.email=t@example.com commit -qm "sample company plugin"

CONF="$TMP/company.conf"
cat > "$CONF" <<'EOF'
COMPANY_NAME="Sample Co"
GITHUB_ORG="sample-org"
CATALOG_REPO="sample-org/plugin-catalog"
CATALOG_OWNER_CONTACT="Pat Admin (pat@sample.example.com)"
EOF

echo "Company lane test: building a throwaway sample plugin"
echo
check "skill zip builds (team sweep)" 0 'built dist/weekly-digest.zip' -- bash "$C/scripts/build_client_zips.sh" --for team
check "plugin zip builds and validates" 0 'built dist/weekly-digest-plugin.zip' -- bash "$C/scripts/build_plugin_zip.sh"
check "plugin zip: manifest at the root, no marketplace.json" 0 '^\.claude-plugin/plugin\.json$' -- \
  sh -c "unzip -Z1 '$C/dist/weekly-digest-plugin.zip' | grep -v marketplace.json"
check "  ...and marketplace.json really stayed out" 1 '^' -- sh -c "unzip -Z1 '$C/dist/weekly-digest-plugin.zip' | grep marketplace.json"
check "company kit checks green (repo not on GitHub yet = warning)" 0 'ALL CHECKS GREEN' -- bash "$C/scripts/check_kit.sh" --lane company

mkdir -p "$C/bin" && printf '#!/bin/sh\necho hi\n' > "$C/bin/fetch"
check "top-level bin/ -> plugin zip build stops" 1 'top-level bin/' -- bash "$C/scripts/build_plugin_zip.sh"
check "top-level bin/ -> kit check 8 fails" 1 'FAIL 8\..*bin/' -- bash "$C/scripts/check_kit.sh" --lane company
rm -rf "$C/bin"

cp "$C/README.md" "$TMP/README.bak"
printf '\nTrigger: {{TRIGGER PHRASE}}\n' >> "$C/README.md"
check "unfilled README -> kit check 10 fails" 1 'FAIL 10\.' -- bash "$C/scripts/check_kit.sh" --lane company
cp "$TMP/README.bak" "$C/README.md"
grep -v 'claude plugin install' "$TMP/README.bak" > "$C/README.md"
check "README missing an install command -> check 10 fails" 1 'FAIL 10\..*install commands' -- bash "$C/scripts/check_kit.sh" --lane company
cp "$TMP/README.bak" "$C/README.md"

cp "$C/skills/weekly-digest/SKILL.md" "$TMP/SKILL.bak"
printf 'Run python3 ${CLAUDE_PLUGIN_ROOT}/scripts/digest.py\n' >> "$C/skills/weekly-digest/SKILL.md"
check "plugin-root path in a skill -> portability warning" 0 'WARN 3b\.' -- sh -c "bash '$C/scripts/build_client_zips.sh' --for team >/dev/null && bash '$C/scripts/check_kit.sh' --lane company"
cp "$TMP/SKILL.bak" "$C/skills/weekly-digest/SKILL.md"

check "route A when you can push to the catalog" 0 '"source": "github", "repo": "sample-org/weekly-digest"' -- \
  bash "$HERE/company_route.sh" --config "$CONF" --plugin-repo sample-org/weekly-digest --assume-access yes "$C"
check "route B when you can't" 0 'ROUTE: B' -- \
  bash "$HERE/company_route.sh" --config "$CONF" --plugin-repo sample-org/weekly-digest --assume-access no "$C"
check "route C drafts the ask to the catalog owner" 0 'Pat Admin.*weekly-digest' -- \
  sh -c "bash '$HERE/company_route.sh' --config '$CONF' --plugin-repo sample-org/weekly-digest --upload-missing '$C' | tr '\n' ' '"
check "different repo owner than the catalog -> warning" 0 'differs from the catalog' -- \
  bash "$HERE/company_route.sh" --config "$CONF" --plugin-repo someone-else/weekly-digest --assume-access no "$C"

echo
if [ "$bad" -eq 0 ]; then
  echo "COMPANY LANE: PASS ($ran/$ran cases behaved)."
  exit 0
fi
echo "COMPANY LANE: FAIL ($bad of $ran cases misbehaved; see WRONG lines above)."
exit 1
