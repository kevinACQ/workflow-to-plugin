#!/usr/bin/env bash
# sweep-canary.sh: proves the publish gate (scripts/sweep.sh) actually catches leaks.
# Builds a throwaway sample repo in a temp folder, plants one leak at a time (fake key, fake
# member email, never-ship word, machine path, phone number, giant file, a secret hidden in
# git history, a missing never-ship list), and checks the sweep FAILS on each with the right
# check. Then checks that clean and fictional data PASS. Nothing here touches your real files.
# All fake values are generated at run time, so this script contains no key-shaped text.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SWEEP="$HERE/sweep.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bad=0
ran=0
gitc() { git -C "$1" -c user.name=Canary -c user.email=canary@example.com "${@:2}"; }
rand() { LC_ALL=C tr -dc "$1" < /dev/urandom | head -c "$2"; }

# Never-ship list lives OUTSIDE the sample repo, like the real one.
DENY="$TMP/never-ship.txt"
cat > "$DENY" <<'EOF'
# fictional company, staff, internal ID, and table name
Fernhollow Supply
Dana Quillfeather
84731920
crm_member_ledger
EOF

# A clean sample plugin repo, committed once.
BASE="$TMP/base"
mkdir -p "$BASE/.claude-plugin" "$BASE/skills/hello" "$BASE/tests"
cat > "$BASE/.claude-plugin/plugin.json" <<'EOF'
{"name": "canary-sample", "description": "Sweep canary sample", "version": "0.0.1", "author": {"name": "Sample Owner"}}
EOF
cat > "$BASE/skills/hello/SKILL.md" <<'EOF'
---
name: hello
description: Canary sample skill that greets the user by the name in their config.
---

# Hello

Read the user's name from config.json and say hello.
EOF
echo '{"name": "Your Name"}' > "$BASE/config.example.json"
echo "config.json" > "$BASE/.gitignore"
printf 'Sample Owner owns this kit.\n' > "$BASE/README.md"
git init -q "$BASE" && gitc "$BASE" add -A && gitc "$BASE" commit -qm "clean sample"

fresh() { rm -rf "$TMP/case"; cp -R "$BASE" "$TMP/case"; echo "$TMP/case"; }

# expect NAME EXPECT(PASS|FAIL) CHECK_REGEX MODE [extra sweep args...]
expect() {
  local name="$1" want="$2" check="$3" mode="$4"; shift 4
  local out rc got ok
  out="$(bash "$SWEEP" --for "$mode" --denylist "$DENY" "$@" "$TMP/case" 2>&1)"; rc=$?
  case "$rc" in 0) got=PASS ;; 1) got=FAIL ;; *) got="ERROR($rc)" ;; esac
  ok=yes
  [ "$got" = "$want" ] || ok=no
  if [ "$ok" = yes ] && [ -n "$check" ] && ! printf '%s\n' "$out" | grep -qE "$check"; then ok=no; fi
  ran=$((ran + 1))
  if [ "$ok" = yes ]; then
    printf '  ok    %-62s expected %s, got %s\n' "$name" "$want" "$got"
  else
    bad=$((bad + 1))
    printf '  WRONG %-62s expected %s, got %s\n' "$name" "$want" "$got"
    printf '%s\n' "$out" | sed 's/^/          | /' | head -40
  fi
}

echo "Sweep canary: planting fake leaks in a throwaway repo, one at a time"
echo

# --- The headline test: plant a fake key and a fake member email, then remove them.
d="$(fresh)"
key="AKIA$(rand 'A-Z2-7' 16)"
mail_domain="gmail"
member="jordan.member$(rand '0-9' 3)@${mail_domain}.com"
printf 'AWS_ACCESS_KEY_ID = "%s"\n' "$key" > "$d/settings.py"
printf 'name,email\nJordan Member,%s\n' "$member" > "$d/tests/members.csv"
expect "fake key + fake member email planted -> must FAIL" FAIL '^\[FAIL\] 1\..*' public
expect "  ...and the email is named too" FAIL '^\[FAIL\] 3\..*' public
rm -f "$d/settings.py" "$d/tests/members.csv"
expect "same leaks removed -> must PASS" PASS 'SWEEP: PASS' public

# --- One leak at a time, each must trip its own check.
d="$(fresh)"; printf 'Built for Fernhollow Supply.\n' >> "$d/skills/hello/SKILL.md"
expect "never-ship company name in a skill -> FAIL (check 2)" FAIL '^\[FAIL\] 2\.' public

d="$(fresh)"; printf 'SELECT * FROM crm_member_ledger WHERE portal = 84731920;\n' > "$d/skills/hello/query.sql"
expect "internal table name + internal ID -> FAIL (check 2)" FAIL '^\[FAIL\] 2\.' public

d="$(fresh)"; mkdir -p "$d/skills/fernhollow-supply"; printf -- '---\nname: x\ndescription: y\n---\n' > "$d/skills/fernhollow-supply/SKILL.md"
expect "never-ship word in a FILE NAME -> FAIL (check 2)" FAIL 'file name' public

d="$(fresh)"; u="Users"; who="pat"; printf 'cd /%s/%s/work/kit\n' "$u" "$who" > "$d/run.sh"
expect "absolute machine path -> FAIL (check 5)" FAIL '^\[FAIL\] 5\.' public

d="$(fresh)"; printf 'Call Dana at (415) 8%s-%s\n' "$(rand '0-9' 2)" "$(rand '0-9' 4)" >> "$d/README.md"
expect "real-looking phone number -> FAIL (check 4)" FAIL '^\[FAIL\] 4\.' public

d="$(fresh)"; head -c 11534336 /dev/zero > "$d/render.mov"
expect "11 MB file -> FAIL (check 6)" FAIL '^\[FAIL\] 6\.' public

d="$(fresh)"; printf 'token = "ghp_%s"\n' "$(rand 'A-Za-z0-9' 36)" > "$d/old.py"
gitc "$d" add -A && gitc "$d" commit -qm "add helper" && git -C "$d" rm -q old.py && gitc "$d" commit -qm "remove helper"
expect "secret deleted but still in git history -> FAIL" FAIL 'in commit [0-9a-f]{7}' public

d="$(fresh)"
expect "never-ship list missing -> FAIL" FAIL 'missing or empty' public --denylist "$TMP/does-not-exist.txt"

d="$(fresh)"; cp "$DENY" "$d/never-ship.txt"; gitc "$d" add never-ship.txt
expect "never-ship list committed inside the repo -> FAIL" FAIL 'inside this repo' public --denylist "$d/never-ship.txt"

d="$(fresh)"; gitc "$d" commit -q --allow-empty -m "notes from the Fernhollow Supply call"
expect "never-ship word in a commit message -> FAIL" FAIL 'commit message' public

d="$(fresh)"; tok="tok_$(rand 'A-Za-z0-9' 20)"; printf 'ID = "%s"\n' "$tok" > "$d/ids.py"
printf 're:tok_[A-Za-z0-9]{20}\n' > "$TMP/never-ship-re.txt"
expect "re: pattern hit -> FAIL (check 2)" FAIL '^\[FAIL\] 2\.' public --denylist "$TMP/never-ship-re.txt"
ran=$((ran + 1))
if bash "$SWEEP" --for public --denylist "$TMP/never-ship-re.txt" "$TMP/case" 2>&1 | grep -qF "$tok"; then
  bad=$((bad + 1)); printf '  WRONG %-62s the full matched text was printed\n' "  ...and the matched text stays hidden"
else
  printf '  ok    %-62s only the first 4 characters print\n' "  ...and the matched text stays hidden"
fi

# --- No false alarms on fictional data, and audience rules behave.
d="$(fresh)"; printf 'Contact: owner@example.com, tester@shop.test, (312) 555-0142, ~/bin, /Users/you/kit\n' >> "$d/README.md"
expect "fictional email/phone/path only -> PASS" PASS 'SWEEP: PASS' public

tld="com"; owner_mail="help@ownerco.$tld"
d="$(fresh)"; printf 'Questions: %s\n' "$owner_mail" >> "$d/README.md"
expect "owner email NOT yet approved -> FAIL (check 3)" FAIL '^\[FAIL\] 3\.' public
printf '%s\n' "$owner_mail" > "$d/.sweep-allow"
expect "owner email approved in .sweep-allow -> PASS" PASS 'SWEEP: PASS' public

d="$(fresh)"; printf 'Internal notes for Fernhollow Supply staff.\n' >> "$d/README.md"
expect "client kit: never-ship word outside skills/ -> PASS + WARN" PASS '^\[WARN\] 2b' client
printf 'Made by Fernhollow Supply.\n' >> "$d/skills/hello/SKILL.md"
expect "client kit: never-ship word inside skills/ -> FAIL" FAIL '^\[FAIL\] 2\.' client

d="$(fresh)"; printf 'Ask Dana Quillfeather for access.\n' >> "$d/skills/hello/SKILL.md"
expect "team kit: never-ship word in a skill -> PASS + WARN" PASS '^\[WARN\] 2b' team

echo
if [ "$bad" -eq 0 ]; then
  echo "CANARY: PASS ($ran/$ran cases behaved: every planted leak was caught, clean data passed)."
  exit 0
fi
echo "CANARY: FAIL ($bad of $ran cases misbehaved; see WRONG lines above). The sweep can't be trusted until this passes."
exit 1
