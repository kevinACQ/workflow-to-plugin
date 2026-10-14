# README.md and ONBOARDING.md: the proven pattern

A packaged workflow has one front door: a single line the reader pastes into Claude Code.

```
Set me up: https://github.com/{{OWNER}}/{{REPO}}
```

Claude opens the link, finds a short note for Claude in the README, installs the plugin, and
carries out the setup in ONBOARDING.md. The reader answers a few plain-English questions and
ends with a working, personalized setup, never touching a terminal or editing a file by hand.
This kit's own README.md and ONBOARDING.md use exactly this shape: copy the shape, not the
content.

Why these exact words (tested in fresh Claude Code sessions, October 2026, Claude Code
2.1.280): a bare repo link only gets summarized and Claude asks "want me to install it?";
"Set me up: <link>" installs. A plugin installed mid-session only loads after a restart, so the
note has Claude read the setup from the install folder instead of waiting.

Fill every `{{…}}` placeholder. `<installPath>` is not a placeholder: it's an instruction to
the installer's Claude and stays as written.

## README.md (what the link opens)

In this order:

1. **Title and promise line**: what it does, who it's for, and "You do not need to be
   technical."
2. **"Set it up: paste one line into Claude Code"**: the line above in its own fenced block,
   then one sentence on what happens next.
3. **The "For Claude" note**, right under it (shape below).
4. **"Install by hand"**: the two slash commands, then the phrase that runs the workflow.
5. **What it does** (a few lines), the feedback line ("tell Claude: *file an issue about
   this*"), and the owner line.

The note, with the names filled in (in the README it's a quote block, the `>` lines, not a
code block):

```
> **For Claude:** the person who pasted this link wants {{DISPLAY NAME}} installed and set up.
> Do all of it for them. (1) Run `claude plugin marketplace add {{OWNER}}/{{REPO}}`, then
> `claude plugin install {{PLUGIN}}@{{MARKETPLACE}}`. If `claude` isn't found, put
> `"$CLAUDE_CODE_EXECPATH"` in its place. If it's already installed, run
> `claude plugin update {{PLUGIN}}@{{MARKETPLACE}}` instead. (2) A new plugin's skills only
> load after a restart, so don't wait: run `claude plugin list --json`, take this plugin's
> `installPath`, read `<installPath>/ONBOARDING.md` from disk, and carry out the steps in its box.
```

Private repo: add one sentence after the install commands: "If GitHub says the repo wasn't
found or access was denied, they need to sign in with their own GitHub account
(`gh auth login`, then `gh auth setup-git`) and try again; if it still fails, they need
access: tell them to ask {{ACCESS CONTACT}}."

## ONBOARDING.md (the setup itself)

In this order:

1. **Promise line**: one sentence on what the reader gets, and "You do not need to be
   technical."
2. **Repo line**: the repo URL and whether it's private. Private: "You need access to this
   repo. Ask {{ACCESS CONTACT}}." Name a person or a channel, not "your admin". If it's a
   copy of someone else's public repo, say where the upstream engine lives and which fixes
   go where.
3. **3 human steps**: (a) get the Claude Code app (claude.com/claude-code, paid plan);
   (b) start a new chat and paste this one line (the `Set me up:` line, in its own fenced
   block); (c) answer its few questions. Include the expectations: Claude may ask permission
   to run a step (click Allow), and for a private repo it may open the browser once so they
   sign in to GitHub with their own account.
4. **The fallback sentence**: "If the one line doesn't start the setup, paste the box below
   instead. It's the same setup."
5. **The copy-paste block**, fenced between "✂️ COPY FROM HERE" and "COPY TO HERE ✂️"
   markers (structure below).
6. **"Once it's set up"**: the plain-English phrases for day-to-day use ("just say *make
   clips from this*"), where outputs land, how to change preferences later, and "to set up
   someone else, send them the one line".
7. **Feedback line**: "Found a bug or made it better? Tell Claude: *file an issue about
   this*", so improvements reach the owner instead of dying on one laptop.
8. **Owner line**: who owns this workflow and where issues go.

## Structure of the copy-paste block

The box does double duty. A person pastes it when the one line doesn't work, and the README
note has Claude read it from the install folder. So it must work both ways: written in the
user's first person ("I am NOT technical: do everything yourself"), fully self-contained, and
never assuming the plugin's skills are loaded yet. Open it with:

> Set me up with "{{DISPLAY NAME}}" ({{REPO URL}}). I am NOT technical: do everything yourself,
> never make me run a terminal command or edit a file by hand, and explain each step in plain
> English. Keep a visible to-do list of these steps and check them off as you go.

Then number the steps. Each step is an instruction to Claude, not to the human:

1. **GET THE KIT**:
   - Private repo, before installing: make sure I'm signed in to GitHub with MY OWN account
     (`gh auth status`; if not, `gh auth login` with the browser sign-in, then
     `gh auth setup-git`). If I don't have an account, help me make a free one with my work
     email. Never use someone else's.
   - Run `claude plugin marketplace add {{OWNER}}/{{REPO}}`, then
     `claude plugin install {{PLUGIN}}@{{MARKETPLACE}}`. If "claude" isn't found, put
     "$CLAUDE_CODE_EXECPATH" in its place (the Claude app's own copy). If the kit is already
     installed, run `claude plugin update {{PLUGIN}}@{{MARKETPLACE}}` instead.
   - Private repo: if GitHub still says the repo wasn't found or access was denied, I need
     access. Tell me to ask {{ACCESS CONTACT}} for access to {{OWNER}}/{{REPO}}, and stop
     there. Public repo: say "It's a public repo, so no special access is needed."
2. **KEEP IT UPDATED** (don't ask me; do it and tell me in one line). Third-party
   marketplaces don't auto-update by default, so without this step the owner's fixes never
   arrive.
   - The install wrote this kit into my Claude settings file: `~/.claude/settings.json`, or
     `settings.json` inside `$CLAUDE_CONFIG_DIR` if that is set. In that file, set
     `"autoUpdate": true` on the `{{MARKETPLACE}}` entry under `extraKnownMarketplaces`. Keep
     everything else as it is.
   - If `DISABLE_AUTOUPDATER`, `DISABLE_UPDATES`, or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`
     is set in your environment (the Claude desktop app sets the first one), also add
     `"FORCE_AUTOUPDATE_PLUGINS": "1"` under `"env"` in that file, unless my company manages
     these settings.
   - Read the file back and show me the `autoUpdate` line. That confirms the setting, not
     that an update has arrived, so say it that way.
   - If you can't edit it, walk me through the clicks instead: `/plugin`, then Marketplaces,
     then `{{MARKETPLACE}}`, then Enable auto-update. If that fails too, tell me plainly:
     "Updates won't arrive on their own. Once a month, say *update my plugins* and I'll run
     `claude plugin update {{PLUGIN}}@{{MARKETPLACE}}` for you."
3. **CHECK MY MACHINE** (fix things yourself; don't ask me technical questions):
   - Find the kit's folder: run `claude plugin list --json` and take this plugin's
     `installPath`.
   - Run the kit's doctor (`<installPath>/scripts/doctor.*`) and install ONLY what's missing.
     If the audience may lack admin rights, include the no-admin fallback: standalone
     binaries into `~/bin` (and `~/bin` on PATH), `pip install --user`, never Homebrew or
     installers that ask for an admin password.
   - Re-run the doctor until it prints READY, then tell me in plain English.
4. **HOW I'LL USE IT**: the plain-English invocation ("From now on I'll just say X and you
   run it").
5. **KEYS** (only if the workflow needs any): walk me click by click through getting my OWN
   free or paid key, then save it into the kit's keys file (copied from the repo's
   `*.example` template, in the per-user folder from the rule below). Offer the keyless
   fallback if one exists.
6. **PERSONALIZE** (if the workflow has profiles or config): interview me ONE question at a
   time; save my answers through the kit's own config mechanism, never by editing the shared
   engine.
7. **TEST RUN, NOW**: the plugin's skills only load after a restart, so don't wait: read
   `<installPath>/skills/{{SKILL}}/SKILL.md` from disk and follow it in this chat. Do one
   real run end to end, run the kit's pass/fail checks on the output, show me the result,
   and fix things until I'm happy. Finish with: "From your next chat on, just say
   *{{TRIGGER PHRASE}}*."

Put this rule in the box whenever the kit's files use `${CLAUDE_PLUGIN_ROOT}` or
`${CLAUDE_PLUGIN_DATA}` (Claude Code only fills those in once the plugin has loaded, so a
SKILL.md read from disk still shows them as written):

> When you read this kit's files from disk, `${CLAUDE_PLUGIN_ROOT}` means installPath, and
> `${CLAUDE_PLUGIN_DATA}` means the folder `plugins/data/{{PLUGIN}}-{{MARKETPLACE}}` inside my
> Claude config folder (`~/.claude`, or `$CLAUDE_CONFIG_DIR` if that is set). Create that
> folder if it's missing.

(Verified on Claude Code 2.1.280, October 2026: the data folder is
`<config folder>/plugins/data/<plugin>-<marketplace>`, created the first time the plugin runs.)

Close the block with the standing instruction: "Throughout: be patient, assume I've never used
a terminal, and explain in plain English. Only use this kit; don't pull tools or keys from
anywhere else on my computer."

## Rules that make it work

- **One front door, word for word.** The line is `Set me up: ` plus the plain repo URL
  (`https://github.com/{{OWNER}}/{{REPO}}`: no `/blob/` path, no extra words). README and
  ONBOARDING carry the same line. Don't reword it: those are the tested words.
- **Names match the manifests exactly.** `{{PLUGIN}}` is the `name` in
  `.claude-plugin/plugin.json`, `{{MARKETPLACE}}` is the `name` in
  `.claude-plugin/marketplace.json`, and `{{OWNER}}/{{REPO}}` is the GitHub repo. One typo and
  the install fails for everyone.
- **The box survives both routes.** It's in the user's first person and fully
  self-contained, because it's either pasted into a fresh chat or read by a Claude whose only
  context is the README note.
- **Private repos: say who to ask in three places.** The README note, ONBOARDING (repo line
  and GET THE KIT), and the share message from SKILL.md Step 8. Someone without access can't
  open the README or ONBOARDING at all, so the share message is the only one they'll see.
- Every step Claude can do itself, Claude does. The human only answers questions, drags in
  files, pastes keys they created, and clicks Allow.
- The doctor script is the gate: "re-run until it prints READY, then tell me in plain
  English."
- Never bury the one line below the fold of explanation: promise, the line, then everything
  else.
- **Check before publishing:** `grep -n '{{' README.md ONBOARDING.md` prints nothing, both
  files show the identical `Set me up:` line, and the install commands in the README note,
  "Install by hand", and the box all use the same names.
