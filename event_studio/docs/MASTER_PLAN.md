# EVENT STUDIO — Master Plan

> Product owner / publisher: **Krovix Store** · Version target: `0.1.0-alpha` → `1.0.0`
> Companion documents: [RESEARCH](RESEARCH.md) · [ARCHITECTURE](ARCHITECTURE.md) · [EVENT_ENGINE](EVENT_ENGINE.md) · [EVENT_CATALOG](EVENT_CATALOG.md) · [SECURITY](SECURITY.md) · [DATABASE](DATABASE.md) · [API](API.md) · [DEVELOPMENT](DEVELOPMENT.md) · [TESTING](TESTING.md)

---

## 1. Product vision

EVENT STUDIO is an **event operating system for FiveM servers**: one resource that lets staff create, schedule, run, monitor, score and reward recurring competitions — races, PvP, objectives, survival, hunts, obstacle courses, social games and tournaments — on any server (standalone, ESX, QBCore, Qbox), with no server-specific assumptions. It is sold to server owners, so it must install without code edits, look professional, be secure by default, and grow through content packs without core rewrites.

## 2. Requirements

### Functional
- F1 Event definitions (presets) from config files and an in-game builder.
- F2 Arena/location definitions reusable across events.
- F3 Lifecycle `SCHEDULED → … → ARCHIVED` with cancel at any safe state, pause/resume.
- F4 Multiple simultaneous instances isolated by routing buckets.
- F5 Player browser, registration, HUD, live scoreboard, results.
- F6 Admin center: dashboard, definitions, builder, scheduler, live control, tournaments, leaderboards, logs, settings.
- F7 Scheduler: once/daily/weekly/monthly/interval + weekly rotations; optional Director.
- F8 Server-side scoring, placement, season points; leaderboards; personal bests.
- F9 Modular rewards (cash, bank, item, XP hook, command, callback, webhook) with duplicate protection.
- F10 Tournaments reusing the engine: single elimination, round robin, best-of-N.
- F11 Spectator framework.
- F12 Framework adapters, permission abstraction, localization, Discord logging, announcements.
- F13 Developer API (exports + server events).

### Non-functional
- N1 Server authoritative; all client input untrusted.
- N2 Idle server CPU ≈ 0.00 ms; idle client ≈ 0.00 ms (no loops outside events).
- N3 No hard dependencies besides OneSync; oxmysql optional.
- N4 Config split into focused files; everything customisable is escrow-ignorable.
- N5 All player-facing strings localizable.
- N6 Documentation complete for buyers and developers.

## 3. Research findings (summary)

Full detail in RESEARCH.md.
1. The market has many single-purpose event scripts, few unified platforms → clear positioning.
2. Most free/cheap scripts trust client-reported kills/finishes/payouts → security is a differentiator.
3. Routing buckets (OneSync) make parallel instances cheap; they are not a security boundary.
4. OneSync lets the server read ped/vehicle coordinates and health → zones, bounds, red-light and checkpoint validation can be fully server-side.
5. `weaponDamageEvent` gives server-side attacker identity and can be cancelled → friendly-fire filter, weapon whitelist, and kill attribution.
6. Framework integration is a thin surface (identifier, name, groups, money, items, notify, revive) → adapter pattern.
7. Buyers value no-build NUI theming, config split, auto-migration, auto-detect.

## 4. Architecture

See ARCHITECTURE.md. Core idea: **Engine + Components + Modes + Presets**.

```
Preset (data) ──configures──▶ Mode (code) ──composes──▶ Components (code) ──runs in──▶ Instance (engine)
```

## 5. Folder structure

See ARCHITECTURE.md §3. Resource folder: `event_studio/`.

## 6. Database design

See DATABASE.md. 8 tables with oxmysql; KVP adapter for standalone; `none` for testing. Configuration-like data stored as JSON documents; aggregate data in columns.

## 7. Event Engine architecture

See EVENT_ENGINE.md. Instance object with participants, teams, components, pause-aware clock; one engine tick loop only while instances exist; mode contract of optional hooks.

## 8. Event lifecycle

`SCHEDULED → REGISTRATION → LOBBY → COUNTDOWN → ACTIVE ⇄ PAUSED → FINISHING → RESULTS → REWARDS → ARCHIVED`, `CANCELLED → ARCHIVED`. Transition table in `shared/lifecycle.lua`, unit-tested.

## 9. Networking architecture

Single inbound RPC (`es:rpc`), single push channel (`es:push`), targeted to instance members/spectators; throttled change-only scoreboard; client-side countdown from `remainingMs`; bucket pool with relaxed lockdown and no population.

## 10. UI architecture

Vanilla ES-module NUI (no build step). Views: Browser, HUD, Results, Spectator bar, Admin Center. Theme = CSS variables. Builder generated from mode option schemas.

## 11. Framework adapter architecture

`integrations/framework/<name>/{server,client}.lua` each implementing the Bridge interface; auto-detect; `integrations/custom` hooks for buyers.

## 12. Security architecture

SECURITY.md. Gateway + schema + rate limit + permission + confirm; positional validation; damage-log kill attribution; weapon whitelist; payout ledger; audit logs.

## 12.1 Licensing, activation & code protection

Full plan: [PROTECTION.md](PROTECTION.md). Summary of the researched, platform-compliant design:

| Goal | Mechanism |
|---|---|
| Only servers approved by Krovix Store can run it | **Cfx Asset Escrow**: the entitlement is checked against the server's license key before decryption. Customers are approved through **Tebex** (checkout or **manual payments**). |
| Revoke a customer | Sell as a **Tebex subscription**: access ends with the subscription (PLA §6.3(ii)). One-time sales are irrevocable (PLA §6.3(i)). |
| Core cannot be read or edited | Escrow encrypts all Lua; server code is only decrypted in memory. Editable surface = `config/**`, `locales`, `web/themes`, `integrations/custom`, `migrations`. |
| Client/NUI copying is worthless | Server-authoritative architecture: no rules, scoring, rewards or admin logic on the client; NUI is a view. |
| Release can't ship weakened | `tools/build_release.py` blocks: version mismatch, missing `lua54`, over-broad `escrow_ignore`, secrets in config, custom licensing/IP-lock/remote-code/obfuscation patterns, syntax errors, failing tests. |
| Legal enforcement | EULA + PLA §6.4 (no resale/sharing/decompiling/modifying); Cfx suspends and bans servers using leaked assets. |

**Deliberately not done:** a custom activation server keyed by server id / IP, obfuscation, remote code loading, a kill switch in one-time sales. The Cfx.re release rules forbid custom licensing, license tokens and remote code checks for released resources; FiveM blocks "prohibited logic"; and such checks would be *weaker* than escrow because they run unencrypted-equivalent logic on the customer's server. Escrow **is** per-server, server-side activation, run by the platform and tied to accounts you approve.

**Honest limits:** no software is unhackable. NUI and client Lua can be copied from players' machines (they hold no value here); escrow had an exploit in 2025 that Cfx patched; one purchase runs on all servers of the buyer's Cfx account, so per-server pricing is a commercial/subscription term.

## 13. API architecture

API.md. Exports for definitions, arenas, instances, participants, scoring, objectives, eliminations, teams, state, leaderboards, rewards; non-networked server events for lifecycle hooks.

## 14. Scheduler architecture

- Rule types: `once {date,time}`, `daily {time}`, `weekly {days,time}`, `monthly {day,time}`, `interval {minutes, from, to}`.
- `nextOccurrence(rule, now)` is a pure function (unit tested).
- Each schedule targets a `definition` or a `rotation` (weekly slots of categories/definition pools, `pick = random|sequential|leastRecent`).
- Instances are created `leadMinutes` before start in `REGISTRATION` (or `SCHEDULED` if lead is larger than registration).
- Scheduler tick: 30 s. Missed occurrences during downtime are skipped (not replayed).
- Director (optional): when no instance is live and cooldown passed, picks a definition matching player-count bands and category weights, avoiding recent repeats.

## 15. Tournament architecture

- Tournament object: format (`single_elimination`, `round_robin`), series length (1/3/5), entrants (players or fixed teams), seeding (`registration`, `random`, `leaderboard`), definition used for matches.
- Bracket generation and advancement are pure functions (unit tested). Byes for non-power-of-two.
- For each ready match the engine creates an instance restricted to the match's entrants (`invite` list; no public registration). On `RESULTS` the tournament advances the winner. No-shows forfeit after `noShowSeconds`.

## 16. Testing architecture

TESTING.md. Three layers:
1. **Unit tests** (pure Lua 5.4): lifecycle, scoring/ranking, scheduler, tournament, schema validation, rate limiter, ledger.
2. **Simulation tests**: a FiveM mock runtime (natives, events, virtual clock, fake players with positions) loads the real server code and plays full events with 1–64 players including disconnects, reconnects, invalid RPCs, resource stop.
3. **In-game test plan**: manual scenarios (checklist) for things that need the real game (rendering, vehicles, damage, spectator camera).

## 17. Performance strategy

- No client threads unless in an event; component loops start on enter and stop on leave. Marker drawing (per-frame) only for the nearest 1–2 markers within draw distance.
- Server tick 500 ms; per-instance work O(participants).
- Change-only scoreboard pushes throttled to 1 Hz; timers client-side.
- Browser pull-based; leaderboards cached 60 s.
- Storage writes batched at instance end.
- Profiling plan: `resmon` at idle / lobby / active 8 / active 32 / 3 simultaneous / cleanup; targets idle 0.00 ms, active client < 0.20 ms, server < 0.50 ms per active instance at 32 players.

## 18. Development phases

| Phase | Scope | Version |
|---|---|---|
| 0 Research | RESEARCH.md | — |
| 1 Architecture | ARCHITECTURE, ENGINE, SECURITY, DATABASE, API, CATALOG, this plan | — |
| 2 Core Event Engine | shared, storage, permissions, rpc, registry, arenas, definitions, buckets, instance, manager, scoring, components | 0.1.0-alpha |
| 3 Admin System | admin RPCs + Admin Center NUI | 0.1.0-alpha |
| 4 Player UI | browser, HUD, results, spectator | 0.1.0-alpha |
| 5 Scheduler | scheduler, rotations, director | 0.1.0-alpha |
| 6 Scoring / Leaderboards | stats, bests, leaderboards | 0.1.0-alpha |
| 7 First Event Pack | race, deathmatch, sumo, koth, hunt | 0.1.0-alpha |
| 8 Additional Packs | gungame, ctf, zone_survival, redlight, trivia, reaction, custom | 0.1.0-alpha (initial) → 0.3.0 polish |
| 9 Tournament System | single elim, round robin, series | 0.1.0-alpha (engine) → 0.4.0 UI polish |
| 10 Security Hardening | audit, fuzz invalid RPCs in sim tests | 0.5.0 |
| 11 Performance | resmon profiling, tuning | 0.5.0 |
| 12 Testing | full in-game matrix | 0.5.0 → 1.0.0 |
| 13 Documentation | guides complete | 1.0.0 |
| 14 Commercial Packaging & Protection | escrow build (`tools/build_release.py`), Cfx Portal upload, Tebex one-time/subscription packages, manual-payment activation, EULA (PROTECTION.md) | 1.0.0 |

## 19. Dependencies

| Dependency | Required | Purpose |
|---|---|---|
| FXServer with OneSync (on / infinity) | **Yes** | buckets, server-side coords, server setters |
| Recent server artifact (≥ 7290 recommended) | Yes | `CreateVehicleServerSetter`, lockdown modes |
| oxmysql | Optional | SQL persistence |
| es_extended / qb-core / qbx_core | Optional | money, items, groups, names |
| ox_inventory | Optional | items |
| chat | Optional | chat announcements |

No ox_lib dependency (kept optional to avoid version coupling).

## 20. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Framework death/ambulance systems fight event respawn | High | client bridge `revive` + `onEnterEvent` hooks; config per framework; documented |
| Inventory-managed weapons (ox_inventory) strip native weapons | High | client hook disables inventory weapon handling while in event; loadout snapshot/restore |
| Kill attribution edge cases (explosives, vehicles, melee) | Medium | damage log with fallback to last damager; mode tolerant of "no killer" deaths |
| Cross-bucket game events (explosions) | Low | damage filter cancels cross-instance damage |
| Vehicle spawn failure / model missing | Medium | model validation, retry, fallback to on-foot with warning |
| Voice chat across buckets (pma-voice) | Medium | document: pma-voice follows buckets? — configurable voice channel hook |
| Scope creep (119 events) | High | modes + presets; Tier 2/Future discipline |
| Escrow constraints later | Medium | keep editable surfaces in ignored paths from day one |
| Piracy / leaks | High | escrow + server-authoritative design + subscriptions + legal enforcement (PROTECTION.md §4) |
| Building custom DRM against platform rules | High | explicitly rejected (PROTECTION.md §6); release build blocks such patterns |
| Escrow vulnerability in the future | Medium | nothing depends on client secrets; re-upload each release; Cfx enforcement |
| Buyer runs one purchase on several servers | Medium | allowed by escrow/PLA per account; handled with tiers/subscriptions in the EULA |
| Lack of in-game CI | Medium | simulation mock runtime; manual test matrix |

## 21. Technical decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Lua 5.4 for server & client | FiveM native, escrow supported, lowest buyer friction |
| D2 | Vanilla JS NUI, no bundler | Buyer themeability without Node; small payload |
| D3 | Single RPC gateway | One audited entry point, uniform rate limiting |
| D4 | Modes as in-resource drop-in folders | Real object access; manifest glob; escrow-friendly |
| D5 | JSON documents for config-like data | Fewer tables, schema evolves with modes |
| D6 | KVP adapter | Standalone persistence without MySQL |
| D7 | Role levels + ACE/framework resolution | Works on every framework, simple mental model |
| D8 | Server tick 500 ms | Enough for zones/bounds; negligible cost |
| D9 | Match score ≠ season points | Modes rank naturally; points uniform across modes |
| D10 | Ledger-guarded payouts | Idempotent rewards |
| D11 | Asset Escrow + Tebex is the only licensing/activation mechanism | Strongest available protection and the only compliant one |
| D12 | Revocable licensing via Tebex subscriptions; hand-picked activation via manual payments | One-time licenses are irrevocable under the PLA |
| D13 | Release build enforces protection rules | A mistake can't ship an exposed or non-compliant build |

## 22. Alternatives considered

| Alternative | Rejected because |
|---|---|
| React/Vue NUI with build step | Buyers can't theme without Node; larger bundle; value not needed for forms/HUD |
| One script per event type | Unmaintainable, duplicated bugs, inconsistent security |
| ox_lib as hard dependency | Version coupling; not all servers run it |
| State bags for all sync | Replication issues reported for player bags; less control over who receives data |
| Client-side zone detection | Spoofable; server can compute from coords |
| Modes registered via exports from other resources | Functions/metatables don't survive export boundary cleanly |
| Separate SQL table per entity type | Unnecessary complexity for rarely-changed config data |

| Custom activation server (server-id/IP lock, phone-home) | Forbidden by Cfx release rules; risk of prohibited-logic blocks; weaker than escrow |
| Obfuscators / third-party encryption layers | Forbidden; blocked by FiveM; unnecessary with escrow |
| Running the core on the vendor's backend | Remote code loading is forbidden; natives must run on the game server |

## 23. Future expansion

Roles component (Juggernaut, VIP, Hunter/Runner), NPC wave spawner, carriable-objective generalisation (delivery, bomb), in-game arena editor with gizmos and prop placement, double elimination & Swiss, championships, web dashboard, phone app adapters (npwd/lb-phone), additional locales, content packs (Seasonal, Halloween …).

## 24. Definition of Done (V1)

Mirrors the product brief §46. Tracked in `CHANGELOG.md` and `docs/TESTING.md`:
resource starts clean · escrowed build starts only on entitled servers ("You lack the required entitlement" elsewhere) · release build passes all protection checks · standalone works · ≥1 framework adapter works · admin can create & schedule · players discover, register, participate · server-side scores · results · safe rewards · cleanup · spectators · simultaneous instances · persistence · security validation · permissions · logs · docs (install, config, API) · no server-specific branding.

---

## 25. Self-review (performed before implementation)

| Question | Answer | Change made |
|---|---|---|
| Commercially viable? | Yes — unified platform, secure, framework-agnostic, themeable. | Added escrow-ignore surface design from day one. |
| Can it be protected and activated only by the creator? | Yes, within platform limits: escrow + Tebex approval/subscriptions; not "unhackable" | Added §12.1, PROTECTION.md and the release build guard. |
| Scalable architecture? | Engine + components + modes; tick cost O(players). | Tick loop only runs while instances exist. |
| New event types without core rewrite? | Yes — new preset (data) or new mode folder (code). | Changed mode registration from exports to drop-in folders (object access). |
| Simultaneous events? | Yes — bucket pool, per-instance state, player→instance index. | Bucket range configurable to avoid clashing with other scripts. |
| Works without ESX/QBCore? | Yes — standalone adapter; KVP persistence. | Added KVP adapter (initial plan required MySQL for persistence). |
| Framework adapters later? | Yes — one folder per framework. | — |
| Server authoritative? | Yes. | Zones/bounds/red-light computed from server coords; checkpoint validation w/ travel-time check. |
| Rewards secure? | Yes — engine-only trigger + ledger + limits. | Added `Config.Rewards.limits`. |
| UI reusable? | Builder generated from schemas; themes. | — |
| Database necessary & efficient? | Optional; writes at instance end only. | Collapsed 12 candidate tables into 8. |
| Unnecessary dependencies? | None hard beyond OneSync. | Dropped ox_lib requirement. |
| Performance acceptable? | Yes by design; to be profiled in Phase 11. | Change-only scoreboard + throttle. |
| Understandable code? | Small files, one responsibility each, EVENT_ENGINE doc. | — |
| Install without source edits? | Yes — config + auto-detect + auto-migrate. | — |
| Future packs? | Yes — mode folders + data exports. | — |
| Tournament reuses engine? | Yes — matches are normal instances with invite lists. | — |

Contradictions found and resolved during review:
1. The brief lists `DRAFT` as an instance state; it is modelled as a definition status because nothing runs in draft.
2. The brief's `/event` command overlaps `/events`; `/event` is mapped to the admin center (configurable).
3. Brief requires Discord for security violations and "not mandatory": webhook disabled by default, all logs also go to console/storage.

---

## 26. Implementation status (0.1.0-alpha)

| Phase | Status | Notes |
|---|---|---|
| 0 Research · 1 Architecture | ✅ | this document set |
| 2 Core Event Engine | ✅ | instance state machine, manager, buckets, components; covered by simulation tests |
| 3 Admin System | ✅ | admin RPCs + Admin Center NUI (dashboard, events, builder, arenas, scheduler, live, tournaments, leaderboard, logs, settings) |
| 4 Player UI | ✅ | browser, HUD, results, spectator, trivia/reaction panels |
| 5 Scheduler | ✅ | recurrence rules, rotations, director |
| 6 Scoring / Leaderboards | ✅ | profiles, season points, stats, personal bests |
| 7 First Event Pack | ✅ | race, deathmatch, sumo, koth, hunt |
| 8 Additional Packs | ✅ | gungame, ctf, zone_survival, redlight, trivia, reaction, custom; V2 pack: roles component + juggernaut, vip, hunters, keep_moving, musical_chairs |
| 9 Tournament System | ✅ engine + admin UI | single elimination, round robin, best-of-N |
| 10 Security Hardening | 🟡 | gateway/validation/ledger done; offline fuzzing of every RPC and every mode (test_fuzz.lua) passes; live-server checks pending |
| 11 Performance | 🟡 | offline benchmark (tests/bench.lua): ≤ 0.17 ms Lua per 500 ms tick at 64 players / 3 events, 0 when idle; resmon on a live server pending |
| 12 Testing | 🟡 | 90 automated tests pass (unit, simulation, fuzzing) + offline tick benchmark; in-game matrix (TESTING.md §2) pending |
| 13 Documentation | ✅ | guides, API, architecture, testing |
| 14 Commercial Packaging | 🟡 | protection plan (PROTECTION.md) + release builder with compliance checks done; Cfx Portal upload, Tebex packages and final EULA pending (creator) |

Definition-of-Done items that can only be confirmed on a real FXServer (rendering, vehicles, framework money calls, ambulance interplay) are listed in `docs/TESTING.md §2` and are the gate for `0.5.0`.
