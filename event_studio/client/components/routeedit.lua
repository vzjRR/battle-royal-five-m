-- EVENT STUDIO — route editing helpers for staff (Admin Center → Arenas):
--   * record a route by driving / sailing / running it (checkpoints dropped by distance and at turns)
--   * build a road route from the map waypoint (GPS)
--   * preview an arena's points in the world while editing
--   * teleport to a point, generate a start grid behind you
-- Every action first asks the server for the admin's position (permission 'arena.edit'), so players cannot use them.

local rec = nil       -- active recording
local preview = nil   -- points being previewed

local function allowed(cb)
    ES.rpc('admin:position', {}, function(ok, pos) cb(ok, pos) end)
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function here()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local e = veh ~= 0 and veh or ped
    local c = GetEntityCoords(e)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = GetEntityHeading(e) }
end

local function round(p)
    return { x = math.floor(p.x * 100 + 0.5) / 100, y = math.floor(p.y * 100 + 0.5) / 100, z = math.floor(p.z * 100 + 0.5) / 100,
             w = p.w and math.floor(p.w * 10 + 0.5) / 10 or nil }
end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function angleDiff(a, b) return math.abs((a - b + 180) % 360 - 180) end

local function addRecorded(p)
    rec.points[#rec.points + 1] = round(p)
    rec.last = p
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', false)
end

local function finishRecording(cancelled)
    if not rec then return end
    local r = rec
    rec = nil
    if not cancelled then
        local final = here()
        if dist(final, r.last) > 8.0 then r.points[#r.points + 1] = round(final) end
    end
    ES.NUI.send('arenaRecorded', { cancelled = cancelled == true, points = r.points, target = r.target })
    ES.NUI.send('toast', { text = cancelled and 'Route recording cancelled.' or ('Route recorded: %d checkpoints. Open /event → Arenas to review and save.'):format(#r.points),
        kind = cancelled and 'warn' or 'success' })
end

local function recordLoop()
    CreateThread(function()
        while rec do
            local p = here()
            local d = dist(p, rec.last)
            -- a checkpoint every `spacing` metres, or earlier on a clear turn
            if d >= rec.spacing or (d >= rec.spacing * 0.35 and angleDiff(p.w, rec.last.w) >= 40.0) then addRecorded(p) end
            help(('~b~Recording route~s~: %d checkpoints · ~INPUT_DETONATE~ add one now · ~INPUT_REPLAY_START_STOP_RECORDING_SECONDARY~ finish'):format(#rec.points))
            for i, cp in ipairs(rec.points) do
                if dist(p, cp) < 300.0 then
                    DrawMarker(1, cp.x, cp.y, cp.z - 1.0, 0, 0, 0, 0, 0, 0, 3.0, 3.0, 1.2, 212, 178, 106, 140, false, false, 2, false, nil, nil, false)
                    if i > 1 then local q = rec.points[i - 1] DrawLine(q.x, q.y, q.z + 0.5, cp.x, cp.y, cp.z + 0.5, 212, 178, 106, 200) end
                end
            end
            if IsControlJustPressed(0, 47) then addRecorded(p) end            -- G
            if IsControlJustPressed(0, 289) then finishRecording(false) end   -- F2
            Wait(0)
        end
    end)
end

RegisterNUICallback('route:record', function(data, cb)
    cb({ ok = true })
    allowed(function(ok)
        if not ok then return ES.NUI.send('toast', { text = 'No permission.', kind = 'error' }) end
        local spacing = tonumber(data and data.spacing) or 80.0
        spacing = math.max(10.0, math.min(400.0, spacing))
        local start = here()
        rec = { points = {}, spacing = spacing, last = start, target = data and data.target }
        addRecorded(start)
        ES.NUI.panelOpen = false
        ES.NUI.setFocus(false)
        ES.NUI.send('close', {})
        recordLoop()
    end)
end)

RegisterNUICallback('route:cancel', function(_, cb) finishRecording(true) cb({ ok = true }) end)

-- Road route from the waypoint on the map, sampled along the game's GPS line.
RegisterNUICallback('route:fromWaypoint', function(data, cb)
    allowed(function(ok)
        if not ok then return cb({ ok = false, res = 'forbidden' }) end
        if not IsWaypointActive() then return cb({ ok = false, res = 'no_waypoint' }) end
        local spacing = math.max(20.0, math.min(400.0, tonumber(data and data.spacing) or 120.0))
        local points = { round(here()) }
        local okLen, length = pcall(GetGpsBlipRouteLength)
        if not okLen or not length or length <= 0 then return cb({ ok = false, res = 'no_gps' }) end
        local d = spacing
        while d < length and #points < 200 do
            local okPos, found, pos = pcall(GetPosAlongGpsTypeRoute, true, d + 0.0, 0)
            if not okPos or not found or not pos then break end
            points[#points + 1] = round({ x = pos.x, y = pos.y, z = pos.z })
            d = d + spacing
        end
        local wp = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
        points[#points + 1] = round({ x = wp.x, y = wp.y, z = points[#points].z })
        if #points < 3 then return cb({ ok = false, res = 'no_gps' }) end
        cb({ ok = true, res = points })
    end)
end)

-- A start grid of `count` places behind the admin, two abreast.
RegisterNUICallback('route:grid', function(data, cb)
    allowed(function(ok)
        if not ok then return cb({ ok = false, res = 'forbidden' }) end
        local p = here()
        local count = math.max(2, math.min(32, tonumber(data and data.count) or 8))
        local h = math.rad(p.w)
        local fwd = { x = -math.sin(h), y = math.cos(h) }
        local right = { x = math.cos(h), y = math.sin(h) }
        local out = {}
        for i = 0, count - 1 do
            local row, side = math.floor(i / 2), (i % 2 == 0) and -1 or 1
            local x = p.x - fwd.x * (row * 7.0) + right.x * side * 2.6
            local y = p.y - fwd.y * (row * 7.0) + right.y * side * 2.6
            local found, gz = GetGroundZFor_3dCoord(x, y, p.z + 5.0, false)
            out[#out + 1] = round({ x = x, y = y, z = (found and gz or p.z) + 0.5, w = p.w })
        end
        cb({ ok = true, res = out })
    end)
end)

RegisterNUICallback('route:teleport', function(data, cb)
    allowed(function(ok)
        if not ok or type(data) ~= 'table' or not tonumber(data.x) then return cb({ ok = false }) end
        local ped = PlayerPedId()
        RequestCollisionAtCoord(data.x + 0.0, data.y + 0.0, data.z + 0.0)
        SetEntityCoordsNoOffset(ped, data.x + 0.0, data.y + 0.0, (tonumber(data.z) or 0.0) + 1.0, false, false, false)
        cb({ ok = true })
    end)
end)

-- Preview: markers, route line and numbered blips for the arena being edited.
local previewBlips = {}
local function clearPreview()
    for _, b in ipairs(previewBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    previewBlips = {}
    preview = nil
end

local colors = { checkpoints = { 212, 178, 106 }, spawns = { 123, 227, 166 }, vehicleSpawns = { 95, 212, 224 }, zones = { 255, 143, 163 },
    targets = { 195, 107, 255 }, objectives = { 246, 198, 107 }, spectator = { 180, 180, 180 } }

RegisterNUICallback('route:preview', function(data, cb)
    clearPreview()
    if type(data) ~= 'table' or type(data.lists) ~= 'table' then return cb({ ok = true }) end
    allowed(function(ok)
        if not ok then return cb({ ok = false }) end
        preview = data.lists
        for key, list in pairs(preview) do
            for i, p in ipairs(list) do
                local b = AddBlipForCoord(p.x + 0.0, p.y + 0.0, p.z + 0.0)
                SetBlipSprite(b, key == 'checkpoints' and 1 or 318)
                SetBlipScale(b, 0.7)
                if key == 'checkpoints' then ShowNumberOnBlip(b, i) end
                previewBlips[#previewBlips + 1] = b
            end
        end
        CreateThread(function()
            while preview do
                local me = here()
                for key, list in pairs(preview) do
                    local c = colors[key] or { 255, 255, 255 }
                    for i, p in ipairs(list) do
                        if dist(me, p) < 400.0 then
                            local r = tonumber(p.radius) or (key == 'checkpoints' and 8.0 or 1.5)
                            DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, r * 2.0, r * 2.0, 1.0, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
                            if key == 'checkpoints' and i > 1 then
                                local q = list[i - 1]
                                DrawLine(q.x, q.y, q.z + 1.0, p.x, p.y, p.z + 1.0, c[1], c[2], c[3], 220)
                            end
                        end
                    end
                end
                Wait(0)
            end
        end)
        cb({ ok = true })
    end)
end)

RegisterNUICallback('route:previewStop', function(_, cb) clearPreview() cb({ ok = true }) end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clearPreview() rec = nil end
end)
