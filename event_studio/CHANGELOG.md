# Changelog

All notable changes to EVENT STUDIO. Uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `docs/PROTECTION.md`: researched licensing, activation and code-protection plan (Asset Escrow + Tebex approval/subscriptions, server-authoritative design, legal enforcement, rejected approaches, residual risks).
- `tools/build_release.py`: release builder with protection and compliance checks and escrow-ready zip output.

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
