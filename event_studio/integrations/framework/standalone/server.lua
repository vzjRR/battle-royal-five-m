-- EVENT STUDIO — standalone adapter (no framework)
ES.Bridges = ES.Bridges or {}

local B = { name = 'standalone' }

function B.detect() return true end
function B.init() return true end

function B.getIdentifier(src)
    for _, kind in ipairs(Config.Framework.standaloneIdentifiers or { 'license' }) do
        local id = GetPlayerIdentifierByType(tostring(src), kind)
        if id and id ~= '' then return id end
    end
    return 'src:' .. tostring(src)
end

function B.getName(src)
    return GetPlayerName(tostring(src)) or ('Player ' .. tostring(src))
end

function B.getGroups() return {} end

-- No economy in standalone. Use a custom reward type or the 'command' reward.
function B.addMoney() return false, 'no_economy' end
function B.addItem() return false, 'no_inventory' end

function B.notify(src, message, kind)
    TriggerClientEvent('es:push', src, 'notify', { text = message, kind = kind or 'info' })
end

ES.Bridges.standalone = B
