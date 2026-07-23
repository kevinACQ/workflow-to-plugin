# Claude Code plugin format — verified reference

Verified against code.claude.com/docs (plugins-reference.md, plugins.md, plugin-marketplaces.md,
discover-plugins.md), July 2026. If a command below errors unexpectedly, re-check those docs —
the format evolves.

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

- Omit `version` during active development (each git commit acts as the version); set and bump
  it once teammates depend on stable releases.
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

```bash
claude plugin validate ./my-workflow            # checks plugin.json, SKILL.md frontmatter, hooks.json
claude plugin validate ./my-workflow --strict   # warnings become errors
claude --plugin-dir ./my-workflow               # load into a live session without installing
```

Inside a test session, `/reload-plugins` picks up edits without restarting.

## Paths inside plugin scripts/hooks

- `${CLAUDE_PLUGIN_ROOT}` — plugin install dir. Changes on every update; never store state there.
- `${CLAUDE_PLUGIN_DATA}` — persistent per-plugin dir (`~/.claude/plugins/data/<id>/`); use for
  caches, downloaded models, state that must survive updates.
- Never hardcode absolute machine paths in executing code — that's a top secret-sweep finding.

## Updates

Owner pushes to the repo → users get them via `/plugin update <name>` (or background
auto-update + a `/reload-plugins` notice). This is why fixes must be merged upstream, not
patched locally: one merge updates every teammate.
