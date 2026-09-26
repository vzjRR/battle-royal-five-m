-- EVENT STUDIO — client component: checkpoints (markers, blips, route, enter intent)

local C = { data = nil, blips = {}, thread = false, pending = false }

local function clearBlips()
    for _, b in ipairs(C.blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    C.blips = {}
end

local function groundZ(pt)
    if pt.gz then return pt.gz end
    local found, z = GetGroundZFor_3dCoord(pt.x, pt.y, pt.z + 5.0, false)
    pt.gz = found and z or pt.z
    return pt.gz
end

local function refreshBlips()
    clearBlips()
    local d = C.data
    if not d or d.hidden or not d.points then return end
    local personal = d.personal or {}
    if d.ordered then
        for k = 0, (d.nextCount or 2) - 1 do
            local idx = (personal.next or 1) + k
            if d.laps and personal.lap and personal.lap < d.laps and idx > #d.points then idx = idx - #d.points end
            local pt = d.points[idx]
            if pt and pt.x then
                local b = AddBlipForCoord(pt.x, pt.y, pt.z)
                SetBlipSprite(b, 1)
                SetBlipColour(b, k == 0 and 5 or 0)
                SetBlipScale(b, k == 0 and 1.0 or 0.7)
                ShowNumberOnBlip(b, idx)
                if k == 0 then SetBlipRoute(b, true) SetBlipRouteColour(b, 5) end
                C.blips[#C.blips + 1] = b
            end
        end
    else
        local visited = {}
        for _, v in ipairs(personal.visited or {}) do visited[v] = true end
        for i, pt in ipairs(d.points) do
            if pt.x and not visited[i] then
                local b = AddBlipForCoord(pt.x, pt.y, pt.z)
                SetBlipSprite(b, 161)
                SetBlipColour(b, 27)
                SetBlipScale(b, 0.8)
                C.blips[#C.blips + 1] = b
            end
        end
    end
end

local function markerLoop()
    if C.thread then return end
    C.thread = true
    CreateThread(function()
        local drawDist = (ES.Config.UI and ES.Config.UI.markers and ES.Config.UI.markers.drawDistance) or 250.0
        while C.data do
            local d = C.data
            local sleep = 500
            local st = ES.Client.current and ES.Client.current.state
            if not d.hidden and d.points and (st == 'ACTIVE' or st == 'FINISHING' or st == 'COUNTDOWN' or st == 'LOBBY') then
                local ped = PlayerPedId()
                local pos = GetEntityCoords(ped)
                local personal = d.personal or {}
                local targets = {}
                if d.ordered then
                    if not personal.done then targets[1] = personal.next or 1 end
                else
                    local visited = {}
                    for _, v in ipairs(personal.visited or {}) do visited[v] = true end
                    for i = 1, #d.points do if not visited[i] then targets[#targets + 1] = i end end
                end
                for _, idx in ipairs(targets) do
                    local pt = d.points[idx]
                    if pt and pt.x then
                        local dist = #(pos - vector3(pt.x, pt.y, pt.z))
                        if dist < drawDist then
                            sleep = 0
                            local z = d.use3d and pt.z or groundZ(pt)
                            local r = pt.radius or 10.0
                            if d.use3d then
                                DrawMarker(6, pt.x, pt.y, pt.z, 0, 0, 0, 0, 0, 0, r * 2, r * 2, r * 2, 255, 210, 60, 110, false, false, 2, false, nil, nil, false)
                            else
                                DrawMarker(1, pt.x, pt.y, z - 1.0, 0, 0, 0, 0, 0, 0, r * 2, r * 2, 6.0, 255, 210, 60, 90, false, false, 2, false, nil, nil, false)
                            end
                            local planar = d.use3d and dist or #(vector2(pos.x, pos.y) - vector2(pt.x, pt.y))
                            if not d.serverDetect and st ~= 'COUNTDOWN' and st ~= 'LOBBY' and planar <= r and not C.pending then
                                C.pending = true
                                ES.rpc('event:action', { action = 'checkpoint', data = { index = idx } }, function(ok, res)
                                    C.pending = false
                                    if ok and type(res) == 'table' and C.data then
                                        C.data.personal = res
                                        refreshBlips()
                                        PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end
        C.thread = false
    end)
end

ES.RegisterClientComponent('checkpoints', {
    setup = function(data)
        C.data = data
        C.pending = false
        refreshBlips()
        markerLoop()
        ES.NUI.send('checkpoints', { personal = data.personal, points = data.hidden and data.points or nil, allowReset = data.allowReset })
    end,
    update = function(personal)
        if not C.data then return end
        C.data.personal = personal
        refreshBlips()
        ES.NUI.send('checkpoints', { personal = personal })
    end,
    clear = function()
        C.data = nil
        clearBlips()
    end,
})

-- Reset to last checkpoint (races)
local function reset()
    if not C.data or C.data.allowReset == false then return end
    ES.rpc('event:action', { action = 'reset', data = {} })
end
ES.resetToCheckpoint = reset   -- bound to the player's reset key in client/main.lua
