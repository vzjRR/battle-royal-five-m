-- EVENT STUDIO — ctf client rendering (flag markers + blips). All logic is server-side.

local flags, blips, running = nil, {}, false

local function clear()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
end

local function teamRgb(team)
    local cur = ES.Client.current
    local hex = cur and cur.teams and cur.teams[team] and cur.teams[team].color or '#ffffff'
    hex = hex:gsub('#', '')
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

local function refresh()
    clear()
    for _, f in ipairs(flags or {}) do
        local b = AddBlipForCoord(f.x, f.y, f.z)
        SetBlipSprite(b, 38)
        SetBlipColour(b, f.team == 1 and 1 or 3)
        SetBlipScale(b, f.carrier and 1.1 or 0.9)
        blips[#blips + 1] = b
    end
end

local function loop()
    if running then return end
    running = true
    CreateThread(function()
        while flags and ES.Client.current do
            local pos = GetEntityCoords(PlayerPedId())
            local sleep = 500
            for _, f in ipairs(flags) do
                if not f.carrier and #(pos - vector3(f.x, f.y, f.z)) < 150.0 then
                    sleep = 0
                    local r, g, b = teamRgb(f.team)
                    DrawMarker(4, f.x, f.y, f.z + 1.0, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 1.5, r, g, b, 200, true, true, 2, false, nil, nil, false)
                    DrawMarker(1, f.x, f.y, f.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 0.6, r, g, b, 120, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(sleep)
        end
        running = false
        clear()
    end)
end

ES.on('mode', function(d)
    if d.flags then
        flags = d.flags
        refresh()
        loop()
    end
end)

ES.on('left', function() flags = nil clear() end)
