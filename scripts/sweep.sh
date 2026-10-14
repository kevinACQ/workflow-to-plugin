#!/usr/bin/env bash
# sweep.sh: the publish gate. Nothing is published, pushed, zipped for a client, or uploaded
# until this prints "SWEEP: PASS".
#
# Usage: scripts/sweep.sh [--for public|team|client] [--denylist FILE] [--allow FILE] [REPO_DIR]
#
#   --for public   (default) anyone can see the repo: every check blocks.
#   --for team     private repo for coworkers: never-ship words and past-version hits only warn.
#   --for client   private repo; clients receive skills/ and client/ only: never-ship words
#                  block there, warn elsewhere.
#   --denylist     the owner's "never ship" list (default: $SWEEP_DENYLIST, else
#                  ~/.config/workflow-to-plugin/never-ship.txt). It holds the very words that
#                  must not leak, so it lives OUTSIDE the repo. Missing or empty list = FAIL.
#   --allow        strings approved to appear in this repo (default: REPO_DIR/.sweep-allow).
#                  A "file:<path>" line approves one whole file for checks 3-5, 8 and 9 after
#                  the owner has looked at it (a fictional test transcript, a numeric data table).
#
# What it checks, on everything the audience can see (current files, every past version in
# git history, commit messages, file names, commit author emails):
#   1. secrets (gitleaks)   2. never-ship words   3. emails   4. phone numbers
#   5. absolute machine paths (5b warns on home-folder paths into the owner's own setup)
#   6. files over 10 MB   7. commit author emails (public only)   8. recordings and transcripts
#   9. text inside PDFs, Office files, zips, and media tags (unreadable documents block)
# Exit codes: 0 PASS, 1 FAIL, 2 setup problem (not a git repo, gitleaks missing, bad option).
set -u

MODE=public
DENYLIST="${SWEEP_DENYLIST:-$HOME/.config/workflow-to-plugin/never-ship.txt}"
ALLOW=""
REPO=""
MAX_BYTES=10485760   # 10 MB
SHOW=15              # max hits printed per check

die() { echo "SWEEP: ERROR: $1" >&2; exit 2; }
need_arg() { [ "$2" -ge 2 ] || die "$1 needs a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --for) need_arg "$1" $#; MODE="$2"; shift 2 ;;
    --for=*) MODE="${1#--for=}"; shift ;;
    --denylist) need_arg "$1" $#; DENYLIST="$2"; shift 2 ;;
    --denylist=*) DENYLIST="${1#--denylist=}"; shift ;;
    --allow) need_arg "$1" $#; ALLOW="$2"; shift 2 ;;
    --allow=*) ALLOW="${1#--allow=}"; shift ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) REPO="$1"; shift ;;
  esac
done

case "$MODE" in public|team|client) ;; *) die "--for must be public, team, or client" ;; esac

REPO="$(cd "${REPO:-.}" 2>/dev/null && pwd -P)" || die "repo folder not found"
top="$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null)" || die "$REPO is not a git repo. Run 'git init' there first: the sweep uses git to know exactly what will be published."
top="$(cd "$top" && pwd -P)"
[ "$top" = "$REPO" ] || die "$REPO is inside another git repo ($top). Give the packaged workflow its own repo ('git init' in its folder) and sweep that."

GITLEAKS="$(command -v gitleaks 2>/dev/null || true)"
[ -z "$GITLEAKS" ] && [ -x "$HOME/bin/gitleaks" ] && GITLEAKS="$HOME/bin/gitleaks"
[ -n "$GITLEAKS" ] || die "gitleaks not found. Install it (no admin needed): download the release for your computer from https://github.com/gitleaks/gitleaks/releases into ~/bin, then re-run. scripts/doctor.sh checks this."

[ -z "$ALLOW" ] && [ -f "$REPO/.sweep-allow" ] && ALLOW="$REPO/.sweep-allow"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
g() { git -C "$REPO" "$@"; }

blocking=0
warnings=0
report() { # report SEVERITY "title" FILE_WITH_HITS ; SEVERITY = FAIL or WARN
  local sev="$1" title="$2" file="$3" n
  n=$(grep -c . "$file" 2>/dev/null || true)
  if [ "${n:-0}" -eq 0 ]; then
    printf '[PASS] %s\n' "$title"
    return
  fi
  printf '[%s] %s: %s hit(s)\n' "$sev" "$title" "$n"
  [ "$n" -gt "$SHOW" ] && tally "$file"
  head -n "$SHOW" "$file" | sed 's/^/         /'
  [ "$n" -gt "$SHOW" ] && printf '         ... and %s more\n' "$((n - SHOW))"
  if [ "$sev" = FAIL ]; then blocking=$((blocking + 1)); else warnings=$((warnings + 1)); fi
}

lower() { tr '[:upper:]' '[:lower:]'; }

tally() { # one-line "what was found, how often" summary for long hit lists
  awk '
    / \(in past commit [0-9a-f]+\)$/ { m=$0; sub(/  \(in past commit [0-9a-f]+\)$/, "", m); sub(/^[^:]*: /, "", m) }
    !/ \(in past commit / && !/\(file name\)$/ && !/^commit message / { m=$0; sub(/^[^:]*:[^:]*:/, "", m) }
    /\(file name\)$/ || /^commit message / { next }
    { c[tolower(m)]++ }
    END { for (k in c) printf "%d\t%s\n", c[k], k }' "$1" | sort -rn | head -n 12 \
    | awk -F'\t' 'BEGIN{ printf "         found: " } { printf "%s%s (%d)", (NR>1 ? ", " : ""), $2, $1 } END{ print "" }'
}

# Clean list files: drop blanks and full-line comments, trim spaces and Windows line endings.
clean_list() { sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^#' | grep -v '^$' || true; }

: > "$TMP/allow"
[ -n "$ALLOW" ] && [ -f "$ALLOW" ] && clean_list "$ALLOW" | lower > "$TMP/allow"
allowed() { [ -s "$TMP/allow" ] && printf '%s\n' "$1" | lower | grep -qxF -f "$TMP/allow"; }
# "file:<path>" lines: whole files the owner has looked at and approved (case kept: paths).
: > "$TMP/allow_files"
[ -n "$ALLOW" ] && [ -f "$ALLOW" ] && { clean_list "$ALLOW" | sed -n 's/^file:[[:space:]]*//p' > "$TMP/allow_files"; }
drop_allowed_files() { # drop hit lines ("path:..." or "path: ...") whose path is approved
  if [ -s "$TMP/allow_files" ]; then awk 'NR==FNR { ok[$0]=1; next } { p=$0; sub(/:.*/, "", p) } !(p in ok)' "$TMP/allow_files" -; else cat; fi
}

# What the audience can see: current files that git would publish (tracked + new, minus
# .gitignore'd), and every past commit.
g ls-files -co --exclude-standard | while IFS= read -r f; do [ -f "$REPO/$f" ] && printf '%s\n' "$f"; done > "$TMP/files"
g rev-list --all > "$TMP/revs" 2>/dev/null || : > "$TMP/revs"
nfiles=$(grep -c . "$TMP/files" || true)
nrevs=$(grep -c . "$TMP/revs" || true)

# Severity of past-version (history) hits: anyone who can see a public repo can read its
# history; a private repo's history is only seen by people with repo access.
if [ "$MODE" = public ]; then HIST_SEV=FAIL; else HIST_SEV=WARN; fi

# Binary documents (PDFs, images, archives, media, Office files) look like text to git but are
# compressed bytes: the plain-text checks skip them. Check 9 pulls the text out of the ones it
# can read; the rest are listed at the end. Keep each shipped PDF's source text in the repo.
BIN_EXT="pdf png jpg jpeg gif webp ico heic psd zip gz tgz bz2 7z rar mp4 mov m4v mp3 m4a wav aac woff woff2 ttf otf eot docx xlsx pptx key pages numbers sqlite db"
SPEC=(.)
for x in $BIN_EXT; do SPEC+=(":(exclude,icase)*.$x"); done
is_bin_ext() { local e; e="$(printf '%s' "${1##*.}" | lower)"; case " $BIN_EXT " in *" $e "*) return 0 ;; esac; return 1; }
# Numeric data tables (color LUTs) are rows of 3-4 digit numbers: thousands of fake "phone
# numbers" and no place for a real one. Checks 3-5 skip them; checks 1 and 2 still read them.
DATA_EXT="3dl cube lut csp"
XSPEC=()

tree_grep() { g grep --untracked -I -n -o "$@" -- "${SPEC[@]}" ${XSPEC[@]+"${XSPEC[@]}"} 2>/dev/null || true; }   # path:line:match
hist_grep() {                                                               # path: match (in <sha>)
  [ "$nrevs" -gt 0 ] || return 0
  # shellcheck disable=SC2046  # one argument per commit is intended
  git -C "$REPO" grep -I -o "$@" $(cat "$TMP/revs") -- "${SPEC[@]}" ${XSPEC[@]+"${XSPEC[@]}"} 2>/dev/null \
    | awk -F: '{ sha=substr($1,1,7); path=$2; m=$0; sub(/^[^:]*:[^:]*:/, "", m); k=path SUBSEP m; if (!(k in seen)) { seen[k]=1; print path ": " m "  (in past commit " sha ")" } }' || true
}

echo "Sweep for: $MODE | repo: $REPO"
echo "Scanning $nfiles current file(s) and $nrevs past commit(s)."
echo

# ---------------------------------------------------------------------------------------
# 1. Secrets: gitleaks on the files about to be published, then on every past commit.
stage="$TMP/stage"; mkdir -p "$stage"
(cd "$REPO" && tr '\n' '\0' < "$TMP/files" | tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$stage" 2>/dev/null
parse_leaks() { awk '/^RuleID:/{r=$2} /^File:/{f=$2} /^Line:/{l=$2} /^Commit:/{c=substr($2,1,7)} /^Fingerprint:/{ if (c!="") print f ":" l "  " r "  (in commit " c ")"; else print f ":" l "  " r; r=f=l=c="" }' "$1"; }
run_gitleaks() { # exit 0 = clean, 3 = leaks found, anything else = gitleaks itself broke (counts as FAIL)
  local out="$1" rc; shift
  "$GITLEAKS" "$@" --no-banner --no-color --redact -v -l error --exit-code 3 > "$out" 2>&1; rc=$?
  case "$rc" in
    0|3) parse_leaks "$out" ;;
    *) echo "gitleaks could not finish ($*): exit $rc. Treating as FAIL until it runs clean." ;;
  esac
}
(cd "$stage" && run_gitleaks "$TMP/gl_dir.txt" dir . --max-archive-depth 3) > "$TMP/leaks"
if [ "$nrevs" -gt 0 ]; then
  run_gitleaks "$TMP/gl_git.txt" git "$REPO" --log-opts="--all" >> "$TMP/leaks"
fi
report FAIL "1. Secrets (keys, tokens, passwords) in files or history" "$TMP/leaks"

# ---------------------------------------------------------------------------------------
# 2. Never-ship words: the owner's list of company, staff, and customer names, internal IDs,
#    internal domains, and table names. Matched as whole words, any capitalization.
: > "$TMP/deny_fail"; : > "$TMP/deny_warn"
if [ ! -s "$DENYLIST" ]; then
  echo "never-ship list missing or empty: $DENYLIST" > "$TMP/deny_fail"
  echo "  (fill it in first; template: skills/workflow-to-plugin/templates/never-ship.example.txt)" >> "$TMP/deny_fail"
else
  clean_list "$DENYLIST" > "$TMP/deny_all"
  # Multi-word names also hide as slugs: "Jane Doe" -> jane-doe, jane_doe, janedoe.
  grep -v '^re:' "$TMP/deny_all" | while IFS= read -r t; do
    printf '%s\n' "$t"
    case "$t" in *" "*) printf '%s\n' "$t" | tr ' ' '-'; printf '%s\n' "$t" | tr ' ' '_'; printf '%s\n' "$t" | tr -d ' ' ;; esac
  done | sort -u > "$TMP/terms_raw"
  grep '^re:' "$TMP/deny_all" | sed 's/^re:[[:space:]]*//' > "$TMP/regexes" || true
  # git's -E grep silently ignores \b, \d, \w and \s on macOS (the pattern then matches nothing).
  # Patterns that use them run with -P (Perl syntax) instead; if this git can't, the sweep stops.
  RE_FLAG=-E
  if grep -q '\\[bBdDwWsS]' "$TMP/regexes" 2>/dev/null; then
    g grep -q -P -e x -- .sweep-pcre-probe >/dev/null 2>&1
    if [ $? -le 1 ]; then RE_FLAG=-P
    else echo "a re: pattern uses \\b, \\d, \\w or \\s, which this computer's git can't read. Rewrite it with [0-9], [A-Za-z0-9_] or [[:space:]]." >> "$TMP/deny_fail"; fi
  fi
  if [ -s "$TMP/allow" ]; then grep -vixF -f "$TMP/allow" "$TMP/terms_raw" > "$TMP/terms" || true; else cp "$TMP/terms_raw" "$TMP/terms"; fi
  denyabs="$(cd "$(dirname "$DENYLIST")" && pwd -P)/$(basename "$DENYLIST")"
  case "$denyabs" in
    "$REPO"/*)
      rel="${denyabs#"$REPO"/}"
      if grep -qxF "$rel" "$TMP/files"; then
        echo "$rel: the never-ship list itself is inside this repo and would be published. Move it outside the repo." >> "$TMP/deny_fail"
      fi ;;
  esac
  if [ ! -s "$TMP/terms" ] && [ ! -s "$TMP/regexes" ]; then
    echo "never-ship list has no words in it: $DENYLIST" >> "$TMP/deny_fail"
  fi
  # re: patterns can match secret-shaped text, so their hits print only the first 4 characters.
  hide() { awk -v n="$1" '{ suf = ""; if (match($0, /  \(in past commit [0-9a-f]+\)$/)) { suf = substr($0, RSTART); $0 = substr($0, 1, RSTART - 1) }
    m = $0; for (i = 0; i < n; i++) sub(/^[^:]*:/, "", m); sub(/^ /, "", m)
    pre = substr($0, 1, length($0) - length(m)); if (length(m) > 6) m = substr(m, 1, 4) "...(" length(m) " chars, hidden)"
    print pre m suf }'; }
  deny_tree() { [ -s "$TMP/terms" ] && tree_grep -F -i -w -f "$TMP/terms"; [ -s "$TMP/regexes" ] && tree_grep "$RE_FLAG" -i -f "$TMP/regexes" | hide 2; true; }
  deny_hist() { [ -s "$TMP/terms" ] && hist_grep -F -i -w -f "$TMP/terms"; [ -s "$TMP/regexes" ] && hist_grep "$RE_FLAG" -i -f "$TMP/regexes" | hide 1; true; }
  deny_names() { # file names (current and past) that contain a never-ship word
    { cat "$TMP/files"; [ "$nrevs" -gt 0 ] && g log --all --format= --name-only 2>/dev/null; } | grep -v '^$' | sort -u > "$TMP/allnames"
    { [ -s "$TMP/terms" ] && grep -iwF -f "$TMP/terms" "$TMP/allnames"; [ -s "$TMP/regexes" ] && grep -iE -f "$TMP/regexes" "$TMP/allnames"; true; } | sort -u | sed 's/$/  (file name)/'
  }
  deny_msgs() { # commit messages
    [ "$nrevs" -gt 0 ] || return 0
    g log --all --format='@@%h%n%B' 2>/dev/null | awk '/^@@/{sha=substr($0,3); next} NF{print sha "\t" $0}' > "$TMP/msgs"
    { [ -s "$TMP/terms" ] && grep -iwF -f "$TMP/terms" "$TMP/msgs"
      [ -s "$TMP/regexes" ] && grep -iE -f "$TMP/regexes" "$TMP/msgs" | awk -F'\t' '{ print $1 "\t(matches a re: pattern; text hidden)" }'; true; } \
      | awk -F'\t' '{print "commit message " $1 ": " $2}'
  }
  case "$MODE" in
    public)
      { deny_tree; deny_names; deny_hist; deny_msgs; } >> "$TMP/deny_fail" ;;
    team)
      { deny_tree; deny_names; deny_hist; deny_msgs; } >> "$TMP/deny_warn" ;;
    client)
      # Clients receive skills/ and client/: any hit there blocks the release.
      deny_tree > "$TMP/dt"; deny_names > "$TMP/dn"
      grep -E '^(skills|client)/' "$TMP/dt" >> "$TMP/deny_fail" || true
      grep -E '^(skills|client)/' "$TMP/dn" >> "$TMP/deny_fail" || true
      grep -vE '^(skills|client)/' "$TMP/dt" >> "$TMP/deny_warn" || true
      grep -vE '^(skills|client)/' "$TMP/dn" >> "$TMP/deny_warn" || true
      { deny_hist; deny_msgs; } >> "$TMP/deny_warn" ;;
  esac
fi
case "$MODE" in
  public) report FAIL "2. Never-ship words (files, file names, history, commit messages)" "$TMP/deny_fail" ;;
  team)   report FAIL "2. Never-ship list is set up" "$TMP/deny_fail"
          report WARN "2b. Never-ship words in a team repo: move personal values to config.example.json or userConfig" "$TMP/deny_warn" ;;
  client) report FAIL "2. Never-ship words in what clients receive (skills/, client/)" "$TMP/deny_fail"
          report WARN "2b. Never-ship words in the private repo (not sent to clients)" "$TMP/deny_warn" ;;
esac

# ---------------------------------------------------------------------------------------
# Shared filter for checks 3-5: drop hits the rules or the allow file approve.
EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
PHONE_RE='(^|[^0-9A-Za-z+])(\+?1[ .-]?)?\(?[2-9][0-9]{2}\)?[ .-][0-9]{3}[ .-][0-9]{4}([^0-9]|$)|\+[1-9][0-9]{0,2}[ .-]?[0-9]{1,4}([ .-][0-9]{2,4}){2,4}'
PATH_RE='/(Users|home)/[A-Za-z][A-Za-z0-9._-]*|[A-Za-z]:(\\)+Users(\\)+[A-Za-z][A-Za-z0-9._-]*'

email_ok() {
  local e dom loc
  e="$(printf '%s' "$1" | lower)"; dom="${e#*@}"; loc="${e%@*}"
  case "$dom" in
    example.com|example.org|example.net|*.example.com|*.example.org|*.example.net) return 0 ;;
    test|*.test|example|*.example|invalid|*.invalid|localhost|*.localhost) return 0 ;;
    users.noreply.github.com) return 0 ;;
  esac
  case "$loc" in noreply|no-reply|git) return 0 ;; esac
  allowed "$e"
}
phone_ok() {
  local d
  d="$(printf '%s' "$1" | tr -cd '0-9')"
  case "$d" in *55501[0-9][0-9]) return 0 ;; esac   # 555-0100..0199: reserved fictional numbers
  allowed "$(printf '%s' "$1" | sed -e 's/^[^0-9+(]*//' -e 's/[^0-9]*$//')"
}
path_ok() {
  local name
  name="$(printf '%s' "$1" | sed -E 's#^.*[/\\](Users|home)[/\\]##' | lower)"
  case "$name" in you|yourname|your-name|username|user|name|example|me|shared) return 0 ;; esac
  allowed "$1"
}
filter_hits() { # filter_hits CHECKER < hits ; hit lines end in the matched text after the last ": " or ":"
  local fn="$1" line m
  while IFS= read -r line; do
    case "$line" in
      *"  (in past commit "*) m="${line%  (in past commit *}"; m="${m#*: }" ;;
      *) m="${line#*:}"; m="${m#*:}" ;;
    esac
    "$fn" "$m" || printf '%s\n' "$line"
  done
}
# Fast pass before counting: drop the reserved fictional forms (the full rules still run after),
# so a big fixture of example.com emails or 555-01xx phones is never mistaken for data.
EMAIL_SAFE='(@([A-Za-z0-9-]+\.)*(example\.(com|org|net)|test|example|invalid|localhost|users\.noreply\.github\.com)|(^|[^A-Za-z0-9._%+-])(noreply|no-reply|git)@[^ ]*)(  \(in past commit [0-9a-f]+\))?$'
PHONE_SAFE='555[ .-]?01[0-9]{2}([^0-9]|$)'
prefilter() { # prefilter CHECKER < hits
  case "$1" in
    email_ok) grep -v -i -E -e "$EMAIL_SAFE" || true ;;
    phone_ok) grep -v -E -e "$PHONE_SAFE" || true ;;
    *) cat ;;
  esac
}
CAP=200   # a file with more hits than this on one check is reported once, as one finding
collapse() { # one summary line for any file over CAP hits: fast, and a data file is one finding
  awk -v cap="$CAP" '{ p=$0; sub(/:.*/, "", p); n[p]++; L[NR]=$0; P[NR]=p }
    END { for (i = 1; i <= NR; i++) if (n[P[i]] <= cap) print L[i]; else if (!(P[i] in s)) { s[P[i]] = 1
      print P[i] ": " n[P[i]] " matches, too many to list (open it; then remove it, or approve it with file:" P[i] " in .sweep-allow)" } }'
}
scan_pattern() { # scan_pattern REGEX CHECKER TITLE  -> FAIL for current files, history per mode
  XSPEC=(); for x in $DATA_EXT; do XSPEC+=(":(exclude,icase)*.$x"); done
  tree_grep -E -e "$1" | drop_allowed_files | prefilter "$2" | collapse | filter_hits "$2" > "$TMP/hit_tree"
  hist_grep -E -e "$1" | drop_allowed_files | prefilter "$2" | collapse | filter_hits "$2" > "$TMP/hit_hist"
  XSPEC=()
  if [ "$HIST_SEV" = FAIL ]; then
    cat "$TMP/hit_hist" >> "$TMP/hit_tree"
    report FAIL "$3 (files and history)" "$TMP/hit_tree"
  else
    report FAIL "$3 (current files)" "$TMP/hit_tree"
    report WARN "$3 (past versions; private repo)" "$TMP/hit_hist"
  fi
}

# 3. Emails: only reserved test domains (example.com/.org/.net, .test, .example, .invalid),
#    noreply addresses, and strings in the allow file may appear.
scan_pattern "$EMAIL_RE" email_ok "3. Real-looking email addresses"
# 4. Phone numbers: only 555-01xx fictional numbers or allow-file entries.
scan_pattern "$PHONE_RE" phone_ok "4. Real-looking phone numbers"
# 5. Absolute machine paths (they leak usernames and break on everyone else's computer).
scan_pattern "$PATH_RE" path_ok "5. Absolute machine paths (/Users/<name>, /home/<name>)"
# 5b. Home-folder paths in code that point into the owner's own setup (~/Documents/<this kit>,
#     ~/.claude/skills): they leak no username but only work on the owner's computer. Warn only.
#     Comment lines and dot-folders (~/.config/<kit>, ~/.cache/<kit>: per-user settings) are fine.
kitnames="$( { basename "$REPO"; cat "$REPO"/.claude-plugin/*.json "$REPO"/plugins/*/.claude-plugin/plugin.json 2>/dev/null \
  | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'; } | sort -u | sed 's/[][\.*^$()+?{}|]/\\&/g' | paste -sd'|' -)"
HOMEDIR_RE="(~|\\\$HOME|\\\$\\{HOME\\}|Path\\.home\\(\\)|os\\.homedir\\(\\))"
HOME_RE="${HOMEDIR_RE}.{0,40}\\.claude/skills|${HOMEDIR_RE}(/[^./\"' ][^/\"']*)*/($kitnames)(/|[\"']|\$)"
g grep --untracked -I -n -E -e "$HOME_RE" -- '*.py' '*.sh' '*.bash' '*.zsh' '*.js' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.rb' '*.json' 2>/dev/null \
  | awk '{ c=$0; sub(/^[^:]*:[^:]*:/, "", c) } c !~ /^[[:space:]]*(#|\/\/)/' | drop_allowed_files | cut -c1-160 > "$TMP/homepaths" || true
report WARN "5b. Home-folder paths into the owner's own setup (work only on the owner's computer)" "$TMP/homepaths"

# ---------------------------------------------------------------------------------------
# 6. Files over 10 MB, now and in history (renders, models, exports, node_modules).
: > "$TMP/big"
while IFS= read -r f; do
  s=$(wc -c < "$REPO/$f" | tr -d ' ')
  [ "$s" -gt "$MAX_BYTES" ] && echo "$f  ($((s / 1048576)) MB)" >> "$TMP/big"
done < "$TMP/files"
: > "$TMP/bighist"
if [ "$nrevs" -gt 0 ]; then
  g rev-list --objects --all | g cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' \
    | awk -v max="$MAX_BYTES" '$1=="blob" && $2>max { s=$2; $1=""; $2=""; sub(/^  /,""); print $0 "  (" int(s/1048576) " MB, in history)" }' > "$TMP/bighist"
fi
if [ "$HIST_SEV" = FAIL ]; then cat "$TMP/bighist" >> "$TMP/big"; report FAIL "6. Files over 10 MB (files and history)" "$TMP/big"
else report FAIL "6. Files over 10 MB (current files)" "$TMP/big"; report WARN "6. Files over 10 MB (past versions; private repo)" "$TMP/bighist"; fi

# 7. Commit author emails are published with a public repo's history.
if [ "$MODE" = public ] && [ "$nrevs" -gt 0 ]; then
  g log --all --format='%ae%n%ce' | sort -u | while IFS= read -r e; do
    email_ok "$e" || echo "$e  (commit author/committer; GitHub shows it publicly)"
  done > "$TMP/authors"
  report FAIL "7. Commit author emails" "$TMP/authors"
fi

# ---------------------------------------------------------------------------------------
# 8. Recordings and transcripts. A kit never needs a real conversation in it: raw speech-to-text
#    output, subtitles, and speaker-labelled logs are how a guest's words leak. Word-timing JSON
#    has one word per line, so no name, email, or phone check can see inside it. Flags subtitle
#    files, files named like a stray command-line flag, and text files with TRANSCRIPT_MIN+
#    timed lines. Fictional fixtures: approve the file with file:<path> in .sweep-allow.
TRANSCRIPT_MIN=50
TS_RE='"(start|end|start_time|end_time|timestamp)"[[:space:]]*:[[:space:]]*[0-9]|^[[:space:]]*[0-9]{1,2}:[0-9]{2}:[0-9]{2}[,.][0-9]{3}[[:space:]]+-->|^[[:space:]]*\[?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?\]?[[:space:]]+[A-Za-z][A-Za-z .]{0,30}:'
rec_names() { # rec_names SUFFIX < paths
  awk -v suf="$1" '{ n=$0; sub(/.*\//, "", n); low=tolower(n)
    if (n ~ /^-/) print $0 ": file name starts with \"-\" (a command-line flag became a file)" suf
    else if (low ~ /\.(srt|vtt|ass|ssa|sbv|ttml)$/) print $0 ": subtitle file" suf }'
}
{ rec_names "" < "$TMP/files"
  g grep --untracked -I -c -E -e "$TS_RE" -- "${SPEC[@]}" 2>/dev/null \
    | awk -F: -v min="$TRANSCRIPT_MIN" '$NF+0 >= min { n=$NF; p=$0; sub(/:[0-9]+$/, "", p); print p ": " n " timed lines, looks like a transcript" }'
} | drop_allowed_files > "$TMP/rec_tree"
: > "$TMP/rec_hist"
if [ "$nrevs" -gt 0 ]; then
  { g log --all --format= --name-only 2>/dev/null | grep -v '^$' | sort -u | grep -vxF -f "$TMP/files" | rec_names "  (in history)"
    # shellcheck disable=SC2046  # one argument per commit is intended
    git -C "$REPO" grep -I -c -E -e "$TS_RE" $(cat "$TMP/revs") -- "${SPEC[@]}" 2>/dev/null \
      | awk -F: -v min="$TRANSCRIPT_MIN" '$NF+0 >= min { sha=substr($1,1,7); n=$NF; p=$0; sub(/^[^:]*:/, "", p); sub(/:[0-9]+$/, "", p)
          if (!(p in seen)) { seen[p]=1; print p ": " n " timed lines, looks like a transcript  (in past commit " sha ")" } }' \
      | grep -vF -f <(sed 's/:.*//' "$TMP/rec_tree"; echo '//no-such-path//')
  } | drop_allowed_files > "$TMP/rec_hist"
fi
if [ "$HIST_SEV" = FAIL ]; then
  cat "$TMP/rec_hist" >> "$TMP/rec_tree"; report FAIL "8. Recordings and transcripts (files and history)" "$TMP/rec_tree"
else
  report FAIL "8. Recordings and transcripts (current files)" "$TMP/rec_tree"
  report WARN "8. Recordings and transcripts (past versions; private repo)" "$TMP/rec_hist"
fi

# ---------------------------------------------------------------------------------------
# 9. Text inside binary documents. PDFs, Office files, zips, and media tags can carry the same
#    names, emails, and transcripts as text files, so their text is pulled out and checked.
#    A document no tool here can read blocks a public or client release until the owner opens
#    it and approves it with file:<path> in .sweep-allow. Images and fonts are listed for a look.
DOC_EXT="pdf zip gz tgz bz2 7z rar mp4 mov m4v mp3 m4a wav aac docx xlsx pptx odt ods odp key pages numbers sqlite db"
is_doc_ext() { local e; e="$(printf '%s' "${1##*.}" | lower)"; case " $DOC_EXT " in *" $e "*) return 0 ;; esac; return 1; }
extract_text() { # extract_text FILE -> its readable text on stdout; exit 1 = nothing here can read it
  local f="$1" e; e="$(printf '%s' "${f##*.}" | lower)"
  case "$e" in
    pdf)
      if command -v pdftotext >/dev/null 2>&1; then pdftotext -q "$f" - 2>/dev/null
      elif command -v osascript >/dev/null 2>&1; then
        osascript -l JavaScript -e 'function run(a) { ObjC.import("PDFKit"); var d = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(a[0])); return d.isNil() ? "" : ObjC.unwrap(d.string) }' "$f" 2>/dev/null
      else return 1; fi ;;
    docx|xlsx|pptx|odt|ods|odp) unzip -p "$f" '*.xml' 2>/dev/null | sed -e 's/<[^>]*>/ /g' ;;
    zip) unzip -p "$f" 2>/dev/null | LC_ALL=C tr -c '[:print:]\t\n' '\n' ;;
    gz|tgz|bz2) { tar -xOf "$f" 2>/dev/null || gzip -dc "$f" 2>/dev/null || bzip2 -dc "$f" 2>/dev/null; } | LC_ALL=C tr -c '[:print:]\t\n' '\n' ;;
    mp4|mov|m4v|mp3|m4a|wav|aac)
      command -v ffprobe >/dev/null 2>&1 || return 1
      ffprobe -v quiet -show_entries format_tags:stream_tags:stream=codec_type -of default=nw=1 "$f" 2>/dev/null ;;
    sqlite|db) command -v sqlite3 >/dev/null 2>&1 || return 1; sqlite3 "$f" .dump 2>/dev/null ;;
    *) return 1 ;;
  esac
}
: > "$TMP/inbin_fail"; : > "$TMP/inbin_warn"; : > "$TMP/unread"; : > "$TMP/bin"
mkdir -p "$TMP/x"; i=0
while IFS= read -r f; do
  [ -s "$REPO/$f" ] || continue
  if ! is_bin_ext "$f" && LC_ALL=C grep -Iq . "$REPO/$f" 2>/dev/null; then continue; fi
  grep -qxF -- "$f" "$TMP/allow_files" && continue
  if ! is_doc_ext "$f"; then echo "$f" >> "$TMP/bin"; continue; fi
  i=$((i + 1)); t="$TMP/x/$i.txt"; lbl="$f (text inside)"
  if ! extract_text "$REPO/$f" > "$t"; then echo "$f: no tool on this computer can read it" >> "$TMP/unread"; continue; fi
  tag() { awk -v p="$lbl" '{ print p ":" $0 }'; }
  # Only media files have tracks; in a zip or PDF this text is just text (e.g. this script's own source).
  case "$(printf '%s' "${f##*.}" | lower)" in
    mp4|mov|m4v|mp3|m4a|wav|aac) grep -q 'codec_type=subtitle' "$t" && echo "$lbl: has a subtitle track (a transcript)" >> "$TMP/inbin_fail" ;;
  esac
  [ "$(grep -c -E -e "$TS_RE" "$t")" -ge "$TRANSCRIPT_MIN" ] && echo "$lbl: looks like a transcript" >> "$TMP/inbin_fail"
  { grep -n -o -E -e "$EMAIL_RE" "$t" | tag | prefilter email_ok | collapse | filter_hits email_ok
    grep -n -o -E -e "$PHONE_RE" "$t" | tag | prefilter phone_ok | collapse | filter_hits phone_ok
    grep -n -o -E -e "$PATH_RE" "$t" | tag | filter_hits path_ok; } >> "$TMP/inbin_fail"
  { [ -s "$TMP/terms" ] && grep -n -o -i -w -F -f "$TMP/terms" "$t" | tag
    [ -s "$TMP/regexes" ] && grep -n -o -i -E -f "$TMP/regexes" "$t" | tag | hide 2; true; } > "$TMP/inbin_deny"
  case "$MODE" in
    public) cat "$TMP/inbin_deny" >> "$TMP/inbin_fail" ;;
    team) cat "$TMP/inbin_deny" >> "$TMP/inbin_warn" ;;
    client) case "$f" in skills/*|client/*) cat "$TMP/inbin_deny" >> "$TMP/inbin_fail" ;; *) cat "$TMP/inbin_deny" >> "$TMP/inbin_warn" ;; esac ;;
  esac
done < "$TMP/files"
report FAIL "9. Text inside PDFs, Office files, zips, and media tags" "$TMP/inbin_fail"
[ "$MODE" = public ] || report WARN "9b. Never-ship words inside binary files (private repo)" "$TMP/inbin_warn"
if [ "$MODE" = team ]; then report WARN "9c. Documents no tool here could read (open each once)" "$TMP/unread"
else report FAIL "9c. Documents no tool here could read (open each, then approve with file:<path>)" "$TMP/unread"; fi

# Images, fonts, and other binaries can't be text-checked. List them so a human looks once.
if [ -s "$TMP/bin" ]; then
  echo "[INFO] Other binary files (images, fonts, models): not text-checked (gitleaks only looks for keys). Open each image once by eye:"
  head -n "$SHOW" "$TMP/bin" | sed 's/^/         /'
fi

echo
if [ "$blocking" -eq 0 ]; then
  echo "SWEEP: PASS ($MODE). $warnings warning(s). Safe to continue to validation and publishing."
  exit 0
fi
echo "SWEEP: FAIL ($MODE). $blocking blocking check(s), $warnings warning(s). Do NOT publish."
echo "Fix: move personal values to config.example.json / userConfig, replace real people with"
echo "fictional ones (example.com emails, 555-01xx phones), gitignore big or private files."
echo "Transcripts and recordings of real people never ship: delete them, don't just edit them."
echo "Hits in past commits mean the history is dirty: publish from a fresh repo with a clean copy."
echo "Approved public strings (like the owner's contact email) go in .sweep-allow, one per line."
exit 1
