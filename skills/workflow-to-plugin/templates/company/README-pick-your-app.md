# {{PLUGIN DISPLAY NAME}}

{{ONE SENTENCE: what it does and who it's for}}

## Pick your app

**Claude (claude.ai or the desktop app)**
It's in our company plugins. Go to Customize > Plugins > Discover, search "{{PLUGIN DISPLAY NAME}}", and turn it on. Then say: "{{TRIGGER PHRASE}}".

**Claude Code**
Paste this one line into Claude Code: `Set me up: https://github.com/{{GITHUB OWNER}}/{{REPO NAME}}`

**ChatGPT**
Download `{{SKILL ZIP NAME}}` from this repo's latest Release (Releases, on the right side of this page). In ChatGPT, upload it as a skill: Create > Upload from your computer. Don't unzip it. Your workspace admin has to have Skills turned on.

### If you are Claude reading this

The user wants this installed. Run these two commands, then tell them to start a new session and say "{{TRIGGER PHRASE}}":

```
claude plugin marketplace add {{GITHUB OWNER}}/{{REPO NAME}}
claude plugin install {{PLUGIN NAME}}@{{MARKETPLACE NAME}}
```

If `claude` isn't found (some desktop-app setups), run the same commands with
`"$CLAUDE_CODE_EXECPATH"` in its place: that is the Claude app's own command. New skills load
in the next session, not this one. If a command says the repository wasn't found or access was denied, the user needs access to the {{GITHUB OWNER}} GitHub organization. Tell them to ask {{OWNER CONTACT}}.

**Owner:** {{OWNER}}. Found a bug or have an idea? Tell Claude "file an issue about this."
