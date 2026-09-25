-- EVENT STUDIO — scheduler: recurrence rules, rotations, instance creation at lead time

local U = ES.Util
local Log = ES.Log

local Scheduler = { schedules = {}, rotations = {}, lastRun = {}, rotationCursor = {} }
ES.Scheduler = Scheduler

----------------------------------------------------------------------------
-- Time helpers (pure). offsetMinutes = nil → server local time; number → fixed UTC offset.
----------------------------------------------------------------------------

local function tzOffsetSeconds()
    return os.time(os.date('*t', 86400)) - os.time(os.date('!*t', 86400))
end

local function breakdown(ts, offsetMinutes)
    if offsetMinutes == nil then return os.date('*t', ts) end
    return os.date('!*t', ts + offsetMinutes * 60)
end

---Timestamp for a calendar time in the scheduler's zone (fields are normalised: day overflow ok).
local function stamp(y, m, d, hh, mm, offsetMinutes)
    local t = { year = y, month = m, day = d, hour = hh, min = mm, sec = 0, isdst = nil }
    if offsetMinutes == nil then return os.time(t) end
    t.isdst = false
    return os.time(t) + tzOffsetSeconds() - offsetMinutes * 60
end

local function parseTime(s)
    local h, m = tostring(s or ''):match('^(%d%d?):(%d%d)$')
    h, m = tonumber(h), tonumber(m)
    if not h or h > 23 or m > 59 then return nil end
    return h, m
end
Scheduler.parseTime = parseTime

local function isoWeekday(t) return (t.wday + 5) % 7 + 1 end -- 1 = Monday .. 7 = Sunday

local function daysInMonth(y, m)
    return os.date('*t', os.time({ year = y, month = m + 1, day = 0, hour = 12 })).day
end

---Validate a rule. Returns ok, err.
function Scheduler.validateRule(rule)
    if type(rule) ~= 'table' then return false, 'rule must be a table' end
    local t = rule.type
    if t == 'interval' then
        if type(rule.minutes) ~= 'number' or rule.minutes < 5 or rule.minutes > 1440 then return false, 'interval minutes 5-1440' end
        if rule.from and not parseTime(rule.from) then return false, 'invalid from' end
        if rule.to and not parseTime(rule.to) then return false, 'invalid to' end
        return true
    end
    if not parseTime(rule.time) then return false, 'invalid time (HH:MM)' end
    if t == 'daily' then return true end
    if t == 'weekly' then
        if type(rule.days) ~= 'table' or #rule.days == 0 then return false, 'weekly needs days' end
        for _, d in ipairs(rule.days) do
            if type(d) ~= 'number' or d < 1 or d > 7 then return false, 'days are 1 (Mon) .. 7 (Sun)' end
        end
        return true
    end
    if t == 'monthly' then
        if type(rule.day) ~= 'number' or rule.day < 1 or rule.day > 31 then return false, 'monthly day 1-31' end
        return true
    end
    if t == 'once' then
        if type(rule.date) ~= 'string' or not rule.date:match('^%d%d%d%d%-%d%d%-%d%d$') then return false, 'once needs date YYYY-MM-DD' end
        return true
    end
    return false, 'unknown rule type'
end

---Next occurrence strictly after `now` (unix seconds) or nil.
function Scheduler.nextOccurrence(rule, now, offsetMinutes)
    local ok = Scheduler.validateRule(rule)
    if not ok then return nil end
    local today = breakdown(now, offsetMinutes)
    for delta = 0, 400 do
        local dayTs = stamp(today.year, today.month, today.day + delta, 12, 0, offsetMinutes)
        local d = breakdown(dayTs, offsetMinutes)
        local times = {}
        if rule.type == 'interval' then
            local fh, fm = parseTime(rule.from or '00:00')
            local th, tm = parseTime(rule.to or '23:59')
            local start, stop = fh * 60 + fm, th * 60 + tm
            if stop <= start then stop = stop + 1440 end
            for minute = start, stop, rule.minutes do times[#times + 1] = minute end
        else
            local match = false
            if rule.type == 'daily' then
                match = true
            elseif rule.type == 'weekly' then
                match = U.contains(rule.days, isoWeekday(d))
            elseif rule.type == 'monthly' then
                match = d.day == math.min(rule.day, daysInMonth(d.year, d.month))
            elseif rule.type == 'once' then
                match = rule.date == ('%04d-%02d-%02d'):format(d.year, d.month, d.day)
            end
            if match then
                local h, m = parseTime(rule.time)
                times[1] = h * 60 + m
            end
        end
        for _, minute in ipairs(times) do
            local ts = stamp(d.year, d.month, d.day, 0, minute, offsetMinutes)
            if ts > now then return ts end
        end
    end
    return nil
end

----------------------------------------------------------------------------
-- Schedules
----------------------------------------------------------------------------

local scheduleSchema = {
    id = 'id',
    enabled = { type = 'boolean', default = true },
    definition = { type = 'id', optional = true },
    rotation = { type = 'id', optional = true },
    rule = 'table',
    leadMinutes = { type = 'integer', min = 0, max = 1440, optional = true },
    label = { type = 'string', maxLen = 64, optional = true },
}

function Scheduler.validate(s)
    local ok, clean = ES.Schema.validateFields(s, scheduleSchema)
    if not ok then return false, clean end
    if not clean.definition and not clean.rotation then return false, 'definition or rotation required' end
    if clean.definition and not ES.Definitions.get(clean.definition) then return false, 'unknown definition' end
    if clean.rotation and not Scheduler.rotations[clean.rotation] then return false, 'unknown rotation' end
    local okR, err = Scheduler.validateRule(clean.rule)
    if not okR then return false, err end
    return true, clean
end

function Scheduler.put(s, source)
    local ok, clean = Scheduler.validate(s)
    if not ok then return false, clean end
    clean.source = source or 'api'
    clean.nextAt = nil
    Scheduler.schedules[clean.id] = clean
    return true, clean.id
end

function Scheduler.remove(id) Scheduler.schedules[id] = nil end

---Resolve a rotation slot to a definition id for the given time.
function Scheduler.resolveRotation(rotId, ts)
    local rot = Scheduler.rotations[rotId]
    if not rot then return nil end
    local slot = rot.days and rot.days[isoWeekday(breakdown(ts, Config.Scheduler.utcOffsetMinutes))]
    if not slot then return nil end
    local candidates = {}
    if slot.definitions then
        for _, id in ipairs(slot.definitions) do
            local d = ES.Definitions.get(id)
            if ES.Definitions.isRunnable(d) then candidates[#candidates + 1] = d.id end
        end
    elseif slot.category then
        for _, d in ipairs(ES.Definitions.all()) do
            if d.category == slot.category and d.visibility == 'public' and ES.Definitions.isRunnable(d) then
                candidates[#candidates + 1] = d.id
            end
        end
    end
    if #candidates == 0 then return nil end
    table.sort(candidates)
    local pick = rot.pick or 'random'
    if pick == 'sequential' then
        local c = (Scheduler.rotationCursor[rotId] or 0) % #candidates + 1
        Scheduler.rotationCursor[rotId] = c
        return candidates[c]
    elseif pick == 'leastRecent' then
        local best, bestT
        for _, id in ipairs(candidates) do
            local t = Scheduler.lastRun[id] or 0
            if not bestT or t < bestT then best, bestT = id, t end
        end
        return best
    end
    return U.pick(candidates)
end

function Scheduler.tick(now)
    now = now or os.time()
    local offset = Config.Scheduler.utcOffsetMinutes
    for _, s in pairs(Scheduler.schedules) do
        if s.enabled then
            s.nextAt = s.nextAt or Scheduler.nextOccurrence(s.rule, now - 1, offset)
            if s.nextAt then
                local lead = (s.leadMinutes or Config.Scheduler.defaultLeadMinutes or 5) * 60
                if now > s.nextAt + 60 then
                    -- missed (server was down): skip, do not replay
                    s.nextAt = Scheduler.nextOccurrence(s.rule, now, offset)
                elseif now >= s.nextAt - lead and s.createdFor ~= s.nextAt then
                    s.createdFor = s.nextAt
                    local defId = s.definition or Scheduler.resolveRotation(s.rotation, s.nextAt)
                    if defId then
                        local ok, idOrErr = ES.Manager.create(defId, { startAt = s.nextAt, createdBy = 'scheduler:' .. s.id })
                        if ok then
                            Scheduler.lastRun[defId] = now
                            Log.info('Schedule %s created instance #%d (%s)', s.id, idOrErr, defId)
                        else
                            Log.warn('Schedule %s could not create %s: %s', s.id, tostring(defId), tostring(idOrErr))
                        end
                    else
                        Log.warn('Schedule %s: rotation resolved no definition', s.id)
                    end
                    s.nextAt = Scheduler.nextOccurrence(s.rule, s.nextAt, offset)
                end
            end
        end
    end
end

---Upcoming occurrences for the browser/admin (next N).
function Scheduler.upcoming(limit, now)
    now = now or os.time()
    local out = {}
    for _, s in pairs(Scheduler.schedules) do
        if s.enabled then
            local ts = s.nextAt or Scheduler.nextOccurrence(s.rule, now, Config.Scheduler.utcOffsetMinutes)
            if ts then
                local def = s.definition and ES.Definitions.get(s.definition)
                out[#out + 1] = {
                    schedule = s.id, at = ts, definition = s.definition, rotation = s.rotation,
                    name = def and def.name or (s.label or ('Rotation: ' .. tostring(s.rotation))),
                    category = def and def.category or nil,
                    visibility = def and def.visibility or 'public',
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    while #out > (limit or 10) do table.remove(out) end
    return out
end

function Scheduler.list()
    local out = {}
    for _, s in pairs(Scheduler.schedules) do out[#out + 1] = s end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Scheduler.loadAll()
    Scheduler.rotations = U.deepCopy(Config.Scheduler.rotations or {})
    for id, r in pairs(ES.Storage.loadDocuments('rotation') or {}) do Scheduler.rotations[id] = r end
    for _, s in ipairs(Config.Scheduler.schedules or {}) do
        local ok, err = Scheduler.put(s, 'config')
        if not ok then Log.warn('Schedule %s invalid: %s', tostring(s.id), tostring(err)) end
    end
    for id, s in pairs(ES.Storage.loadDocuments('schedule') or {}) do
        local ok, err = Scheduler.put(s, 'storage')
        if not ok then Log.warn('Stored schedule %s invalid: %s', id, tostring(err)) end
    end
    Log.info('Loaded %d schedules', U.count(Scheduler.schedules))
end

function Scheduler.start()
    if not Config.Scheduler.enabled then return end
    Citizen.CreateThread(function()
        while true do
            local ok, err = pcall(Scheduler.tick)
            if not ok then Log.error('scheduler tick: %s', tostring(err)) end
            Wait((Config.Scheduler.tickSeconds or 30) * 1000)
        end
    end)
end

return Scheduler
