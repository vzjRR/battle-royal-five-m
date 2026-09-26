-- EVENT STUDIO — commands & key mappings (set a command to false to disable it)

Config.Commands = {
    browser = 'events',          -- open the event browser
    admin = 'event',             -- open the admin center (permission: host+)
    join = 'eventjoin',          -- /eventjoin [id]  (joins the only open event if no id)
    leave = 'eventleave',
    spectate = 'eventspectate',  -- /eventspectate [id]
    scoreboard = 'eventboard',   -- hold to expand the scoreboard while in an event
    reset = 'eventreset',        -- races: back to the last checkpoint (stuck / flipped)
    arenaFix = 'eventarenafix',  -- staff: /eventarenafix <arenaId> [apply] — measure & fix arena heights in game

    keys = {
        browser = 'F7',          -- default key mapping (players can rebind in GTA settings); false = none
        scoreboard = 'U',        -- hold; only acts while in an event
        reset = 'F9',
    },
}
