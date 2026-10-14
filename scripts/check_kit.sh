#!/usr/bin/env bash
# check_kit.sh: pass/fail checks on a client kit before anything is sent to a client.
# Copy into a client kit's scripts/ folder next to build_client_zips.sh and sweep.sh.
#
# Usage: scripts/check_kit.sh [--skills a,b,c] [--prefix Name-Skill-]   (defaults: client/kit.conf)
#
# Checks 1-7: the skills and zips claude.ai will accept, and zips that match their source.
# Checks 8-10: the client-lane rules (proprietary license, private repo, a filled-in install
# prompt plus PDF guide). Exits non-zero on any failure.
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS=""
ZIP_PREFIX=""
# shellcheck disable=SC1091
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

FAIL=0
pass() { echo "  PASS $1"; }
fail() { echo "  FAIL $1"; FAIL=1; }
warn() { echo "  WARN $1"; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Frontmatter value of KEY from SKILL.md; handles quotes and multi-line (| or >) values.
fm() {
  awk -v key="$2" '
    NR==1 && $0!="---" { exit }
    NR>1 && $0=="---" { exit }
    collecting { if ($0 ~ /^[ \t]/) { sub(/^[ \t]+/, ""); val = val (val=="" ? "" : " ") $0; next } else { exit } }
    $0 ~ "^" key ":" {
      v = $0; sub("^" key ":[ \t]*", "", v)
      if (v ~ /^[|>][-+]?$/ || v == "") { collecting = 1; next }
      val = v; exit
    }
    END {
      if (val ~ /^".*"$/ || val ~ /^'\''.*'\''$/) val = substr(val, 2, length(val) - 2)
      print val
    }' "$1"
}

# Exactly the files that ship for skill $1 (git-visible, minus OS junk), relative to skills/.
ship_list() {
  (cd "$REPO_DIR/skills" && git ls-files -co --exclude-standard -- "$1" \
    | grep -vE '(^|/)(\.DS_Store|__MACOSX)(/|$)' \
    | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done | sort)
}

echo "Client kit checks: $REPO_DIR"
echo "Shipping skills:$SKILLS"
echo
[ -n "$SKILLS" ] || fail "no skills found in skills/"

# 1. Every shipped skill has a SKILL.md
for s in $SKILLS; do
  [ -f "$REPO_DIR/skills/$s/SKILL.md" ] && pass "1. skills/$s/SKILL.md exists" || fail "1. skills/$s/SKILL.md missing"
done

# 2. Name matches the folder and follows claude.ai's rules
for s in $SKILLS; do
  f="$REPO_DIR/skills/$s/SKILL.md"; [ -f "$f" ] || continue
  n="$(fm "$f" name)"
  if [ "$n" != "$s" ]; then
    fail "2. frontmatter name '$n' does not match folder '$s'"
  elif ! printf '%s' "$n" | grep -qE '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$'; then
    fail "2. name '$n' must be lowercase letters, numbers, and hyphens, at most 64 characters"
  elif printf '%s' "$n" | grep -qiE 'anthropic|claude'; then
    fail "2. name '$n' uses a reserved word (anthropic, claude)"
  else
    pass "2. name ok: $s"
  fi
done

# 3. Description present and within claude.ai's 1024-character limit (counted in bytes: never
#    under-counts, so a pass here is safe)
for s in $SKILLS; do
  f="$REPO_DIR/skills/$s/SKILL.md"; [ -f "$f" ] || continue
  len=$(fm "$f" description | LC_ALL=C wc -c | tr -d ' ')
  len=$((len - 1))   # wc counts the trailing newline from print
  if [ "$len" -gt 0 ] && [ "$len" -le 1024 ]; then
    pass "3. description present, $len/1024 characters: $s"
  else
    fail "3. description missing or over 1024 characters: $s ($len)"
  fi
done

# 4. No OS junk files in shipped skills
if find "$REPO_DIR/skills" \( -name '.DS_Store' -o -name '__MACOSX' \) 2>/dev/null | grep -q .; then
  fail "4. junk files (.DS_Store or __MACOSX) under skills/: delete them"
else
  pass "4. no junk files under skills/"
fi

# 5. Each zip exists with <name>/SKILL.md at the top level and nothing else at the top
for s in $SKILLS; do
  z="$REPO_DIR/dist/${ZIP_PREFIX}${s}.zip"
  if [ ! -s "$z" ]; then fail "5. zip missing: dist/$(basename "$z") (run scripts/build_client_zips.sh)"; continue; fi
  names="$(unzip -Z1 "$z" 2>/dev/null)"
  if ! printf '%s\n' "$names" | grep -qx "$s/SKILL.md"; then
    fail "5. dist/$(basename "$z") has no $s/SKILL.md at the top level"
  elif printf '%s\n' "$names" | grep -v "^$s/" | grep -q .; then
    fail "5. dist/$(basename "$z") has files outside the $s/ folder"
  elif printf '%s\n' "$names" | grep -qE '(^|/)(\.DS_Store|__MACOSX)(/|$)'; then
    fail "5. junk entries inside dist/$(basename "$z")"
  else
    pass "5. zip layout ok: dist/$(basename "$z")"
  fi
done

# 6. Each zip under claude.ai's 30 MB upload cap
for s in $SKILLS; do
  z="$REPO_DIR/dist/${ZIP_PREFIX}${s}.zip"; [ -f "$z" ] || continue
  size=$(wc -c < "$z" | tr -d ' ')
  [ "$size" -lt 31457280 ] && pass "6. under 30 MB: dist/$(basename "$z") ($size bytes)" || fail "6. over 30 MB: dist/$(basename "$z")"
done

# 7. Zips match the skill source exactly (no drift: what clients get is what was checked)
for s in $SKILLS; do
  z="$REPO_DIR/dist/${ZIP_PREFIX}${s}.zip"; [ -f "$z" ] || continue
  rm -rf "$TMP/zip" "$TMP/src"; mkdir -p "$TMP/zip" "$TMP/src"
  unzip -qo "$z" -d "$TMP/zip"
  ship_list "$s" > "$TMP/list"
  (cd "$REPO_DIR/skills" && tr '\n' '\0' < "$TMP/list" | tar --null -T - -cf -) | tar -xf - -C "$TMP/src"
  if diff -r "$TMP/src" "$TMP/zip" > /dev/null 2>&1; then
    pass "7. zip matches skills/$s (no drift)"
  else
    fail "7. dist/$(basename "$z") is out of date with skills/$s: run scripts/build_client_zips.sh"
  fi
done

# 8. Proprietary license: paid kits are not open source
lic=""
for c in LICENSE LICENSE.md LICENSE.txt; do [ -f "$REPO_DIR/$c" ] && lic="$REPO_DIR/$c" && break; done
if [ -z "$lic" ]; then
  fail "8. no LICENSE file (copy templates/client/LICENSE-proprietary.txt and fill it in)"
elif grep -qiE 'Permission is hereby granted|MIT License|Apache License|GNU GENERAL PUBLIC|Creative Commons' "$lic"; then
  fail "8. LICENSE is an open-source license; a paid kit needs 'All rights reserved'"
elif grep -q '{{' "$lic"; then
  fail "8. LICENSE still has unfilled {{ }} placeholders"
elif grep -qi 'all rights reserved' "$lic"; then
  pass "8. LICENSE is proprietary (all rights reserved)"
else
  fail "8. LICENSE doesn't say 'All rights reserved'"
fi

# 9. The repo is private (paid work never goes on public GitHub)
url="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)"
case "$url" in
  "") warn "9. no GitHub remote yet: create the repo PRIVATE, then re-run" ;;
  *github.com*)
    slug="$(printf '%s' "$url" | sed -E 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)##; s#\.git$##')"
    vis="$(gh repo view "$slug" --json visibility -q .visibility 2>/dev/null || true)"
    case "$vis" in
      PRIVATE|INTERNAL) pass "9. GitHub repo $slug is $vis" ;;
      PUBLIC) fail "9. GitHub repo $slug is PUBLIC: make it private now (gh repo edit $slug --visibility private --accept-visibility-change-consequences)" ;;
      *) fail "9. couldn't confirm $slug is private (is 'gh' signed in?)" ;;
    esac ;;
  *) warn "9. remote is not GitHub ($url): confirm by hand that it's private" ;;
esac

# 10. A filled-in install prompt (one download link per skill) and a PDF guide in client/
p="$REPO_DIR/client/INSTALL-PROMPT.txt"
if [ ! -f "$p" ]; then
  fail "10. client/INSTALL-PROMPT.txt missing (copy templates/client/INSTALL-PROMPT.txt)"
elif grep -q '{{' "$p"; then
  fail "10. client/INSTALL-PROMPT.txt still has unfilled {{ }} placeholders"
else
  nskills=$(printf '%s\n' $SKILLS | grep -c .)
  nlinks=$(grep -oE 'https://[^ )>"]+' "$p" | sort -u | grep -c . || true)
  [ "$nlinks" -ge "$nskills" ] && pass "10. install prompt filled in ($nlinks links for $nskills skills)" || fail "10. install prompt has $nlinks link(s) for $nskills skills: one download link per skill"
fi
if ls "$REPO_DIR"/client/*.pdf > /dev/null 2>&1; then
  pass "10. PDF install guide present in client/"
else
  fail "10. no PDF install guide in client/ (export client/INSTALL-GUIDE.md to PDF)"
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "ALL CHECKS GREEN"; else echo "CHECKS FAILED"; exit 1; fi
