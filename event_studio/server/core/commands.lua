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

subs.status = function(src)
    reply(src, ('Event Studio %s | framework=%s items=%s storage=%s | instances=%d buckets=%d | director=%s'):format(
        ES.version, ES.Bridge.name, tostring(ES.Bridge.inventory), tostring(ES.Storage.adapter),
        ES.Util.count(ES.Manager.instances), ES.Buckets.inUse(), tostring(ES.Director.enabled)))
end

RegisterCommand('eventstudio', function(src, args)
    local sub = table.remove(args, 1) or 'status'
    if src ~= 0 and ES.Perm.level(src) <= 0 then return end
    local fn = subs[sub]
    if not fn then return reply(src, 'Usage: eventstudio status|list|defs|create <def> [regSeconds]|start <id> [force]|stop <id>|cancel <id>|director on|off') end
    fn(src, args)
end, false)
