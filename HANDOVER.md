# Project handover: EVENT STUDIO (Krovix Store)

Read this first. It is the single place that says what exists, what was decided, what is next and how to work on the repository. The change log at the bottom updates itself on every commit (see "Keeping this file current").

## 1. What this is

EVENT STUDIO is a commercial FiveM resource (Lua 5.4 + NUI in plain HTML/CSS/JS) for running server events and competitions: races, deathmatch, gun game, KOTH, CTF, zone survival, hunts, trivia, tournaments and more (20 modes, 48 ready-made events). Publisher: **Krovix Store**. It lives in `event_studio/`.

- Standalone, ESX, QBCore and Qbox. oxmysql or KVP storage. English and Arabic (right-to-left UI).
- Every event runs in its own routing bucket; the server decides everything (positions, kills, checkpoints, rewards).
- Sold as a **monthly subscription** through Tebex and protected with **Cfx Asset Escrow**. Custom licensing, obfuscation and remote code are forbidden by the Cfx rules (see `event_studio/docs/PROTECTION.md`).

## 2. Decisions that must not be undone

| Decision | Where it is written |
|---|---|
| Monthly subscription only, via Tebex + Cfx Portal escrow; no custom license servers, no obfuscation, no remote code | `event_studio/docs/PROTECTION.md` |
| No server-specific branding or data in the product (no ENCLAVE references, no hard-coded frameworks, inventories, economies or Discord data) | `event_studio/docs/MASTER_PLAN.md` |
| Server-authoritative: never trust the client for positions, kills, finishes or rewards | `event_studio/docs/SECURITY.md` |
| Krovix design system is the default look; owners may change everything | `event_studio/config/ui.lua`, Krovix Design System (section 5) |
| FXServer does not expand `*` in folder names inside `fxmanifest.lua`: list mode files explicitly | `event_studio/fxmanifest.lua`, `tests/test_boot.lua` |
| No AI model names or identifiers in commits, code, docs or PRs | this file |

## 3. Current state (update this when you change something big)

**Built and tested offline (141 automated tests pass):** event engine and lifecycle, 20 modes, 48 presets, 12 sample arenas, tournaments (single/double elimination, round robin, Swiss), scheduler and director, rewards with payout ledger, stats and leaderboards, Discord webhooks, Admin Center, event builder, arena editor, self-test, arena height fixer, permissions diagnostic, English and Arabic, 8 UI designs with live appearance editing.

**Tested on a live server (owner's local QBCore server, txAdmin):**
- `eventstudio selftest` passes: OneSync, buckets, vehicle spawn, oxmysql, QBCore, 48 definitions.
- A boat race was played to the end.
- Fixed from live testing: modes not loading (manifest glob), HUD staying after an event ended, staff permission diagnosis (`eventstudio perms`).

**UI / design (latest work):**
- Designs: `krovix-gilded` (default), `krovix-sapphire`, `krovix-obsidian`, `krovix-emerald`, `krovix-crimson`, `krovix-arctic`, `classic`, `light`. Registry: `event_studio/shared/themes.lua`; CSS: `event_studio/web/themes/`.
- Player window (F7) layouts: compact (default), docked (optional keep-moving), full.
- Admin Center → Appearance edits theme, layout, colors, branding, artwork and category icons live; saved server-side (`server/core/ui.lua`, storage document `setting/ui`), pushed to all players.
- Fonts bundled in `web/fonts/` (OFL), icons in `web/js/icons.js` (no emoji).

**Routes, rewards, settings (latest work, from live testing feedback):**
- Owner reported race lines going into buildings and boat checkpoints on land. Added **Check route** (client `client/components/arenatool.lua`, server `admin:arena:applyFix`): snaps to roads / deep water / safe ground with the game's own map data and checks every leg. Sample arenas now carry `route` types. Must be run in game on each sample route (it cannot run offline).
- Route editor (`web/js/admin/arenas.js`, client `client/components/routeedit.lua`): record by driving, from waypoint (beta), start grid, in-world preview, per-point tools. Builder has a route picker with Edit/New route.
- Rewards: multi-entry editor; pending queue for disconnected winners and failed payouts (`server/core/rewards.lua`, storage kind `payout_pending`).
- Settings page shows only product, developer (vzjRR, Krovix Team, Oman) and rights.

**Phone & tablet app (latest work, owner request):**
- `web/phone.html` is the F7 window in app mode (`data-embed`, `?device=phone|tablet|npwd`): `app.js` detects it, pulls its data with the `phone:init` NUI callback every 10 s (no messages reach an iframe inside another resource), `closePanels` asks the phone to close. CSS under `body.embed` in `panels.css`.
- `client/components/phone.lua`: one adapter per device (LB Phone, LB Tablet, Quasar PRO, YSeries, 17mov, GKSPhone), registered after `client:ready`, re-added when a phone restarts; `ES.Phone.close()` runs on every event teleport (only LB exposes a close export). NPWD 4: `server/core/phone.lua` + `dist/web/app.js` (plain JS, `window.__npwd_React`). Settings: `config/phone.lua`. Guide: `docs/guides/PHONES.md`.
- Built from each phone's official docs and templates; **not tested with the real phones** (paid resources). GKSPhone fields come from search snippets (their docs site did not load); NPWD 4 load path (`dist/web/app.js`) follows their app template.

**Commands and keys (latest work, owner request):**
- Typed commands (`/event`, `/events`, `/eventjoin`, `/eventleave`, `/eventspectate`, `/eventarenafix`) are registered on the client only when `client:ready` says the player is staff (`ES.registerStaffCommands`, `client/main.lua`). Console `eventstudio` is `restricted` (console, or ACE `command.eventstudio`).
- Players only use keys: events window (F7), scoreboard hold (U), race reset (F9). Owners change them in Admin Center → Appearance → Player controls; stored in the UI overrides (`keys`), validated in `server/core/ui.lua` (whitelist, no F8, no duplicates), sent as `ui.keys` and applied live by `ES.applyKeys`.
- Each key mapping's internal command has the key in its name (`es_menu_f7`) because GTA keeps the first default per command; chat suggestions for these names are removed.
- Announcements say "Press <key>" (`ES.UI.menuKey()`), no command names.

**Not done yet / next steps:**
0. Owner: run **Check route** on every sample route in game and apply the fixes; re-record any route with problems.
1. Owner: in-game test matrix in `event_studio/docs/TESTING.md` §2 (combat, CTF, trivia, tournaments, reconnects), `resmon` numbers.
2. Owner: `/eventarenafix <arena> apply` for every sample arena (coordinates are approximate).
3. Owner: open the Events app in the phone/tablet you use (check sign up / join and that LB closes on event start). 3b. Owner: check the new UI in game (all designs, compact/docked/full, keep-moving, Arabic), and that a normal player has no typed commands while staff do; change the F7 key in Appearance → Player controls and check it switches live.
4. Cfx Portal escrow upload of `dist/event_studio-<version>.zip`, Tebex monthly package, price.
5. Legal review of `event_studio/LICENSE.md` (draft subscription license).
6. Move the CHANGELOG `[Unreleased]` section under a version before the first release.
7. Ideas not started: NPC waves, in-game prop placement, per-player UI preferences.

## 4. How to work on it

```sh
sh tools/install_hooks.sh                 # once per clone: enables the automatic change log below
cd event_studio && lua5.4 tests/run.lua   # all tests (FiveM mock runtime); lua5.4 tests/run.lua <filter> for one file
ES_SEED=7 lua5.4 tests/run.lua fuzz       # random-input tests with another seed
python3 tools/build_release.py            # release guard: versions, escrow rules, secrets, syntax, tests -> dist/*.zip
python3 tools/gen_catalog.py event_studio/docs/EVENT_CATALOG.md   # regenerate the event catalog
cd event_studio && python3 -m http.server 8765   # UI preview: web/index.html?theme=krovix-obsidian&layout=docked#browser
```

UI preview scenes (`#...`): browser, admin, appearance, live, builder, tournaments, hud, results, trivia, tdm, jug. Query: `theme=`, `layout=compact|docked|full`, `lang=ar`, `accent=ff8800`.

Key places:
- Server core: `event_studio/server/core/` (rpc gateway, manager, instance, participants, results, admin, ui, tournament...).
- Components: `event_studio/server/components/`; modes: `event_studio/modes/<id>/server.lua` (register new mode files in `fxmanifest.lua`).
- Client: `event_studio/client/`; NUI: `event_studio/web/` (`js/app.js` message bus, `js/theme.js`, `js/browser.js`, `js/hud.js`, `js/admin/*`).
- Config for owners: `event_studio/config/`; locales: `event_studio/locales/` (every locale must keep English placeholders in order; tested).
- Docs: `event_studio/docs/` (plan, architecture, security, API, testing, guides, store listing).

Rules for changes:
- Every client request goes through the RPC gateway with a schema, rate limit and permission; dangerous actions need `confirm`.
- User text is always inserted as text nodes in the NUI, never as HTML.
- Add or update tests with every behaviour change; run the full suite and `tools/build_release.py` before pushing.
- Develop on the branch you were given; never force-push someone else's branch. Commit messages end with the co-author trailers the session asks for.

## 5. Krovix design system

The reusable brand and UI reference for all Krovix products is kept outside this repository as a design-system artifact:

**https://claude.ai/artifact/ALQwJWLMpLUHLsNyw5YMxh** (Krovix Design System: six colour themes as tokens, bundled fonts, 38 icons, logos, brand book, component previews, developer guide).

Its reference implementation is this repository's `event_studio/web/themes/`, `web/js/theme.js` and `web/js/icons.js`. When the product's look changes, update the design system too. The design exploration canvas with the first mockups: https://claude.ai/artifact/Mrtg4nZTppqjv9wCmyh6Gg

## 6. Keeping this file current

- **Automatic:** `.githooks/post-commit` runs `tools/update_handover.py` after every commit and folds the refreshed change log into that commit. Enable it once per clone with `sh tools/install_hooks.sh`. Without hooks, run `python3 tools/update_handover.py` before committing (`--check` reports if it is stale).
- **By hand:** when you finish a piece of work, update section 3 (current state and next steps) in the same commit. Keep it short and true.

## 7. Change log (automatic)

<!-- AUTO-LOG:START -->
_Generated by `tools/update_handover.py` from git history (21 commits in total, newest first, last 21 shown). Do not edit by hand._

| Date | Change | Files |
|---|---|---|
| 2026-09-27 | Refresh the handover change log | 1 |
| 2026-09-27 | Say active / in progress instead of live | 9 |
| 2026-09-27 | Add an Events app for phones and tablets | 20 |
| 2026-09-26 | Make typed commands staff only; players use a configurable events window key | 27 |
| 2026-09-26 | Route check and repair, route editor, reliable rewards, clean settings page | 27 |
| 2026-09-26 | Uppercase display text in Syncopate themes | 6 |
| 2026-09-26 | Add Krovix design system to the UI, live Appearance editing and Codex handover | 70 |
| 2026-09-26 | Fix HUD staying on screen after an event ends | 5 |
| 2026-09-26 | Add 'eventstudio perms' console diagnostic for staff permissions | 5 |
| 2026-09-26 | Fix modes not loading on FXServer: list mode files in the manifest | 6 |
| 2026-09-26 | Add Arabic locale and right-to-left NUI support | 16 |
| 2026-09-26 | Add bounty/assassin, package, vehicle tag modes; KOTH attack style; memory trivia | 24 |
| 2026-09-26 | feat(tournaments): double elimination (with bracket reset) and Swiss formats | 5 |
| 2026-09-26 | feat(ops): monthly-subscription licensing + draft EULA, live self test, arena ground-height fixer | 13 |
| 2026-09-25 | feat: V2 pack (roles, juggernaut, VIP, hunters, keep moving, musical chairs), fuzzing, benchmark, CI; Krovix Store branding | 43 |
| 2026-09-25 | docs(protection): researched licensing/activation plan + release build guard | 10 |
| 2026-09-25 | docs: buyer guides, testing doc, changelog, license placeholder; fix weapon snapshot ordering and far-vehicle streaming | 24 |
| 2026-09-25 | feat(nui): event browser, HUD, results, trivia/reaction panels, admin center, event builder, arena editor | 17 |
| 2026-09-25 | test: combat, mode, platform and security simulations; fix schema object defaults and join order | 5 |
| 2026-09-25 | feat: EVENT STUDIO core engine, modes, client and test harness | 95 |
| 2026-09-25 | docs: EVENT STUDIO research, master plan, architecture and catalog | 11 |
<!-- AUTO-LOG:END -->
