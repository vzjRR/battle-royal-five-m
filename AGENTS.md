# Instructions for coding agents (Codex and others)

1. **Read `HANDOVER.md` first.** It has the project state, the decisions that must not be undone, the next steps and how to run everything.
2. **Enable the hooks once:** `sh tools/install_hooks.sh`. After that every commit updates the change log in `HANDOVER.md` automatically. If hooks cannot run in your environment, run `python3 tools/update_handover.py` before each commit.
3. **Update `HANDOVER.md` section 3** (current state and next steps) in the same commit whenever you finish or change something significant.
4. **Test before you push:** `cd event_studio && lua5.4 tests/run.lua` and `python3 tools/build_release.py` must both pass. Add tests for every behaviour change.
5. **Respect the product rules:** server-authoritative logic, every client request through the RPC gateway (schema, rate limit, permission, `confirm` for dangerous actions), user text as text nodes only, no server-specific branding, no custom licensing or obfuscation, and new mode files listed explicitly in `fxmanifest.lua`.
6. **Design:** follow the Krovix Design System (link in `HANDOVER.md` section 5). New UI uses the CSS variables in `event_studio/web/themes/base.css` and icons from `event_studio/web/js/icons.js`; no emoji in the UI.
7. **Git:** work on the branch you were given, write clear commit messages, never rewrite someone else's history, and never put AI model names or identifiers in commits, code, docs or PRs.
