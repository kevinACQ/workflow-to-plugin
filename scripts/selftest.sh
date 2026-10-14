#!/usr/bin/env bash
# Workflow → Plugin self-test: proves the recipe this kit teaches still works, and that its
# safety checks still catch problems. Six parts:
#   1. A good sample plugin (plugin + self-marketplace + one skill) passes validation on BOTH
#      paths: the repo folder (checks marketplace.json) and .claude-plugin/plugin.json (checks
#      the plugin and every SKILL.md). Validating only the repo folder never looks at skills.
#   2. A deliberately broken sample (a skill with no description) must FAIL. If it passes,
#      validation can't be trusted and nothing should be published.
#   3. This kit itself passes validation on both paths.
#   4. The sweep canary (scripts/sweep-canary.sh) catches every planted leak.
#   5. The client lane (scripts/client-lane-test.sh) builds a sample client kit and catches
#      stale zips, open-source licenses, unfilled prompts, and never-ship words.
#   6. The company lane (scripts/company-lane-test.sh) builds a plugin zip claude.ai accepts,
#      catches a top-level bin/ and an unfilled README, and picks the right catalog route.
# FAIL on part 1 or 3 usually means the plugin spec changed: re-check
# skills/workflow-to-plugin/references/plugin-spec.md against https://code.claude.com/docs
# and file an issue on this repo.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$HERE/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "SELFTEST: FAIL. Claude Code CLI not found (run scripts/doctor.sh first)."
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bad=0

ok()   { printf '  [ok]   %s\n' "$1"; }
nope() { printf '  [FAIL] %s\n' "$1"; bad=1; }

# validate_both DIR: the two commands every packaged repo must pass before publishing.
validate_both() {
  claude plugin validate "$1" --strict > "$tmp/v1.log" 2>&1 &&
  claude plugin validate "$1/.claude-plugin/plugin.json" --strict > "$tmp/v2.log" 2>&1
}

scaffold() { # scaffold DIR SKILL_FRONTMATTER_DESCRIPTION_LINE
  mkdir -p "$1/.claude-plugin" "$1/skills/hello-workflow"
  cat > "$1/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "sample-workflow",
  "description": "Self-test sample plugin",
  "version": "0.0.1",
  "author": {"name": "Self Test"}
}
EOF
  cat > "$1/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "sample-workflow-marketplace",
  "description": "Self-test sample marketplace",
  "owner": {"name": "Self Test"},
  "plugins": [
    {"name": "sample-workflow", "source": "./", "description": "Self-test sample plugin"}
  ]
}
EOF
  {
    echo "---"
    echo "name: hello-workflow"
    [ -n "$2" ] && echo "$2"
    echo "---"
    echo
    echo "# Hello Workflow"
    echo
    echo "Say hello. That is the whole workflow."
  } > "$1/skills/hello-workflow/SKILL.md"
}

echo "Workflow → Plugin self-test"
echo "---------------------------"

# 1. Good sample: both paths pass.
scaffold "$tmp/good" "description: Self-test sample skill. Prints a greeting when the user asks for the sample workflow."
if validate_both "$tmp/good"; then
  ok "good sample passes on both paths (marketplace + plugin/skills)"
else
  nope "good sample was rejected. The plugin format has likely changed:"
  cat "$tmp/v1.log" "$tmp/v2.log" 2>/dev/null | sed 's/^/         /'
fi

# 2. Broken sample: a skill with no description must be caught.
scaffold "$tmp/broken" ""
if claude plugin validate "$tmp/broken" --strict > "$tmp/b1.log" 2>&1; then
  repo_path="passes"
else
  repo_path="fails"
fi
if claude plugin validate "$tmp/broken/.claude-plugin/plugin.json" --strict > "$tmp/b2.log" 2>&1; then
  nope "broken sample (skill with no description) PASSED plugin.json validation. Validation can't be trusted; do not publish."
  sed 's/^/         /' "$tmp/b2.log"
else
  ok "broken sample (skill with no description) correctly FAILS plugin.json validation"
fi
echo "         (repo-folder validation alone $repo_path on it: that is why both paths are required)"

# 3. This kit itself.
if validate_both "$KIT"; then
  ok "this kit passes on both paths"
else
  nope "this kit fails validation:"
  cat "$tmp/v1.log" "$tmp/v2.log" 2>/dev/null | sed 's/^/         /'
fi

# 4. The publish gate catches planted leaks.
if bash "$HERE/sweep-canary.sh" > "$tmp/canary.log" 2>&1; then
  ok "sweep canary: $(grep '^CANARY' "$tmp/canary.log")"
else
  nope "sweep canary failed:"
  sed 's/^/         /' "$tmp/canary.log"
fi

# 5. The client lane builds a sample client kit and catches each kind of mistake.
if bash "$HERE/client-lane-test.sh" > "$tmp/client.log" 2>&1; then
  ok "client lane: $(grep '^CLIENT LANE' "$tmp/client.log")"
else
  nope "client lane test failed:"
  sed 's/^/         /' "$tmp/client.log"
fi

# 6. The company lane builds a plugin zip claude.ai accepts and picks the right catalog route.
if bash "$HERE/company-lane-test.sh" > "$tmp/company.log" 2>&1; then
  ok "company lane: $(grep '^COMPANY LANE' "$tmp/company.log")"
else
  nope "company lane test failed:"
  sed 's/^/         /' "$tmp/company.log"
fi

echo "---------------------------"
if [ "$bad" -eq 0 ]; then
  echo "SELFTEST: PASS. Valid plugins build, broken skills get caught, the sweep catches leaks, and the client and company lanes work."
  exit 0
fi
echo "SELFTEST: FAIL. See [FAIL] lines above. Check references/plugin-spec.md and file an issue."
exit 1
