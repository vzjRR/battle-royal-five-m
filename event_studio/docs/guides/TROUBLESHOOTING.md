# Troubleshooting

Set `set es_debug 1` in `server.cfg` for detailed logs. `eventstudio status` shows the adapters and running instances.

| Symptom | Cause / fix |
|---|---|
| `OneSync is disabled` error | Add `set onesync on`. Routing buckets and server-side positions need OneSync. |
| `Definition X invalid: arena … lacks checkpoints` | The arena is missing the points that mode needs; see EVENT_CREATION.md. |
| `/event` does nothing, is unknown, or says "No permission" | Run `eventstudio perms` in the server console: it shows each online player's identifiers, which Event Studio roles their ACE grants and their framework groups, and prints the exact `add_ace identifier.license:… eventstudio.admin allow` line for anyone without a role. Add that line to `server.cfg` (and type it in the console to apply it now). txAdmin only puts the owner's identifier in `group.admin`, so `add_ace group.admin …` does nothing for players who are not in that group. Staff commands are given when a player connects, so reconnect after getting a role. |
| F7 does nothing or opens another resource | Another resource uses the same key. Pick a free key in **Admin Center → Settings → Player controls** and save; every player gets it at once. A player who rebound the key in GTA Settings → Key Bindings → FiveM keeps their own choice. |
| Players spawn under the map / in the air | Run **Check route** on the arena (Admin Center → Routes & arenas) and apply the fixes. |
| Race checkpoints lead into buildings, or boat checkpoints are on land | Run **Check route**: road checkpoints are moved onto roads and boat checkpoints onto open water; legs without a road path or crossing land are listed. Re-place those points, or record the route by driving it. |
| A winner did not get their reward | Rewards are paid automatically when the event ends. A player who disconnected after finishing, or whose character was not loaded yet, is paid when they are online again (checked every minute). Logs show `reward.pending` and `reward.paid`. Cash and bank need a framework (ESX/QBCore/Qbox); standalone servers can use item, command or webhook rewards. |
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
