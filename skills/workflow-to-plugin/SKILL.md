---
name: workflow-to-plugin
description: Package any workflow the user has built (skills, scripts, slash commands, or a process proven in conversation) into a Claude Code plugin repo on GitHub that anyone can install with two slash commands, or into a private client kit of claude.ai skill zips for paying clients. Use whenever the user wants to share, distribute, or sell a workflow: "package my workflow", "turn this into a plugin", "make this installable", "share this with my team", "share this with everyone at my company", "publish this so others can use it", "package this for my clients", "people keep asking how I do this", or when a team workflow catalog needs a new entry. Handles the full path: inventory, plugin scaffold with self-marketplace, a one-line "Set me up" setup backed by ONBOARDING.md, pass/fail checks, a scripted leak sweep that blocks publishing, validation, publish, and install verification. NOT for authoring a new personal skill (use skill-creator) or for installing someone else's existing plugin.
---

# Workflow → Plugin

One person figures out a great workflow; packaging it means everyone else gets it for free.
Because installs point at one GitHub repo, every fix the owner merges reaches every teammate
on their next update. The alternative is workflows dying on one laptop and being re-explained
forever. The human never touches git; you do all of it.

**Price of admission. A packaged workflow ships with all three, no exceptions:**
1. A one-line setup: a non-technical person pastes `Set me up: <repo link>` into Claude Code
   and Claude does the rest, using the README's note for Claude and the full setup in
   `ONBOARDING.md`.
2. Its own pass/fail checks, so output is known-good before a human reviews it. A workflow
   without checks is a rumor.
3. A named owner, so bugs and improvements have somewhere to go (that repo's Issues page).

If the user can't or won't supply one of the three, say what's missing and stop. Shipping
without it creates support burden that lands on them later.

This kit's scripts live in its plugin root, two folders up from this skill's base directory
(`<kit>/scripts/`). Templates live in this skill's `templates/` folder.

## Understand first, then ask as little as possible

The person on the other end is often not technical and wants this done, not a quiz. So read
before you ask. Go through every piece of context you can reach: this conversation, the
user's CLAUDE.md and memory files, their skills folder (`~/.claude/skills/`, or
`$CLAUDE_CONFIG_DIR/skills/` when that is set), the current project and its git remote, and
their GitHub account and orgs (`gh api user`, `gh api user/orgs`). From that, work out which
workflow to package, who it's for, what in it is personal, which words must never ship, and
what a correct output looks like.

Then ask only what that context can't answer, one question at a time, each with your
recommended answer first. If you can make a reasonable call, make it, say it in one line, and
list it in the Step 7 preview where the user can change it. A question is worth asking only
when a wrong guess would change what gets built or who can see it:

- **Which workflow?** Ask only when more than one is plausible. If one clearly fits, say
  "I'll package X" and go on. It must be one they've already used for real.
- **Who's it for?** Ask only if they haven't said and the context doesn't settle it. It picks
  private or public, so never guess public.
- **The publish OK** (Step 7) is the one question you always ask. Nothing goes online
  without it.

Everything else goes in the Step 7 preview instead of a question: the owner (their GitHub
account), the repo name, the pass/fail checks (drafted from the workflow), the never-ship
words you found, and an ONBOARDING.md for non-technical readers with the no-admin install
fallback. Detect instead of asking: whether the workflow is already packaged (its files), and
whether it's a copy of someone else's public repo (its git remote's owner versus their GitHub
account). Stop and ask when something blocks the run: no GitHub account, a workflow that has
never run, a sweep FAIL that needs the owner's call, or a remote owned by someone else.

## Pre-flight: GitHub access (always run this first)

Packaging ends at GitHub, so confirm access before any other work. Discovering a missing
login at publish time wastes the whole session. Assume the user may be brand new to all of
this; do every step yourself and narrate in plain English. Run the ladder top to bottom:

1. **Check:** run `gh auth status`. Signed in → name the account in one line ("You're signed
   in to GitHub as X"), then move on to Step 0. Stop and ask only if it looks like a
   coworker's or a shared login.
2. **Installed but not signed in** → run `gh auth login` (browser flow) and guide them
   through the clicks. They sign in with their OWN account.
3. **`gh` not installed** → install it yourself. If the machine has no admin rights, never
   use Homebrew or installers that ask for a password. Download the standalone `gh` release
   binary into `~/bin` and make sure `~/bin` is on PATH.
4. **No GitHub account at all** → walk them through creating a free one, click by click
   (github.com → Sign up → their own email). Then return to rung 2.

Never proceed on someone else's credentials. Publishing THEIR workflow requires THEIR
account; a borrowed login means the wrong person owns the repo, the issues, and the update
keys forever. Then run `<kit>/scripts/doctor.sh` and loop until it prints READY. It also
verifies git, the Claude Code CLI, gitleaks (the publish gate's secret scanner), and zip.

## Step 0: Identify and qualify the workflow

Find what's actually being packaged: an existing skill directory, a set of scripts, or a
process demonstrated earlier in this conversation (extract the tools used, the step sequence,
and the corrections the user made along the way). Never invent steps that didn't happen.

Qualify it before building anything: the workflow must have been run successfully at least
once for real. Packaging an unvalidated workflow distributes a guess. If it hasn't been run,
run it together first, then package. If a real run would touch live money, customers, or
production systems, the owner's confirmation that it has run, plus a dry run on fictional
data, counts instead.

The admission items don't need questions: the owner is the user's GitHub account, and the
pass/fail checks are drafted in Step 3. Both go in the Step 7 preview. The audience picks the
lane. When the context doesn't already settle it, ask in these words: **"Is this for
teammates, for everyone at your company, for anyone in public, or for paying clients?"**

| Answer | Lane | Repo | Sweep mode |
|---|---|---|---|
| Teammates | standard (Steps 1-8) | private | `--for team` |
| Anyone in public | standard (Steps 1-8) | public | `--for public` |
| Everyone at my company | **company lane**: read `references/company-lane.md` now | private, in the company GitHub org | `--for team` |
| Paying clients | **client lane**: read `references/client-lane.md` now | always private | `--for client` |

For teammates or the public, don't ask whether readers are technical or have admin rights:
write ONBOARDING.md for non-technical readers and include the no-admin fallback, which works
for everyone. Clients use claude.ai, not Claude Code or GitHub, and only skills transfer
there; the client lane covers what that rules out. "Everyone at my company" means one GitHub
link plus the company's Claude plugin catalog; the company lane says who the link reaches and
how people without GitHub still get it.

**Already packaged?** If the workflow is already a plugin or a shared kit (it has
`.claude-plugin/`, an ONBOARDING.md, or teammates get it with `git clone`), don't rebuild it.
Keep its layout and run Steps 1-6 as an audit. Note two facts now, because later steps depend
on them: where each plugin lives (every `source` in `.claude-plugin/marketplace.json`; older
kits use `./plugins/<name>`), and how teammates install it (`/plugin install`, or a `git clone`
folder with a CLAUDE.md). Also check whether it's a copy of someone else's public repo: compare
its git remote's owner with the user's GitHub account, and ask only if they differ. If it is a
copy, fixes sent back to it are public releases (see the maintenance loop).

## Step 1: Inventory, the engine/personal split, and the never-ship list

List everything the workflow needs: files, scripts, skills/commands, external tools (ffmpeg,
CLIs), API keys, and config. Then separate two categories:

- **Engine:** the generic method, same for every user. This goes in the repo.
- **Personalization:** names, brand assets, machine paths, accounts, IDs, keys, and "the
  owner prefers X" rules. Never hardcoded in the engine. Move it to `config.example.json`
  (committed, placeholder values) plus a gitignored `config.json`, or to the plugin's
  `userConfig` prompt; keys go in a gitignored keys file with a committed `*.example` template.
  Placeholders must be values nobody would really answer (`YOUR FIRST NAME`, not `Sam`): a
  doctor that treats "same as the example" as unfilled blocks every teammate named Sam.

This split is what lets others adopt the workflow without forking it: same procedure,
different parameters. It is enforced, not advisory: the sweep's never-ship list runs over
`skills/` and every other file that ships.

**Fill the owner's never-ship list now**, while the inventory is fresh. It lives at
`~/.config/workflow-to-plugin/never-ship.txt`, outside every repo, because it holds the very
words that must not leak. If it doesn't exist, copy `templates/never-ship.example.txt` there.
Fill it yourself so it costs the owner no question: search the workflow's files and the context
you read (CLAUDE.md, memory, git config, GitHub orgs) for company and product names, people's
names, emails, internal IDs, internal domains, and table and field names. Save them, and show
the list in the Step 7 preview so the owner can add anything you missed; if they do, re-run
the sweep. The list is reused for every future package, so it only gets filled once. The sweep
refuses to pass while it's empty.

Recordings are the leak this list can't cover. Guests, callers, and customers in the
recordings a workflow processed can't be listed ahead of time, and speech-to-text output has one
word per line, so no name, email, or phone check sees inside it. Never commit a transcript, a
subtitle file, or speech-to-text output, not even "for testing", and don't paste a real guest's
lines into SKILL.md examples. The sweep blocks transcripts by their shape (check 8). A fictional
test transcript is approved with a `file:<path>` line in `.sweep-allow`.

## Step 2: Scaffold the plugin repo

Read `references/plugin-spec.md` for the verified format, exact JSON schemas, and commands.
The default shape: one repo that is **both the plugin and its own marketplace**
(`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` with `"source": "./"`), so
installation is exactly two commands against one URL. Workflow logic goes in `skills/` (each
capability its own SKILL.md, namespaced `/plugin-name:skill-name` after install); helper
scripts in `scripts/` or `bin/`; state that must survive updates uses `${CLAUDE_PLUGIN_DATA}`,
never the install dir.

Build in a scratch directory first, not the user's project, and run `git init` there right
away: the sweep uses git to know exactly what will be published. Client lane: also copy the
scripts and templates listed in `references/client-lane.md`.

## Step 3: Add the pass/fail checks

Two layers, both required:

- **Doctor:** a self-check script (`scripts/doctor.*`) that verifies dependencies and config
  and prints a clear READY / what's-missing report. This is the onboarding gate: setup loops
  until doctor passes.
- **Output checks:** objective assertions on the workflow's actual output (files exist,
  format is right, domain rules hold), runnable on demand. If the workflow already has an
  eval harness, wire it in; if not, write the 3-10 checks that would catch the failures the
  user has actually seen. Test fixtures use fictional people only: `example.com` or `.test`
  emails and 555-01xx phone numbers. The sweep fails anything else.

The checks run before any human reviews output. That's what makes the workflow trustworthy
when the owner isn't in the room.

## Step 4: Write the one-line setup (README.md and ONBOARDING.md)

Read `references/onboarding-template.md` and write both files from that proven shape. The
front door is one line, `Set me up: https://github.com/<owner>/<repo>`, in both files.
README.md (what the link opens): promise → the one line → a short "For Claude:" note that
installs the plugin, then reads ONBOARDING.md from the install folder and carries out its box
(skills installed mid-session only load after a restart) → install by hand → owner line.
ONBOARDING.md: promise → 3 human steps, where step 2 is pasting the one line → the full
copy-paste block as the fallback (written in the user's first person: install, turn on
updates, doctor-gated setup, personalization interview, verified test run) → day-to-day
usage phrases → "file an issue about this" feedback line → owner line. If the audience may
lack admin rights, the no-admin fallback (standalone binaries to `~/bin`,
`pip install --user`) goes in the block. Private repo: name who to ask for access in the
README note, ONBOARDING, and the Step 8 share message.

The "turn on updates" step tells the installer's Claude to edit `~/.claude/settings.json`, so
a permission check may stop it, or stop you from writing it. That's expected, not a reason to
route around it: tell the user, and use the click path instead (`/plugin` → Marketplaces →
select the marketplace → Enable auto-update).

Kits installed with `git clone` (not `/plugin install`) never auto-update: their KEEP IT
UPDATED step is "run `git pull` in the kit folder at the start of each session, and tell me
if it brought changes." Their README note clones the repo into a folder instead of running
the two install commands, then reads ONBOARDING.md from that folder.

Client lane: clients never see ONBOARDING.md (it's for the owner's team). Their front door is
`client/INSTALL-PROMPT.txt` plus the PDF guide, built from `templates/client/`.

Company lane: the README is the front door. Start it from
`templates/company/README-pick-your-app.md` ("Pick your app" for Claude, Claude Code, and
ChatGPT, plus an "If you are Claude reading this" block with the two install commands).

## Step 5: The sweep (a hard gate before anything leaves the machine)

Run the publish gate with the Step 0 audience:

```bash
bash <kit>/scripts/sweep.sh --for <team|public|client> <repo-dir>
```

It checks everything the audience can see (current files, every past commit, commit
messages, file names, and for public repos the commit author emails) for: secrets
(gitleaks), never-ship words, real-looking emails and phone numbers, absolute machine paths,
files over 10 MB, recordings and transcripts, and the text inside PDFs, Office files, zips,
and media tags. Nothing is pushed, zipped, or uploaded until it prints `SWEEP: PASS`.

- **A FAIL is a hard stop, not a judgment call.** Fix the cause: move the value to the
  personalization layer, replace real people with fictional ones, or gitignore the file.
  Never shorten the never-ship list to get a pass.
- **A string the owner deliberately wants visible** (their public contact email, the brand
  name inside a client kit) goes in the repo's `.sweep-allow`, one per line, only after the
  owner approves that exact line.
- **Hits "in past commit"** mean the history is dirty. Publish from a fresh repo with a clean
  copy instead of scrubbing history.
- **A real key or password that ever sat in the workflow's files or history** gets rotated:
  tell the owner to make a new one and revoke the old one, even if it was never pushed. Leave
  their original folder as it is; never publish from it.
- **Binary documents:** the sweep reads the text inside PDFs, Office files, zips, and media
  tags. One it can't read blocks a public or client release until the owner opens it and
  approves it with a `file:<path>` line in `.sweep-allow`. Images are listed: open each once.
- **Data files:** color LUTs (`.cube`, `.3dl`) skip the email, phone, and path checks. Any
  other file with over 200 hits on one check is reported once. Open it; if it's data, approve
  it with `file:<path>`.
- **If the sweep can't run** (gitleaks missing, not a git repo), fix that. Never skip the gate.

## Step 6: Validate locally (both paths)

Find each plugin folder first: it's the `source` of each entry in
`.claude-plugin/marketplace.json` (`"./"` means the repo itself; older kits use
`./plugins/<name>`). Both commands must pass, the second once per plugin folder:

```bash
claude plugin validate <repo-dir> --strict                                       # marketplace.json
claude plugin validate <repo-dir>/<source>/.claude-plugin/plugin.json --strict   # plugin.json + every SKILL.md
```

The first command checks only marketplace.json: a skill with no description still passes it.
The second is the one that checks the skills. Pointing it at a folder without a
`.claude-plugin/plugin.json` fails with "File not found". Then smoke-test with
`claude --plugin-dir <repo-dir>/<source>`: confirm the skill count matches the plugin's
`skills/` folders (pointed at the wrong folder it loads zero skills with no error) and the
doctor script runs. Fix and re-validate until clean. Never publish a plugin you haven't loaded.

Client lane: also run `scripts/build_client_zips.sh` then `scripts/check_kit.sh` until it
prints ALL CHECKS GREEN (see `references/client-lane.md` for the allowed pre-upload warnings).

Company lane: also run `scripts/build_client_zips.sh --for team`, `scripts/build_plugin_zip.sh`,
and `scripts/check_kit.sh --lane company` until it prints ALL CHECKS GREEN.

## Step 7: Publish (needs the user's explicit OK)

Creating the repo and pushing is an external, user-visible action. Re-run the sweep (it must
be the last check before the push), then show the user what will be published (file list +
repo name + visibility, plus each decision you made instead of asking: owner, checks,
never-ship words, onboarding) and get their approval. Visibility follows Step 0: teammates →
private, public → public, paying clients → private with no exceptions. Create the repo under
the user's account or org (`gh repo create`), push, then prove the install path works from
GitHub itself, not just locally: add the marketplace from the pushed repo URL and install.
Report with receipts (repo URL and the install output), never on faith.

**Versions:** `plugin.json` always carries a `version` (strict validation fails without it),
and every release bumps it. Claude Code only updates installers when the version string
changes, so a release that keeps the old number never reaches anyone, even with auto-update on.

Client lane: after the push, follow `references/client-lane.md` steps 7-9 (check 9 confirms
the repo is private, the owner tests like a client, then hand-off).

Company lane: the repo goes under the company GitHub org (same owner as the company catalog).
After the push, each of these is its own OK: the GitHub Release with the skill zips, and the
catalog route that `<kit>/scripts/company_route.sh` picks (A: a catalog pull request; B: upload
the plugin zip to your own account, test, then Publish to org; C: ask the catalog owner). Never
click Publish to org before a pilot on your own account: on Team plans it goes live for the
whole company right after the security scan.

## Step 8: Hand back the share kit

Teammates or public: give the user, in one copyable block, the one setup line
(`Set me up: https://github.com/<owner>/<repo>`), a one-paragraph announcement ("what it does
/ paste this line into Claude Code / where bugs go"), the two install commands for anyone who'd
rather do it by hand, and, if their team keeps a workflow catalog, a ready-to-submit catalog
row and an offer to open that PR. Private repo: the announcement also says who to ask for
access, because someone without access can't open the README or ONBOARDING to find out.
Onboarding someone later = send them the one line, nothing else.

Paying clients: give the user the filled `client/INSTALL-PROMPT.txt` text in one copyable
block. That text is everything a client receives.

Everyone at the company: give the user the ONE repo link and a short announcement ("what it
does / say this / open the link and pick your app / where bugs go"), and say who the link
reaches (GitHub org members) and how everyone else gets it (the company catalog in Claude).

## Maintenance loop (tell the owner how this works)

- Users report bugs by telling Claude "file an issue about this" → issue lands on the repo.
- The owner fixes, bumps the version, and merges. Installers get it automatically only if
  auto-update is on for the marketplace (off by default for every non-Anthropic marketplace),
  which is why ONBOARDING.md turns it on. Otherwise they run
  `claude plugin update <plugin>@<marketplace>` or `/plugin` → Installed → Update now.
- Client kits: rebuild, check, and upload each changed zip as a new version of the SAME file,
  so links already sent keep working (`references/client-lane.md`).
- **A team copy of someone's public repo:** every fix sent back to the public repo is a
  public release. Copy only the outgoing change into a fresh folder, `git init` it, and run
  `sweep.sh --for public` on it before opening the pull request. Removing a file from the team
  copy doesn't remove it from the public repo it came from, or from that repo's history.
- Improvements from users arrive as PRs; profiles/configs let people personalize without
  forking the engine. If someone edits the engine to encode a personal preference, that's
  the signal a config option is missing.

## Pairs with

`skill-creator` (author/refine the skills that go inside the plugin), a team workflow-catalog
skill if one exists (this skill produces the repo; the catalog skill lists it).
