# Workflow → Plugin: Setup

Turn a workflow you've figured out into a **shareable Claude Code plugin on GitHub**, so
anyone you choose can install it and get your workflow working on their machine. **You do not
need to be technical.** Claude does the whole thing. It works out what it can on its own and
asks you only what it can't.

**Repo:** https://github.com/kevinACQ/workflow-to-plugin *(public: anyone can install it).*

---

## How to set it up (about 5 minutes)

**1. Get the Claude Code desktop app:** **https://claude.com/claude-code**
Download it, open it, and sign in (you need a paid Claude plan).

**2. Start a new chat and paste this one line:**

```
Set me up: https://github.com/kevinACQ/workflow-to-plugin
```

**3. Answer its few questions.** Claude reads what it can about your workflow first, so it only
asks what it can't figure out, like which workflow or who it's for. It always ends the same
way: it shows you exactly what will go on GitHub and asks "OK to publish?"

> 💡 Claude may ask permission to run a step: click **Allow**. One of these asks to change
> your Claude settings. That one turns on automatic updates, so click **Allow** there too.
> It may also open your browser once so you can sign in to GitHub with your own account.

If the one line doesn't start the setup, paste the box below instead. It's the same setup.

---

### ✂️ COPY FROM HERE ⬇️

```
Set me up with "Workflow → Plugin" (https://github.com/kevinACQ/workflow-to-plugin) and
package my first workflow. I am NOT technical: do everything yourself, never make me run a
terminal command or edit a file by hand, and explain each step in plain English. Keep a
visible to-do list of these steps and check them off as you go.

1) GET THE KIT
   - Run: claude plugin marketplace add kevinACQ/workflow-to-plugin
     then: claude plugin install workflow-to-plugin@workflow-to-plugin-marketplace
     If "claude" isn't found, put "$CLAUDE_CODE_EXECPATH" in its place (the Claude app's
     own copy). If the kit is already installed, run
     claude plugin update workflow-to-plugin@workflow-to-plugin-marketplace instead.
   - It's a public repo, so no special access is needed.

2) KEEP IT UPDATED (don't ask me; do it and tell me in one line)
   - Before you touch the file, warn me in one line, in these words: "A box is about to pop
     up asking to let me change your Claude settings. Click Allow: that turns on automatic
     updates." Then make the change.
   - The install wrote this kit into my Claude settings file: ~/.claude/settings.json, or
     settings.json inside $CLAUDE_CONFIG_DIR if that is set. In that file, set
     "autoUpdate": true on the "workflow-to-plugin-marketplace" entry under
     "extraKnownMarketplaces". Keep everything else as it is.
   - If DISABLE_AUTOUPDATER, DISABLE_UPDATES, or CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC is
     set in your environment (the Claude desktop app sets the first one), also add
     "FORCE_AUTOUPDATE_PLUGINS": "1" under "env" in that file, unless my company manages
     these settings. Read the file back to check.
   - If you can't edit it, walk me through the clicks instead: /plugin, then Marketplaces,
     then workflow-to-plugin-marketplace, then Enable auto-update. If that fails too, tell
     me: "Updates won't arrive on their own. Once a month, say 'update my plugins'."

3) CHECK MY MACHINE (fix things yourself; don't ask me technical questions)
   - Find the kit's folder: run claude plugin list --json and take this plugin's installPath.
   - Run <installPath>/scripts/doctor.sh and fix anything missing: git, the GitHub CLI,
     gitleaks, zip. If an install would need an admin password, don't use Homebrew or
     installers: put standalone binaries in ~/bin and add ~/bin to my PATH.
   - GitHub: I must be signed in with MY OWN account (gh auth login, browser sign-in). If I
     don't have one, help me make a free account with my email. Never use someone else's.
   - Re-run the doctor until it prints READY.

4) PACKAGE MY FIRST WORKFLOW, NOW
   - A new plugin's skills only load after a restart, so don't wait for that: read
     <installPath>/skills/workflow-to-plugin/SKILL.md from disk and follow it, in this chat.
   - First read everything you can about my workflow, as that file says. Then ask me only
     what you still can't figure out, and show me every choice you made in the final preview.
   - If I have no workflow ready, tell me "Any time, just say: package my workflow" and stop.

Throughout: be patient, assume I've never used a terminal, and explain in plain English.
Never publish anything without showing me exactly what will be published and getting my OK.
```

### ⬆️ COPY TO HERE ✂️

---

## Once it's set up

- **Package a workflow anytime:** just say *"package my workflow"* (or *"turn this into a
  plugin"*, *"make this shareable"*). Claude runs the whole process and asks before anything
  goes public.
- **Your published workflow** ends up as a GitHub repo with the same one-line setup as this
  kit. To onboard someone, send them one line: *Set me up:* followed by your repo link.
  Nothing else.
- **Private or public is your call:** private for company workflows, public to share with
  the world. Claude always shows you the file list before publishing.
- **Selling it to clients?** Say *"package this for my clients."* You get a private repo, one
  download file per skill, a paste-in setup prompt to send each client, and a PDF guide.
  Nothing goes on public GitHub.
- **Found a bug, or made this kit better?** Tell Claude: *"file an issue about this."* It
  writes it up on this repo's Issues page so the owner can fix it for everyone.

**Owner:** Kevin Gong. Issues: https://github.com/kevinACQ/workflow-to-plugin/issues
