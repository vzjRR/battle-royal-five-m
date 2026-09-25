-- EVENT STUDIO — announcements via adapters: nui | chat | notify | discord

local Announce = { outputs = {} }
ES.Announce = Announce

Announce.outputs.nui = function(target, text, kind)
    TriggerClientEvent('es:push', target, 'announce', { text = text, kind = kind or 'global' })
end

Announce.outputs.chat = function(target, text)
    if GetResourceState('chat') ~= 'started' then return end
    TriggerClientEvent('chat:addMessage', target, { args = { Config.Notifications.chatPrefix or '[Events]', text } })
end

Announce.outputs.notify = function(target, text, kind)
    if target == -1 then
        for _, id in ipairs(GetPlayers()) do ES.Bridge.notify(tonumber(id), text, kind) end
    else
        ES.Bridge.notify(target, text, kind)
    end
end

Announce.outputs.discord = function(_, text)
    if ES.Discord then ES.Discord.send('lifecycle', { title = text }) end
end

---Register a custom output (e.g. a phone app). fn(target, text, kind)
function Announce.registerOutput(name, fn) Announce.outputs[name] = fn end

---Server-wide announcement configured under Config.Notifications.global[event].
function Announce.global(event, localeKey, ...)
    local outputs = Config.Notifications.global[event]
    if not outputs then return end
    local text = L(localeKey, ...)
    for _, o in ipairs(outputs) do
        local fn = Announce.outputs[o]
        if fn then pcall(fn, -1, text, 'global') end
    end
end

---Free text announcement (admin) to everyone or a list of players.
function Announce.custom(targets, text, outputs)
    outputs = outputs or { 'nui' }
    if targets == -1 then
        for _, o in ipairs(outputs) do if Announce.outputs[o] then pcall(Announce.outputs[o], -1, text, 'admin') end end
        return
    end
    for _, src in ipairs(targets) do
        for _, o in ipairs(outputs) do
            if o ~= 'discord' and Announce.outputs[o] then pcall(Announce.outputs[o], src, text, 'admin') end
        end
    end
end

return Announce
