# Workflow → Plugin

Turn any workflow you've figured out — a process you run with Claude, a set of scripts, a
skill — into a **Claude Code plugin on GitHub** that anyone can install with two slash
commands. Built for business owners and teams: the person installing never touches git or a
terminal; Claude does all of it.

## Install

In Claude Code, run:

```
/plugin marketplace add kevinACQ/workflow-to-plugin
/plugin install workflow-to-plugin@workflow-to-plugin-marketplace
```

Then just say: **"package my workflow"**.

Non-technical? Open [ONBOARDING.md](ONBOARDING.md) and paste the block into Claude — it does
everything for you.

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
5. **ONBOARDING.md**: a proven paste-into-Claude setup page a non-technical person can use,
   which also turns on automatic updates
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

1. An **ONBOARDING.md** a non-technical person can paste into Claude — Claude does the rest.
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
