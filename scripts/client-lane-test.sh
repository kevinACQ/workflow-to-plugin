#!/usr/bin/env bash
# client-lane-test.sh: proves the client lane works end to end on a throwaway sample kit.
# Builds a 2-skill client kit from the templates, then checks: zips build and pass every check,
# a private gitignored file stays out of the zips, and each kind of mistake gets caught
# (never-ship word in a skill, stale zip, open-source license, unfilled install prompt,
# description over 1024 characters). Nothing here touches your real files.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$HERE/.." && pwd)"
TPL="$KIT/skills/workflow-to-plugin/templates/client"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SWEEP_DENYLIST="$TMP/never-ship.txt"
printf 'Fictional Seller Co\n' > "$SWEEP_DENYLIST"

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
mkdir -p "$C/scripts" "$C/client" "$C/skills/lead-magnet" "$C/skills/offer-writer"
cp "$HERE/sweep.sh" "$HERE/build_client_zips.sh" "$HERE/check_kit.sh" "$C/scripts/"
cp "$TPL/kit.conf" "$C/client/"
sed -e 's/{{YEAR}}/2026/' -e 's/{{YOUR NAME OR COMPANY}}/Sample Seller/g' -e 's/{{SUPPORT CONTACT}}/help@seller.example.com/' \
  "$TPL/LICENSE-proprietary.txt" > "$C/LICENSE"
sed -E 's#\{\{DOWNLOAD LINK ([0-9])\}\}#https://files.example.com/skill\1#; s#\{\{[^}]*\}\}#filled#g' \
  "$TPL/INSTALL-PROMPT.txt" > "$C/client/INSTALL-PROMPT.txt"
printf '%%PDF-1.4\n%% sample\n' > "$C/client/Sample-Install-Guide.pdf"
printf -- '---\nname: lead-magnet\ndescription: Writes a lead magnet outline when the user asks for a lead magnet or opt-in offer.\n---\n\n# Lead magnet\n\nAsk three questions, then write the outline.\n' \
  > "$C/skills/lead-magnet/SKILL.md"
printf -- '---\nname: offer-writer\ndescription: >\n  Turns a rough idea into a one-page offer when the user says\n  "write my offer".\n---\n\n# Offer writer\n\nInterview, then draft.\n' \
  > "$C/skills/offer-writer/SKILL.md"
printf '{"name": "Private Value"}\n' > "$C/skills/offer-writer/config.json"
echo "config.json" > "$C/.gitignore"
git init -q "$C" && git -C "$C" add -A && git -C "$C" -c user.name=T -c user.email=t@example.com commit -qm "sample client kit"

echo "Client lane test: building a throwaway 2-skill client kit"
echo
check "zips build from a clean kit" 0 'built dist/offer-writer.zip' -- bash "$C/scripts/build_client_zips.sh"
check "all kit checks green" 0 'ALL CHECKS GREEN' -- bash "$C/scripts/check_kit.sh"
check "gitignored config.json stays out of the zip" 0 '^offer-writer/SKILL.md$' -- sh -c "unzip -Z1 '$C/dist/offer-writer.zip' | grep -v config.json"
check "  ...and is really absent" 1 '^' -- sh -c "unzip -Z1 '$C/dist/offer-writer.zip' | grep config.json"

echo "Edited after build." >> "$C/skills/lead-magnet/SKILL.md"
check "skill edited after build -> stale zip caught (check 7)" 1 'FAIL 7\.' -- bash "$C/scripts/check_kit.sh"
git -C "$C" checkout -q skills/lead-magnet/SKILL.md

echo "Built for Fictional Seller Co." >> "$C/skills/offer-writer/SKILL.md"
check "never-ship word in a skill -> build stops" 1 'BUILD STOPPED' -- bash "$C/scripts/build_client_zips.sh"
git -C "$C" checkout -q skills/offer-writer/SKILL.md

cp "$C/LICENSE" "$TMP/LICENSE.bak"
printf 'MIT License\n\nPermission is hereby granted, free of charge...\n' > "$C/LICENSE"
check "open-source license on a paid kit -> caught (check 8)" 1 'FAIL 8\.' -- bash "$C/scripts/check_kit.sh"
cp "$TMP/LICENSE.bak" "$C/LICENSE"

cp "$C/client/INSTALL-PROMPT.txt" "$TMP/prompt.bak"
echo "3. {{DOWNLOAD LINK 3}}" >> "$C/client/INSTALL-PROMPT.txt"
check "unfilled install prompt -> caught (check 10)" 1 'FAIL 10\.' -- bash "$C/scripts/check_kit.sh"
cp "$TMP/prompt.bak" "$C/client/INSTALL-PROMPT.txt"

long="$(printf 'x%.0s' $(seq 1 1030))"
printf -- '---\nname: lead-magnet\ndescription: %s\n---\nbody\n' "$long" > "$C/skills/lead-magnet/SKILL.md"
check "description over 1024 characters -> caught (check 3)" 1 'FAIL 3\.' -- bash "$C/scripts/check_kit.sh"
git -C "$C" checkout -q skills/lead-magnet/SKILL.md

check "restored kit is green again" 0 'ALL CHECKS GREEN' -- bash "$C/scripts/check_kit.sh"

echo
if [ "$bad" -eq 0 ]; then
  echo "CLIENT LANE: PASS ($ran/$ran cases behaved)."
  exit 0
fi
echo "CLIENT LANE: FAIL ($bad of $ran cases misbehaved; see WRONG lines above)."
exit 1
