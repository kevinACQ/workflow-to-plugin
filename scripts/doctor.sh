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

# gitleaks powers the publish gate (scripts/sweep.sh). ~/bin counts even if it's not on PATH.
gl="$(command -v gitleaks 2>/dev/null || true)"
[ -z "$gl" ] && [ -x "$HOME/bin/gitleaks" ] && gl="$HOME/bin/gitleaks"
if [ -n "$gl" ]; then
  pass "gitleaks $("$gl" version 2>/dev/null | head -1) (secret scanner for the publish gate)"
else
  fail "gitleaks (secret scanner the publish gate needs)" "no admin needed: download the release for this computer from https://github.com/gitleaks/gitleaks/releases (e.g. gh release download -R gitleaks/gitleaks -p '*darwin_arm64.tar.gz'), unpack it, and put the gitleaks file in ~/bin"
fi

if command -v zip >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  pass "zip and unzip (client kits)"
else
  fail "zip / unzip (needed to build client kits)" "macOS has them built in; on Linux install your OS's zip and unzip packages"
fi

echo "------------------------"
if [ "$missing" -eq 0 ]; then
  echo "READY — everything this kit needs is present."
  exit 0
else
  echo "NOT READY — fix the MISSING items above, then run this again."
  exit 1
fi
