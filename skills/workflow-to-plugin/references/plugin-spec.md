# Claude Code plugin format — verified reference

Verified against code.claude.com/docs (plugins-reference.md, plugins.md, plugin-marketplaces.md,
discover-plugins.md), July 2026; validation and update sections re-verified October 2026 on
Claude Code 2.1.280 (docs: plugins/install, plugins/loading, env-vars). If a command below
errors unexpectedly, re-check those docs: the format evolves. `scripts/selftest.sh` is the
alarm for spec changes.

## The standard repo layout (plugin + its own marketplace in one repo)

```
my-workflow/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest (required)
│   └── marketplace.json     # makes this repo installable directly — see below
├── skills/                  # skill dirs, each <name>/SKILL.md (auto-scanned)
├── commands/                # flat .md slash-command files (legacy; prefer skills/)
├── agents/                  # custom agent definitions (optional)
├── hooks/hooks.json         # event handlers (optional)
├── .mcp.json                # MCP server configs (optional)
├── bin/                     # executables added to Bash PATH (optional)
├── scripts/                 # doctor.py / check scripts (plain files, run via skills)
├── ONBOARDING.md            # the paste-into-Claude front door
├── README.md                # what it does, install one-liner, owner
├── keys.env.example         # template for user keys (real keys file gitignored)
├── config.example.json      # placeholder personal settings (real config.json gitignored)
├── .sweep-allow             # optional: strings the owner approved to appear (see sweep.sh)
└── .gitignore
```

Components live at the **repo root**, not inside `.claude-plugin/`. Only the two JSON manifests
live in `.claude-plugin/`. Single-skill shorthand: a bare `SKILL.md` at repo root (no `skills/`
dir) auto-loads as one skill — fine for tiny workflows.

## plugin.json (`.claude-plugin/plugin.json`)

Only `name` is required (kebab-case; it namespaces skills as `/plugin-name:skill-name`).
Recommended:

```json
{
  "name": "my-workflow",
  "displayName": "My Workflow",
  "description": "One line: what it does and for whom",
  "version": "1.0.0",
  "author": {"name": "Owner Name", "email": "owner@example.com"},
  "repository": "https://github.com/owner/my-workflow",
  "keywords": ["video", "clips"]
}
```

- Always set `version` (start at `1.0.0`): `claude plugin validate --strict` fails without it
  (verified on Claude Code 2.1.280). Bump it on every release; installers only update when the
  string changes.
- `skills`/`commands`/`agents`/`hooks`/`mcpServers` fields override default component paths —
  only needed for non-standard layouts.
- `userConfig` prompts the user for values at enable time; reference as `${user_config.KEY}` in
  MCP/hook configs — useful for per-user keys and paths.

## marketplace.json (`.claude-plugin/marketplace.json`)

This is what makes `/plugin marketplace add owner/repo` work on the plugin's own repo:

```json
{
  "name": "my-workflow-marketplace",
  "description": "One line: what this marketplace offers (required in practice — strict validation warns without it)",
  "owner": {"name": "Owner Name", "email": "owner@example.com"},
  "plugins": [
    {
      "name": "my-workflow",
      "source": "./",
      "description": "One line: what it does"
    }
  ]
}
```

`source` also accepts `{"source": "github", "repo": "owner/repo", "ref": "branch"}`, git URLs,
`git-subdir` (monorepo sparse checkout), and npm packages — relevant when one catalog repo
lists many workflow repos.

## What teammates run (put these in ONBOARDING.md and README)

```
/plugin marketplace add owner/my-workflow
/plugin install my-workflow@my-workflow-marketplace
```

Non-interactive equivalents: `claude plugin marketplace add owner/repo` and
`claude plugin install <name> [--scope user|project|local]` (default scope: user).
Skills arrive namespaced: `/my-workflow:skill-name`.

Private repos: install uses the user's own git credentials — teammates need repo access and
`gh auth login` first.

## Validate and test locally BEFORE pushing

Run BOTH validation commands. `--strict` turns warnings (like a skill with no description)
into failures:

```bash
claude plugin validate ./my-workflow --strict                              # marketplace.json only
claude plugin validate ./my-workflow/.claude-plugin/plugin.json --strict   # plugin.json, every SKILL.md, hooks.json
claude --plugin-dir ./my-workflow                                          # load into a live session without installing
```

If marketplace.json lists `"source": "./plugins/<name>"` instead of `"./"` (older and
multi-plugin kits), put `plugins/<name>/` in place of `./my-workflow/` in the last two
commands. At the repo root they fail with "File not found" (validate) or load zero skills with
no error (`--plugin-dir`). Verified on Claude Code 2.1.280, October 2026.

Why both: when a repo has `.claude-plugin/marketplace.json` (the default shape here), pointing
`validate` at the repo folder validates the marketplace manifest and stops. It never opens the
skills, so a skill with no description prints "Validation passed". Pointing it at
`plugin.json` validates the plugin and each SKILL.md. Tested on Claude Code 2.1.280;
`scripts/selftest.sh` keeps a deliberately broken sample that must fail.

Inside a test session, `/reload-plugins` picks up edits without restarting.

## Paths inside plugin scripts/hooks

- `${CLAUDE_PLUGIN_ROOT}` — plugin install dir. Changes on every update; never store state there.
- `${CLAUDE_PLUGIN_DATA}` — persistent per-plugin dir (`~/.claude/plugins/data/<id>/`); use for
  caches, downloaded models, state that must survive updates.
- Never hardcode absolute machine paths in executing code — that's a top secret-sweep finding.
- Both variables are filled in inside SKILL.md text (and hook/MCP configs), not in a plain Bash
  shell. So any ONBOARDING step that saves per-user files (config, keys) goes through the
  plugin's own skill, which shows the real path, never a bare `$CLAUDE_PLUGIN_DATA` in a shell
  command (observed in October 2026 eval runs).

## Updates

Owner pushes to the repo → installers get it on their next update. Fixes must be merged
upstream, not patched locally: one merge updates every teammate. Three things decide whether
"next update" ever happens:

1. **Auto-update is OFF by default** for every marketplace except Anthropic's official ones.
   Turn it on per marketplace: `/plugin` → Marketplaces → select it → Enable auto-update, or
   set `"autoUpdate": true` on its entry under `extraKnownMarketplaces` in
   `~/.claude/settings.json` (adding a marketplace creates that entry; a settings entry wins
   over the toggle's record in `~/.claude/plugins/known_marketplaces.json`).
2. **Environment switches turn the whole update pass off:** `DISABLE_AUTOUPDATER`,
   `DISABLE_UPDATES`, or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`. The Claude desktop app's
   built-in Claude Code runs with `DISABLE_AUTOUPDATER` set (observed October 2026). Plugin
   updates come back with `"FORCE_AUTOUPDATE_PLUGINS": "1"` under `"env"` in
   `~/.claude/settings.json`. Leave company-managed settings alone.
3. **The `version` string gates every update.** Claude Code only updates installers when
   plugin.json's `"version"` changes, so bump it on every release. (Leaving it out would make
   each commit a new version, but strict validation fails without it, so always set it.)

Manual update: `claude plugin update <plugin>@<marketplace>` in a shell, or `/plugin` →
Installed → the plugin → Update now. Updates apply on the next session or `/reload-plugins`.
