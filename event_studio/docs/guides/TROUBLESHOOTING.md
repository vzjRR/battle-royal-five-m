# Troubleshooting

Set `set es_debug 1` in `server.cfg` for detailed logs. `eventstudio status` shows the adapters and running instances.

| Symptom | Cause / fix |
|---|---|
| `OneSync is disabled` error | Add `set onesync on`. Routing buckets and server-side positions need OneSync. |
| `Definition X invalid: arena … lacks checkpoints` | The arena is missing the points that mode needs; see EVENT_CREATION.md. |
| `/event` says "No permission" | Grant a role: `add_ace group.admin eventstudio.admin allow` and make sure you are in that group. |
| Players spawn under the map / in the air | The arena's Z values are off. The client snaps to the ground when it can, but fixing the point in the arena editor is better. |
| Vehicle doesn't appear | Wrong model name (`vehicle_spawn_failed` in the log) or a server artifact too old for `CreateVehicleServerSetter`. |
| Checkpoints rejected (`checkpoint_far` / `too_fast` in security logs) | Checkpoint radius too small, or very fast vehicles; raise `checkpointTolerance` / `maxPlausibleSpeed`. |
| Kills don't count | Only damage from the event's allowed weapons counts. Check the `weapons` option. With friendly fire off, team damage is cancelled. |
| Players stay dead / ambulance screen shows | Set `ES.ClientHooks.revive` for your medical resource (FRAMEWORKS.md). |
| Weapons disappear after an event | Your inventory re-syncs weapons on its own; set `gameplay.restoreWeapons = false` and let the inventory handle it. |
| Players see other people who aren't in the event | Another resource moved them into the same bucket; change `Config.General.buckets`. |
| Cash rewards don't arrive (standalone) | Standalone has no economy. Use `command`, `xp` or a custom reward type. |
| `Storage adapter: kvp` although I use MySQL | oxmysql isn't started before event_studio. Fix the `ensure` order. |
| NUI doesn't open | The folder must be named `event_studio`. Check F8 for errors. |
| Event cancelled "not enough players" | Registration closed below `players.min`. Lower `min`, or raise `timing.registration` / `extendOnce`. |
