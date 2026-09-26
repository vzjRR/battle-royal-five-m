# FAQ

**Do I need ESX/QBCore/Qbox?** No. Standalone mode works fully; only cash/bank rewards need a framework (or a custom reward type).

**Do I need MySQL?** No. Without oxmysql, definitions, arenas, schedules, stats and the payout ledger are stored in resource KVP. oxmysql is recommended on larger servers.

**Can several events run at once?** Yes. Each runs in its own routing bucket. The default range allows 200 at the same time.

**Can players cheat scores or rewards?** Clients only send intents. The server checks positions, timing and damage, and pays rewards only after results, through a ledger that blocks duplicate payouts. See SECURITY.md.

**Will my players lose their weapons?** Weapons are snapshotted on entry and restored on exit (this can be switched off).

**Can I add my own event types?** Yes: presets need no code, and new modes are small Lua files that reuse the components. See EVENT_CREATION.md.

**Can other scripts start events or give points?** Yes, through exports (`CreateEvent`, `GivePoints`, `CompleteObjective`, …). See API.md.

**Does it work with pma-voice?** Voice follows routing buckets in most setups, so players in an event hear each other. Spectators can hear the event bucket.

**How heavy is it?** Nothing runs when no event exists. While events run, the server ticks every 500 ms. Client loops run only for markers and checks in the active event.

**Can I rebrand it?** Yes. Pick one of the 8 designs and change any color, the title, logo and artwork live in the Admin Center → Appearance, or in `config/ui.lua`. You can add your own design in `web/themes/`. Nothing is tied to a particular server.
