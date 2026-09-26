-- EVENT STUDIO — server console / admin command: /eventstudio <sub> ...
-- Player-facing commands (/events, /eventjoin ...) are client commands routed through RPCs.

local Log = ES.Log

local function reply(src, msg)
    if src == 0 then print('[event_studio] ' .. msg) else ES.push(src, 'notify', { text = msg, kind = 'info' }) end
end

local subs = {}

subs.list = function(src)
    local any = false
    for _, i in ipairs(ES.Manager.list()) do
        any = true
        reply(src, ('#%d %s [%s] %s players=%d bucket=%s'):format(i.id, i.def.name, i.def.mode, i.state,
            i:participantCount({ registered = true, active = true }), tostring(i.bucket)))
    end
    if not any then reply(src, 'No events running.') end
end

subs.defs = function(src)
    for _, d in ipairs(ES.Definitions.all()) do
        reply(src, ('%s — %s (%s)%s'):format(d.id, d.name, d.mode, d.enabled and '' or ' [disabled]'))
    end
end

subs.create = function(src, args)
    if not ES.Perm.can(src, 'instance.create') then return reply(src, 'No permission.') end
    local ok, id = ES.Manager.create(args[1] or '', { registration = tonumber(args[2]), createdBy = src, allowDraft = true })
    reply(src, ok and ('Created #' .. id) or ('Failed: ' .. tostring(id)))
    if ok then Log.audit('instance.created', src, id, { definition = args[1] }) end
end

subs.start = function(src, args)
    if not ES.Perm.can(src, 'instance.start') then return reply(src, 'No permission.') end
    local i = ES.Manager.get(args[1])
    if not i then return reply(src, 'Not found.') end
    local ok, err = i:start(args[2] == 'force')
    reply(src, ok and 'Started.' or ('Failed: ' .. tostring(err)))
end

subs.cancel = function(src, args)
    if not ES.Perm.can(src, 'instance.cancel') then return reply(src, 'No permission.') end
    local i = ES.Manager.get(args[1])
    if not i then return reply(src, 'Not found.') end
    local ok, err = i:cancel('admin')
    reply(src, ok and 'Cancelled.' or ('Failed: ' .. tostring(err)))
    if ok then Log.audit('instance.cancel', src, i.id) end
end

subs.stop = function(src, args)
    if not ES.Perm.can(src, 'instance.stop') then return reply(src, 'No permission.') end
    local i = ES.Manager.get(args[1])
    if not i then return reply(src, 'Not found.') end
    local ok, err = i:finishNow('admin')
    reply(src, ok and 'Finishing.' or ('Failed: ' .. tostring(err)))
end

subs.director = function(src, args)
    if not ES.Perm.can(src, 'director.toggle') then return reply(src, 'No permission.') end
    ES.Director.setEnabled(args[1] == 'on')
    reply(src, 'Director ' .. (ES.Director.enabled and 'enabled' or 'disabled'))
end

subs.selftest = function(src)
    if not ES.Perm.can(src, 'debug') then return reply(src, 'No permission.') end
    Citizen.CreateThread(function() ES.SelfTest.report(src, ES.SelfTest.run()) end)
end

---Console only: what the server sees for a player's permissions (identifiers, ACE per role, framework groups).
subs.perms = function(src, args)
    if src ~= 0 then return reply(src, 'Run this in the server console.') end
    local targets = {}
    if args[1] then targets[1] = tonumber(args[1]) else
        for _, id in ipairs(GetPlayers()) do targets[#targets + 1] = tonumber(id) end
    end
    if #targets == 0 then return reply(src, 'No players online.') end
    for _, id in ipairs(targets) do
        if not GetPlayerName(tostring(id)) then
            reply(src, ('Player %s is not online.'):format(tostring(id)))
        else
            ES.Perm.clear(id)
            local level, role = ES.Perm.level(id)
            reply(src, ('[%d] %s → role: %s (level %d)'):format(id, GetPlayerName(tostring(id)), tostring(role or 'none'), level))
            local ids = {}
            for _, ident in ipairs(GetPlayerIdentifiers(tostring(id)) or {}) do
                if not ident:find('^ip:') then ids[#ids + 1] = ident end
            end
            reply(src, '    identifiers: ' .. table.concat(ids, '  '))
            local aces = {}
            for r in pairs(Config.Permissions.roles) do
                aces[#aces + 1] = ('%s=%s'):format(r, IsPlayerAceAllowed(tostring(id), (Config.Permissions.acePrefix or 'eventstudio.') .. r) and 'yes' or 'no')
            end
            table.sort(aces)
            local groups = {}
            for g in pairs(ES.Bridge.getGroups(id) or {}) do groups[#groups + 1] = g end
            reply(src, ('    ACE: %s | %s groups: %s'):format(table.concat(aces, ' '), ES.Bridge.name, #groups > 0 and table.concat(groups, ', ') or 'none'))
            if level <= 0 then
                local license
                for _, ident in ipairs(ids) do if ident:find('^license:') then license = ident end end
                if license then
                    reply(src, ('    grant admin (add to server.cfg too): add_ace identifier.%s eventstudio.admin allow'):format(license))
                end
            end
        end
    end
end

subs.status = function(src)
    reply(src, ('Event Studio %s | framework=%s items=%s storage=%s | instances=%d buckets=%d | director=%s'):format(
        ES.version, ES.Bridge.name, tostring(ES.Bridge.inventory), tostring(ES.Storage.adapter),
        ES.Util.count(ES.Manager.instances), ES.Buckets.inUse(), tostring(ES.Director.enabled)))
end

RegisterCommand('eventstudio', function(src, args)
    local sub = table.remove(args, 1) or 'status'
    if src ~= 0 and ES.Perm.level(src) <= 0 then return end
    local fn = subs[sub]
    if not fn then return reply(src, 'Usage: eventstudio status|selftest|perms [playerId]|list|defs|create <def> [regSeconds]|start <id> [force]|stop <id>|cancel <id>|director on|off') end
    fn(src, args)
end, true) -- restricted: server console always; in game only with `add_ace group.admin command.eventstudio allow`
