-- EVENT STUDIO — spectator framework (follow cam, cycle targets, free cam, admin spectate)
-- The spectator's own ped is hidden, frozen and non-colliding and kept near the target so the target
-- stays inside the streaming/culling range. Target coordinates come from the server (validated RPC).

local S = { active = false, auto = false, targets = {}, index = 1, cam = nil, free = false }
ES.Spectator = S

local function hidePed(hide)
    local ped = PlayerPedId()
    SetEntityVisible(ped, not hide, false)
    SetEntityCollision(ped, not hide, not hide)
    SetEntityInvincible(ped, hide)
    FreezeEntityPosition(ped, hide)
    if hide then SetEntityAlpha(ped, 0, false) else ResetEntityAlpha(ped) end
end

local function current() return S.targets[S.index] end

local function updateNui()
    local t = current()
    ES.NUI.send('spectate', { active = S.active, target = t and t.name or nil, index = S.index, count = #S.targets, free = S.free })
end

function S.refreshTargets()
    local rows = ES.Client.rows or {}
    local list = {}
    local me = GetPlayerServerId(PlayerId())
    for _, r in ipairs(rows) do
        if r.src and r.src ~= me and (r.status == 'active' or r.status == 'finished') then list[#list + 1] = { src = r.src, name = r.name } end
    end
    if #list > 0 then
        local cur = current()
        S.targets = list
        S.index = 1
        if cur then for i, t in ipairs(list) do if t.src == cur.src then S.index = i end end end
        updateNui()
    end
end

local function ensureCam()
    if S.cam and DoesCamExist(S.cam) then return S.cam end
    S.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(S.cam, 60.0)
    RenderScriptCams(true, true, 400, true, false)
    return S.cam
end

local function followLoop()
    CreateThread(function()
        local lastFetch = 0
        local targetPos
        while S.active do
            local t = current()
            local now = GetGameTimer()
            if S.free then
                local cam = ensureCam()
                local c = GetCamCoord(cam)
                local rot = GetCamRot(cam, 2)
                DisableAllControlActions(0)
                EnableControlAction(0, 1, true) EnableControlAction(0, 2, true)
                local speed = IsDisabledControlPressed(0, 21) and 2.5 or 0.8
                local rz, rx = math.rad(rot.z), math.rad(rot.x)
                local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
                local right = vector3(math.cos(rz), math.sin(rz), 0.0)
                if IsDisabledControlPressed(0, 32) then c = c + fwd * speed end
                if IsDisabledControlPressed(0, 33) then c = c - fwd * speed end
                if IsDisabledControlPressed(0, 34) then c = c - right * speed end
                if IsDisabledControlPressed(0, 35) then c = c + right * speed end
                local mx, my = GetDisabledControlNormal(0, 1), GetDisabledControlNormal(0, 2)
                SetCamRot(cam, math.max(-89.0, math.min(89.0, rot.x - my * 6.0)), 0.0, rot.z - mx * 6.0, 2)
                SetCamCoord(cam, c.x, c.y, c.z)
                SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
                Wait(0)
            elseif t then
                if now - lastFetch > 1000 then
                    lastFetch = now
                    ES.rpc('spectate:coords', { target = t.src }, function(ok, res) if ok and res then targetPos = res end end)
                end
                local player = GetPlayerFromServerId(t.src)
                local tPed = player ~= -1 and GetPlayerPed(player) or 0
                if targetPos then
                    local me = PlayerPedId()
                    local mp = GetEntityCoords(me)
                    if #(mp - vector3(targetPos.x, targetPos.y, targetPos.z)) > 60.0 then
                        SetEntityCoordsNoOffset(me, targetPos.x, targetPos.y, targetPos.z - 25.0, false, false, false)
                    end
                end
                local cam = ensureCam()
                if tPed ~= 0 and DoesEntityExist(tPed) then
                    local ent = IsPedInAnyVehicle(tPed, false) and GetVehiclePedIsIn(tPed, false) or tPed
                    local back = IsPedInAnyVehicle(tPed, false) and -8.0 or -4.0
                    AttachCamToEntity(cam, ent, 0.0, back, 2.2, true)
                    PointCamAtEntity(cam, ent, 0.0, 0.0, 0.5, true)
                    SetFocusEntity(ent)
                elseif targetPos then
                    SetCamCoord(cam, targetPos.x, targetPos.y - 6.0, targetPos.z + 4.0)
                    PointCamAtCoord(cam, targetPos.x, targetPos.y, targetPos.z)
                    SetFocusPosAndVel(targetPos.x, targetPos.y, targetPos.z, 0.0, 0.0, 0.0)
                end
                Wait(0)
            else
                Wait(250)
            end
        end
    end)
end

---Start spectating. targets = { {src, name}, ... }
function S.start(targets, auto, center)
    S.targets = targets or {}
    S.index = 1
    S.auto = auto == true
    S.free = #S.targets == 0
    if S.active then updateNui() return end
    S.active = true
    hidePed(true)
    if S.free and center then
        local cam = ensureCam()
        SetCamCoord(cam, center.x, center.y, center.z + 40.0)
        SetCamRot(cam, -45.0, 0.0, 0.0, 2)
    end
    followLoop()
    updateNui()
end

function S.startFromRows()
    S.start({}, true)
    S.refreshTargets()
    S.free = #S.targets == 0
    updateNui()
end

function S.stop(silent)
    if not S.active then return end
    S.active = false
    S.free = false
    if S.cam then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(S.cam, false)
        S.cam = nil
    end
    ClearFocus()
    hidePed(false)
    ES.NUI.send('spectate', { active = false })
end

function S.control(cmd)
    if not S.active then return end
    if cmd == 'next' and #S.targets > 0 then
        S.free = false
        S.index = S.index % #S.targets + 1
    elseif cmd == 'prev' and #S.targets > 0 then
        S.free = false
        S.index = (S.index - 2) % #S.targets + 1
    elseif cmd == 'free' then
        S.free = not S.free
        if S.cam and S.free then DetachCam(S.cam) StopCamPointing(S.cam) end
    elseif cmd == 'stop' then
        ES.rpc('spectate:stop', {})
        return
    end
    updateNui()
end

ES.on('spectate', function(d)
    if d.start then S.start(d.targets, false, d.center) end
end)

-- Keyboard controls while spectating (no NUI focus needed)
CreateThread(function()
    while true do
        if S.active then
            if IsControlJustPressed(0, 174) then S.control('prev') end      -- arrow left
            if IsControlJustPressed(0, 175) then S.control('next') end      -- arrow right
            if IsControlJustPressed(0, 22) and not S.free then S.control('free') end -- space
            if IsControlJustPressed(0, 177) then S.control('stop') end      -- backspace
            Wait(0)
        else
            Wait(500)
        end
    end
end)
