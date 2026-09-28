-- EVENT STUDIO — redlight client: green / red lights over the track, the tower shot, walking only.
-- Drawing only; the server decides who moved and who is out.

local R = nil          -- { light, tower, start, finish, walkOnly, poles }
local running = false
local SNIPER = GetHashKey('WEAPON_SNIPERRIFLE')

local COLORS = { green = { 30, 255, 110 }, red = { 255, 30, 45 } }

---Light poles every ~20 m from the start line to the finish, 7 m above the ground.
local function poles(s, f)
    local out = {}
    if not (s and f) then return out end
    local dx, dy = f.x - s.x, f.y - s.y
    local len = math.sqrt(dx * dx + dy * dy)
    local n = math.max(1, math.floor(len / 20.0))
    for i = 0, n do
        local t = i / n
        out[#out + 1] = vector3(s.x + dx * t, s.y + dy * t, s.z + (f.z - s.z) * t + 7.0)
    end
    return out
end

local function loop()
    if running then return end
    running = true
    CreateThread(function()
        while R and ES.Client.current do
            local c = COLORS[R.light or 'red'] or COLORS.red
            for _, p in ipairs(R.poles) do
                DrawLightWithRangeAndShadow(p.x, p.y, p.z, c[1], c[2], c[3], 26.0, 7.0, 12.0)
            end
            if R.tower then
                local t = R.tower
                DrawLightWithRangeAndShadow(t.x, t.y, t.z, c[1], c[2], c[3], 70.0, 12.0, 20.0)
                DrawMarker(28, t.x, t.y, t.z, 0, 0, 0, 0, 0, 0, 1.6, 1.6, 1.6, c[1], c[2], c[3], 230, false, false, 2, false, nil, nil, false)
            end
            if R.walkOnly then
                DisableControlAction(0, 21, true)   -- sprint
                DisableControlAction(0, 22, true)   -- jump
            end
            Wait(0)
        end
        running = false
    end)
end

local function revive()
    local ped = PlayerPedId()
    if not IsEntityDead(ped) then return end
    local c = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    local b = ES.ClientBridge
    if b and b.revive then pcall(b.revive) end   -- clears the ambulance script's death screen
end

---The tower fires at `src`. The target's own client makes the lethal shot; everyone else sees and hears a tracer.
local function shot(d)
    if not d or not d.from then return end
    local me = GetPlayerServerId(PlayerId())
    local target = GetPlayerFromServerId(d.src)
    if target == -1 then return end
    local ped = GetPlayerPed(target)
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    RequestWeaponAsset(SNIPER, 31, 0)
    if d.src == me then
        ShootSingleBulletBetweenCoords(d.from.x, d.from.y, d.from.z, head.x, head.y, head.z, 250, true, SNIPER, 0, true, false, 1500.0)
        CreateThread(function()
            Wait(300)
            if not IsEntityDead(PlayerPedId()) then SetEntityHealth(PlayerPedId(), 0) end
            Wait(3500)
            revive()   -- after the fall: back on your feet for spectating; the event returns you at the end
        end)
    else
        ShootSingleBulletBetweenCoords(d.from.x, d.from.y, d.from.z, head.x, head.y, head.z + 1.5, 0, true, SNIPER, 0, true, false, 1500.0)
    end
end

ES.on('mode', function(d)
    if type(d) ~= 'table' then return end
    if d.redlight then
        R = R or { poles = {} }
        for k, v in pairs(d.redlight) do R[k] = v end
        if d.redlight.start or d.redlight.finish then R.poles = poles(R.start, R.finish) end
        loop()
    end
    if d.redlightShot then shot(d.redlightShot) end
end)

ES.on('left', function() R = nil end)
