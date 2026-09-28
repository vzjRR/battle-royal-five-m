-- EVENT STUDIO — component: combat
-- Loadouts, weapon whitelist, friendly fire, server-side kill attribution, lives & respawn.

local U = ES.Util
local Log = ES.Log

local Combat = {}
Combat.__index = Combat

local function norm(h)
    h = math.tointeger(h) or 0
    return h & 0xFFFFFFFF
end
Combat.norm = norm

-- Damage types always allowed (fists, falling, vehicles)
local alwaysAllowed = {}
for _, name in ipairs({ 'WEAPON_UNARMED', 'WEAPON_FALL', 'WEAPON_RAMMED_BY_CAR', 'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_EXPLOSION' }) do
    alwaysAllowed[norm(GetHashKey(name))] = true
end

---cfg = {
---  weapons = { 'WEAPON_PISTOL', ... } | {} (fists), ammo = 250, random = false (one random weapon per life),
---  lives = 0 (infinite), respawnDelay = 3, spawnProtectionMs = 3000,
---  friendlyFire = bool, enforceWhitelist = true, attributionWindowMs = 10000,
---}
function Combat.attach(inst, cfg)
    local self = setmetatable({
        inst = inst,
        cfg = cfg,
        allowed = {},
        damageLog = {},    -- [victimSrc] = { {attacker, t, weapon}, ... }
        alive = {},        -- [participant] = true while alive (one death per life)
        pendingRespawn = {},
        weaponsOf = {},    -- [participant] = current weapon list
    }, Combat)
    cfg.ammo = cfg.ammo or 250
    cfg.lives = cfg.lives or 0
    cfg.respawnDelay = cfg.respawnDelay or 3
    if cfg.friendlyFire == nil then cfg.friendlyFire = inst.def.gameplay.friendlyFire end
    self:setAllowed(cfg.weapons or {})
    for _, p in pairs(inst.participants) do
        if p.status == 'active' then self:initParticipant(p) end
    end
    return self
end

function Combat:setAllowed(list)
    self.allowed = {}
    for _, w in ipairs(list) do self.allowed[norm(GetHashKey(w))] = true end
end

function Combat:allowWeapon(name) self.allowed[norm(GetHashKey(name))] = true end

function Combat:initParticipant(p)
    self.alive[p] = true
    if self.cfg.lives > 0 and p.lives == nil then p.lives = self.cfg.lives end
end

function Combat:weaponsFor(p)
    local list = self.cfg.weapons or {}
    if self.cfg.random and #list > 0 then return { U.pick(list) } end
    return list
end

---Order the client to replace its weapons (clear = true removes others).
function Combat:giveLoadout(p, weapons)
    if not p.src then return end
    weapons = weapons or self:weaponsFor(p)
    self.weaponsOf[p] = weapons
    local list = {}
    for i, w in ipairs(weapons) do list[i] = { name = w, ammo = self.cfg.ammo } end
    self.inst:push(p, 'loadout', { weapons = list, clear = true })
end

function Combat:giveAll(weapons)
    for _, p in ipairs(self.inst:activeParticipants()) do self:giveLoadout(p, weapons) end
end

function Combat:clientSetup(p)
    if not p then return { active = false } end
    local weapons = self.weaponsOf[p] or self:weaponsFor(p)
    self.weaponsOf[p] = weapons
    local list = {}
    for i, w in ipairs(weapons) do list[i] = { name = w, ammo = self.cfg.ammo } end
    return { active = true, weapons = list, lives = p.lives, respawnDelay = self.cfg.respawnDelay }
end

---Called by the manager's weaponDamageEvent filter. Returns true to allow.
function Combat:filterDamage(attacker, victim, weaponHash)
    local a, v = self.inst.participants[attacker], self.inst.participants[victim]
    if not a or not v then return false end
    if a.status ~= 'active' or v.status ~= 'active' then return false end
    if self.inst.state ~= ES.Lifecycle.States.ACTIVE then return false end
    if not self.cfg.friendlyFire and a.team and a.team == v.team then return false end
    local h = norm(weaponHash)
    if self.cfg.enforceWhitelist ~= false and not self.allowed[h] and not alwaysAllowed[h] then
        Log.security(attacker, 'weapon_not_allowed', { instanceId = self.inst.id, weapon = h })
        return false
    end
    local logList = self.damageLog[victim] or {}
    table.insert(logList, 1, { attacker = attacker, t = ES.now(), weapon = h })
    while #logList > 8 do table.remove(logList) end
    self.damageLog[victim] = logList
    return true
end

local function isDead(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and GetEntityHealth(ped) <= 100
end

---Resolve the killer from the damage log (hint is only accepted if present in the log).
function Combat:resolveKiller(victimSrc, hint)
    local window = self.cfg.attributionWindowMs or 10000
    local now = ES.now()
    local fallback
    for _, e in ipairs(self.damageLog[victimSrc] or {}) do
        if now - e.t <= window then
            if hint and e.attacker == hint then return e.attacker, e.weapon end
            fallback = fallback or e
        end
    end
    if fallback then return fallback.attacker, fallback.weapon end
    return nil
end

function Combat:confirmDeath(p, hint)
    if not self.alive[p] then return end
    self.alive[p] = false
    local killerSrc, weapon = self:resolveKiller(p.src, hint)
    local killer = killerSrc and self.inst.participants[killerSrc] or nil
    self.damageLog[p.src] = nil
    if killer and killer ~= p then
        self.inst:push(killer, 'announce', ES.say(killer, 'success', 'you_killed', p.name))
        self.inst:push(p, 'announce', ES.say(p, 'error', 'killed_by', killer.name))
    end
    self.inst:onDeath(p, killer, weapon)
    if p.status ~= 'active' then return end -- mode may have eliminated/finished
    if self.cfg.lives > 0 then
        p.lives = (p.lives or self.cfg.lives) - 1
        if p.lives <= 0 then
            self.inst:eliminate(p, 'out_of_lives', killer)
            return
        end
    end
    self:scheduleRespawn(p)
end

function Combat:scheduleRespawn(p)
    if self.pendingRespawn[p] then return end
    self.pendingRespawn[p] = true
    SetTimeout(math.floor(self.cfg.respawnDelay * 1000), function()
        self.pendingRespawn[p] = nil
        if p.status ~= 'active' or not p.src then return end
        if self.inst.state ~= ES.Lifecycle.States.ACTIVE and self.inst.state ~= ES.Lifecycle.States.PAUSED then return end
        self.alive[p] = true
        self.inst:respawn(p)
        self:giveLoadout(p, self.cfg.random and self:weaponsFor(p) or self.weaponsOf[p])
        self.inst:syncState(p.src)
    end)
end

---Client death hint: { killer = serverId? }
function Combat:onAction(p, action, data)
    if action ~= 'died' then return nil end
    if not self.alive[p] then return true end -- duplicate hint, ignore silently
    local hint = data and tonumber(data.killer) or nil
    if isDead(p.src) then
        self:confirmDeath(p, hint)
        return true
    end
    -- health sync may lag; re-check shortly before rejecting
    SetTimeout(750, function()
        if self.alive[p] and p.src and isDead(p.src) then
            self:confirmDeath(p, hint)
        elseif self.alive[p] then
            Log.debug('#%d death hint from %s not confirmed', self.inst.id, tostring(p.src))
        end
    end)
    return true
end

function Combat:onJoin(p, rejoin)
    self:initParticipant(p)
end

function Combat:onLeave(p)
    self.alive[p] = nil
    self.pendingRespawn[p] = nil
end

function Combat:onEliminated(p)
    self.alive[p] = false
    if p.src then self.inst:push(p, 'loadout', { weapons = {}, clear = true }) end
end

function Combat:detach()
    for _, p in pairs(self.inst.participants) do
        if p.src then self.inst:push(p, 'loadout', { weapons = {}, clear = true }) end
    end
end

ES.RegisterComponent('combat', Combat)
