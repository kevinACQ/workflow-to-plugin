Hi {{CATALOG OWNER}}, could you add {{PLUGIN NAME}} to the {{COMPANY}} Claude plugin catalog?

What it does: {{PLUGIN DESCRIPTION}}
Repo (private, same GitHub owner as the catalog): {{REPO LINK}}

Either of these works:
1. Add this entry to the "plugins" list in {{CATALOG REPO}}'s .claude-plugin/marketplace.json:
   {"name": "{{PLUGIN NAME}}", "source": {"source": "github", "repo": "{{PLUGIN REPO}}"}}
2. Or upload the attached plugin zip in Organization settings > Plugins & skills > Add > Upload a plugin.

It passed its own checks and a leak sweep before I sent this. Suggested access: Available to install.
Thanks!
