-- EVENT STUDIO — general settings (shared with clients: do NOT put secrets here)

Config.General = {
    locale = 'en',

    -- Engine tick while at least one event exists (ms). 250-1000 is sensible.
    tickMs = 500,

    -- Start and finish of every event.
    flow = {
        manualStart = true,   -- players wait in the arena until the host presses Start (Admin Center → Active Events)
        countdown = 10,       -- seconds of countdown after Start
        lobbyWaitMax = 300,   -- nobody pressed Start: begin anyway after this many seconds (0 = always wait for the host)
        graceAfterPlace = 3,  -- races / hunts / red light: the finish grace starts when this place has finished
                              -- (with fewer racers: the place before the last one, e.g. 1st in a 2-player race)
        finishGrace = 60,     -- ...and then the others have at most this many seconds to finish
        lastFinishWait = 10,  -- when everyone has finished, results come this many seconds after the last one
    },

    -- Routing bucket pool used for event instances. Pick a range no other resource uses.
    buckets = { from = 7100, to = 7299, lockdown = 'relaxed', population = false },

    -- Default values merged into every event definition (a definition can override any of them).
    definitionDefaults = {
        visibility = 'public',          -- public | hidden (API/invite only) | staff
        difficulty = 'medium',          -- easy | medium | hard | extreme
        players = {
            min = 2, max = 16,
            spectators = true,
            spectateOnEliminate = true,
            reconnectGrace = 60,         -- seconds a disconnected player may rejoin (0 = off)
            teams = nil,                 -- { count = 2, size = 8, auto = true } for team events
        },
        timing = {
            registration = 120,          -- seconds registration stays open
            extendOnce = 60,             -- extend registration once if below min (0 = cancel immediately)
            lobby = 10,                  -- seconds inside the arena before countdown
            countdown = 5,
            duration = 600,              -- 0 = until mode decides
            grace = 30,                  -- finishing window after the winner (races)
            results = 15,
        },
        gameplay = {
            health = 200, armor = 0,
            friendlyFire = false,
            restoreWeapons = true,       -- snapshot + restore player weapons around the event
            blockInventoryWeapons = true, -- ask the framework adapter to block inventory weapons
        },
    },

    -- Where players go when an event ends: 'return' (where they were) or a fixed coordinate.
    exit = { mode = 'return', coords = nil },

    -- Players cannot join if they joined another event within this many seconds.
    joinCooldown = 10,

    security = {
        maxViolationsBeforeKick = 0,     -- 0 = never kick automatically
        violationWindow = 60,
        checkpointTolerance = 8.0,       -- extra metres accepted over checkpoint radius (latency)
        maxPlausibleSpeed = 140.0,       -- m/s used for travel-time plausibility (aircraft ~ 140)
    },
}
