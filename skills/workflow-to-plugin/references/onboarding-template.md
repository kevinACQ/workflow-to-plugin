# ONBOARDING.md — the proven pattern

The ONBOARDING.md is the front door of a packaged workflow. Its job: a non-technical person
pastes ONE block into Claude, answers plain-English questions, and ends with a working,
personalized setup — never touching a terminal or editing a file by hand. This pattern is
proven in production (a video-editing workflow onboarded non-technical marketers with it);
copy its shape, not its content.

## The shape (7 parts, in order)

1. **Promise line** — one sentence: what the reader gets, and "You do not need to be technical."
2. **Repo line** — the repo URL, whether it's private, and (if forked) where the upstream engine
   lives and which fixes go where.
3. **3-step human instructions** — (a) get the Claude Code app (claude.com/claude-code, paid plan),
   (b) start a new chat and paste the big box below, (c) answer its questions. Include the two
   expectations: Claude will ask permission to run steps (click Allow), and it keeps a visible
   checklist.
4. **The copy-paste block** — fenced between "✂️ COPY FROM HERE" and "COPY TO HERE ✂️" markers.
   This is a prompt TO Claude, written in the user's first person ("I am NOT technical — do
   everything yourself"). See structure below.
5. **"Once it's set up"** — the plain-English phrases the user says to run the workflow day-to-day
   ("just say *make clips from this*"), where outputs land, how to change preferences later.
6. **Feedback loop line** — "Found a bug or made it better? Tell Claude: *file an issue about
   this*" — so improvements reach the owner instead of dying on one laptop.
7. **Owner line** — who owns this workflow and where issues go.

## Structure of the copy-paste block

Number the steps. Each step is an instruction to Claude, not to the human:

1. **GET THE KIT** — install the plugin. Give the exact commands Claude should relay:
   `/plugin marketplace add <owner>/<repo>` then `/plugin install <plugin>@<marketplace-name>`.
   Include the auth fallback: if access is refused, run `gh auth login` (browser flow, work
   account); if no account/org access, help them create one and tell them who to ask for an
   org invite. Never proceed on someone else's credentials.
2. **SET UP MY MACHINE** — run the kit's doctor/self-check script; install ONLY what's missing.
   Include the no-admin fallback if the audience may lack admin rights: standalone binaries
   into `~/bin` (on PATH), `pip install --user`, never Homebrew or installers that prompt for
   an admin password.
3. **HOW I'LL USE IT** — the plain-English invocation ("I'll just say X and you run it").
4. **KEYS** (only if the workflow needs any) — walk the user click-by-click through getting
   their OWN free/paid key, then save it into the kit's gitignored keys file (copied from the
   repo's `*.example` template). Offer the keyless fallback if one exists.
5. **PERSONALIZE** (if the workflow has profiles/config) — interview ONE question at a time;
   apply answers to the kit's own config/profile mechanism, never by editing the shared engine.
6. **TEST RUN** — do one real run end-to-end, run the kit's pass/fail checks on the output,
   show the result, and iterate until the user is happy.

Close the block with the standing instruction: "Throughout: be patient, assume I've never used
a terminal, explain in plain English. Only use this kit — don't pull tools or keys from anywhere
else on my computer."

## Rules that make it work

- Write the block in the **user's first person** — it survives copy-paste into a fresh session
  with zero surrounding context. It must be fully self-contained.
- Every step Claude can do itself, Claude does. The human only: answers questions, drags in
  files, pastes keys they created, and clicks Allow.
- The doctor script is the gate: "re-run until it prints READY, then tell me in plain English."
- Never bury the paste block below the fold of explanation — promise, 3 steps, block.
