# Client lane: packaging a workflow for paying clients

Use this lane when the Step 0 answer is "paying clients". Clients don't have GitHub or Claude
Code. They use claude.ai, where skills install by uploading a zip file in Settings. So the
two-command plugin install doesn't apply, and paid work must never sit in a public repo.

What clients get: one paste-in prompt (with download links inside it) and a PDF guide.
What the owner keeps: a private repo that is the single source of truth, with the checks that
make every release safe.

## What can ship to a client

Only skills transfer to claude.ai: each skill folder (SKILL.md plus its references, templates,
and scripts that run in claude.ai's code sandbox). These do NOT work there: slash commands,
hooks, MCP servers, plugin `userConfig`, and anything that calls the owner's own systems
(their CRM, database, internal APIs, or files on their computer). During Step 1, flag every
step of the workflow that depends on one of those. It gets rewritten to work from what the
client pastes or uploads, or it stays out of the client kit.

## Kit layout

```
my-client-kit/
├── .claude-plugin/              # plugin.json + marketplace.json: the owner's team installs
│                                #   and tests the kit the normal two-command way
├── skills/<name>/SKILL.md       # what clients get: one zip per skill
├── client/
│   ├── kit.conf                 # which skills ship, zip name prefix
│   ├── INSTALL-PROMPT.txt       # the ONLY thing a client receives
│   ├── INSTALL-GUIDE.md         # text source of the PDF (the sweep can read this)
│   └── <Kit>-Install-Guide.pdf  # the same steps for clients who prefer reading
├── dist/<prefix><name>.zip      # committed; check 7 proves they match skills/
├── scripts/                     # sweep.sh, build_client_zips.sh, check_kit.sh, doctor.sh
├── LICENSE                      # proprietary: "All rights reserved"
└── .sweep-allow                 # strings approved to appear (e.g. the brand name)
```

Copy from this kit: `scripts/sweep.sh`, `scripts/build_client_zips.sh`, `scripts/check_kit.sh`
(plugin root), and everything in `templates/client/` (this skill's folder):
`kit.conf` and `INSTALL-PROMPT.txt` and `INSTALL-GUIDE.md` go in `client/`, and
`LICENSE-proprietary.txt` becomes `LICENSE` at the repo root.

## The rules, and what enforces each one

| Rule | Enforced by |
|---|---|
| The repo is always **private**. Paid work never goes on public GitHub. | check_kit.sh check 9 |
| A **proprietary license** ("All rights reserved"), never MIT or another open license. | check 8 |
| **Zero never-ship words** in what clients receive (skills/ and client/). Any hit blocks the release. | `sweep.sh --for client`, which `build_client_zips.sh` runs before building |
| Zip layout claude.ai accepts: `<name>/SKILL.md` at the top level, nothing else at the top. | check 5 |
| Skill name: lowercase letters, numbers, hyphens, at most 64 characters, matches its folder, no reserved words (anthropic, claude). | check 2 |
| Description present and at most **1,024 characters**. | check 3 |
| Each zip under **30 MB** (claude.ai's upload cap). | check 6 |
| Zips match the source exactly. A stale zip ships old or unchecked text. | check 7 (drift) |
| A filled-in **paste-in install prompt** with one download link per skill, plus a **PDF guide**. | check 10 |
| Private files never ride along: zips hold only what git would publish (no gitignored config). | `build_client_zips.sh` |
| Download links are **unlisted and revocable** (e.g. a Google Drive file shared "Anyone with the link"), never a public page. | the owner, at upload time |
| **Release rule:** a fix replaces the SAME file (a new version of it), never a new upload, so links already sent keep working. | the owner, at upload time |

Branding: a client kit may name the seller ("from Example Co"). Keep the company name on the
never-ship list (it still protects public repos) and add it to this kit's `.sweep-allow`
instead, with the owner's OK.

Limits above are claude.ai's as of October 2026. If an upload is rejected for a reason the
checks didn't catch, update check_kit.sh and this table.

## The lane, step by step

1. **Scaffold** (SKILL.md Step 2) and copy the scripts and templates above. `git init` at once.
2. **Fill in** `client/kit.conf`, `LICENSE`, `client/INSTALL-GUIDE.md`, and every part of
   `client/INSTALL-PROMPT.txt` except the download links (they come in step 5). Include one
   test line per skill: the exact sentence a client types to see it work.
3. **Build:** `bash scripts/build_client_zips.sh`. It runs the client sweep first and stops on
   any hit. Fix and re-run until it builds.
4. **Check:** `bash scripts/check_kit.sh`. Before upload, the only allowed problems are check 9
   (no GitHub repo yet, a warning) and check 10 (links not filled in yet).
5. **Upload (owner's OK first):** upload each zip to the owner's file storage as an unlisted,
   revocable link. For Google Drive, a direct-download link looks like
   `https://drive.google.com/uc?export=download&id=<FILE_ID>`. Paste the links into the
   prompt. Export `INSTALL-GUIDE.md` to `client/<Kit>-Install-Guide.pdf`.
6. **Check again:** `bash scripts/check_kit.sh` must print ALL CHECKS GREEN (check 9 may still
   warn). Run `sweep.sh --for client` one last time.
7. **Private repo (owner's OK first):** `gh repo create <owner>/<kit> --private`, push, and
   re-run check_kit.sh. Check 9 must now PASS.
8. **Test like a client:** the owner pastes the prompt into a fresh claude.ai chat, installs
   every skill, and runs each test line. This is the only check that proves a client's
   experience, so it is not optional.
9. **Hand off:** give the owner the filled prompt text in one copyable block. That text is
   all a client receives.

## Releasing a fix

Edit the skill → `build_client_zips.sh` → `check_kit.sh` all green → upload each changed zip
as a **new version of the same file** (Drive: right-click > File information > Manage
versions > Upload new version) → commit the source and the rebuilt `dist/` zips → bump the
`version` in `.claude-plugin/plugin.json`. Clients re-download from the same link.

**Revoking access:** turn off link sharing on the files. The client's installed copy keeps
working, but they can't download again.
