-- EVENT STUDIO — permissions (role levels resolved from ACE and framework groups)

local Perm = {}
ES.Perm = Perm

local cache = {}

local function cfg() return Config.Permissions end

---Highest role level the player holds (0 = none). Console = admin.
function Perm.level(src)
    if src == 0 then return 1000 end
    local now = os.time()
    local c = cache[src]
    if c and now - c.at < (cfg().cacheSeconds or 30) then return c.level, c.role end

    local best, bestRole = 0, nil
    local groups = (cfg().sources.framework and ES.Bridge) and ES.Bridge.getGroups(src) or {}
    for role, def in pairs(cfg().roles) do
        local has = false
        if cfg().sources.ace and IsPlayerAceAllowed(tostring(src), (cfg().acePrefix or 'eventstudio.') .. role) then
            has = true
        end
        if not has and def.framework then
            for _, g in ipairs(def.framework) do
                if groups[g] then has = true break end
            end
        end
        if has and def.level > best then best, bestRole = def.level, role end
    end
    cache[src] = { at = now, level = best, role = bestRole }
    return best, bestRole
end

function Perm.roleLevel(role)
    local def = cfg().roles[role]
    return def and def.level or math.huge
end

---Can `src` perform `action`?
function Perm.can(src, action)
    local role = cfg().actions[action]
    if not role then
        ES.Log.warn('Permission action "%s" is not mapped; denying', tostring(action))
        return false
    end
    return Perm.level(src) >= Perm.roleLevel(role)
end

---List of actions the player may perform (sent to the admin NUI to hide controls; server still enforces).
function Perm.allowedActions(src)
    local out = {}
    for action in pairs(cfg().actions) do
        if Perm.can(src, action) then out[action] = true end
    end
    return out
end

function Perm.clear(src) cache[src] = nil end

return Perm
