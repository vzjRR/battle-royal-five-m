# Store listing draft — EVENT STUDIO by Krovix Store

> Internal draft for the Tebex package page and the Cfx.re forum release post. Not shipped to customers.
> **Publish only after the in-game test matrix passes** (docs/TESTING.md §2). Prices and support details are placeholders for Krovix Store to fill in.

---

## Title

**EVENT STUDIO — All-in-one Events & Competitions | Standalone · ESX · QBCore · Qbox**

## Short description (Tebex card, ~150 chars)

Run races, PvP, objectives, survival, hunts, social games and tournaments from one resource. Built-in scheduler, admin panel, leaderboards.

## Description

Turn your server into an event destination. **EVENT STUDIO** gives your staff one place to create, schedule, run and reward events, and gives your players a clean event browser, a live HUD and season leaderboards.

**17 game modes, 41 ready-made events**
Racing (circuits, sprints, time trials, drag, boat, bike, elimination races, parkour) · Deathmatch (FFA, TDM, last man/team standing, duels, weapon-restricted variants) · Gun Game · Sumo & Demolition Derby · King of the Hill & Domination · Capture the Flag · Shrinking-Zone Survival · Scavenger & Hidden Treasure Hunts · Red Light Green Light · Trivia · Reaction · Juggernaut · Protect the VIP · Hunters vs Runners · Keep Moving · Musical Chairs · staff-hosted custom events.

**Built for staff**
- In-game Admin Center: event builder, arena editor ("add point at my position"), live control (pause, force finish, spectate, teleport, disqualify, announce), logs.
- Scheduler with weekly rotations, plus an optional Event Director that starts events on its own based on how many players are online.
- Tournaments: knockout brackets and leagues, best of 1/3/5.

**Built for players**
- Event browser with live and upcoming events, lightweight HUD, live scoreboard, results screen, spectator camera, personal bests, season leaderboards.

**Built to be fair**
- The server decides everything: checkpoints, kills, zones and rewards are all validated on the server. Players' own weapons are saved and returned after each event. Rewards can't be paid twice.

**Built to fit your server**
- Works standalone or with ESX / QBCore / Qbox (auto-detected), ox_inventory items, optional oxmysql (or no database at all).
- Several events at once, each in its own instance.
- Your branding: title, logo, accent color, themes. English included; add languages through locale files.

## Spec table (required by the Cfx.re release rules)

| | |
|---|---|
| Code is accessible | Partial: config, locales, themes, hook files and SQL are open; core is protected by Cfx Asset Escrow |
| Subscription based | Yes — monthly subscription |
| Lines (approximately) | ~10,800 Lua + ~1,600 UI |
| Requirements | OneSync; optional: oxmysql, ESX/QBCore/Qbox, ox_inventory |
| Support | Yes (*Krovix Store support channel — fill in*) |

## Package plan (see docs/PROTECTION.md)

| Package | Type | Notes |
|---|---|---|
| EVENT STUDIO — Monthly | Subscription, billed every month | The only public package. Access ends when the subscription ends (revocable). Tied to the buyer's Cfx account |
| Partner / approved servers | Manual payment on the monthly package | Krovix Store issues access itself (Tebex → Payments → Manual Payment). Check how this behaves on subscriptions before use (PROTECTION.md §5) |

Pricing (to fill in): monthly price ______ · optional "network" tier for several servers on one Cfx account, enforced by the EULA.

## Media checklist

- [ ] 60–90 s trailer: race start countdown → TDM scoreboard → sumo → admin panel → results screen
- [ ] Screenshots: event browser, HUD in a race, admin live view, event builder, tournament bracket, results
- [ ] Short install GIF: `ensure event_studio` → `/events`

## Pre-publish checklist

- [ ] In-game test matrix passed (docs/TESTING.md §2) on standalone plus at least one framework
- [ ] Sample arena coordinates checked in game
- [ ] `python3 tools/build_release.py` passes; zip uploaded to the Cfx Portal and escrowed
- [ ] Final EULA in LICENSE.md
- [ ] CHANGELOG `[Unreleased]` cut into a version; version bumped in fxmanifest, shared/init.lua and CHANGELOG
- [ ] Tebex package type **FiveM Asset**, correct asset selected, tag `escrow` + `paid` on the forum post
