# Workflow → Plugin — Setup

Turn a workflow you've figured out into a **shareable Claude Code plugin on GitHub** — so
anyone you choose can install it with two commands and get your workflow working on their
machine. **You do not need to be technical.** Claude does the whole thing for you and asks
plain-English questions along the way.

**Repo:** https://github.com/kevinACQ/workflow-to-plugin *(public — anyone can install it).*

---

## How to set it up — 3 steps (about 5 minutes)

**1. Get the Claude Code desktop app** → **https://claude.com/claude-code**
Download it, open it, and sign in (you need a paid Claude plan). This one app does
everything — there's no other software to install.

**2. Start a new chat and paste the big box below.**
Copy **everything between "✂️ COPY FROM HERE" and "COPY TO HERE ✂️"** and paste it into the
chat.

**3. Answer its questions.**
Claude installs the kit, checks your machine, and then packages your workflow step by step.

> 💡 **Two things to expect:** (a) Claude may ask permission to run a step — just click
> **Allow / Yes**. (b) It keeps a **checklist** so you can watch it work.

---

### ✂️ COPY FROM HERE ⬇️

```
You're setting up "Workflow → Plugin" for me. I am NOT technical — do everything yourself,
never make me run a terminal command or edit a file by hand, and explain each step in plain
English. Keep a visible to-do list of the steps below and check them off as you go.

1) GET THE KIT
   - Install the plugin by running these two commands for me:
       /plugin marketplace add kevinACQ/workflow-to-plugin
       /plugin install workflow-to-plugin@workflow-to-plugin-marketplace
   - It's a public repo, so no special access is needed.

2) CHECK MY MACHINE
   - Run the kit's doctor script (scripts/doctor.sh inside the installed plugin) and fix
     anything missing yourself: git, the GitHub CLI, and make sure I'm signed in to GitHub
     ("gh auth login", browser sign-in, my own account — help me create a free account with
     my email if I don't have one; publishing MY workflows needs MY account, never someone
     else's).
   - If any install would need an admin password we don't have, do NOT use Homebrew or
     installers — put standalone binaries in ~/bin instead and add ~/bin to my PATH.
   - Re-run the doctor until it prints READY, then tell me in plain English that it's ready.

3) HOW I'LL USE IT
   - Nothing to memorize. When I want to share a workflow, I'll just say "package my
     workflow" and you'll run the whole process: figure out what my workflow is, separate my
     personal settings and keys from the shareable part, build the plugin repo, write the
     setup page for non-technical people, add the pass/fail checks, sweep it for anything
     private, and — only after showing me exactly what will be published and getting my OK —
     put it on GitHub and prove the install works.

4) QUICK TEST (so I can see it work)
   - Run the kit's self-test (scripts/selftest.sh) and show me the PASS.
   - Then ask me: "What's a workflow you run repeatedly that someone else keeps asking
     about?" — and offer to package it. If I don't have one ready, that's fine; we're done.

Throughout: be patient, assume I've never used a terminal, and explain what's happening in
plain English. Never publish anything to GitHub without showing me first and getting my OK.
```

### ⬆️ COPY TO HERE ✂️

---

## Once it's set up

- **Package a workflow anytime:** just say *"package my workflow"* (or *"turn this into a
  plugin"*, *"make this shareable"*). Claude runs the whole process and asks before anything
  goes public.
- **Your published workflow** ends up as a GitHub repo with its own two-command install and
  its own ONBOARDING.md — to onboard someone, send them that one file. Nothing else.
- **Private or public is your call** — private for company workflows, public to share with
  the world. Claude always shows you the file list before publishing.
- **Found a bug, or made this kit better?** Tell Claude: *"file an issue about this."* It
  writes it up on this repo's Issues page so the owner can fix it for everyone.

**Owner:** Kevin Gong — issues → https://github.com/kevinACQ/workflow-to-plugin/issues
