-- EVENT STUDIO — ESX adapter (es_extended legacy)
ES.Bridges = ES.Bridges or {}

local B = { name = 'esx' }
local ESX

local function res() return Config.Framework.resources.esx or 'es_extended' end

function B.detect() return GetResourceState(res()) == 'started' end

function B.init()
    ESX = exports[res()]:getSharedObject()
    return ESX ~= nil
end

local function xp(src) return ESX and ESX.GetPlayerFromId(src) end

function B.getIdentifier(src)
    local p = xp(src)
    if p and Config.Framework.useCharacterIdentifier and p.identifier then return p.identifier end
    return ES.Bridges.standalone.getIdentifier(src)
end

function B.getName(src)
    local p = xp(src)
    if p and p.getName then
        local ok, name = pcall(p.getName)
        if ok and name and name ~= '' then return name end
    end
    return GetPlayerName(tostring(src)) or ('Player ' .. src)
end

function B.getGroups(src)
    local p = xp(src)
    local out = {}
    if p and p.getGroup then out[p.getGroup()] = true end
    return out
end

function B.addMoney(src, account, amount, reason)
    local p = xp(src)
    if not p then return false, 'no_player' end
    local acc = account == 'cash' and 'money' or account
    p.addAccountMoney(acc, amount, reason)
    return true
end

function B.addItem(src, item, count, metadata)
    local p = xp(src)
    if not p then return false, 'no_player' end
    if p.canCarryItem and not p.canCarryItem(item, count) then return false, 'cannot_carry' end
    p.addInventoryItem(item, count, metadata)
    return true
end

function B.notify(src, message, kind)
    TriggerClientEvent('esx:showNotification', src, message, kind)
end

ES.Bridges.esx = B
