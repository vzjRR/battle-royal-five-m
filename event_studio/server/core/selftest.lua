-- EVENT STUDIO — live-server self test:  eventstudio selftest   (console or admin)
-- Verifies the real environment in ~5 seconds: OneSync, routing buckets, server vehicle spawning,
-- storage read/write, framework adapter, content validity, bucket-range conflicts, permissions, Discord.

local SelfTest = {}
ES.SelfTest = SelfTest

local function row(results, level, name, detail)
    results[#results + 1] = { level = level, name = name, detail = detail }
end

---Run all checks. Must be called from a thread (waits for the vehicle spawn). Returns results list.
function SelfTest.run()
    local r = {}

    -- OneSync
    local onesync = GetConvar('onesync', 'off')
    row(r, onesync ~= 'off' and 'PASS' or 'FAIL', 'OneSync', 'onesync = ' .. onesync)

    -- Routing buckets + server vehicle spawn inside a bucket
    local bucket = ES.Buckets.acquire(-1)
    if not bucket then
        row(r, 'FAIL', 'Routing buckets', 'no free bucket in the configured range')
    else
        row(r, 'PASS', 'Routing buckets', ('allocated bucket %d (range %d-%d)'):format(bucket, Config.General.buckets.from, Config.General.buckets.to))
        local ok, err = pcall(function()
            local veh = CreateVehicleServerSetter(GetHashKey('adder'), 'automobile', 0.0, 0.0, 200.0, 0.0)
            local waited = 0
            while not DoesEntityExist(veh) and waited < 3000 do Wait(50) waited = waited + 50 end
            if not DoesEntityExist(veh) then error('CreateVehicleServerSetter did not create an entity (server artifact too old?)') end
            SetEntityRoutingBucket(veh, bucket)
            local b = GetEntityRoutingBucket(veh)
            DeleteEntity(veh)
            if b ~= bucket then error(('vehicle bucket %s ~= %s'):format(tostring(b), bucket)) end
        end)
        row(r, ok and 'PASS' or 'FAIL', 'Server vehicle spawn', ok and 'created, moved to bucket, deleted' or tostring(err))
        ES.Buckets.release(bucket)
    end

    -- Bucket range conflicts with other resources
    local conflicts = 0
    for _, id in ipairs(GetPlayers()) do
        local b = GetPlayerRoutingBucket(id)
        if b >= Config.General.buckets.from and b <= Config.General.buckets.to and not ES.Manager.ofPlayer(tonumber(id)) then
            conflicts = conflicts + 1
        end
    end
    row(r, conflicts == 0 and 'PASS' or 'WARN', 'Bucket range', conflicts == 0 and 'no players from other resources in the range'
        or (conflicts .. ' player(s) in the event bucket range but not in an event — another resource uses this range'))

    -- Storage round trip
    local ok, err = pcall(function()
        local token = tostring(os.time()) .. math.random(1000, 9999)
        ES.Storage.saveDocument('selftest', 'probe', { token = token }, 'selftest')
        local docs = ES.Storage.loadDocuments('selftest') or {}
        ES.Storage.deleteDocument('selftest', 'probe')
        if not docs.probe or docs.probe.token ~= token then error('read back mismatch') end
    end)
    row(r, ok and 'PASS' or 'FAIL', 'Storage (' .. tostring(ES.Storage.adapter) .. ')', ok and 'write → read → delete OK' or tostring(err))
    if ES.Storage.adapter == 'kvp' and GetResourceState('oxmysql') ~= 'missing' then
        row(r, 'WARN', 'Storage', 'oxmysql exists but KVP is in use — check the ensure order (oxmysql before event_studio)')
    end

    -- Framework adapter
    local fw = ES.Bridge.name
    row(r, 'PASS', 'Framework', ('%s (items: %s)'):format(fw, tostring(ES.Bridge.inventory)))
    local players = GetPlayers()
    if #players > 0 then
        local src = tonumber(players[1])
        local okId, ident = pcall(ES.Bridge.getIdentifier, src)
        local okName, name = pcall(ES.Bridge.getName, src)
        row(r, (okId and okName) and 'PASS' or 'FAIL', 'Framework player lookup',
            (okId and okName) and ('%s → %s'):format(tostring(name), tostring(ident)) or tostring(okId and name or ident))
    else
        row(r, 'WARN', 'Framework player lookup', 'no players online — join the server and run again')
    end
    if fw == 'standalone' then
        row(r, 'WARN', 'Economy', 'standalone mode: cash/bank rewards need a framework or a custom reward type')
    end

    -- Content
    local defs, arenas = ES.Util.count(ES.Definitions.list), ES.Util.count(ES.Arenas.list)
    local failed = #(ES.LoadErrors or {})
    row(r, failed == 0 and 'PASS' or 'WARN', 'Content', ('%d definitions, %d arenas, %d load error(s)%s'):format(defs, arenas, failed,
        failed > 0 and (': ' .. table.concat(ES.LoadErrors, ' | ')):sub(1, 300) or ''))

    -- Permissions
    local staff = 0
    for _, id in ipairs(players) do if ES.Perm.level(tonumber(id)) > 0 then staff = staff + 1 end end
    row(r, staff > 0 and 'PASS' or 'WARN', 'Permissions', staff > 0 and (staff .. ' staff member(s) online')
        or 'no online player has an Event Studio role — add: add_ace group.admin eventstudio.admin allow')

    -- Discord
    local d = Config.Discord
    if d.enabled then
        local n = 0
        for _, url in pairs(d.webhooks) do if url ~= '' then n = n + 1 end end
        row(r, n > 0 and 'PASS' or 'WARN', 'Discord', n .. ' webhook(s) configured')
    else
        row(r, 'PASS', 'Discord', 'disabled')
    end
    return r
end

function SelfTest.report(src, results)
    local colors = { PASS = '^2', WARN = '^3', FAIL = '^1' }
    local fails, warns = 0, 0
    for _, x in ipairs(results) do
        if x.level == 'FAIL' then fails = fails + 1 elseif x.level == 'WARN' then warns = warns + 1 end
        local line = ('%s%-4s^7 %-26s %s'):format(colors[x.level], x.level, x.name, x.detail or '')
        if src == 0 then print(line) else ES.push(src, 'notify', { text = ('%s %s — %s'):format(x.level, x.name, x.detail or ''), kind = x.level == 'FAIL' and 'error' or (x.level == 'WARN' and 'warn' or 'success') }) end
    end
    local summary = ('Event Studio self test: %d fail, %d warn, %d checks'):format(fails, warns, #results)
    if src == 0 then print(summary) else ES.push(src, 'notify', { text = summary, kind = fails > 0 and 'error' or 'success' }) end
    ES.Log.record('audit', 'selftest', src, nil, { fails = fails, warns = warns })
    return fails, warns
end

return SelfTest
