-- EVENT STUDIO — Qbox adapter (qbx_core)
-- Qbox recommends ACE for permissions: add_ace group.admin eventstudio.admin allow
ES.Bridges = ES.Bridges or {}

local B = { name = 'qbox' }
local qbx

local function res() return Config.Framework.resources.qbox or 'qbx_core' end

function B.detect() return GetResourceState(res()) == 'started' end

function B.init()
    qbx = exports[res()]
    return qbx ~= nil
end

local function player(src)
    local ok, p = pcall(function() return qbx:GetPlayer(src) end)
    return ok and p or nil
end

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

function B.getGroups() return {} end

function B.addMoney(src, account, amount, reason)
    local ok, res2 = pcall(function() return qbx:AddMoney(src, account, amount, reason) end)
    return ok and res2 ~= false
end

function B.addItem() return false, 'use_ox_inventory' end

function B.notify(src, message, kind)
    local ok = pcall(function() qbx:Notify(src, message, kind or 'inform') end)
    if not ok then TriggerClientEvent('es:push', src, 'notify', { text = message, kind = kind or 'info' }) end
end

ES.Bridges.qbox = B
