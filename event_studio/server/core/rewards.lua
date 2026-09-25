-- EVENT STUDIO — rewards: resolution from definitions, ledger-guarded payouts, adapters

local U = ES.Util
local Log = ES.Log

local Rewards = { types = {} }
ES.Rewards = Rewards

local function clampAmount(kind, amount)
    local lim = Config.Rewards.limits and Config.Rewards.limits[kind]
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 then amount = 0 end
    if lim and amount > lim then amount = lim end
    return amount
end

local function safeName(s) return (tostring(s or ''):gsub('[^%w_%- ]', '')) end

-- Built-in reward types ---------------------------------------------------

Rewards.types.cash = function(src, e, ctx)
    local amount = clampAmount('cash', e.amount)
    if amount <= 0 then return false end
    return ES.Bridge.addMoney(src, Config.Rewards.accounts.cash or 'cash', amount, ctx.reason)
end

Rewards.types.bank = function(src, e, ctx)
    local amount = clampAmount('bank', e.amount)
    if amount <= 0 then return false end
    return ES.Bridge.addMoney(src, Config.Rewards.accounts.bank or 'bank', amount, ctx.reason)
end

Rewards.types.item = function(src, e)
    local count = math.floor(tonumber(e.count) or 1)
    local lim = Config.Rewards.limits and Config.Rewards.limits.itemCount
    if lim and count > lim then count = lim end
    if count <= 0 or type(e.name) ~= 'string' then return false end
    return ES.Bridge.addItem(src, e.name, count, e.metadata)
end

Rewards.types.xp = function(src, e, ctx)
    local amount = clampAmount('xp', e.amount)
    if type(Config.Rewards.xp) ~= 'function' then return false end
    return Config.Rewards.xp(src, amount, ctx) == true
end

Rewards.types.command = function(src, e, ctx)
    if type(e.command) ~= 'string' then return false end
    local cmd = e.command:gsub('{src}', tostring(src)):gsub('{identifier}', safeName(ctx.identifier)):gsub('{name}', safeName(ctx.name))
    ExecuteCommand(cmd)
    return true
end

Rewards.types.webhook = function(src, e, ctx)
    if type(e.url) ~= 'string' or not e.url:match('^https://') then return false end
    PerformHttpRequest(e.url, function() end, 'POST', json.encode({
        source = src, identifier = ctx.identifier, name = ctx.name, instance = ctx.instanceId,
        definition = ctx.definitionId, placement = ctx.placement, reward = e,
    }), { ['Content-Type'] = 'application/json' })
    return true
end

Rewards.types.none = function() return true end

function Rewards.registerType(name, handler)
    if not U.isId(name) or type(handler) ~= 'function' and type(handler) ~= 'table' then return false end
    Rewards.types[name] = handler
    return true
end

---Pay one reward entry now (no ledger). Returns ok.
function Rewards.pay(src, entry, ctx)
    local handler = Rewards.types[entry.type]
    if not handler then
        Log.warn('Unknown reward type %s', tostring(entry.type))
        return false
    end
    local ok, res = pcall(handler, src, entry, ctx or {})
    if not ok then
        Log.error('Reward %s failed: %s', entry.type, tostring(res))
        return false
    end
    return res ~= false
end

function Rewards.describe(e)
    if e.type == 'cash' or e.type == 'bank' then return ('$%s'):format(tostring(math.floor(e.amount or 0)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')) end
    if e.type == 'item' then return ('%dx %s'):format(e.count or 1, e.label or e.name) end
    if e.type == 'xp' then return ('%d XP'):format(e.amount or 0) end
    return e.label or e.type
end

---Short string for browser cards (1st place reward).
function Rewards.preview(def)
    local r = def.rewards
    local first = r and r.placement and (r.placement[1] or r.placement['1'])
    if not first or #first == 0 then
        if r and r.participation and #r.participation > 0 then return Rewards.describe(r.participation[1]) end
        return nil
    end
    local parts = {}
    for i = 1, math.min(2, #first) do parts[i] = Rewards.describe(first[i]) end
    return table.concat(parts, ' + ')
end

---Rewards for an instance after RESULTS. Idempotent via the storage ledger.
function Rewards.distribute(inst)
    if not Config.Rewards.enabled then return end
    local r = inst.def.rewards
    if not r or not inst.results then return end
    local winnerTeam = inst.teamResults and inst.teamResults[1] and inst.teamResults[1].placement == 1 and inst.teamResults[1].index or nil
    local paidCount = 0

    for _, row in ipairs(inst.results) do
        local eligible = row.everActive and not row.removed and row.status ~= 'disqualified'
            and row.status ~= 'left' and row.status ~= 'disconnected'
        local src = row.src
        if eligible and src and GetPlayerName(tostring(src)) then
            local entries = {}
            local placeList = row.placement and r.placement and (r.placement[row.placement] or r.placement[tostring(row.placement)])
            if placeList then
                for i, e in ipairs(placeList) do entries[#entries + 1] = { kind = 'place', idx = i, e = e } end
            end
            if r.participation then
                local completed = row.status == 'finished' or row.status == 'active' or row.status == 'eliminated'
                if completed or not Config.Rewards.requireCompletionForParticipation then
                    for i, e in ipairs(r.participation) do entries[#entries + 1] = { kind = 'part', idx = i, e = e } end
                end
            end
            if winnerTeam and r.winnerTeam and row.team == winnerTeam then
                for i, e in ipairs(r.winnerTeam) do entries[#entries + 1] = { kind = 'team', idx = i, e = e } end
            end
            local ctx = { reason = ('event:%s:%d'):format(inst.def.id, inst.id), identifier = row.identifier, name = row.name,
                          instanceId = inst.id, definitionId = inst.def.id, placement = row.placement }
            local received = {}
            for _, item in ipairs(entries) do
                local key = ('%d:%s:%s:%d'):format(inst.id, row.identifier, item.kind, item.idx)
                if ES.Storage.claimPayout(key, inst.id, row.identifier, item.e) then
                    local ok = Rewards.pay(src, item.e, ctx)
                    ES.Storage.markPayout(key, ok and 'paid' or 'failed')
                    if ok then
                        paidCount = paidCount + 1
                        received[#received + 1] = Rewards.describe(item.e)
                        TriggerEvent('event_studio:rewarded', inst.id, src, item.e)
                        Log.record('info', 'reward.paid', src, inst.id, { reward = item.e, placement = row.placement })
                    else
                        Log.warn('#%d reward %s for %s failed', inst.id, item.e.type, row.name)
                    end
                else
                    Log.warn('#%d duplicate payout prevented (%s)', inst.id, key)
                end
            end
            if #received > 0 then
                ES.push(src, 'announce', { text = L('reward_received', table.concat(received, ', ')), kind = 'success' })
            end
        end
    end
    Log.debug('#%d rewards distributed (%d entries)', inst.id, paidCount)
end

return Rewards
