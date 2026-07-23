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

1. **Identify & qualify** — what the workflow is, who owns it, proof it actually works
2. **Inventory** — split the generic engine from your personal config/keys (nothing personal
   gets hardcoded)
3. **Scaffold** — a GitHub-ready plugin repo that is also its own marketplace, so installing
   it is exactly two commands
4. **Checks** — a doctor script plus pass/fail checks on the workflow's output, because a
   workflow without checks is a rumor
5. **ONBOARDING.md** — a proven paste-into-Claude setup page a non-technical person can use
6. **Secret sweep** — an adversarial pass for keys, personal data, customer content, machine
   paths, and giant files before anything is pushed
7. **Publish & verify** — create the repo (private or public — your call), push, and prove
   the install actually works from GitHub before declaring done

## The rules (what every packaged workflow ships with)

1. An **ONBOARDING.md** a non-technical person can paste into Claude — Claude does the rest.
2. Its own **pass/fail checks** so output is known-good before a human reviews it.
3. A **named owner** — bugs and ideas go to that repo's Issues page (tell Claude "file an
   issue about this"). The owner fixes and merges, and the fix reaches every installer on
   their next update. That's how workflows get better for everyone instead of dying on one
   laptop.

## Check your setup

```bash
bash scripts/doctor.sh     # verifies git, GitHub CLI (signed in), Claude Code CLI
bash scripts/selftest.sh   # proves the scaffold recipe still produces a valid plugin
```

## Owner

**Kevin Gong** — bugs and ideas → [Issues](https://github.com/kevinACQ/workflow-to-plugin/issues)
(or tell Claude: "file an issue about this").

MIT licensed.
