-- EVENT STUDIO — admin tool: /eventarenafix <arenaId> [apply]
-- Visits every point of an arena, measures the real ground (or water) height and proposes Z corrections.
-- Without "apply" it only reports (F8 console). With "apply" the server validates and saves the corrections.

local busy = false

local function measure(p)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z + 2.0, false, false, false)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 2500 do Wait(0) end
    Wait(150)
    local found, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 50.0, false)
    local hasWater, wz = GetWaterHeight(p.x, p.y, p.z + 10.0)
    if hasWater and (not found or wz > gz) then return wz, 'water' end
    if found then return gz, 'ground' end
    return nil, 'none'
end

local function run(arenaId, apply)
    if busy then return end
    busy = true
    ES.rpc('admin:arena:probe', { id = arenaId }, function(ok, res)
        if not ok then
            busy = false
            ES.NUI.send('toast', { text = 'arena probe: ' .. tostring(res), kind = 'error' })
            return
        end
        CreateThread(function()
            local ped = PlayerPedId()
            local home, heading = GetEntityCoords(ped), GetEntityHeading(ped)
            FreezeEntityPosition(ped, true)
            SetEntityVisible(ped, false, false)
            SetEntityInvincible(ped, true)
            local fixes, report = {}, {}
            for i, p in ipairs(res.points) do
                ES.NUI.send('toast', { text = ('Arena check %s: %d/%d'):format(res.name, i, #res.points), kind = 'info' })
                local z, kind = measure(p)
                local label = ('%s%s%s'):format(p.key, p.team and ('[team ' .. p.team .. ']') or '', p.index and ('#' .. p.index) or '')
                if not z then
                    report[#report + 1] = ('?  %-28s no ground found (keep %.2f)'):format(label, p.z)
                else
                    local target = z + ((p.key == 'spawns' or p.key == 'teamSpawns' or p.key == 'vehicleSpawns') and kind == 'ground' and 0.5 or 0.0)
                    local dz = target - p.z
                    if p.key == 'checkpoints' and p.z - z > 30.0 then
                        report[#report + 1] = ('=  %-28s %.1f m above ground — treated as an air checkpoint, kept'):format(label, p.z - z)
                    elseif math.abs(dz) > 1.5 then
                        fixes[#fixes + 1] = { key = p.key, index = p.index, team = p.team, z = target }
                        report[#report + 1] = ('!  %-28s z %.2f → %.2f (%s, %+.1f m)'):format(label, p.z, target, kind, dz)
                    else
                        report[#report + 1] = ('ok %-28s z %.2f'):format(label, p.z)
                    end
                end
            end
            SetEntityCoordsNoOffset(ped, home.x, home.y, home.z, false, false, false)
            SetEntityHeading(ped, heading)
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, false)
            SetEntityInvincible(ped, false)
            print(('[event_studio] arena check "%s": %d points, %d need fixing'):format(res.name, #res.points, #fixes))
            for _, line in ipairs(report) do print('  ' .. line) end
            if apply and #fixes > 0 then
                ES.rpc('admin:arena:applyZ', { id = arenaId, fixes = fixes }, function(okA, r2)
                    ES.NUI.send('toast', { text = okA and ('Arena %s: %d heights fixed and saved'):format(res.name, r2.applied)
                        or ('Arena fix failed: ' .. tostring(r2)), kind = okA and 'success' or 'error' })
                end)
            else
                ES.NUI.send('toast', { text = ('Arena %s: %d point(s) need fixing — see F8. Run again with "apply" to save.'):format(res.name, #fixes),
                    kind = #fixes > 0 and 'warn' or 'success' })
            end
            busy = false
        end)
    end)
end

local cmd = ES.Config.Commands and ES.Config.Commands.arenaFix
if cmd then
    RegisterCommand(cmd, function(_, args)
        if not args[1] then return ES.NUI.send('toast', { text = 'Usage: /' .. cmd .. ' <arenaId> [apply]', kind = 'info' }) end
        run(args[1], args[2] == 'apply')
    end, false)
end
