-- EVENT STUDIO — framework bridge selection (server)

local Log = ES.Log

local order = { 'qbox', 'qbcore', 'esx' }

local function oxInventory()
    local mode = Config.Framework.inventory or 'auto'
    if mode == 'none' then return nil end
    local name = Config.Framework.resources.ox_inventory or 'ox_inventory'
    if mode == 'ox_inventory' or (mode == 'auto' and GetResourceState(name) == 'started') then
        return exports[name]
    end
    return nil
end

function ES.initBridge()
    local wanted = Config.Framework.adapter or 'auto'
    local chosen
    if wanted ~= 'auto' then
        chosen = ES.Bridges[wanted]
        if not chosen then Log.error('Unknown framework adapter "%s", using standalone', wanted) end
    else
        for _, name in ipairs(order) do
            local b = ES.Bridges[name]
            if b and b.detect() then chosen = b break end
        end
    end
    chosen = chosen or ES.Bridges.standalone
    local ok, res = pcall(chosen.init)
    if not ok or res == false then
        Log.error('Framework adapter %s failed to init (%s); using standalone', chosen.name, tostring(res))
        chosen = ES.Bridges.standalone
    end

    local bridge = setmetatable({}, { __index = chosen })
    -- license-style identifier, available immediately on connect (reconnect + crash recovery keys)
    bridge.getLicense = ES.Bridges.standalone.getIdentifier
    local ox = oxInventory()
    if ox then
        bridge.addItem = function(src, item, count, metadata)
            local okCarry, can = pcall(function() return ox:CanCarryItem(src, item, count, metadata) end)
            if okCarry and can == false then return false, 'cannot_carry' end
            local okAdd, success = pcall(function() return ox:AddItem(src, item, count, metadata) end)
            return okAdd and success ~= false
        end
    end
    ES.Bridge = bridge
    ES.Bridge.inventory = ox and 'ox_inventory' or chosen.name
    GlobalState['es:framework'] = chosen.name
    Log.info('Framework adapter: %s (items: %s)', chosen.name, ES.Bridge.inventory)
    return chosen.name
end
