---
name: workflow-to-plugin
description: Package any workflow the user has built — skills, scripts, slash commands, or a process proven in conversation — into a Claude Code plugin repo on GitHub that anyone can install with two slash commands (/plugin marketplace add + /plugin install). Use whenever the user wants to share or distribute a workflow — "package my workflow", "turn this into a plugin", "make this installable", "share this with my team", "publish this so others can use it", "people keep asking how I do this" — or when a team workflow catalog needs a new entry. Handles the full path — inventory → plugin scaffold with self-marketplace → paste-into-Claude ONBOARDING.md → pass/fail checks → secret sweep → local validation → publish → install verification. NOT for authoring a new personal skill (use skill-creator) or for installing someone else's existing plugin.
---

# Workflow → Plugin

One person figures out a great workflow; packaging it means everyone else gets it for free —
and because installs point at one GitHub repo, every fix the owner merges reaches every
teammate on their next update. The alternative is workflows dying on one laptop and being
re-explained forever. The human never touches git; you do all of it.

**Price of admission — a packaged workflow ships with all three, no exceptions:**
1. An `ONBOARDING.md` a non-technical person can paste into Claude — Claude does the rest.
2. Its own pass/fail checks, so output is known-good before a human reviews it. A workflow
   without checks is a rumor.
3. A named owner, so bugs and improvements have somewhere to go (that repo's Issues page).

If the user can't or won't supply one of the three, say what's missing and stop — shipping
without it creates support burden that lands on them later.

## Pre-flight — GitHub access (always run this first)

Packaging ends at GitHub, so confirm access before any other work — discovering a missing
login at publish time wastes the whole session. Assume the user may be brand new to all of
this; do every step yourself and narrate in plain English. Run the ladder top to bottom:

1. **Check:** run `gh auth status`. Signed in → say so in one line and move on to Step 0.
2. **Installed but not signed in** → run `gh auth login` (browser flow) and guide them
   through the clicks. They sign in with their OWN account.
3. **`gh` not installed** → install it yourself. If the machine has no admin rights, never
   use Homebrew or installers that ask for a password — download the standalone `gh` release
   binary into `~/bin` and make sure `~/bin` is on PATH.
4. **No GitHub account at all** → walk them through creating a free one, click by click
   (github.com → Sign up → their own email). Then return to rung 2.

Never proceed on someone else's credentials — publishing THEIR workflow requires THEIR
account, and a borrowed login means the wrong person owns the repo, the issues, and the
update keys forever. If this kit's doctor script is available (`scripts/doctor.sh` in the
plugin folder), run it after the ladder and loop until it prints READY — it also verifies
git and the Claude Code CLI.

## Step 0 — Identify and qualify the workflow

Find what's actually being packaged: an existing skill directory, a set of scripts, or a
process demonstrated earlier in this conversation (extract the tools used, the step sequence,
and the corrections the user made along the way).

Qualify it before building anything: the workflow must have been run successfully at least
once for real. Packaging an unvalidated workflow distributes a guess. If it hasn't been run,
run it together first, then package.

Confirm the three admission items with the user in one short exchange: who owns it, what a
pass/fail check on its output looks like, and who the intended audience is (technical
teammates? non-technical? Do their machines have admin rights?). The audience answer shapes
the ONBOARDING.md.

## Step 1 — Inventory

List everything the workflow needs: files, scripts, skills/commands, external tools (ffmpeg,
CLIs), API keys, and config. Then separate two categories:

- **Engine** — the generic method, same for every user. This goes in the repo.
- **Personalization** — names, brand assets, machine paths, accounts, keys. This must NOT be
  hardcoded in the engine. Move it to a config/profile mechanism (a `profiles/` dir, a
  `config.json`, or the plugin's `userConfig` prompt) and a gitignored keys file with a
  committed `*.example` template.

This split is what lets teammates adopt the workflow without forking it: a workflow is a
method call — same procedure, different parameters.

## Step 2 — Scaffold the plugin repo

Read `references/plugin-spec.md` for the verified format, exact JSON schemas, and commands.
The default shape: one repo that is **both the plugin and its own marketplace**
(`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` with `"source": "./"`), so
installation is exactly two commands against one URL. Workflow logic goes in `skills/` (each
capability its own SKILL.md, namespaced `/plugin-name:skill-name` after install); helper
scripts in `scripts/` or `bin/`; state that must survive updates uses `${CLAUDE_PLUGIN_DATA}`,
never the install dir.

Build in a scratch directory first, not the user's project.

## Step 3 — Add the pass/fail checks

Two layers, both required:

- **Doctor** — a self-check script (`scripts/doctor.*`) that verifies dependencies and config
  and prints a clear READY / what's-missing report. This is the onboarding gate: setup loops
  until doctor passes.
- **Output checks** — objective assertions on the workflow's actual output (files exist,
  format is right, domain rules hold), runnable on demand. If the workflow already has an
  eval harness, wire it in; if not, write the 3–10 checks that would catch the failures the
  user has actually seen.

The checks run before any human reviews output — that's what makes the workflow trustworthy
when the owner isn't in the room.

## Step 4 — Write ONBOARDING.md

Read `references/onboarding-template.md` and follow that proven shape: promise → 3 human
steps → one self-contained copy-paste block (written in the user's first person, ending in a
doctor-gated setup, a personalization interview, and a verified test run) → day-to-day usage
phrases → "file an issue about this" feedback line → owner line. If the audience may lack
admin rights, the no-admin fallback (standalone binaries to `~/bin`, `pip install --user`)
goes in the block — it's the difference between onboarding working and stalling on a password
prompt.

## Step 5 — Secret sweep (adversarial, before anything is pushed)

Review every file as an attacker/auditor would, not as the author. The five things that have
actually been caught in first-push audits — assume this repo has them too:

1. Keys, tokens, or credentials (including in history, examples, and notebooks)
2. Personal data (real names, emails, phone numbers in fixtures or configs)
3. Customer content (transcripts, exports, member data used as test files)
4. Machine-specific absolute paths in executing code
5. Gigabyte-scale artifacts (renders, models, node_modules)

Fix by relocating to the personalization layer, replacing with fictional fixtures, or
gitignoring — never by hoping. If anything sensitive was ever committed, the history is dirty:
start the repo from a clean copy rather than trying to scrub it.

## Step 6 — Validate locally

Before publishing: `claude plugin validate <repo-dir> --strict` must pass, then smoke-test
with `claude --plugin-dir <repo-dir>` — confirm the skills load under the plugin namespace and
the doctor script runs. Fix and re-validate until clean. Never publish a plugin you haven't
loaded.

## Step 7 — Publish (needs the user's explicit OK)

Creating the repo and pushing is an external, user-visible action — show the user what will be
published (file list + repo name/visibility) and get their approval first. Ask whether the
repo is **private** (team/company workflows — the safe default) or **public** (sharing with
the world — only after the Step 5 sweep is clean), then create it under the user's account or
org (`gh repo create`). Push, then prove the
install path works from GitHub itself, not just locally: add the marketplace from the pushed
repo URL and install. Report with receipts — repo URL and the install output — never on faith.

## Step 8 — Hand back the share kit

Give the user, in one copyable block: the two install commands, a one-paragraph announcement
("what it does / say this to Claude / where bugs go"), and — if their team keeps a workflow
catalog — a ready-to-submit catalog row and an offer to open that PR. Onboarding a teammate
later = send them ONBOARDING.md, nothing else.

## Maintenance loop (tell the owner how this works)

- Users report bugs by telling Claude "file an issue about this" → issue lands on the repo.
- The owner fixes and merges; `/plugin update` (or auto-update) carries it to every installer.
- Improvements from users arrive as PRs; profiles/configs let people personalize without
  forking the engine — if someone edits the engine to encode a personal preference, that's
  the signal a profile mechanism is missing.

## Pairs with

`skill-creator` (author/refine the skills that go inside the plugin), a team workflow-catalog
skill if one exists (this skill produces the repo; the catalog skill lists it).
