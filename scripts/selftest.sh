#!/usr/bin/env bash
# Workflow → Plugin self-test: proves the plugin format this kit teaches produces a VALID plugin.
# Scaffolds a minimal sample plugin (plugin + self-marketplace + one skill) in a temp dir and
# runs `claude plugin validate --strict` on it. PASS means the recipe is current; FAIL usually
# means the plugin spec changed — re-check skills/workflow-to-plugin/references/plugin-spec.md
# against https://code.claude.com/docs and file an issue on this repo.
set -u

if ! command -v claude >/dev/null 2>&1; then
  echo "SELFTEST: FAIL — Claude Code CLI not found (run scripts/doctor.sh first)."
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sample="$tmp/sample-workflow"
mkdir -p "$sample/.claude-plugin" "$sample/skills/hello-workflow"

cat > "$sample/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "sample-workflow",
  "description": "Self-test sample plugin",
  "version": "0.0.1",
  "author": {"name": "Self Test"}
}
EOF

cat > "$sample/.claude-plugin/marketplace.json" <<'EOF'
{
  "name": "sample-workflow-marketplace",
  "description": "Self-test sample marketplace",
  "owner": {"name": "Self Test"},
  "plugins": [
    {"name": "sample-workflow", "source": "./", "description": "Self-test sample plugin"}
  ]
}
EOF

cat > "$sample/skills/hello-workflow/SKILL.md" <<'EOF'
---
name: hello-workflow
description: Self-test sample skill. Prints a greeting when the user asks for the sample workflow.
---

# Hello Workflow

Say hello. That is the whole workflow.
EOF

if claude plugin validate "$sample" --strict; then
  echo "SELFTEST: PASS — the scaffold recipe produces a valid plugin + marketplace."
  exit 0
else
  echo "SELFTEST: FAIL — 'claude plugin validate --strict' rejected the scaffold."
  echo "The plugin format has likely changed. Check references/plugin-spec.md and file an issue."
  exit 1
fi
