-- EVENT STUDIO — storage adapters: oxmysql | kvp | none (memory)
-- Everything persistent goes through ES.Storage. See docs/DATABASE.md.

local Storage = {}
ES.Storage = Storage

local json = json
local Log = ES.Log

----------------------------------------------------------------------------
-- Key/value backends (kvp + memory) — shared repository implementation
----------------------------------------------------------------------------

local function kvpBackend()
    return {
        get = function(key)
            local s = GetResourceKvpString(key)
            if not s or s == '' then return nil end
            local ok, v = pcall(json.decode, s)
            return ok and v or nil
        end,
        set = function(key, value) SetResourceKvp(key, json.encode(value)) end,
        del = function(key) DeleteResourceKvp(key) end,
        keys = function(prefix)
            local out, handle = {}, StartFindKvp(prefix)
            if handle ~= -1 then
                while true do
                    local k = FindKvp(handle)
                    if not k then break end
                    out[#out + 1] = k
                end
                EndFindKvp(handle)
            end
            return out
        end,
    }
end

local function memoryBackend()
    local data = {}
    return {
        get = function(key) return data[key] and ES.Util.deepCopy(data[key]) or nil end,
        set = function(key, value) data[key] = ES.Util.deepCopy(value) end,
        del = function(key) data[key] = nil end,
        keys = function(prefix)
            local out = {}
            for k in pairs(data) do if k:sub(1, #prefix) == prefix then out[#out + 1] = k end end
            return out
        end,
    }
end

local function kvRepository(kv, name)
    local R = { name = name }
    local lbCache = {}

    function R.init() return true end

    function R.loadDocuments(kind)
        local out, prefix = {}, 'doc:' .. kind .. ':'
        for _, key in ipairs(kv.keys(prefix)) do
            local v = kv.get(key)
            if v then out[key:sub(#prefix + 1)] = v end
        end
        return out
    end

    function R.saveDocument(kind, id, data) kv.set('doc:' .. kind .. ':' .. id, data) end
    function R.deleteDocument(kind, id) kv.del('doc:' .. kind .. ':' .. id) end

    function R.recordInstance(summary, results)
        local list = kv.get('instances_recent') or {}
        table.insert(list, 1, { summary = summary, results = results })
        while #list > 100 do table.remove(list) end
        kv.set('instances_recent', list)
    end

    function R.recentInstances(limit)
        local list = kv.get('instances_recent') or {}
        local out = {}
        for i = 1, math.min(limit or 20, #list) do out[i] = list[i].summary end
        return out
    end

    function R.addStats(rows)
        for _, r in ipairs(rows) do
            local key = ('stat:%s:%s:%s'):format(r.season, r.category, r.identifier)
            local cur = kv.get(key) or {
                identifier = r.identifier, season = r.season, category = r.category,
                joined = 0, completed = 0, wins = 0, podiums = 0, kills = 0, deaths = 0,
                objectives = 0, points = 0, best_streak = 0,
            }
            cur.name = r.name
            for _, f in ipairs({ 'joined', 'completed', 'wins', 'podiums', 'kills', 'deaths', 'objectives', 'points' }) do
                cur[f] = (cur[f] or 0) + (r[f] or 0)
            end
            cur.best_streak = math.max(cur.best_streak or 0, r.best_streak or 0)
            cur.updated_at = os.time()
            kv.set(key, cur)
        end
        lbCache = {}
    end

    function R.leaderboard(season, category, limit)
        local ck = season .. '|' .. category
        local cached = lbCache[ck]
        if cached and os.time() - cached.at < (Config.Database.leaderboardCacheSeconds or 60) then
            return cached.rows
        end
        local rows = {}
        for _, key in ipairs(kv.keys(('stat:%s:%s:'):format(season, category))) do
            rows[#rows + 1] = kv.get(key)
        end
        table.sort(rows, function(a, b)
            if a.points ~= b.points then return a.points > b.points end
            return a.wins > b.wins
        end)
        local out = {}
        for i = 1, math.min(limit or 25, #rows) do out[i] = rows[i] end
        lbCache[ck] = { at = os.time(), rows = out }
        return out
    end

    function R.playerStats(identifier, season)
        local out = {}
        for _, key in ipairs(kv.keys(('stat:%s:'):format(season))) do
            if key:sub(-#identifier - 1) == ':' .. identifier then out[#out + 1] = kv.get(key) end
        end
        return out
    end

    function R.submitBest(identifier, name, defId, ms)
        local key = ('pb:%s:%s'):format(defId, identifier)
        local cur = kv.get(key)
        if cur and cur.best_ms <= ms then return false, cur.best_ms end
        kv.set(key, { identifier = identifier, name = name, definition_id = defId, best_ms = ms, achieved_at = os.time() })
        return true, cur and cur.best_ms or nil
    end

    function R.bests(defId, limit)
        local rows = {}
        for _, key in ipairs(kv.keys(('pb:%s:'):format(defId))) do rows[#rows + 1] = kv.get(key) end
        table.sort(rows, function(a, b) return a.best_ms < b.best_ms end)
        local out = {}
        for i = 1, math.min(limit or 10, #rows) do out[i] = rows[i] end
        return out
    end

    -- Single Lua thread: check-and-set with no yield in between is atomic.
    function R.claimPayout(key, instanceId, identifier, reward)
        local k = 'pay:' .. key
        if kv.get(k) then return false end
        kv.set(k, { instance_id = instanceId, identifier = identifier, reward = reward, status = 'claimed', created_at = os.time() })
        return true
    end

    function R.markPayout(key, status)
        local k = 'pay:' .. key
        local cur = kv.get(k)
        if cur then cur.status = status; kv.set(k, cur) end
    end

    function R.log(entry)
        local seq = (kv.get('log_seq') or 0) + 1
        kv.set('log_seq', seq)
        kv.set(('log:%010d'):format(seq), entry)
        local limit = Config.Database.kvpLogLimit or 500
        if seq > limit then kv.del(('log:%010d'):format(seq - limit)) end
    end

    function R.recentLogs(limit, level)
        local keys = kv.keys('log:')
        table.sort(keys, function(a, b) return a > b end)
        local out = {}
        for _, k in ipairs(keys) do
            local e = kv.get(k)
            if e and (not level or e.level == level) then out[#out + 1] = e end
            if #out >= (limit or 100) then break end
        end
        return out
    end

    function R.pruneLogs() end

    return R
end

----------------------------------------------------------------------------
-- oxmysql repository
----------------------------------------------------------------------------

local function sqlRepository()
    local R = { name = 'oxmysql' }
    local ox = exports.oxmysql
    local lbCache = {}

    local function await(fn, sql, params)
        local p = promise.new()
        ox[fn](ox, sql, params or {}, function(res) p:resolve(res) end)
        return Citizen.Await(p)
    end

    local function query(sql, params) return await('query', sql, params) end
    local function execute(sql, params) return await('update', sql, params) end
    local function scalar(sql, params) return await('scalar', sql, params) end

    local function transaction(queries)
        local p = promise.new()
        ox:transaction(queries, function(ok) p:resolve(ok) end)
        return Citizen.Await(p)
    end

    function R.init()
        query('CREATE TABLE IF NOT EXISTS `es_migrations` (`version` INT NOT NULL PRIMARY KEY, `applied_at` INT NOT NULL)')
        if Config.Database.runMigrations == false then return true end
        local applied = {}
        for _, row in ipairs(query('SELECT version FROM es_migrations') or {}) do applied[row.version] = true end
        local version = 1
        while true do
            local file = ('migrations/%03d_'):format(version)
            local content
            -- migration files are named NNN_<name>.sql; we look up the known list in the manifest order
            for _, name in ipairs(Storage.migrationFiles or {}) do
                if name:sub(1, #file) == file then content = LoadResourceFile(ES.name, name) break end
            end
            if not content then break end
            if not applied[version] then
                for stmt in content:gmatch('(.-);%s*\n') do
                    local s = stmt:gsub('%-%-[^\n]*', ''):gsub('^%s+', '')
                    if s ~= '' then execute(s) end
                end
                execute('INSERT INTO es_migrations (version, applied_at) VALUES (?, ?)', { version, os.time() })
                Log.info('Applied migration %03d', version)
            end
            version = version + 1
        end
        return true
    end

    function R.loadDocuments(kind)
        local out = {}
        for _, row in ipairs(query('SELECT id, data FROM es_documents WHERE kind = ?', { kind }) or {}) do
            local ok, v = pcall(json.decode, row.data)
            if ok and v then out[row.id] = v end
        end
        return out
    end

    function R.saveDocument(kind, id, data, actor)
        execute([[INSERT INTO es_documents (kind, id, data, updated_by, updated_at) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by), updated_at = VALUES(updated_at)]],
            { kind, id, json.encode(data), actor, os.time() })
    end

    function R.deleteDocument(kind, id)
        execute('DELETE FROM es_documents WHERE kind = ? AND id = ?', { kind, id })
    end

    function R.recordInstance(s, results)
        local queries = {
            { query = [[INSERT INTO es_instances (id, definition_id, mode, category, final_state, started_at, ended_at,
                participants, winner, tournament_id, summary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE final_state = VALUES(final_state)]],
              values = { s.id, s.definitionId, s.mode, s.category, s.finalState, s.startedAt, s.endedAt,
                         s.participants, s.winner, s.tournamentId, json.encode(s) } },
        }
        for _, r in ipairs(results or {}) do
            queries[#queries + 1] = {
                query = [[INSERT IGNORE INTO es_results (instance_id, identifier, name, team, placement, status, score, points,
                    kills, deaths, objectives, finish_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                values = { s.id, r.identifier, r.name, r.team, r.placement, r.status, r.score, r.points,
                           r.kills, r.deaths, r.objectives, r.finishMs },
            }
        end
        transaction(queries)
    end

    function R.recentInstances(limit)
        local rows = query('SELECT summary FROM es_instances ORDER BY ended_at DESC LIMIT ?', { limit or 20 }) or {}
        local out = {}
        for i, row in ipairs(rows) do
            local ok, v = pcall(json.decode, row.summary)
            out[i] = ok and v or nil
        end
        return out
    end

    function R.addStats(rows)
        local queries = {}
        for _, r in ipairs(rows) do
            queries[#queries + 1] = {
                query = [[INSERT INTO es_player_stats (identifier, season, category, name, joined, completed, wins, podiums,
                    kills, deaths, objectives, points, best_streak, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE name = VALUES(name), joined = joined + VALUES(joined),
                    completed = completed + VALUES(completed), wins = wins + VALUES(wins), podiums = podiums + VALUES(podiums),
                    kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths), objectives = objectives + VALUES(objectives),
                    points = points + VALUES(points), best_streak = GREATEST(best_streak, VALUES(best_streak)),
                    updated_at = VALUES(updated_at)]],
                values = { r.identifier, r.season, r.category, r.name, r.joined or 0, r.completed or 0, r.wins or 0,
                           r.podiums or 0, r.kills or 0, r.deaths or 0, r.objectives or 0, r.points or 0,
                           r.best_streak or 0, os.time() },
            }
        end
        if #queries > 0 then transaction(queries) end
        lbCache = {}
    end

    function R.leaderboard(season, category, limit)
        local ck = season .. '|' .. category .. '|' .. (limit or 25)
        local c = lbCache[ck]
        if c and os.time() - c.at < (Config.Database.leaderboardCacheSeconds or 60) then return c.rows end
        local rows = query([[SELECT identifier, name, joined, completed, wins, podiums, kills, deaths, objectives, points, best_streak
            FROM es_player_stats WHERE season = ? AND category = ? ORDER BY points DESC, wins DESC LIMIT ?]],
            { season, category, limit or 25 }) or {}
        lbCache[ck] = { at = os.time(), rows = rows }
        return rows
    end

    function R.playerStats(identifier, season)
        return query('SELECT * FROM es_player_stats WHERE identifier = ? AND season = ?', { identifier, season }) or {}
    end

    function R.submitBest(identifier, name, defId, ms)
        local cur = scalar('SELECT best_ms FROM es_personal_bests WHERE identifier = ? AND definition_id = ?', { identifier, defId })
        if cur and cur <= ms then return false, cur end
        execute([[INSERT INTO es_personal_bests (identifier, definition_id, name, best_ms, achieved_at) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE name = VALUES(name), best_ms = VALUES(best_ms), achieved_at = VALUES(achieved_at)]],
            { identifier, defId, name, ms, os.time() })
        return true, cur
    end

    function R.bests(defId, limit)
        return query('SELECT identifier, name, best_ms, achieved_at FROM es_personal_bests WHERE definition_id = ? ORDER BY best_ms ASC LIMIT ?',
            { defId, limit or 10 }) or {}
    end

    function R.claimPayout(key, instanceId, identifier, reward)
        local affected = execute([[INSERT IGNORE INTO es_payouts (ledger_key, instance_id, identifier, reward, status, created_at)
            VALUES (?, ?, ?, ?, 'claimed', ?)]], { key, instanceId, identifier, json.encode(reward), os.time() })
        return (affected or 0) > 0
    end

    function R.markPayout(key, status)
        execute('UPDATE es_payouts SET status = ? WHERE ledger_key = ?', { status, key })
    end

    function R.log(e)
        -- fire-and-forget; do not await in hot paths
        ox:insert('INSERT INTO es_logs (created_at, level, action, actor, instance_id, data) VALUES (?, ?, ?, ?, ?, ?)',
            { e.created_at, e.level, e.action, e.actor, e.instance_id, e.data and json.encode(e.data) or nil })
    end

    function R.recentLogs(limit, level)
        local rows
        if level then
            rows = query('SELECT * FROM es_logs WHERE level = ? ORDER BY id DESC LIMIT ?', { level, limit or 100 })
        else
            rows = query('SELECT * FROM es_logs ORDER BY id DESC LIMIT ?', { limit or 100 })
        end
        for _, r in ipairs(rows or {}) do
            if type(r.data) == 'string' then
                local ok, v = pcall(json.decode, r.data)
                r.data = ok and v or r.data
            end
        end
        return rows or {}
    end

    function R.pruneLogs()
        local days = Config.Database.logRetentionDays or 30
        execute('DELETE FROM es_logs WHERE created_at < ?', { os.time() - days * 86400 })
    end

    return R
end

----------------------------------------------------------------------------
-- Selection
----------------------------------------------------------------------------

Storage.migrationFiles = { 'migrations/001_initial.sql' }

local repo
local kvpAlways -- crash-recovery + sequence always use KVP (or memory in tests)

function Storage.init()
    local adapter = Config.Database.adapter or 'auto'
    if adapter == 'auto' then
        adapter = GetResourceState('oxmysql') == 'started' and 'oxmysql' or 'kvp'
    end
    if adapter == 'oxmysql' and GetResourceState('oxmysql') ~= 'started' then
        Log.warn('Database adapter oxmysql requested but oxmysql is not started. Falling back to kvp.')
        adapter = 'kvp'
    end
    kvpAlways = (GetResourceKvpString ~= nil) and kvpBackend() or memoryBackend()
    if adapter == 'oxmysql' then
        repo = sqlRepository()
    elseif adapter == 'kvp' then
        repo = kvRepository(kvpAlways, 'kvp')
    else
        repo = kvRepository(memoryBackend(), 'none')
    end
    local ok, err = pcall(repo.init)
    if not ok then
        Log.error('Storage init failed (%s): %s — falling back to memory', repo.name, tostring(err))
        repo = kvRepository(memoryBackend(), 'none')
    end
    pcall(repo.pruneLogs)
    Storage.adapter = repo.name
    Log.info('Storage adapter: %s', repo.name)
    return repo.name
end

-- Forward repository methods.
for _, fn in ipairs({ 'loadDocuments', 'saveDocument', 'deleteDocument', 'recordInstance', 'recentInstances',
    'addStats', 'leaderboard', 'playerStats', 'submitBest', 'bests', 'claimPayout', 'markPayout', 'log', 'recentLogs' }) do
    Storage[fn] = function(...)
        if not repo then return nil end
        return repo[fn](...)
    end
end

-- Crash-recovery return points & sequence (always local KVP, never SQL).
function Storage.setReturnPoint(identifier, point) kvpAlways.set('ret:' .. identifier, point) end
function Storage.getReturnPoint(identifier) return kvpAlways.get('ret:' .. identifier) end
function Storage.clearReturnPoint(identifier) kvpAlways.del('ret:' .. identifier) end

function Storage.nextInstanceId()
    local seq = (kvpAlways.get('instance_seq') or 1000) + 1
    kvpAlways.set('instance_seq', seq)
    return seq
end

-- Exposed for tests
Storage._kvRepository = kvRepository
Storage._memoryBackend = memoryBackend

return Storage
