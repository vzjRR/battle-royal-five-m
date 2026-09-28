-- Simulation: every non-race mode plays through to a result.
local H = T
H.boot()

local function reg(d)
    d.timing = d.timing or {}
    d.timing.registration = d.timing.registration or 30
    d.timing.lobby = 1 d.timing.countdown = 1 d.timing.results = 3
    d.timing.duration = d.timing.duration or 600
    d.players = d.players or { min = 2, max = 16 }
    d.name = d.name or d.id
    local ok, err = ES.Definitions.register(d)
    assert(ok, tostring(err))
end

local function finishAndArchive(inst)
    H.ok(H.waitState(inst, 'ARCHIVED', 60000), 'archived, state=' .. inst.state)
end

H.test('sumo: leaving the ring eliminates; knockout credited to nearest opponent', function()
    reg({ id = 't_sumo', mode = 'sumo', arena = 'lsia_sumo', options = { suddenDeathAfter = 0, graceMs = 500 } })
    local a, b, c = table.unpack(H.players(3, 100))
    local inst = H.createAndJoin('t_sumo', { a, b, c })
    H.toActive(inst)
    local center = ES.Arenas.get('lsia_sumo').center
    H.setPos(a, center.x + 44, center.y, center.z) -- b pushed a out
    H.setPos(b, center.x + 35, center.y, center.z)
    H.setPos(c, center.x - 10, center.y, center.z)
    Sim.advance(1500)
    H.eq(inst.byLicense[Sim.players[a].license].status, 'eliminated')
    H.eq(inst.participants[b].score, 1, 'knockout credited')
    H.setPos(c, center.x, center.y + 60, center.z)
    Sim.advance(1500)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, b)
end)

H.test('derby: wrecked vehicle eliminates', function()
    reg({ id = 't_derby', mode = 'sumo', arena = 'lsia_derby', options = { eliminateOnWreck = true, suddenDeathAfter = 0 } })
    local a, b = table.unpack(H.players(2, 110))
    local inst = H.createAndJoin('t_derby', { a, b })
    H.toActive(inst)
    local veh = inst:component('vehicles'):entityOf(inst.participants[a])
    Sim.vehicles[veh].engine = -500.0
    Sim.advance(1000)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, b)
end)

H.test('koth hill: uncontested occupant scores, contested zone does not', function()
    reg({ id = 't_koth', mode = 'koth', arena = 'docks_yard', options = { scoreTarget = 5, weapons = {} } })
    local a, b = table.unpack(H.players(2, 120))
    local inst = H.createAndJoin('t_koth', { a, b })
    H.toActive(inst)
    local z = ES.Arenas.get('docks_yard').zones[1]
    H.setPos(a, z.x, z.y, z.z) H.setPos(b, z.x + 2, z.y, z.z)
    Sim.advance(3000)
    H.eq(inst.participants[a].score, 0, 'contested: no points')
    H.setPos(b, z.x + 60, z.y, z.z)
    Sim.advance(6500)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
    H.ok(inst.results[1].score >= 5)
end)

H.test('domination: capture ownership keeps scoring for the team', function()
    reg({ id = 't_dom', mode = 'koth', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          options = { style = 'domination', captureSeconds = 2, scoreTarget = 6, weapons = {} } })
    local srcs = H.players(2, 130)
    local inst = H.createAndJoin('t_dom', srcs)
    H.toActive(inst)
    local zA = ES.Arenas.get('sandy_airfield').zones[1]
    local red = inst.participants[srcs[1]].team == 1 and srcs[1] or srcs[2]
    local blue = red == srcs[1] and srcs[2] or srcs[1]
    H.setPos(red, zA.x, zA.y, zA.z)
    H.setPos(blue, 0, 0, 0)
    Sim.advance(2600)
    H.eq(inst:component('zones'):ownerOf('A'), 1, 'red owns Alpha')
    H.setPos(red, 0, 0, 0) -- leaves, keeps scoring as owner
    Sim.advance(7000)
    finishAndArchive(inst)
    H.eq(inst.teamResults[1].index, 1)
end)

H.test('ctf: pickup, capture, win', function()
    reg({ id = 't_ctf', mode = 'ctf', arena = 'sandy_airfield', players = { min = 2, max = 8, teams = { count = 2 } },
          options = { capturesToWin = 1 } })
    local srcs = H.players(2, 140)
    local inst = H.createAndJoin('t_ctf', srcs)
    H.toActive(inst)
    local red = inst.participants[srcs[1]].team == 1 and srcs[1] or srcs[2]
    local blueFlag = inst.data.flags[2].base
    local redBase = inst.data.flags[1].base
    H.setPos(red, blueFlag.x, blueFlag.y, blueFlag.z)
    Sim.advance(600)
    H.eq(inst.data.flags[2].carrier, inst.participants[red], 'red carries blue flag')
    H.setPos(red, redBase.x, redBase.y, redBase.z)
    Sim.advance(600)
    finishAndArchive(inst)
    H.eq(inst.teamResults[1].index, 1)
    H.eq(inst.results[1].objectives, 1)
end)

H.test('zone survival: staying outside eliminates, last alive wins', function()
    reg({ id = 't_zone', mode = 'zone_survival', arena = 'senora_desert', options = { eliminateOutsideSeconds = 3 } })
    local a, b = table.unpack(H.players(2, 150))
    local inst = H.createAndJoin('t_zone', { a, b })
    H.toActive(inst)
    local c = ES.Arenas.get('senora_desert').center
    H.setPos(a, c.x, c.y, c.z)
    H.setPos(b, c.x + 1000, c.y, c.z)
    Sim.advance(4000)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
end)

H.test('hunt: server-side discovery, first to find all wins', function()
    reg({ id = 't_hunt', mode = 'hunt', arena = 'city_landmarks', players = { min = 1, max = 8 }, options = { hidden = true } })
    local a, b = table.unpack(H.players(2, 160))
    local inst = H.createAndJoin('t_hunt', { a, b })
    H.toActive(inst)
    -- clients never receive hidden coordinates
    local setup
    for _, m in ipairs(H.pushes(a, 'component')) do if m.name == 'checkpoints' then setup = m.setup end end
    H.ok(setup and setup.hidden)
    H.eq(setup.points[1].x, nil, 'hidden coordinates not sent')
    -- checkpoint intents are refused in server-detect mode
    local ok = H.rpc(a, 'event:action', { action = 'checkpoint', data = { index = 1 } })
    H.no(ok)
    for _, t in ipairs(ES.Arenas.get('city_landmarks').targets) do
        H.setPos(a, t.x, t.y, t.z)
        Sim.advance(600)
    end
    H.eq(inst.byLicense[Sim.players[a].license].status, 'finished')
    local t1 = ES.Arenas.get('city_landmarks').targets[1]
    H.setPos(b, t1.x, t1.y, t1.z)
    Sim.advance(600)
    inst:finishNow('test')
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[2].src, b, 'partial progress ranks second')
end)

H.test('red light: moving during red eliminates, reaching finish wins', function()
    reg({ id = 't_red', mode = 'redlight', arena = 'lsia_runway_field',
          options = { greenMin = 2, greenMax = 2, redMin = 3, redMax = 3, reactionMs = 500 } })
    local a, b = table.unpack(H.players(2, 170))
    local inst = H.createAndJoin('t_red', { a, b })
    H.toActive(inst)
    H.eq(inst.data.light, 'green')
    Sim.advance(2100)
    H.eq(inst.data.light, 'red')
    Sim.advance(1200) -- after reaction window, snapshot taken
    local pb = Sim.players[b].pos
    H.setPos(b, pb.x + 3, pb.y, pb.z)
    Sim.advance(600)
    H.eq(inst.byLicense[Sim.players[b].license].status, 'eliminated', 'mover eliminated')
    Sim.advance(1500) -- green again
    local f = ES.Arenas.get('lsia_runway_field').finish
    H.setPos(a, f.x, f.y, f.z)
    Sim.advance(600)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
end)

H.test('trivia: correct and fast answers win; answers hidden until reveal', function()
    reg({ id = 't_trivia', mode = 'trivia', options = { count = 2, secondsPerQuestion = 5, shuffle = false,
        questions = { { q = 'Q1', answers = { 'x', 'y' }, correct = 2 }, { q = 'Q2', answers = { 'x', 'y' }, correct = 1 } } } })
    local a, b = table.unpack(H.players(2, 180))
    local inst = H.createAndJoin('t_trivia', { a, b })
    H.toActive(inst)
    local q = H.lastPush(a, 'mode').trivia
    H.eq(q.phase, 'question') H.eq(q.correct, nil, 'correct answer not sent')
    H.ok((H.rpc(a, 'event:action', { action = 'answer', data = { choice = 2 } })))
    H.no((H.rpc(a, 'event:action', { action = 'answer', data = { choice = 1 } })), 'second answer refused')
    H.ok((H.rpc(b, 'event:action', { action = 'answer', data = { choice = 1 } })))
    Sim.advance(4600)
    H.ok((H.rpc(a, 'event:action', { action = 'answer', data = { choice = 1 } })))
    H.ok((H.rpc(b, 'event:action', { action = 'answer', data = { choice = 9 } })) == false, 'out of range refused')
    Sim.advance(10000)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[2].score, 0)
end)

H.test('reaction: early press penalised, fastest wins', function()
    reg({ id = 't_react', mode = 'reaction', options = { rounds = 1, minDelay = 2, maxDelay = 2, earlyPenalty = 5 } })
    local a, b = table.unpack(H.players(2, 190))
    local inst = H.createAndJoin('t_react', { a, b })
    H.toActive(inst)
    H.rpc(b, 'event:action', { action = 'react' }) -- early
    Sim.advance(2100)
    H.eq(inst.data.phase, 'go')
    H.ok((H.rpc(a, 'event:action', { action = 'react' })))
    Sim.advance(8000)
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[2].score, -5)
end)

H.test('gun game: ladder progression and win', function()
    reg({ id = 't_gg', mode = 'gungame', arena = 'docks_yard', options = { ladder = { 'WEAPON_PISTOL', 'WEAPON_SMG' }, respawnDelay = 1 } })
    local a, b = table.unpack(H.players(2, 200))
    local inst = H.createAndJoin('t_gg', { a, b })
    H.toActive(inst)
    local function kill(att, vic, w)
        Sim.dispatch('weaponDamageEvent', att, att, { hitGlobalId = GetPlayerPed(vic), weaponType = GetHashKey(w) })
        Sim.players[vic].health = 0
        H.rpc(vic, 'event:action', { action = 'died', data = { killer = att } })
        Sim.advance(1200)
    end
    kill(a, b, 'WEAPON_PISTOL')
    H.eq(inst.data.level[inst.participants[a]], 2)
    kill(a, b, 'WEAPON_SMG')
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
end)

H.test('duel rounds: best of three decided by round wins', function()
    reg({ id = 't_duel', mode = 'deathmatch', arena = 'docks_yard', players = { min = 2, max = 2 },
          options = { lives = 1, rounds = 3, killTarget = 0, weapons = { 'WEAPON_PISTOL' } } })
    local a, b = table.unpack(H.players(2, 210))
    local inst = H.createAndJoin('t_duel', { a, b })
    H.toActive(inst)
    for round = 1, 2 do
        Sim.dispatch('weaponDamageEvent', a, a, { hitGlobalId = GetPlayerPed(b), weaponType = GetHashKey('WEAPON_PISTOL') })
        Sim.players[b].health = 0
        H.rpc(b, 'event:action', { action = 'died', data = { killer = a } })
        Sim.advance(4500)
        if round == 1 then
            H.eq(inst.data.round, 2, 'round 2 started')
            H.eq(inst.participants[b].status, 'active', 'victim revived for next round')
        end
    end
    finishAndArchive(inst)
    H.eq(inst.results[1].src, a)
    H.eq(inst.results[1].score, 2, 'two round wins')
end)

H.test('custom mode: staff manual scoring via admin RPC', function()
    local host, p1, p2 = table.unpack(H.players(3, 220))
    H.admin(host)
    local inst = H.createAndJoin('staff_challenge', { p1, p2 })
    H.toActive(inst)
    local ok = H.rpc(host, 'admin:instance:score', { id = inst.id, target = p2, amount = 25, reason = 'won round' })
    H.ok(ok)
    H.eq(inst.participants[p2].score, 25)
    H.ok((H.rpc(host, 'admin:instance:stop', { id = inst.id, confirm = true })))
    finishAndArchive(inst)
    H.eq(inst.results[1].src, p2)
end)

H.test('beach red light: night, walking only, moving on red = shot from the tower and out', function()
    local a, b = table.unpack(H.players(2, 8800))
    for _, s in ipairs({ a, b }) do H.setPos(s, 0.0, 0.0, 3.0) end
    local inst = H.createAndJoin('beach_red_light', { a, b })
    H.toActive(inst)
    local snap = H.lastPush(a, 'state')
    H.eq(snap.gameplay.clockHour, 0, 'midnight for the players in the event')
    local setup
    for _, m in ipairs(H.pushes(a, 'mode')) do if m.redlight and m.redlight.tower then setup = m.redlight end end
    H.ok(setup and setup.walkOnly, 'clients get the tower, the track and walking only')
    H.ok(setup.tower.z > setup.finish.z, 'tower above the finish line')
    -- wait for a red light that is being measured
    for _ = 1, 400 do
        if inst.data.light == 'red' and inst.data.snapshot then break end
        Sim.advance(100)
    end
    H.eq(inst.data.light, 'red')
    H.clear(b)
    local p = Sim.players[b].pos
    H.setPos(b, p.x + 3.0, p.y, p.z)
    Sim.advance(600)
    local shotAt
    for _, m in ipairs(H.pushes(b, 'mode')) do if m.redlightShot then shotAt = m.redlightShot end end
    H.ok(shotAt and shotAt.src == b, 'the tower fires at the player who moved')
    H.eq(inst.participants[b].status, 'active', 'the shot lands before the player is out')
    Sim.advance(1600)
    H.eq(inst.participants[b].status, 'eliminated')
    H.eq(inst.participants[b].eliminatedReason, 'shot')
    inst:cancel('test')
    Sim.advance(1000)
    for _, s in ipairs({ a, b }) do Sim.players[s] = nil end
end)
