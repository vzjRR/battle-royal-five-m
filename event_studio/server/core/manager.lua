-- EVENT STUDIO — instance manager: creation, player index, tick loop, disconnects, damage filter

local U = ES.Util
local S = ES.Lifecycle.States
local Lifecycle = ES.Lifecycle
local Log = ES.Log

local Manager = { instances = {}, byPlayer = {}, lastJoin = {}, ticking = false }
ES.Manager = Manager

----------------------------------------------------------------------------
-- Index
----------------------------------------------------------------------------

function Manager.index(src, inst) Manager.byPlayer[src] = inst end

function Manager.unindex(src, inst)
    if Manager.byPlayer[src] == inst then Manager.byPlayer[src] = nil end
end

function Manager.ofPlayer(src) return Manager.byPlayer[src] end

function Manager.get(id) return Manager.instances[tonumber(id)] end

function Manager.list()
    local out = {}
    for _, inst in pairs(Manager.instances) do out[#out + 1] = inst end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Manager.remove(inst)
    Manager.instances[inst.id] = nil
    for src, i in pairs(Manager.byPlayer) do
        if i == inst then Manager.byPlayer[src] = nil end
    end
    Log.debug('#%d removed', inst.id)
end

----------------------------------------------------------------------------
-- Creation
----------------------------------------------------------------------------

---Create an instance from a definition id. opts: { overrides, startAt, registration, invite, tournament, match, createdBy, allowDraft }
function Manager.create(defId, opts)
    opts = opts or {}
    local def = ES.Definitions.get(defId)
    if not def then return false, 'not_found' end
    if not opts.allowDraft and not ES.Definitions.isRunnable(def) then return false, 'not_runnable' end
    if opts.overrides then
        local merged = U.merge(def, opts.overrides)
        merged.id = def.id
        local ok, res = ES.Definitions.validate(merged)
        if not ok then return false, 'invalid_overrides:' .. tostring(res) end
        def = res
    end
    local id = ES.Storage.nextInstanceId()
    local inst = ES.Instance.new(id, def, opts)
    Manager.instances[id] = inst
    if inst.state == S.REGISTRATION then
        -- run REGISTRATION entry effects (announcements) for the initial state
        inst.state = S.SCHEDULED
        inst:setState(S.REGISTRATION, 'created')
    end
    Log.info('#%d created: %s (%s) state=%s', id, def.name, def.mode, inst.state)
    Log.record('lifecycle', 'instance.created', opts.createdBy, id, { definition = def.id, name = def.name })
    Manager.ensureTicking()
    return true, id, inst
end

----------------------------------------------------------------------------
-- Player operations
----------------------------------------------------------------------------

function Manager.join(src, id, force)
    local inst = Manager.get(id)
    if not inst then return false, 'not_found' end
    local current = Manager.byPlayer[src]
    if current and current ~= inst then return false, 'in_other_event' end
    if current == inst and inst.participants[src] then return false, 'already_joined' end
    if not force then
        local last = Manager.lastJoin[src]
        if last and os.time() - last < (Config.General.joinCooldown or 0) then return false, 'cooldown' end
        local ped = GetPlayerPed(src)
        if ped == 0 or GetEntityHealth(ped) <= 100 then return false, 'dead' end
    end
    local ok, err = inst:addParticipant(src, force)
    if not ok then return false, err end
    Manager.lastJoin[src] = os.time()
    Manager.index(src, inst)
    return true
end

function Manager.leave(src, reason)
    local inst = Manager.byPlayer[src]
    if not inst then return false, 'not_in_event' end
    if inst.spectators[src] then return inst:removeSpectator(src, reason or 'left') end
    return inst:removeParticipant(src, reason or 'left')
end

function Manager.spectate(src, id, admin)
    local inst = Manager.get(id)
    if not inst then return false, 'not_found' end
    local current = Manager.byPlayer[src]
    if current then
        if current == inst and inst.spectators[src] then return false, 'already_spectating' end
        return false, 'in_other_event'
    end
    return inst:addSpectator(src, admin)
end

----------------------------------------------------------------------------
-- Tick loop (only while instances exist)
----------------------------------------------------------------------------

function Manager.ensureTicking()
    if Manager.ticking then return end
    Manager.ticking = true
    Citizen.CreateThread(function()
        local last = ES.now()
        while next(Manager.instances) do
            Wait(Config.General.tickMs or 500)
            local now = ES.now()
            local dt = now - last
            last = now
            for _, inst in pairs(Manager.instances) do
                local ok, err = pcall(function()
                    inst:update(dt)
                    if Lifecycle.isLive(inst.state) then inst:expireDisconnects() end
                end)
                if not ok then Log.error('#%d tick error: %s', inst.id, tostring(err)) end
            end
        end
        Manager.ticking = false
    end)
end

----------------------------------------------------------------------------
-- Connection lifecycle
----------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local src = source
    local inst = Manager.byPlayer[src]
    if inst then
        local ok, err = pcall(inst.onDisconnect, inst, src)
        if not ok then Log.error('disconnect handling: %s', tostring(err)) end
        Manager.byPlayer[src] = nil
    end
    Manager.lastJoin[src] = nil
    ES.Perm.clear(src)
    ES.RPC.clear(src)
    Log.clearPlayer(src)
end)

---Client finished loading (RPC 'client:ready'): reconnect into a live event, or crash-recovery return.
function Manager.onClientReady(src)
    local license = ES.Bridge.getLicense(src)
    for _, inst in pairs(Manager.instances) do
        local p = inst.byLicense and inst.byLicense[license]
        if p and p.status == 'disconnected' and Lifecycle.isLive(inst.state) then
            local ok = inst:rejoin(p, src)
            if ok then return { rejoined = inst.id } end
        end
    end
    local point = ES.Storage.getReturnPoint(license)
    if point then
        ES.Storage.clearReturnPoint(license)
        ES.push(src, 'left', { coords = point.coords, heading = point.heading, reason = 'recovered' })
        Log.info('Returned %s to their pre-event position (crash recovery)', GetPlayerName(tostring(src)) or src)
        return { recovered = true }
    end
    return {}
end

AddEventHandler('onResourceStop', function(name)
    if name ~= ES.name then return end
    for _, inst in pairs(Manager.instances) do
        for _, ent in ipairs(inst.entities) do
            if DoesEntityExist(ent) then DeleteEntity(ent) end
        end
        local function restore(src, point)
            if point then SetPlayerRoutingBucket(src, point.bucket or 0) end
            Player(src).state:set('es:inEvent', false, true)
            -- clients restore their own position in their onResourceStop handler
            ES.Storage.clearReturnPoint(ES.Bridge.getLicense(src))
        end
        for src, p in pairs(inst.participants) do
            if inst.bucket then restore(src, p.returnPoint) end
        end
        for src, s in pairs(inst.spectators) do restore(src, s.returnPoint) end
        ES.Buckets.release(inst.bucket)
    end
end)

----------------------------------------------------------------------------
-- Damage filter (server authoritative combat)
----------------------------------------------------------------------------

local function pedOwnerInInstance(inst, entity)
    for src in pairs(inst.participants) do
        if GetPlayerPed(src) == entity then return src end
    end
    for src in pairs(inst.spectators) do
        if GetPlayerPed(src) == entity then return src, true end
    end
    return nil
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    local attacker = tonumber(sender)
    local attackerInst = Manager.byPlayer[attacker]
    local ids = data.hitGlobalIds or { data.hitGlobalId }
    for _, netId in ipairs(ids) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and GetEntityType(entity) == 1 and IsPedAPlayer(entity) then
            local victim = NetworkGetEntityOwner(entity)
            local victimInst = victim and Manager.byPlayer[victim]
            if attackerInst or victimInst then
                if attackerInst ~= victimInst then
                    CancelEvent()
                    return
                end
                local inst = attackerInst
                if inst.spectators[attacker] or inst.spectators[victim] then
                    CancelEvent()
                    return
                end
                local combat = inst:component('combat')
                local victimSrc = pedOwnerInInstance(inst, entity) or victim
                if not combat or not combat:filterDamage(attacker, victimSrc, data.weaponType) then
                    CancelEvent()
                    return
                end
            end
        end
    end
end)

return Manager
