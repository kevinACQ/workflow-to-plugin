# Workflow → Plugin

Turn any workflow you've figured out — a process you run with Claude, a set of scripts, a
skill — into a **Claude Code plugin on GitHub** that anyone can install with two slash
commands. Built for business owners and teams: the person installing never touches git or a
terminal; Claude does all of it.

## Set it up: paste one line into Claude Code

```
Set me up: https://github.com/kevinACQ/workflow-to-plugin
```

Claude installs the kit, reads what it can about your workflow, asks only what it can't figure
out, and shows you exactly what will be published before anything goes live.

> **For Claude:** the person who pasted this link wants this kit installed and their first
> workflow packaged. Do all of it for them. (1) Run
> `claude plugin marketplace add kevinACQ/workflow-to-plugin`, then
> `claude plugin install workflow-to-plugin@workflow-to-plugin-marketplace`. If `claude` isn't
> found, put `"$CLAUDE_CODE_EXECPATH"` in its place. (2) A new plugin's skills only load after
> a restart, so don't wait: run `claude plugin list --json`, take this plugin's `installPath`,
> read `<installPath>/ONBOARDING.md` from disk, and carry out the steps in its box.

## Install by hand

In Claude Code, run:

```
/plugin marketplace add kevinACQ/workflow-to-plugin
/plugin install workflow-to-plugin@workflow-to-plugin-marketplace
```

Then just say: **"package my workflow"**.

Non-technical? Use the one line above. [ONBOARDING.md](ONBOARDING.md) has the same setup as
one block to paste, if you'd rather.

## What it does

When you ask Claude to package a workflow, this plugin walks it through the full path:

1. **Identify & qualify**: what the workflow is, who owns it, proof it actually works, and
   who it's for: teammates, anyone in public, or paying clients
2. **Inventory**: split the generic engine from your personal config/keys (nothing personal
   gets hardcoded), and fill in your "never ship" word list once
3. **Scaffold**: a GitHub-ready plugin repo that is also its own marketplace, so installing
   it is exactly two commands
4. **Checks**: a doctor script plus pass/fail checks on the workflow's output, because a
   workflow without checks is a rumor
5. **One-line setup**: a README and ONBOARDING.md so a teammate pastes
   `Set me up: <your repo link>` into Claude Code and Claude installs it, turns on automatic
   updates, and sets it up. The full paste-in box stays in ONBOARDING.md as a fallback
6. **Leak sweep (a hard gate)**: `scripts/sweep.sh` blocks publishing on secrets, your
   never-ship words, real-looking emails and phone numbers, machine paths, files over
   10 MB, recordings and transcripts, and the text inside PDFs, Office files, and zips, in
   current files and in git history
7. **Validate**: both `claude plugin validate` paths, because checking the repo folder alone
   never looks at the skills
8. **Publish & verify**: create the repo (private or public, your call), push, and prove
   the install actually works from GitHub before declaring done

**Sharing with everyone at your company?** The company lane gives you one GitHub link whose
README says how to get it in Claude, Claude Code, or ChatGPT, builds the plugin zip for your
company's Claude catalog, and checks which way into that catalog you have (`company_route.sh`).
See [references/company-lane.md](skills/workflow-to-plugin/references/company-lane.md).

**Selling to clients?** The client lane builds a private kit instead: one claude.ai upload
zip per skill, a paste-in install prompt with the download links inside, a PDF guide, a
proprietary license, and `check_kit.sh` to prove every zip matches its source before release.
See [references/client-lane.md](skills/workflow-to-plugin/references/client-lane.md).

## The rules (what every packaged workflow ships with)

1. A **one-line setup** (`Set me up: <repo link>`) backed by an ONBOARDING.md, so a
   non-technical person pastes one line into Claude and Claude does the rest.
2. Its own **pass/fail checks** so output is known-good before a human reviews it.
3. A **named owner** — bugs and ideas go to that repo's Issues page (tell Claude "file an
   issue about this"). The owner fixes and merges, and the fix reaches every installer on
   their next update. That's how workflows get better for everyone instead of dying on one
   laptop.

## Check your setup

```bash
bash scripts/doctor.sh     # verifies git, GitHub CLI (signed in), Claude Code CLI, gitleaks, zip
bash scripts/selftest.sh   # valid plugins build, a broken skill gets caught, the sweep
                           # catches planted leaks, and the client lane works
bash scripts/sweep.sh --for public <repo>   # the publish gate, on any repo you're about to share
```

The sweep reads your never-ship list from `~/.config/workflow-to-plugin/never-ship.txt`
(template: `skills/workflow-to-plugin/templates/never-ship.example.txt`). It stays outside
every repo because it holds the words that must not leak.

## Owner

**Kevin Gong** — bugs and ideas → [Issues](https://github.com/kevinACQ/workflow-to-plugin/issues)
(or tell Claude: "file an issue about this").

MIT licensed.
