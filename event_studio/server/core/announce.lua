-- EVENT STUDIO — announcements via adapters: nui | chat | notify | discord

local Announce = { outputs = {} }
ES.Announce = Announce

-- `msg` (optional) is { lkey, largs } from ES.msg: each player then sees the text in their own language.

---Text for one player: their language when the message is translatable, otherwise the text as given.
local function textFor(src, text, msg)
    if not msg or not msg.lkey then return text end
    return ES.msg(ES.PlayerLocales and ES.PlayerLocales[src], msg.lkey, table.unpack(msg.largs or {}, 1, msg.n or #(msg.largs or {}))).text
end

local function eachTarget(target, fn)
    if target == -1 then
        for _, id in ipairs(GetPlayers()) do fn(tonumber(id)) end
    else
        fn(target)
    end
end

Announce.outputs.nui = function(target, text, kind, msg)
    -- one event for everyone: the client translates lkey / largs into the player's language itself
    TriggerClientEvent('es:push', target, 'announce', { text = text, kind = kind or 'global', lkey = msg and msg.lkey, largs = msg and msg.largs })
end

Announce.outputs.chat = function(target, text, _, msg)
    if GetResourceState('chat') ~= 'started' then return end
    eachTarget(target, function(src)
        TriggerClientEvent('chat:addMessage', src, { args = { Config.Notifications.chatPrefix or '[Events]', textFor(src, text, msg) } })
    end)
end

Announce.outputs.notify = function(target, text, kind, msg)
    eachTarget(target, function(src) ES.Bridge.notify(src, textFor(src, text, msg), kind) end)
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
    local m = ES.msg(nil, localeKey, ...)
    local msg = { lkey = m.lkey, largs = m.largs, n = select('#', ...) }
    for _, o in ipairs(outputs) do
        local fn = Announce.outputs[o]
        if fn then pcall(fn, -1, m.text, 'global', msg) end
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
