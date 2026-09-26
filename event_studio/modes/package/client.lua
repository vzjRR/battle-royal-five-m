-- EVENT STUDIO — package mode client rendering (markers + blips). All logic is server-side.

local packages, blips, running = nil, {}, false

local function clear()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
end

local function refresh()
    clear()
    for _, p in ipairs(packages or {}) do
        local b = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(b, 478)
        SetBlipColour(b, p.carrier and 1 or 5)
        SetBlipScale(b, 0.9)
        blips[#blips + 1] = b
    end
end

local function loop()
    if running then return end
    running = true
    CreateThread(function()
        while packages and ES.Client.current do
            local pos = GetEntityCoords(PlayerPedId())
            local sleep = 500
            for _, p in ipairs(packages) do
                if not p.carrier and #(pos - vector3(p.x, p.y, p.z)) < 120.0 then
                    sleep = 0
                    DrawMarker(2, p.x, p.y, p.z + 0.8, 0, 0, 0, 0, 180.0, 0, 0.6, 0.6, 0.6, 255, 210, 60, 220, true, true, 2, false, nil, nil, false)
                    DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 0.5, 255, 210, 60, 110, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(sleep)
        end
        running = false
        clear()
    end)
end

ES.on('mode', function(d)
    if d.packages then
        packages = d.packages
        refresh()
        loop()
    end
end)

ES.on('left', function() packages = nil clear() end)
