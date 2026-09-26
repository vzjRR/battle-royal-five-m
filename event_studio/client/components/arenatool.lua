-- EVENT STUDIO — route check & repair (Admin Center → Arenas → Check route, or /eventarenafix <arenaId> [apply]).
-- Uses the game's own data so routes are playable:
--   road  : checkpoints and vehicle spawns must sit on a drivable road node; each leg must have a road path
--   water : checkpoints and boat spawns must be on water deep enough for a boat; each leg must stay on water
--   foot  : points must be safe ground for a player (not inside buildings or in water)
--   open  : tarmac / off-road: ground height only, never in water
--   air   : checkpoints may float; spawns get ground height
-- The result goes to the Admin Center (report + "Apply fixes") and the F8 console. The server re-checks every fix.

local busy = false
local NO_PATH = 100000.0

local function loadAround(x, y, z)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z + 2.0, false, false, false)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 2500 do Wait(0) end
    Wait(120)
end

local function groundAt(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, (z or 0.0) + 60.0, false)
    return found and gz or nil
end

---Water surface height if (x, y) is open water at least `depth` metres deep.
local function deepWater(x, y, z, depth)
    local has, wz = GetWaterHeight(x, y, (z or 0.0) + 10.0)
    if not has then return nil end
    local gz = groundAt(x, y, wz)
    if gz and gz > wz - (depth or 1.5) then return nil end
    return wz
end

local function dist2d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

local function label(p)
    return ('%s%s%s'):format(p.key, p.team and ('[team ' .. p.team .. ']') or '', p.index and (' #' .. p.index) or '')
end

---Nearest deep water around a point (spiral search), for boat routes.
local function findWater(p)
    local node, pos = GetClosestVehicleNode(p.x, p.y, p.z, 3, 3.0, 0) -- nodeType 3 = boat nodes
    if node and pos and dist2d(p, pos) < 300.0 then
        loadAround(pos.x, pos.y, pos.z)
        local wz = deepWater(pos.x, pos.y, pos.z, 1.5)
        if wz then return { x = pos.x, y = pos.y, z = wz } end
    end
    for r = 10, 200, 10 do
        for i = 0, 11 do
            local a = i * math.pi / 6
            local x, y = p.x + math.cos(a) * r, p.y + math.sin(a) * r
            local wz = deepWater(x, y, p.z, 1.5)
            if wz then return { x = x, y = y, z = wz } end
        end
        if r % 60 == 0 then loadAround(p.x, p.y, p.z) end
    end
end

---Nearest drivable road point (and its heading).
local function findRoad(p)
    local ok, pos, heading = GetClosestVehicleNodeWithHeading(p.x, p.y, p.z, 1, 3.0, 0)
    if ok and pos and dist2d(p, pos) < 300.0 then return { x = pos.x, y = pos.y, z = pos.z + 0.3, w = heading } end
end

---Keep spawn grids apart: if a moved spawn lands on top of another, push it sideways.
local function spread(fixed, list, heading)
    for _ = 1, 8 do
        local clash = false
        for _, o in ipairs(list) do
            if dist2d(fixed, o) < 3.2 then clash = true break end
        end
        if not clash then return fixed end
        local a = math.rad((heading or 0.0) + 90.0)
        fixed.x, fixed.y = fixed.x + math.cos(a) * 3.5, fixed.y + math.sin(a) * 3.5
    end
    return fixed
end

local isSpawn = { spawns = true, teamSpawns = true, vehicleSpawns = true }

local function checkPoint(route, p, placed)
    loadAround(p.x, p.y, p.z)
    local key = p.key
    local vehicleRoute = route == 'road' or route == 'water'
    -- boat routes: checkpoints, vehicle spawns and the finish must float
    if route == 'water' and (key == 'checkpoints' or key == 'vehicleSpawns' or key == 'finish') then
        local wz = deepWater(p.x, p.y, p.z, 1.5)
        if wz then
            if math.abs(wz - p.z) > 1.5 then return 'fixed', 'height set to the water surface', { x = p.x, y = p.y, z = wz, w = p.w } end
            return 'ok', 'on open water'
        end
        local w = findWater(p)
        if not w then return 'problem', 'on land or shallow water and no open water within 200 m' end
        if key == 'vehicleSpawns' then w = spread(w, placed, p.w) end
        return 'fixed', ('moved %.0f m onto open water'):format(dist2d(p, w)), { x = w.x, y = w.y, z = w.z, w = p.w }
    end
    -- road routes: checkpoints and vehicle spawns must be on a road
    if route == 'road' and (key == 'checkpoints' or key == 'vehicleSpawns') then
        if IsPointOnRoad(p.x, p.y, p.z, 0) then
            local gz = groundAt(p.x, p.y, p.z)
            if gz and math.abs(gz - p.z) > 1.5 then return 'fixed', 'height matched to the road', { x = p.x, y = p.y, z = gz + (key == 'vehicleSpawns' and 0.5 or 0.0), w = p.w } end
            return 'ok', 'on the road'
        end
        local r = findRoad(p)
        if not r then return 'problem', 'not on a road and no road within 300 m' end
        if key == 'vehicleSpawns' then
            -- keep the grid's own heading unless it points across the road
            local diff = math.abs(((p.w or r.w) - r.w + 180) % 360 - 180)
            local w = (diff < 60 or diff > 120) and (p.w or r.w) or r.w
            r = spread(r, placed, w)
            r.w = w
            r.z = r.z + 0.2
        end
        return 'fixed', ('moved %.0f m onto the road'):format(dist2d(p, r)), r
    end
    -- anything a player stands on: safe ground outside buildings and water
    if isSpawn[key] and key ~= 'vehicleSpawns' or (route == 'foot' and (key == 'checkpoints' or key == 'targets' or key == 'finish')) or key == 'objectives' then
        local ok, safe = GetSafeCoordForPed(p.x, p.y, p.z, true, 16)
        if ok and safe then
            local moved = dist2d(p, safe)
            if moved < 2.0 and math.abs(safe.z - p.z) < 1.5 then return 'ok', 'safe ground' end
            if moved < 40.0 then
                local s = { x = safe.x, y = safe.y, z = safe.z + (isSpawn[key] and 0.5 or 0.0), w = p.w }
                if isSpawn[key] then s = spread(s, placed, p.w) end
                return 'fixed', moved < 2.0 and 'height matched to the ground' or ('moved %.0f m to safe ground'):format(moved), s
            end
        end
    end
    -- everything else: ground height (air checkpoints may float), never in water
    local gz = groundAt(p.x, p.y, p.z)
    local wz = deepWater(p.x, p.y, p.z, 0.8)
    if wz and route ~= 'water' and not vehicleRoute and key ~= 'zones' then
        return 'problem', 'in water'
    end
    if not gz then return 'kept', 'no ground found here, kept as is' end
    if route == 'air' and key == 'checkpoints' and p.z - gz > 5.0 then return 'ok', ('air checkpoint %.0f m above ground'):format(p.z - gz) end
    local target = gz + (isSpawn[key] and 0.5 or 0.0)
    if math.abs(target - p.z) > 1.5 then return 'fixed', ('height %+.1f m'):format(target - p.z), { x = p.x, y = p.y, z = target, w = p.w } end
    return 'ok', 'ground height ok'
end

---Check that each leg of the route can be driven / sailed.
local function checkLegs(route, cps)
    local legs = {}
    if route ~= 'road' and route ~= 'water' then return legs end
    for i = 1, #cps - 1 do
        local a, b = cps[i], cps[i + 1]
        local straight = dist2d(a, b)
        local leg = { from = i, to = i + 1, status = 'ok' }
        if route == 'road' then
            local travel = CalculateTravelDistanceBetweenPoints(a.x, a.y, a.z, b.x, b.y, b.z)
            if travel >= NO_PATH then
                leg.status, leg.note = 'problem', 'no road connects these checkpoints'
            elseif straight > 60.0 and travel > straight * 3.5 then
                leg.status, leg.note = 'warn', ('the road is %.0f m for %.0f m in a straight line: add a checkpoint in between'):format(travel, straight)
            else
                leg.note = ('%.0f m by road'):format(travel)
            end
        else
            local steps = math.max(1, math.floor(straight / 25.0))
            local dry = 0
            for s = 1, steps - 1 do
                local t = s / steps
                local x, y, z = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z
                if s % 5 == 1 then loadAround(x, y, z) end
                if not deepWater(x, y, z, 1.0) then dry = dry + 1 end
            end
            if dry > 0 then
                leg.status, leg.note = 'problem', ('the straight line crosses land or shallows (%d of %d samples): move or add a checkpoint'):format(dry, steps - 1)
            else
                leg.note = ('%.0f m of open water'):format(straight)
            end
        end
        legs[#legs + 1] = leg
    end
    return legs
end

---Run a check. apply = true saves the fixes right away (console command); the Admin Center applies from its report.
function ES.checkArena(arenaId, apply)
    if busy then return ES.NUI.send('toast', { text = 'A route check is already running.', kind = 'warn' }) end
    busy = true
    ES.rpc('admin:arena:probe', { id = arenaId }, function(ok, res)
        if not ok then
            busy = false
            ES.NUI.send('arenaCheck', { id = arenaId, error = tostring(res) })
            return
        end
        CreateThread(function()
            local ped = PlayerPedId()
            local home, heading = GetEntityCoords(ped), GetEntityHeading(ped)
            FreezeEntityPosition(ped, true)
            SetEntityVisible(ped, false, false)
            SetEntityInvincible(ped, true)
            LoadAllPathNodes(true)
            local route = res.route
            local points, fixes, problems = {}, {}, 0
            local placed = {}
            for i, p in ipairs(res.points) do
                ES.NUI.send('arenaCheck', { id = arenaId, progress = i, total = #res.points })
                local status, note, fix = checkPoint(route, p, placed)
                local entry = { label = label(p), key = p.key, status = status, note = note }
                if fix then
                    fixes[#fixes + 1] = { key = p.key, index = p.index, team = p.team, x = fix.x, y = fix.y, z = fix.z, w = fix.w }
                    if isSpawn[p.key] then placed[#placed + 1] = fix end
                elseif isSpawn[p.key] then
                    placed[#placed + 1] = p
                end
                if status == 'problem' then problems = problems + 1 end
                points[#points + 1] = entry
            end
            -- legs use the corrected checkpoint positions
            local cps = {}
            for _, p in ipairs(res.points) do
                if p.key == 'checkpoints' then
                    local c = { x = p.x, y = p.y, z = p.z }
                    for _, f in ipairs(fixes) do if f.key == 'checkpoints' and f.index == p.index then c = f end end
                    cps[#cps + 1] = c
                end
            end
            local legs = checkLegs(route, cps)
            for _, l in ipairs(legs) do if l.status == 'problem' then problems = problems + 1 end end
            SetEntityCoordsNoOffset(ped, home.x, home.y, home.z, false, false, false)
            SetEntityHeading(ped, heading)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, false)
            SetEntityInvincible(ped, false)
            print(('[event_studio] route check "%s" (%s): %d points, %d fixes, %d problems'):format(res.name, route, #points, #fixes, problems))
            for _, e in ipairs(points) do print(('  %-8s %-26s %s'):format(e.status, e.label, e.note or '')) end
            for _, l in ipairs(legs) do print(('  %-8s leg %d → %d  %s'):format(l.status, l.from, l.to, l.note or '')) end
            local report = { id = arenaId, name = res.name, route = route, points = points, legs = legs, fixes = fixes, problems = problems, done = true }
            if apply then
                ES.rpc('admin:arena:applyFix', { id = arenaId, fixes = fixes, problems = problems }, function(okA, r2)
                    report.applied = okA and r2.applied or nil
                    report.error = not okA and tostring(r2) or nil
                    ES.NUI.send('arenaCheck', report)
                    ES.NUI.send('toast', { text = okA and ('Route %s: %d fixes saved, %d problems left'):format(res.name, r2.applied, problems)
                        or ('Route fix failed: ' .. tostring(r2)), kind = okA and (problems > 0 and 'warn' or 'success') or 'error' })
                end)
            else
                ES.NUI.send('arenaCheck', report)
            end
            busy = false
        end)
    end)
end

RegisterNUICallback('arena:check', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return cb({ ok = false }) end
    ES.checkArena(data.id, false)
    cb({ ok = true })
end)

-- Staff only: registered from ES.registerStaffCommands (client/main.lua) when the server says the player is staff.
function ES.registerArenaFixCommand()
    local cmd = ES.Config.Commands and ES.Config.Commands.arenaFix
    if not cmd then return end
    RegisterCommand(cmd, function(_, args)
        if not args[1] then return ES.NUI.send('toast', { text = 'Usage: /' .. cmd .. ' <arenaId> [apply]', kind = 'info' }) end
        ES.checkArena(args[1], args[2] == 'apply')
    end, false)
end
