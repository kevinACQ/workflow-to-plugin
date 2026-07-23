#!/usr/bin/env bash
# Workflow → Plugin doctor: verifies everything packaging needs, prints READY when good.
# Safe to re-run any number of times. No installs, no changes — checks only.
set -u

missing=0

pass() { printf '  [ok]      %s\n' "$1"; }
fail() { printf '  [MISSING] %s\n      fix: %s\n' "$1" "$2"; missing=1; }

echo "Workflow → Plugin doctor"
echo "------------------------"

if command -v git >/dev/null 2>&1; then
  pass "git ($(git --version | head -1))"
else
  fail "git" "install Xcode Command Line Tools (macOS: xcode-select --install) or your OS package"
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    pass "GitHub CLI signed in ($(gh --version | head -1))"
  else
    fail "GitHub CLI is installed but not signed in" "run: gh auth login  (browser sign-in with your own GitHub account)"
  fi
else
  fail "GitHub CLI (gh)" "no-admin machines: download the gh binary release into ~/bin (on PATH); otherwise brew install gh"
fi

if command -v claude >/dev/null 2>&1; then
  pass "Claude Code CLI ($(claude --version 2>/dev/null | head -1))"
else
  fail "Claude Code CLI (claude)" "install Claude Code from https://claude.com/claude-code — needed for 'claude plugin validate'"
fi

echo "------------------------"
if [ "$missing" -eq 0 ]; then
  echo "READY — everything this kit needs is present."
  exit 0
else
  echo "NOT READY — fix the MISSING items above, then run this again."
  exit 1
fi
