-- EVENT STUDIO — QBCore adapter
ES.Bridges = ES.Bridges or {}

local B = { name = 'qbcore' }
local QBCore

local function res() return Config.Framework.resources.qbcore or 'qb-core' end

function B.detect() return GetResourceState(res()) == 'started' end

function B.init()
    QBCore = exports[res()]:GetCoreObject()
    return QBCore ~= nil
end

local function player(src) return QBCore and QBCore.Functions.GetPlayer(src) end

function B.getIdentifier(src)
    local p = player(src)
    if p and Config.Framework.useCharacterIdentifier and p.PlayerData.citizenid then return p.PlayerData.citizenid end
    return ES.Bridges.standalone.getIdentifier(src)
end

function B.getName(src)
    local p = player(src)
    local ci = p and p.PlayerData.charinfo
    if ci and ci.firstname then return (ci.firstname .. ' ' .. (ci.lastname or '')):gsub('%s+$', '') end
    return GetPlayerName(tostring(src)) or ('Player ' .. src)
end

function B.getGroups(src)
    local out = {}
    local ok, perms = pcall(QBCore.Functions.GetPermission, src)
    if ok then
        if type(perms) == 'table' then
            for k, v in pairs(perms) do
                if v == true then out[k] = true elseif type(v) == 'string' then out[v] = true end
            end
        elseif type(perms) == 'string' then
            out[perms] = true
        end
    end
    return out
end

function B.addMoney(src, account, amount, reason)
    local p = player(src)
    if not p then return false, 'no_player' end
    return p.Functions.AddMoney(account, amount, reason) ~= false
end

function B.addItem(src, item, count, metadata)
    local p = player(src)
    if not p then return false, 'no_player' end
    local ok = p.Functions.AddItem(item, count, false, metadata)
    if ok and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item] then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', count)
    end
    return ok ~= false
end

function B.notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind == 'error' and 'error' or (kind == 'success' and 'success' or 'primary'))
end

ES.Bridges.qbcore = B
