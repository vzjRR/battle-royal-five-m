-- EVENT STUDIO — logging, audit and security log sinks

local Log = {}
ES.Log = Log

local levels = { debug = 1, info = 2, warn = 3, error = 4 }
local colors = { debug = '^7', info = '^5', warn = '^3', error = '^1', audit = '^6', security = '^1' }

local function debugEnabled()
    return GetConvarInt('es_debug', 0) == 1
end

local function out(level, msg)
    print(('%s[event_studio:%s]^7 %s'):format(colors[level] or '^7', level, msg))
end

local function fmt(msg, ...)
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, msg, ...)
        if ok then return res end
    end
    return tostring(msg)
end

function Log.debug(msg, ...) if debugEnabled() then out('debug', fmt(msg, ...)) end end
function Log.info(msg, ...) out('info', fmt(msg, ...)) end
function Log.warn(msg, ...) out('warn', fmt(msg, ...)) end
function Log.error(msg, ...) out('error', fmt(msg, ...)) end

local function actorLabel(src)
    if not src then return nil end
    if src == 0 then return 'console' end
    local name = GetPlayerName(src) or '?'
    local ident = ES.Bridge and ES.Bridge.getIdentifier(src) or tostring(src)
    return ('%s (%s) [%s]'):format(name, ident, src)
end
Log.actorLabel = actorLabel

---Persistent structured record (storage + discord routing).
---@param level string 'audit' | 'security' | 'lifecycle' | 'info'
function Log.record(level, action, actorSrc, instanceId, data)
    local entry = {
        created_at = os.time(), level = level, action = action,
        actor = type(actorSrc) == 'number' and actorLabel(actorSrc) or actorSrc,
        instance_id = instanceId, data = data,
    }
    if ES.Storage and ES.Storage.log then
        local ok, err = pcall(ES.Storage.log, entry)
        if not ok then out('error', 'storage log failed: ' .. tostring(err)) end
    end
    if ES.Discord then ES.Discord.route(level, action, entry) end
    return entry
end

---Admin/audit trail.
function Log.audit(action, actorSrc, instanceId, data)
    out('audit', ('%s by %s%s'):format(action, actorLabel(actorSrc) or '?', instanceId and (' on #' .. instanceId) or ''))
    return Log.record('audit', action, actorSrc, instanceId, data)
end

local violations = {}

---Security violation. Throttled per player; optional auto kick.
function Log.security(src, reason, data)
    local now = os.time()
    local v = violations[src]
    local sec = Config.General.security
    if not v or now - v.since > (sec.violationWindow or 60) then
        v = { since = now, count = 0, lastLogged = 0 }
        violations[src] = v
    end
    v.count = v.count + 1
    if now - v.lastLogged >= 2 then
        v.lastLogged = now
        out('security', ('%s: %s (x%d)'):format(actorLabel(src) or tostring(src), reason, v.count))
        Log.record('security', reason, src, data and data.instanceId, data)
    end
    local max = sec.maxViolationsBeforeKick or 0
    if max > 0 and v.count >= max and src and src > 0 then
        DropPlayer(tostring(src), ES.Lp(src, 'security_kick'))
    end
end

function Log.clearPlayer(src) violations[src] = nil end

return Log
