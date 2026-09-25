-- EVENT STUDIO — instance lifecycle (pure)

local S = {
    SCHEDULED = 'SCHEDULED',
    REGISTRATION = 'REGISTRATION',
    LOBBY = 'LOBBY',
    COUNTDOWN = 'COUNTDOWN',
    ACTIVE = 'ACTIVE',
    PAUSED = 'PAUSED',
    FINISHING = 'FINISHING',
    RESULTS = 'RESULTS',
    REWARDS = 'REWARDS',
    ARCHIVED = 'ARCHIVED',
    CANCELLED = 'CANCELLED',
}

local transitions = {
    SCHEDULED = { REGISTRATION = true, CANCELLED = true },
    REGISTRATION = { LOBBY = true, CANCELLED = true },
    LOBBY = { COUNTDOWN = true, CANCELLED = true },
    COUNTDOWN = { ACTIVE = true, LOBBY = true, CANCELLED = true },
    ACTIVE = { PAUSED = true, FINISHING = true, RESULTS = true, CANCELLED = true },
    PAUSED = { ACTIVE = true, FINISHING = true, RESULTS = true, CANCELLED = true },
    FINISHING = { RESULTS = true },
    RESULTS = { REWARDS = true },
    REWARDS = { ARCHIVED = true },
    CANCELLED = { ARCHIVED = true },
    ARCHIVED = {},
}

local Lifecycle = { States = S }
ES.Lifecycle = Lifecycle

function Lifecycle.canTransition(from, to)
    local t = transitions[from]
    return t ~= nil and t[to] == true
end

---States where the instance world is live (players inside the bucket).
function Lifecycle.isLive(state)
    return state == S.LOBBY or state == S.COUNTDOWN or state == S.ACTIVE or state == S.PAUSED or state == S.FINISHING
end

function Lifecycle.isJoinable(state)
    return state == S.REGISTRATION
end

function Lifecycle.isCancellable(state)
    return transitions[state] ~= nil and transitions[state].CANCELLED == true
end

function Lifecycle.isTerminal(state)
    return state == S.ARCHIVED
end

---Player-facing status label key for the browser.
function Lifecycle.publicStatus(state, full)
    if state == S.SCHEDULED then return 'upcoming' end
    if state == S.REGISTRATION then return full and 'full' or 'open' end
    if state == S.LOBBY or state == S.COUNTDOWN then return 'starting' end
    if state == S.ACTIVE or state == S.PAUSED or state == S.FINISHING then return 'live' end
    if state == S.CANCELLED then return 'cancelled' end
    return 'finished'
end

return Lifecycle
