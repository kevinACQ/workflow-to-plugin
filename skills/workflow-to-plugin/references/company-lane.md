# Company lane: one link for everyone at your company

Use this lane when the Step 0 answer is "everyone at my company". The output is ONE link: a
private GitHub repo in the company's GitHub organization, whose README tells each person how
to get the workflow in the app they use.

## Who the link reaches (tell the owner once, plainly)

- **The link opens only for people in the company's GitHub organization.** Anyone else sees a
  "not found" page. Check the size first: `gh api --paginate "orgs/<org>/members?per_page=100" --jq length`.
- **People without GitHub still get it in Claude** through the company plugin catalog, with no
  link and no GitHub account needed. That's why the catalog step matters.
- **ChatGPT has no install-by-link.** Its users download the skill zip from the repo's latest
  Release (which needs GitHub access too) and upload it as a skill.

If the owner wants everyone, including people outside the GitHub org, to reach the ChatGPT zip,
offer the client lane's approach: an unlisted company file link that gets replaced in place on
each release. Then do what the owner picks.

## Where things live

- **Plugin repo:** private, created under the company's GitHub organization, the SAME owner as
  the company catalog repo. A synced catalog can list a private plugin repo only when both have
  the same owner.
- **Company settings** (company name, GitHub org, catalog repo, who to ask):
  `~/.config/workflow-to-plugin/company.conf`, outside every repo. Copy
  `templates/company/company.example.conf` there and fill it in once. Never commit it.

## Make it work in every app

- **No top-level `bin/` folder.** claude.ai and Cowork reject the whole plugin when one exists.
  Keep executables in `scripts/` and call them as `${CLAUDE_PLUGIN_ROOT}/scripts/<name>`.
- **Skills that must also work as uploaded skills** (ChatGPT, or claude.ai "Upload skill") ship
  only their own folder. Keep their scripts inside the skill (`skills/<name>/scripts/`) and call
  them with `${CLAUDE_SKILL_DIR}/scripts/<name>`. `check_kit.sh` warns (check 3b) when a skill
  points at the plugin root.
- **What each app loads:** skills and commands load everywhere. Agents and hooks load in Cowork
  and Claude Code only. A local MCP server doesn't load in claude.ai chat.

## The company catalog: three routes

Run the kit's route checker from inside the plugin repo. It's read-only:

```bash
bash <kit>/scripts/company_route.sh
```

| Route | When | What happens (each outward step needs the owner's OK) |
|---|---|---|
| **A** | You can push to the catalog repo | Add one entry to the catalog's `.claude-plugin/marketplace.json`: `{"name": "<plugin>", "source": {"source": "github", "repo": "<org>/<repo>"}}`. Validate it, then open a pull request. When it merges, the catalog syncs and a Claude Owner sets who gets it. |
| **B** | You can't (the usual case) | Build `dist/<plugin>-plugin.zip` with `scripts/build_plugin_zip.sh`. Pilot it first: Customize > Plugins > Add > Upload plugin puts it on YOUR account only. Test it in a new chat. Then, with the owner's OK and a fresh sweep, open it and click **Publish to org**. On Team plans that publishes at once after a security scan; Enterprise waits for an Owner's review. |
| **C** | Upload plugin or Publish to org is missing (an Owner turned it off) | `company_route.sh --upload-missing` prints a ready request to the catalog owner, with the repo link and the zip to attach. |

## The lane, step by step

1. **Scaffold** (SKILL.md Step 2) and `git init`. Copy from this kit: `scripts/sweep.sh`,
   `scripts/build_client_zips.sh`, `scripts/build_plugin_zip.sh`, `scripts/check_kit.sh`.
2. **README:** start it from `templates/company/README-pick-your-app.md` and fill every
   double-brace placeholder. It opens with "Pick your app" (Claude, Claude Code, ChatGPT) and an
   "If you are Claude reading this" block with the two install commands.
3. **Sweep:** `bash scripts/sweep.sh --for team .` (coworkers may see company names).
4. **Build:** `bash scripts/build_client_zips.sh --for team` (skill zips, for ChatGPT and single-skill
   uploads) and `bash scripts/build_plugin_zip.sh` (the claude.ai plugin zip).
5. **Check:** `bash scripts/check_kit.sh --lane company` must print ALL CHECKS GREEN (check 9
   warns until the repo exists on GitHub). Then validate both paths (SKILL.md Step 6).
6. **Publish (owner's OK for each, never batched):**
   - create the private repo under the company org and push;
   - re-run `check_kit.sh --lane company` (check 9 must PASS);
   - `gh release create v<version> dist/*.zip --notes "<what changed>"` so the README's ChatGPT
     step has a file to download;
   - the catalog route from the table above.
7. **Prove the link:** in a fresh Claude Code session, paste only the repo link and say "install
   this". Then, in another new session, ask for the workflow in plain words and confirm it runs.
   Afterward remove the test install: `claude plugin uninstall <plugin>@<marketplace>` and
   `claude plugin marketplace remove <marketplace>`, then show `claude plugin list`. The claude.ai
   and ChatGPT routes are proven by the owner's own upload in step 6, not by this test.
8. **Hand back:** the one repo link, plus the announcement from SKILL.md Step 8.

## Releasing a fix

Edit → bump `version` in `.claude-plugin/plugin.json` → sweep → rebuild both zips →
`check_kit.sh --lane company` → push → new GitHub Release with the new zips. Then: route A, the
catalog re-syncs on push (if automatic sync is on); route B, upload the new zip as a new version
and publish again. Claude Code installers get it through `/plugin` updates or auto-update.
