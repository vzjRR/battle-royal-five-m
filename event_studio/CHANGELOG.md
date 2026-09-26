# Changelog

All notable changes to EVENT STUDIO. Uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Route check & repair** (Admin Center → Routes & arenas → Check route, or `/eventarenafix <arena> [apply]`): road routes snap to drivable roads with every leg checked for a road path; boat routes stay on deep open water with legs checked for land; on-foot points move to safe ground outside buildings. Report with per-point and per-leg status; fixes validated by the server (`admin:arena:applyFix`, max 300 m move) and the route marked as checked. Arenas carry a `route` type.
- **Route editor:** record a route by driving it, road route from the map waypoint (beta), start grid behind you, go-to / move-here / insert / reorder / radius per point, in-world preview. Event builder route picker with Edit route / New route.
- **Rewards:** several rewards per place, any number of places, participation and winning-team rewards in the builder; reward places normalised to numbers. Winners who disconnect after finishing and payouts that fail (character not loaded) are queued and paid automatically when the player is online (retry every minute).
- **Settings** now shows only the product, developer (vzjRR, Krovix Team) and rights; no technical details.
- **Krovix design system in the UI:** 8 designs (Krovix Gilded default, Sapphire, Obsidian, Emerald, Crimson, Arctic, Classic, Light), bundled fonts, built-in line icons in place of emoji, panel artwork, cut-corner shapes.
- **Admin Center → Appearance:** live design, layout, color, branding, artwork and category icon changes, saved on the server and pushed to every player (`admin:ui:get/save/reset`, permission `ui.edit`).
- **Player window layouts:** compact (default), docked (optionally keep moving while open) and full.
- `docs/PROTECTION.md`: researched licensing, activation and code-protection plan (Asset Escrow + Tebex approval/subscriptions, server-authoritative design, legal enforcement, rejected approaches, residual risks).
- `tools/build_release.py`: release builder with protection and compliance checks and escrow-ready zip output.
- **Roles component** (per-role health, armor, weapons; HUD role badge).
- **Modes:** `juggernaut`, `vip` (Protect the VIP), `hunters` (Hunters vs Runners, infection), `keep_moving` (server-side speed check), `musical_chairs` (dynamic zones). 5 new presets; catalog V1 coverage 79 → 84 of 119.
- **V2 pack 2:** `bounty` mode (Bounty Hunt + Assassin Hunt with private target ring), `package` mode (Deliver the Package / Hold the Package), `vehicle_tag` mode, KOTH `style=attack` (Attack vs Defense), trivia memory questions. 7 new presets (48 total); catalog V1 coverage 84 → 92 of 119.
- **Tournaments:** double elimination (grand final + reset) and Swiss (no rematches, one bye each, Buchholz tie-break).
- **`eventstudio perms [playerId]`** (console): shows identifiers, ACE role checks and framework groups per player and prints the grant line.
- **Self-test** (`eventstudio selftest`) and in-game arena Z-fix tool (`/eventarenafix`).
- **Arabic locale** (`locales/ar.lua`) and right-to-left NUI support (mirrored layout, per-paragraph direction for owner-written English text); `tests/test_locales.lua` checks keys and placeholder order for every locale.
- **Security fuzzing** (`tests/test_fuzz.lua`): every RPC with hostile payloads as player and admin; random actions in every mode.
- **Offline benchmark** (`tests/bench.lua`).
- **CI:** GitHub Actions runs the syntax check, all tests and the release guard on every push.

### Fixed
- HUD stayed on screen after an event ended: entering ARCHIVED sent a final state snapshot after the 'left' message. The server no longer does, and the client ignores ARCHIVED snapshots.
- No modes loaded on a real FXServer (every event failed with "unknown mode"): the manifest used `modes/*/server.lua`, and FXServer does not expand a wildcard in a folder name. Mode files are now listed explicitly; the test runner rejects such patterns like FXServer does.

### Changed
- Publisher branding: Krovix Store.

## [0.1.0-alpha] — 2026-09-25

First alpha. Feature complete for the V1 scope; not yet tested on a live server.

### Added
- **Planning:** research, master plan, architecture, event engine, 119-entry event catalog, security, database, API and development docs.
- **Event Engine:** lifecycle state machine (SCHEDULED → REGISTRATION → LOBBY → COUNTDOWN → ACTIVE ⇄ PAUSED → FINISHING → RESULTS → REWARDS → ARCHIVED, plus CANCELLED), pool of routing buckets, participants/teams/spectators, a clock that stops while paused, viability checks, a reconnect grace window, crash-recovery return points.
- **Components:** spawns, vehicles (spawned by the server), combat (weapon whitelist, friendly-fire filter, damage-log kill attribution, lives/respawn), bounds, zones (capture/ownership/shrinking), checkpoints (server-validated, laps, hidden/unordered).
- **Modes:** race, deathmatch, gungame, sumo, koth, ctf, zone_survival, hunt, redlight, trivia, reaction, custom.
- **Content:** 36 presets, 12 sample arenas, trivia question sets.
- **Services:** scheduler (once/daily/weekly/monthly/interval, rotations), director, tournaments (single elimination, round robin, best-of-N), rewards with payout ledger, stats/leaderboards/personal bests, announcements, Discord webhooks, logs.
- **Integrations:** standalone, ESX, QBCore, Qbox adapters; ox_inventory items; client revive/inventory hooks; buyer hook files.
- **Storage:** oxmysql (automatic migrations), KVP, memory.
- **Security:** single RPC gateway with rate limiting, input validation, role-based permissions, confirmation required for dangerous actions; audit and security logs.
- **NUI:** event browser, HUD, results, trivia/reaction panels, spectator bar, Admin Center with event builder and arena editor, default and light themes.
- **API:** server exports and events; client exports.
- **Tests:** FiveM mock runtime; 64 unit and simulation tests (1–64 players, all modes, security, persistence, tournaments).

### Known limitations
- Arena coordinates are samples and need checking in game.
- The framework death/revive hooks are best-effort defaults; check them against your ambulance resource.
- Planned for later: roles (Juggernaut/VIP), NPC waves, double elimination/Swiss, in-game prop placement.
