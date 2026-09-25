-- EVENT STUDIO — optional Discord webhooks (queued, rate limited)

local Discord = { queues = {}, running = false }
ES.Discord = Discord

local colors = { lifecycle = 3447003, results = 16766720, players = 9807270, admin = 10181046, security = 15158332 }

local function cfg() return Config.Discord end

local function urlFor(channel)
    local c = cfg()
    if not c or not c.enabled then return nil end
    local url = c.webhooks[channel]
    if not url or url == '' then return nil end
    return url
end

local function worker()
    if Discord.running then return end
    Discord.running = true
    Citizen.CreateThread(function()
        while true do
            local sent = false
            for channel, q in pairs(Discord.queues) do
                if #q > 0 then
                    local payload = table.remove(q, 1)
                    local url = urlFor(channel)
                    if url then
                        PerformHttpRequest(url, function(status)
                            if status and status >= 400 and status ~= 429 then
                                print(('[event_studio] discord webhook %s returned %s'):format(channel, status))
                            end
                        end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
                    end
                    sent = true
                end
            end
            if not sent then break end
            Wait(cfg().minIntervalMs or 1200)
        end
        Discord.running = false
    end)
end

---Queue an embed. embed = { title, description, fields = { {name, value, inline} } }
function Discord.send(channel, embed)
    if not urlFor(channel) then return end
    local c = cfg()
    Discord.queues[channel] = Discord.queues[channel] or {}
    local q = Discord.queues[channel]
    if #q > 50 then return end -- drop floods
    q[#q + 1] = {
        username = c.username, avatar_url = c.avatar,
        embeds = { {
            title = embed.title, description = embed.description, color = embed.color or colors[channel],
            fields = embed.fields, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = { text = 'Event Studio ' .. ES.version },
        } },
    }
    worker()
end

---Route a log record to a webhook according to Config.Discord.routes.
function Discord.route(level, action, entry)
    local c = cfg()
    if not c or not c.enabled then return end
    local channel = c.routes[action] or c.routes[level]
    if not channel then return end
    local fields = {}
    if entry.actor then fields[#fields + 1] = { name = 'Actor', value = tostring(entry.actor), inline = true } end
    if entry.instance_id then fields[#fields + 1] = { name = 'Instance', value = '#' .. tostring(entry.instance_id), inline = true } end
    if entry.data then
        local ok, s = pcall(json.encode, entry.data)
        if ok and s and #s > 2 then fields[#fields + 1] = { name = 'Data', value = '```json\n' .. s:sub(1, 900) .. '\n```' } end
    end
    Discord.send(channel, { title = ('%s · %s'):format(level, action), fields = fields })
end

return Discord
