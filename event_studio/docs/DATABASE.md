# EVENT STUDIO — Database

## 1. Principles

- **Optional.** The resource runs with no database at all.
- **Replaceable.** All persistence goes through `server/core/storage.lua`, which exposes a repository interface implemented by three adapters.
- **Minimal.** Configuration-like data (definitions, arenas, schedules, rotations, tournaments) is stored as JSON *documents* in one table, because it is read at boot and edited rarely. Only data that must be queried/aggregated (results, stats, bests, payouts, logs) has real columns.

## 2. Adapters

| Adapter | Requires | Persists | Use case |
|---|---|---|---|
| `oxmysql` | oxmysql resource | everything | recommended for production |
| `kvp` | nothing (resource KVP) | documents, stats, bests, payout ledger, return points, sequence; logs keep last N | standalone servers without MySQL |
| `none` | nothing | nothing except crash-recovery return points (always KVP) | testing |

`Config.Database.adapter = 'auto'` → `oxmysql` if started, else `kvp`.

## 3. Repository interface

```lua
Storage.loadDocuments(kind)            -> { [id] = data }
Storage.saveDocument(kind, id, data, actor)
Storage.deleteDocument(kind, id)
Storage.recordInstance(summary, results)       -- es_instances + es_results
Storage.addStats(rows)                          -- upsert es_player_stats
Storage.submitBest(identifier, name, defId, ms) -> improved(bool), previous
Storage.leaderboard(season, category, limit)   -> rows
Storage.bests(defId, limit)                     -> rows
Storage.playerStats(identifier, season)        -> rows
Storage.claimPayout(key, instanceId, identifier, reward) -> bool   (atomic)
Storage.markPayout(key, status)
Storage.log(entry) / Storage.recentLogs(limit, level)
Storage.nextInstanceId()                        -- KVP sequence (all adapters)
```

## 4. Tables (oxmysql)

Defined in `migrations/001_initial.sql`, applied automatically in order; applied versions recorded in `es_migrations`.

| Table | Purpose | Key |
|---|---|---|
| `es_migrations` | applied migration versions | version |
| `es_documents` | JSON documents: `definition`, `arena`, `schedule`, `rotation`, `tournament` | (kind, id) |
| `es_instances` | one row per finished/cancelled instance with summary JSON | id |
| `es_results` | per-participant result rows | (instance_id, identifier) |
| `es_player_stats` | aggregated counters per season and category (`*` = overall) | (identifier, season, category) |
| `es_personal_bests` | best finish time per definition (time trials, races) | (identifier, definition_id) |
| `es_payouts` | payout ledger — primary key guarantees single payout | ledger_key |
| `es_logs` | audit / security / lifecycle logs | id |

The prompt's candidate tables `events`, `event_schedules`, `event_arenas` collapse into `es_documents`; `event_participants`, `event_teams`, `event_scores` are runtime-only (in memory) and summarised into `es_results`; `event_leaderboards` is a query over `es_player_stats`; `event_statistics` = `es_player_stats`; `event_rewards` = `es_payouts`.

## 5. Seasons

`Config.Scoring.season` = `'monthly'` (`2026-09`), `'quarterly'` (`2026-Q3`), `'yearly'`, or a fixed string (`'S1'`). Stats rows are written for the current season **and** `'all'`, each for the definition's category **and** `'*'`.

## 6. Write volume

Writes happen only at instance end (1 instance row, N result rows, 4N stats upserts batched in one transaction), on admin edits, on payouts, and for logs. Nothing is written per tick.

## 7. Retention

`Config.Database.logRetentionDays` (default 30) — old logs pruned at boot. Instances/results are kept (small rows).
