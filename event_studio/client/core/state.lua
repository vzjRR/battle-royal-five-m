-- EVENT STUDIO — client event state, component registry, HUD bridging

local Client = { current = nil, components = {}, rows = {}, scoreboardOpen = false }
ES.Client = Client

---Register a client component: { setup = fn(data), update = fn(data), clear = fn() }
function ES.RegisterClientComponent(name, comp)
    Client.components[name] = comp
end

function Client.inEvent() return Client.current ~= nil end

local function clearComponents()
    for _, comp in pairs(Client.components) do
        if comp.clear then pcall(comp.clear) end
    end
end

ES.on('state', function(snap)
    if snap.state == 'ARCHIVED' then return end -- the event is over; 'left' handles the cleanup
    local prev = Client.current
    Client.current = snap
    LocalPlayer.state:set('es:clientEvent', snap.id, false)
    if snap.role == 'participant' and (snap.state == 'LOBBY' or snap.state == 'COUNTDOWN' or snap.state == 'ACTIVE' or snap.state == 'PAUSED') then
        ES.World.onEnter(snap)
    end
    -- own elimination → optional auto-spectate
    local wasActive = prev and prev.you and prev.you.status == 'active'
    local nowStatus = snap.you and snap.you.status
    if wasActive and nowStatus == 'eliminated' and snap.spectateOnEliminate and ES.Spectator then
        ES.Spectator.startFromRows()
    elseif nowStatus == 'active' and ES.Spectator and ES.Spectator.active and ES.Spectator.auto then
        ES.Spectator.stop(true)
    end
    ES.NUI.send('state', snap)
end)

ES.on('scoreboard', function(data)
    Client.rows = data.rows or {}
    Client.teams = data.teams
    ES.NUI.send('scoreboard', data)
    if ES.Spectator and ES.Spectator.active then ES.Spectator.refreshTargets() end
end)

ES.on('role', function(d)
    Client.role = d
    local ped = PlayerPedId()
    if d.health then
        SetEntityMaxHealth(ped, math.max(200, d.health))
        SetEntityHealth(ped, d.health)
    end
    if d.armor then SetPedArmour(ped, d.armor) end
    ES.NUI.send('role', d)
end)

-- Staff changed the appearance in the Admin Center: apply it live.
ES.on('ui', function(d)
    if ES.ServerInfo then ES.ServerInfo.ui = d end
    if ES.applyKeys and type(d) == 'table' then ES.applyKeys(d.keys) end
    ES.NUI.send('ui', d)
end)

-- Translatable messages carry lkey / largs: show them in this player's language.
local function localized(d)
    if type(d) == 'table' and d.lkey then
        d.text = ES.msg(nil, d.lkey, table.unpack(d.largs or {})).text
    end
    return d
end
-- Staff: an event is waiting for Start (card with the host key), or no longer waiting.
ES.on('hostPrompt', function(d) ES.NUI.send('hostPrompt', d) end)

ES.on('announce', function(d) ES.NUI.send('toast', localized(d)) end)
ES.on('notify', function(d) ES.NUI.send('toast', d) end)
ES.on('results', function(d) ES.NUI.send('results', d) end)
ES.on('mode', function(d)
    if type(d) == 'table' and type(d.banner) == 'table' and d.banner.lkey then d.banner.text = L(d.banner.lkey) end
    ES.NUI.send('mode', d)
    if Client.modeHandler then pcall(Client.modeHandler, d) end
end)

ES.on('component', function(d)
    local comp = Client.components[d.name]
    if not comp then return end
    if d.setup and comp.setup then comp.setup(d.setup) end
    if d.update and comp.update then comp.update(d.update) end
end)

ES.on('left', function(d)
    local wasIn = Client.current ~= nil
    Client.current = nil
    Client.rows = {}
    Client.role = nil
    LocalPlayer.state:set('es:clientEvent', false, false)
    clearComponents()
    if ES.Spectator then ES.Spectator.stop(true) end
    ES.NUI.send('left', { reason = d.reason })
    CreateThread(function()
        if wasIn or d.coords then ES.World.onExit(d) end
    end)
end)

-- Restore everything if the resource stops while we are inside an event.
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    local cur = Client.current
    clearComponents()
    if ES.Spectator then pcall(ES.Spectator.stop, true) end
    if cur then
        local rp = cur.returnPoint
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
        if ES.World.entered then ES.World.restoreWeapons() end
        if rp and rp.coords then SetEntityCoordsNoOffset(ped, rp.coords.x, rp.coords.y, rp.coords.z, false, false, false) end
    end
end)
