-- EVENT STUDIO — shared namespace
-- Developer: vzjRR · Publisher: Krovix Team

ES = ES or {}
ES.name = 'event_studio'
ES.version = '0.1.0-alpha'
ES.isServer = IsDuplicityVersion and IsDuplicityVersion() or false
ES.Config = ES.Config or {}
Config = ES.Config -- config files write into Config.*

---Monotonic milliseconds.
function ES.now()
    return GetGameTimer()
end

-- Push topics shared by server and client (single outbound net event).
ES.Topics = {
    state = 'state',           -- instance snapshot for members/spectators
    scoreboard = 'scoreboard', -- throttled scoreboard rows (diff)
    component = 'component',   -- component setup/update
    announce = 'announce',     -- toast / banner
    results = 'results',       -- final results
    left = 'left',             -- local player removed from instance
    teleport = 'teleport',
    respawn = 'respawn',
    loadout = 'loadout',
    freeze = 'freeze',
    vehicle = 'vehicle',
    spectate = 'spectate',
    mode = 'mode',             -- mode-specific payload
    notify = 'notify',
}

-- Data helpers used by config/arenas/*.lua and config/events/*.lua (server-side files).
ES.ConfigArenas = ES.ConfigArenas or {}
ES.ConfigDefinitions = ES.ConfigDefinitions or {}

function ES.Arena(a) ES.ConfigArenas[#ES.ConfigArenas + 1] = a end
function ES.Definition(d) ES.ConfigDefinitions[#ES.ConfigDefinitions + 1] = d end
