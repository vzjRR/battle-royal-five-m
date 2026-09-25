-- EVENT STUDIO — optional Event Director (automatic event selection)

local U = ES.Util
local Log = ES.Log

local Director = { enabled = false, lastEnd = 0, lastRun = {} }
ES.Director = Director

local function minutesOf(s)
    local h, m = ES.Scheduler.parseTime(s)
    return h and (h * 60 + m) or nil
end

local function inActiveHours(now)
    local hrs = Config.Director.activeHours
    if not hrs then return true end
    local from, to = minutesOf(hrs.from), minutesOf(hrs.to)
    if not from or not to then return true end
    local t = os.date('*t', now)
    local cur = t.hour * 60 + t.min
    if from <= to then return cur >= from and cur < to end
    return cur >= from or cur < to -- window crosses midnight
end

local function busy()
    for _, inst in pairs(ES.Manager.instances) do
        if not inst.invite and inst.state ~= 'ARCHIVED' then return true end
    end
    return false
end

---Pick a definition for `players` online (pure given inputs; exposed for tests).
function Director.pick(players, now, rng)
    local cfg = Config.Director
    local band
    for _, b in ipairs(cfg.bands or {}) do
        if players >= b.min and players <= b.max then band = b break end
    end
    if not band then return nil end
    local pool = {}
    local poolSet = (#(cfg.pool or {}) > 0) and {} or nil
    if poolSet then for _, id in ipairs(cfg.pool) do poolSet[id] = true end end
    local total = 0
    for _, d in ipairs(ES.Definitions.all()) do
        local weight = band.categories[d.category]
        local cooled = not Director.lastRun[d.id] or (now - Director.lastRun[d.id]) >= (cfg.definitionCooldownMinutes or 90) * 60
        local ok = weight and weight > 0 and ES.Definitions.isRunnable(d) and d.visibility == 'public'
            and (not poolSet or poolSet[d.id]) and not U.contains(cfg.exclude or {}, d.id) and cooled
            and d.players.min <= players
            and (not band.minMaxPlayers or d.players.max >= band.minMaxPlayers)
            and (not band.maxPlayersAtLeast or d.players.max >= band.maxPlayersAtLeast)
        if ok then
            if band.preferTeams and d.players.teams then weight = weight * 2 end
            pool[#pool + 1] = { id = d.id, w = weight }
            total = total + weight
        end
    end
    if total <= 0 then return nil end
    local r = (rng or math.random)() * total
    for _, e in ipairs(pool) do
        r = r - e.w
        if r <= 0 then return e.id end
    end
    return pool[#pool].id
end

function Director.tick(now)
    now = now or os.time()
    if not Director.enabled or busy() then return end
    if now - Director.lastEnd < (Config.Director.minMinutesBetweenEvents or 20) * 60 then return end
    if not inActiveHours(now) then return end
    local players = #GetPlayers()
    local id = Director.pick(players, now)
    if not id then return end
    local ok, instId = ES.Manager.create(id, { registration = Config.Director.registrationSeconds or 120, createdBy = 'director' })
    if ok then
        Director.lastRun[id] = now
        Log.info('Director started %s (#%d) for %d players', id, instId, players)
    end
end

AddEventHandler('event_studio:instanceState', function(_, new)
    if new == 'ARCHIVED' then Director.lastEnd = os.time() end
end)

function Director.setEnabled(on)
    Director.enabled = on == true
    GlobalState['es:director'] = Director.enabled
end

function Director.start()
    Director.setEnabled(Config.Director.enabled)
    Director.lastEnd = os.time() - (Config.Director.minMinutesBetweenEvents or 20) * 60 + 120 -- first pick ~2 min after boot
    Citizen.CreateThread(function()
        while true do
            Wait((Config.Director.checkEverySeconds or 60) * 1000)
            local ok, err = pcall(Director.tick)
            if not ok then Log.error('director tick: %s', tostring(err)) end
        end
    end)
end

return Director
