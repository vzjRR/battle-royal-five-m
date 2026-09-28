-- EVENT STUDIO — commands & player keys
--
-- Typed commands are for staff only (host and above). They are registered on a player's game only when the server
-- says that player is staff, so normal players never have them. Set a command to false to turn it off.
-- Normal players use the keys below: the events window (F7) shows every event and lets them register, join,
-- leave and spectate.

Config.Commands = {
    admin = 'event',             -- staff: open the Admin Center
    browser = 'events',          -- staff: open the events window by command (players use the key)
    join = 'eventjoin',          -- staff: /eventjoin [id]  (joins the only open event if no id)
    leave = 'eventleave',        -- staff: leave the event or stop spectating
    spectate = 'eventspectate',  -- staff: /eventspectate [id]
    arenaFix = 'eventarenafix',  -- staff: /eventarenafix <arenaId> [apply] — check and fix an arena in game

    -- Player keys. Change them live in Admin Center → Settings → Player controls if a key clashes with another
    -- resource on your server (the saved choice overrides these). Allowed: F1-F12 except F8, A-Z, 0-9, NUMPAD0-9,
    -- HOME, END, INSERT, DELETE, PAGEUP, PAGEDOWN. Players can still rebind them in GTA Settings → Key Bindings → FiveM.
    keys = {
        browser = 'F7',          -- events window (always on)
        scoreboard = 'U',        -- hold to expand the scoreboard while in an event; false = off
        reset = 'F9',            -- races: back to the last checkpoint; false = off
    },
}
