-- EVENT STUDIO — client framework adapters (death/revive + inventory weapon handling)
-- Selected from GlobalState['es:framework'] (set by the server adapter).

ES.ClientBridges = {}

local function started(name) return GetResourceState(name) == 'started' end

local function oxWeaponsOff()
    local ox = ES.Config.Framework.resources.ox_inventory or 'ox_inventory'
    if started(ox) then
        pcall(function() exports[ox]:weaponWheel(true) end) -- native weapon wheel on, inventory weapons disabled
        LocalPlayer.state:set('invBusy', true, false)
    end
end

local function oxWeaponsOn()
    local ox = ES.Config.Framework.resources.ox_inventory or 'ox_inventory'
    if started(ox) then
        pcall(function() exports[ox]:weaponWheel(false) end)
        LocalPlayer.state:set('invBusy', false, false)
    end
end

ES.ClientBridges.standalone = {
    revive = function() end,
    onEnterEvent = function(g) if g.blockInventoryWeapons ~= false then oxWeaponsOff() end end,
    onLeaveEvent = function() oxWeaponsOn() end,
}

ES.ClientBridges.esx = {
    revive = function()
        -- esx_ambulancejob listens for this event to clear its death state
        if started('esx_ambulancejob') then TriggerEvent('esx_ambulancejob:revive') end
    end,
    onEnterEvent = ES.ClientBridges.standalone.onEnterEvent,
    onLeaveEvent = ES.ClientBridges.standalone.onLeaveEvent,
}

ES.ClientBridges.qbcore = {
    revive = function()
        if started('qb-ambulancejob') then TriggerEvent('hospital:client:Revive') end
    end,
    onEnterEvent = function(g)
        if g.blockInventoryWeapons ~= false then oxWeaponsOff() end
        LocalPlayer.state:set('inv_busy', true, true)
    end,
    onLeaveEvent = function()
        oxWeaponsOn()
        LocalPlayer.state:set('inv_busy', false, true)
    end,
}

ES.ClientBridges.qbox = {
    revive = function()
        -- qbx_medical: verify the event name for your version; override in integrations/custom/client_hooks.lua
        if started('qbx_medical') then TriggerEvent('qbx_medical:client:playerRevived') end
    end,
    onEnterEvent = ES.ClientBridges.standalone.onEnterEvent,
    onLeaveEvent = ES.ClientBridges.standalone.onLeaveEvent,
}

CreateThread(function()
    local t = GetGameTimer()
    while not GlobalState['es:framework'] and GetGameTimer() - t < 30000 do Wait(250) end
    local name = GlobalState['es:framework'] or 'standalone'
    ES.ClientBridge = ES.ClientBridges[name] or ES.ClientBridges.standalone
    if ES.ClientHooks and ES.ClientHooks.revive then ES.ClientBridge.revive = ES.ClientHooks.revive end
end)
