#!/usr/bin/env python3
# Renders docs/EVENT_CATALOG.md from structured data.
import sys

CAT = {
 'racing':   dict(title='Racing', deps='OneSync; vehicles', sys='vehicles, checkpoints, timer, positions, spawns',
                  exploits='teleport to checkpoint, speed hacks, vehicle spawning, corner cutting', lose='DNF when time expires; last place'),
 'vehicle':  dict(title='Vehicle Competitions', deps='OneSync; vehicles', sys='vehicles, bounds/zones, eliminations, timer, spawns',
                  exploits='god-mode vehicle, handling mods, leaving vehicle, teleport', lose='eliminated (out of bounds / wrecked)'),
 'combat':   dict(title='Combat / PvP', deps='OneSync; weapons', sys='combat (loadout, damage filter, kill attribution), lives/respawn, spawns, timer, teams',
                  exploits='fake kills, god mode, weapon spawning, aimbot (out of scope: anticheat)', lose='out of lives / lower score at time'),
 'objective':dict(title='Objective / Team Modes', deps='OneSync', sys='teams, zones, objectives, combat, spawns, timer',
                  exploits='fake captures, teleport into zone, carrier teleport', lose='opponent reaches target / higher score at time'),
 'survival': dict(title='Survival', deps='OneSync', sys='zones (shrinking), combat, lives, eliminations, timer',
                  exploits='god mode, ignoring zone damage, teleport', lose='death / outside zone too long'),
 'hunt':     dict(title='Hunt / Scavenger', deps='OneSync', sys='checkpoints (unordered/hidden), timer, hints',
                  exploits='teleporting to targets, sniffing target coordinates', lose='not all found before time'),
 'obstacle': dict(title='Obstacle / Skill', deps='OneSync', sys='checkpoints, timer, bounds (fall = reset), spawns',
                  exploits='teleport/noclip, flying', lose='DNF at time'),
 'social':   dict(title='Social / Fun', deps='none beyond base', sys='server rounds, NUI input, timer',
                  exploits='answer sniffing, auto-clickers, timing spoofing', lose='wrong answer / eliminated in round'),
 'tournament':dict(title='Tournaments', deps='Event Engine + tournament engine', sys='tournament engine, match instances, seeding, series',
                  exploits='match fixing (social), disconnect abuse', lose='losing a series / fewer league points'),
}

# name, cat, players, teams, mechanic, win, lose(None=cat default), scoring, systems(None=cat default), difficulty, complexity, exploits(None=default), status
E = [
# RACING
('Standard Circuit Race','racing','2-32','Solo','Lap-based ordered checkpoints on a closed loop','First to complete all laps',None,'Placement table; lap bonus; DNF 0',None,'Easy','Low (mode race)',None,'V1 · mode `race` preset `street_circuit`'),
('Point-to-Point Race','racing','2-32','Solo','Single-lap ordered checkpoints A→B','First to reach finish',None,'Placement table',None,'Easy','Low','','V1 · mode `race` (laps=1)'),
('Checkpoint Race','racing','2-32','Solo','Many dense ordered checkpoints, any vehicle','First to finish',None,'Placement + checkpoint points',None,'Easy','Low',None,'V1 · mode `race`'),
('Time Trial','racing','1-32','Solo','Race against the clock; ghosted; personal bests','Best time in window',None,'Placement by time; PB tracked',None,'Easy','Low',None,'V1 · mode `race` (`ghost=true`, rankBy time)'),
('Drag Race','racing','2-8','Solo','Short straight, 2-3 checkpoints, standing start','First to finish line',None,'Placement',None,'Easy','Low',None,'V1 · mode `race` preset `drag_strip`'),
('Street Race','racing','2-16','Solo','Public-road circuit/sprint with traffic disabled in bucket','First to finish',None,'Placement',None,'Easy','Low',None,'V1 · mode `race`'),
('Off-road Race','racing','2-16','Solo','Off-road vehicle class on dirt route','First to finish',None,'Placement',None,'Medium','Low',None,'V1 · mode `race` (class filter)'),
('Bike Race','racing','2-16','Solo','Motorbikes/bicycles only','First to finish',None,'Placement',None,'Easy','Low',None,'V1 · mode `race` (vehicle type bike)'),
('Boat Race','racing','2-16','Solo','Water checkpoints, boats spawned server-side as `boat`','First to finish',None,'Placement',None,'Medium','Low',None,'V1 · mode `race` (vehicle type boat)'),
('Aircraft Race','racing','2-16','Solo','Air checkpoints (3D radius), planes/helis','First to finish',None,'Placement','vehicles, 3D checkpoints, timer','Hard','Medium','Collision-free flying through terrain; checkpoint radius abuse','V1 · mode `race` (vehicle type plane/heli, `checkpoint3d=true`)'),
('Random Vehicle Race','racing','2-32','Solo','Each racer gets a random model from a pool','First to finish',None,'Placement',None,'Easy','Low',None,'V1 · mode `race` (`vehicle.random=true`)'),
('Vehicle Class Race','racing','2-32','Solo','Player picks from a class-limited list in lobby','First to finish',None,'Placement',None,'Easy','Low',None,'V1 · mode `race` (vehicle pool = class list)'),
('Elimination Race','racing','3-32','Solo','Last place eliminated every N seconds','Last racer remaining / first to finish','Being last at elimination tick','Placement by elimination order',None,'Medium','Low',None,'V1 · mode `race` (`eliminateEvery`)'),
('Reverse / Alternate Route Race','racing','2-32','Solo','Arena checkpoints reversed or alternate set','First to finish',None,'Placement',None,'Easy','Low',None,'V1 · mode `race` (`reverse=true` / `route`)'),
('Stunt Race','racing','2-16','Solo','Stunt props route; respawn at last checkpoint','First to finish',None,'Placement','vehicles, checkpoints, props (map resource), respawn at checkpoint','Hard','Medium (props via external map)',None,'V1 · mode `race` with external map resource; built-in prop placement V2'),
('Team Relay Race','racing','4-16','2-4 teams','Teammates run legs sequentially; baton passes at handover checkpoint','Team finishes all legs first',None,'Team placement',None,'Medium','Medium',None,'V2 · needs relay leg handover in race mode'),
# VEHICLE
('Sumo','vehicle','2-16','Solo or teams','Push others off a platform/arena; handbrake optional disabled; sudden-death shrink','Last in arena',None,'Placement by elimination order; knockouts +points',None,'Medium','Low',None,'V1 · mode `sumo`'),
('Vehicle Knockout','vehicle','2-16','Solo','Sumo variant with knock-out credit to last contact','Most knockouts / last standing',None,'Knockouts ×points + placement',None,'Medium','Medium',None,'V1 · mode `sumo` (`scoreKnockouts=true`)'),
('Demolition Derby','vehicle','2-24','Solo or teams','Wreck others; eliminated when vehicle destroyed','Last vehicle running',None,'Placement + wreck credits',None,'Medium','Low',None,'V1 · mode `sumo` (`eliminateOnWreck=true`, larger bounds)'),
('King of the Hill (Vehicles)','vehicle','2-16','Solo or teams','Hold a zone while in a vehicle','Most hold time',None,'Points per second held',None,'Medium','Low',None,'V1 · mode `koth` (`requireVehicle=true`)'),
('Last Vehicle Standing','vehicle','2-24','Solo','Arena bounds + wreck elimination','Last remaining',None,'Placement',None,'Medium','Low',None,'V1 · mode `sumo` preset'),
('Vehicle Push','vehicle','2-8','2 teams','Push a heavy object/vehicle into goal zone','Object reaches enemy goal','Opponent scores','Goals',None,'Hard','High','Physics desync of pushed entity','V2 · needs networked physics object ownership handling'),
('Vehicle Survival','vehicle','1-16','Solo','Survive in vehicle vs hazards / shrinking zone','Last alive',None,'Survival time points','vehicles, zones, eliminations','Medium','Medium',None,'V1 · mode `zone_survival` (`requireVehicle=true`)'),
('Checkpoint Destruction','vehicle','2-16','2 teams','Destroy enemy props/targets with vehicles','Destroy all first',None,'Objective points','vehicles, destructible objectives','Hard','High','Fake destruction events','V2'),
('Hot Vehicle / Keep Moving','vehicle','2-16','Solo','Must stay above a rising speed threshold (server-side velocity check) or be eliminated','Last moving',None,'Seconds above the limit','vehicles, server velocity check, eliminations','Medium','Medium',None,'V1 · mode `keep_moving`'),
('Delivery Under Pressure','vehicle','1-8','Solo/teams','Deliver a vehicle to destination without exceeding damage','Delivered first with health above threshold',None,'Time + health bonus','vehicles, checkpoints, health check','Medium','Medium',None,'V2'),
('Escort Vehicle','vehicle','4-16','2 teams','Defenders escort a slow vehicle to destination; attackers stop it','Vehicle reaches destination / destroyed',None,'Objective','vehicles, roles, checkpoints, combat','Hard','High',None,'Future'),
('Vehicle Protection','vehicle','4-16','2 teams','Protect a parked vehicle for time','Vehicle survives / destroyed',None,'Objective','vehicles, roles, combat','Medium','Medium',None,'V2'),
('Vehicle Interception','vehicle','4-16','2 teams','Runners reach destination; hunters intercept','Runner arrives / all runners stopped',None,'Objective','vehicles, roles, checkpoints','Hard','High',None,'Future (Hunting-pack inspired)'),
('Vehicle Tag','vehicle','3-16','Solo','"It" vehicle tags others by contact (server proximity)','Least time as "it"',None,'Time not-it','vehicles, roles, proximity','Medium','Medium','Fake contact reports (use server distance)','V2'),
# COMBAT
('Free For All','combat','2-32','Solo','Everyone vs everyone, respawns','Kill target or most kills at time',None,'Kills ×points; placement',None,'Easy','Low',None,'V1 · mode `deathmatch`'),
('Team Deathmatch','combat','4-32','2-4 teams','Team kills, respawns, friendly fire off','Team kill target / most at time',None,'Team kills; individual kills',None,'Easy','Low',None,'V1 · mode `deathmatch` (teams)'),
('Last Man Standing','combat','2-32','Solo','One life, no respawn','Last alive',None,'Placement by elimination order + kills',None,'Easy','Low',None,'V1 · mode `deathmatch` (`lives=1`)'),
('Last Team Standing','combat','4-32','2-4 teams','One life per round, rounds','Team wins most rounds',None,'Round wins',None,'Medium','Low',None,'V1 · mode `deathmatch` (teams, lives=1, rounds)'),
('Gun Game / Kill Quota','combat','2-32','Solo (teams V2)','Advance weapon ladder per kill(s)','First to complete ladder',None,'Level reached; placement',None,'Medium','Low',None,'V1 · mode `gungame`'),
('Weapon Rotation','combat','2-32','Solo/teams','All players switch weapon every N seconds','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · mode `deathmatch` (`rotateEvery`)'),
('One Weapon Only','combat','2-32','Solo/teams','Single configured weapon','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` preset'),
('Snipers Only','combat','2-32','Solo/teams','Sniper rifles only','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` preset `snipers_only`'),
('Pistols Only','combat','2-32','Solo/teams','Pistols only','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` preset `pistols_only`'),
('Melee Only','combat','2-32','Solo/teams','Melee weapons only','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` preset `melee_brawl`'),
('Shotgun Arena','combat','2-32','Solo/teams','Shotguns in close quarters arena','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` preset'),
('Random Weapons','combat','2-32','Solo/teams','Random weapon per life from pool','Most kills',None,'Kills',None,'Easy','Low',None,'V1 · `deathmatch` (`randomWeapons=true`)'),
('Elimination Tournament','combat','4-64','Solo','Bracket of duels/LMS matches','Tournament winner',None,'Tournament placement',None,'Medium','Medium',None,'V1 · tournament (single elimination) of `duel`'),
('Duel','combat','2','Solo','1v1, rounds, one life','Best of N rounds',None,'Round wins',None,'Easy','Low',None,'V1 · `deathmatch` preset `pistol_duel` (min=max=2, rounds)'),
('Team Elimination','combat','4-32','2 teams','Elimination rounds, no respawn','Round wins',None,'Round wins',None,'Easy','Low',None,'V1 · `deathmatch` (teams, lives=1)'),
('Juggernaut','combat','3-24','Juggernaut vs everyone','One heavily armoured player vs attackers; killer takes the role','Most points (time as Juggernaut + takedowns)',None,'Role-based points','combat, roles','Medium','Medium',None,'V1 · mode `juggernaut`'),
('Hunter vs Runners','combat','3-24','2 roles','Runners survive with a head start, hunters catch; optional infection','Runners survive / all caught',None,'Survival seconds, catches, survive bonus','roles, combat','Medium','Medium',None,'V1 · mode `hunters`'),
('Assassin Hunt','combat','4-32','Solo','Each player assigned a secret target','Most valid assassinations',None,'Valid target kills +, wrong kills −','combat, roles, secret assignment','Medium','Medium','Target leaks (server only sends own target)','V2'),
('Bounty Hunt','combat','4-32','Solo','Leader carries bounty, visible on map','Most bounty points',None,'Bounty kills','combat, roles, blips','Medium','Medium',None,'V2'),
('Protect the VIP','combat','2-24','2 teams','Bodyguards escort the VIP to extraction; attackers hunt the VIP; rounds with side swap','VIP extracted / killed / timeout',None,'Round wins','roles, combat, zones','Hard','Medium',None,'V1 · mode `vip`'),
# OBJECTIVE
('Capture the Flag','objective','4-32','2 teams','Grab enemy flag at base, return to own base while own flag home','Capture target / most caps',None,'Captures ×points; returns, carrier kills',None,'Medium','Medium',None,'V1 · mode `ctf`'),
('Capture Point','objective','2-32','Solo/teams','Single zone; capture progress by occupancy','Hold target reached',None,'Points per second held',None,'Easy','Low',None,'V1 · mode `koth`'),
('King of the Hill','objective','2-32','Solo/teams','Hold uncontested zone to earn points','Most points / target',None,'Points per second',None,'Easy','Low',None,'V1 · mode `koth`'),
('Territory Control','objective','4-32','2-4 teams','Several zones owned by teams; income per owned zone','Most points',None,'Points per zone per tick',None,'Medium','Low',None,'V1 · mode `koth` (multiple zones, ownership)'),
('Domination','objective','4-32','2 teams','3+ capture points with ownership flip','Score target',None,'Points per owned point',None,'Medium','Low',None,'V1 · mode `koth` preset `domination`'),
('Search and Collect','objective','2-32','Solo/teams','Collect scattered pickups (server proximity)','Most collected',None,'Objective points','checkpoints (unordered), timer','Easy','Low',None,'V1 · mode `hunt` (visible, collect)'),
('Deliver the Package','objective','2-16','Solo/teams','Pick up package, deliver to drop zone','Most deliveries',None,'Delivery points','carriable objective, zones','Medium','Medium',None,'V2 · generalised carriable from ctf'),
('Escort','objective','4-16','2 teams','Move escort target along path by proximity','Target reaches end',None,'Objective','zones, path progress','Hard','High',None,'Future'),
('Attack vs Defense','objective','4-32','2 teams','Attackers capture sequence of points, defenders hold','Attackers capture all / time out',None,'Objective','zones (sequential), teams, combat','Medium','Medium',None,'V2 · `koth` sequential variant'),
('Bomb/Package Delivery','objective','4-32','2 teams','Carry bomb to site, plant, defend','Detonate / defuse',None,'Round wins','carriable, zones, timer, rounds','Hard','High',None,'Future'),
('Hold the Objective','objective','2-32','Solo/teams','Carry an item as long as possible (server tracks carrier)','Most carry time',None,'Points per second carried','carriable','Medium','Medium',None,'V2'),
('Multi-Point Control','objective','4-32','2-4 teams','Multiple simultaneous points','Most points',None,'Points per owned point',None,'Medium','Low',None,'V1 · `koth` multi-zone'),
('Steal and Return','objective','4-16','2 teams','Steal enemy packages to own base (Raid-like)','Most packages',None,'Deliveries',None,'Medium','Medium',None,'V1 · `ctf` (`flagsPerTeam>1`) partial; full V2'),
('Resource Collection','objective','2-32','Solo/teams','Collect resources, bank at base','Most banked',None,'Banked amount','carriable, zones','Medium','Medium',None,'V2'),
('Zone Conquest','objective','4-32','2-4 teams','Sequential map-wide zone capture','All zones captured',None,'Zones owned','zones, teams','Medium','Medium',None,'V2'),
# SURVIVAL
('Zombie-style Survival','survival','1-16','Co-op','Waves of hostile melee NPCs','Survive all waves','All dead','Waves survived, kills','NPC wave spawner, combat','Hard','High','NPC ownership desync, god mode','Future (NPC ownership + performance)'),
('NPC Wave Survival','survival','1-16','Co-op','Escalating armed NPC waves','Survive waves','All dead','Waves, kills','NPC spawner, combat','Hard','High',None,'V2'),
('Increasing Difficulty Survival','survival','1-16','Co-op','Wave modifiers ramp','Survive longest',None,'Survival time','NPC spawner','Hard','High',None,'V2'),
('Vehicle Survival (zone)','survival','1-16','Solo','Stay in vehicle inside shrinking zone','Last alive',None,'Survival points',None,'Medium','Low',None,'V1 · `zone_survival` (`requireVehicle`)'),
('Limited Ammo Survival','survival','2-32','Solo','Last man standing with limited ammo','Last alive',None,'Placement + kills',None,'Medium','Low',None,'V1 · `zone_survival` / `deathmatch` (ammo option)'),
('Last Player Alive','survival','2-64','Solo','Single life, combat allowed','Last alive',None,'Placement',None,'Easy','Low',None,'V1 · `zone_survival`'),
('Safe Zone Survival','survival','2-64','Solo','Must stay in safe zone that moves','Last alive',None,'Survival points',None,'Medium','Low',None,'V1 · `zone_survival` (`moving=true`)'),
('Shrinking Zone','survival','2-64','Solo/teams','Battle zone shrinks in phases; outside = damage then elimination','Last alive',None,'Placement + kills',None,'Medium','Medium',None,'V1 · mode `zone_survival`'),
('Environmental Survival','survival','2-32','Solo','Weather/fire/explosion hazards','Last alive',None,'Survival time','hazard spawner','Hard','High','Cross-bucket explosions (Cfx caveat)','Future'),
# HUNT
('Scavenger Hunt','hunt','1-32','Solo/teams','Find list of locations in any order','Find all first / most at time',None,'Objective points + time bonus',None,'Easy','Low',None,'V1 · mode `hunt`'),
('Checkpoint Hunt','hunt','1-32','Solo','Visible unordered checkpoints across map','All first',None,'Checkpoint points',None,'Easy','Low',None,'V1 · `hunt` (visible)'),
('Hidden Object Hunt','hunt','1-32','Solo','Hidden locations, proximity "warmer/colder"','Most found',None,'Objective points',None,'Medium','Low',None,'V1 · `hunt` (`hidden=true`, hints)'),
('Vehicle Hunt','hunt','1-16','Solo','Find parked target vehicles','Most found',None,'Objective points','hunt + vehicle spawn','Medium','Medium',None,'V2'),
('Landmark Hunt','hunt','1-32','Solo','Clues describe landmarks; reach them','All first',None,'Objective points',None,'Easy','Low',None,'V1 · `hunt` (clue text per target)'),
('Photograph/Location Challenge','hunt','1-32','Solo','Reach a place shown in a picture','Most found',None,'Objective points','hunt + image URLs in NUI','Easy','Low',None,'V1 · `hunt` (target `image` field)'),
('Treasure Hunt','hunt','1-32','Solo/teams','Chain of clues leads to treasure','First to treasure',None,'Placement',None,'Medium','Low',None,'V1 · `hunt` (`ordered=true`, hidden, clues)'),
('Clue Hunt','hunt','1-32','Solo/teams','Clue revealed after each find','Finish chain first',None,'Placement',None,'Medium','Low',None,'V1 · `hunt` ordered'),
('Timed Search','hunt','1-32','Solo','Find as many as possible in time','Most found',None,'Objective points',None,'Easy','Low',None,'V1 · `hunt`'),
('Multi-stage Hunt','hunt','1-32','Solo/teams','Stages with different target sets','Finish all stages',None,'Stage points','hunt stages','Medium','Medium',None,'V2'),
# OBSTACLE
('Parkour','obstacle','1-32','Solo','On-foot ordered checkpoints; falling resets to last checkpoint','Fastest finish',None,'Placement by time',None,'Medium','Low',None,'V1 · mode `race` (`onFoot=true`)'),
('Obstacle Course','obstacle','1-32','Solo','On-foot course, bounds reset','Fastest finish',None,'Placement',None,'Medium','Low',None,'V1 · `race` (`onFoot`)'),
('Rooftop Challenge','obstacle','1-32','Solo','Rooftop parkour route','Fastest finish',None,'Placement',None,'Hard','Low',None,'V1 · `race` (`onFoot`) preset'),
('Precision Driving','obstacle','1-16','Solo','Tight checkpoints; penalty per touch of wall (vehicle damage delta)','Best time − penalties',None,'Time + damage penalty','vehicles, checkpoints, server vehicle health','Medium','Medium',None,'V2'),
('Precision Parking','obstacle','1-16','Solo','Stop inside a small zone with low speed & heading tolerance','Best accuracy/time',None,'Accuracy points','vehicles, zones, server heading/velocity','Medium','Medium',None,'V2'),
('Stunt Challenge','obstacle','1-16','Solo','Stunt jumps & airtime measured','Best score',None,'Stunt points','vehicle telemetry (client) + sanity checks','Hard','High','Client telemetry spoof','Future'),
('Jump Challenge','obstacle','1-16','Solo','Longest jump distance (server start/land positions)','Longest distance',None,'Distance','vehicles, server position sampling','Medium','Medium',None,'V2'),
('Landing Challenge','obstacle','1-16','Solo','Parachute/aircraft land closest to target','Closest landing',None,'Distance to target','zones, server position','Easy','Low',None,'V2'),
('Balance Challenge','obstacle','1-16','Solo','Stay on narrow structure longest','Last on structure',None,'Survival time','bounds (z/height)','Easy','Low',None,'V2 · on-foot bounds (height) preset'),
('Skill Course','obstacle','1-16','Solo','Mixed checkpoint course','Fastest finish',None,'Placement',None,'Medium','Low',None,'V1 · `race`'),
# SOCIAL
('Musical Chairs','social','2-32','Solo','Music stops → reach one of N-1 chairs (server occupancy, closest to center keeps it)','Last remaining','No chair when the round ends','Placement by elimination order','zones, rounds','Easy','Medium',None,'V1 · mode `musical_chairs`'),
('Random Challenge','social','2-64','Solo','Director picks a random quick challenge','Challenge winner',None,'Per challenge','director, social modes','Easy','Low',None,'V1 · director with social pool'),
('Simon Says','social','3-32','Solo','Host issues commands; failures eliminated','Last remaining',None,'Placement','host tools, rounds','Easy','Medium','Host bias (social)','V2'),
('Freeze / Movement Challenge','social','2-64','Solo','Don\'t move for N seconds (server coords)','Last remaining',None,'Placement',None,'Easy','Low',None,'V1 · mode `redlight` (always red)'),
('Red Light / Green Light','social','2-64','Solo','Move on green, freeze on red; server measures displacement; reach finish line','First to finish / survivors',None,'Placement',None,'Easy','Low',None,'V1 · mode `redlight`'),
('Trivia','social','2-64','Solo','Server-timed multiple choice questions','Most points',None,'Correct × points + speed bonus',None,'Easy','Low',None,'V1 · mode `trivia`'),
('Reaction Challenge','social','2-64','Solo','Press when signal appears (server-timed); early = penalty','Fastest average',None,'Reaction points',None,'Easy','Low',None,'V1 · mode `reaction`'),
('Quick Draw','social','2-16','Solo','Duel: draw & fire on signal','Fastest valid shot',None,'Round wins','reaction + combat','Medium','Medium',None,'V2'),
('Memory Challenge','social','2-64','Solo','Remember sequence shown by server','Most correct',None,'Correct answers','trivia engine (sequence questions)','Easy','Low',None,'V2 · sequence question type for `trivia`'),
('Guessing Challenge','social','2-64','Solo','Guess a number/value, closest wins','Closest answers',None,'Closeness points','trivia engine (numeric)','Easy','Low',None,'V1 · `trivia` (`numeric` question type)'),
('Random Mini Challenge','social','2-64','Solo','Rotation of short social modes','Challenge winner',None,'Per challenge','director','Easy','Low',None,'V1 · director'),
('Staff Challenge','social','2-64','Solo','Staff-hosted with manual scoring via admin panel','Staff decision',None,'Manual points (audited)','admin manual scoring','Easy','Low','Staff abuse (audit logged)','V1 · mode `custom` (manual)'),
('Community Challenge','social','any','Everyone','Server-wide goal (e.g. collective count)','Goal reached',None,'Participation','global counters, API','Easy','Medium',None,'V2 · API-driven'),
# TOURNAMENT
('1v1 Tournament','tournament','4-64','Solo','Bracket of duel matches','Win final',None,'Tournament points',None,'Medium','Medium',None,'V1 · single elimination'),
('2v2 Tournament','tournament','8-64','Teams of 2','Team bracket','Win final',None,'Tournament points','tournament engine + pre-made teams','Medium','Medium',None,'V1 · single elimination with fixed teams'),
('3v3 Tournament','tournament','12-48','Teams of 3','Team bracket','Win final',None,'Tournament points',None,'Medium','Medium',None,'V1 · single elimination with fixed teams'),
('Team Tournament','tournament','8-64','Teams','Generic team bracket','Win final',None,'Tournament points',None,'Medium','Medium',None,'V1'),
('Knockout Bracket','tournament','4-64','Any','Single elimination with byes and seeding','Win final',None,'Placement by round reached',None,'Medium','Medium',None,'V1'),
('Swiss-style Tournament','tournament','8-64','Any','Pair by record each round','Best record',None,'Match points + tiebreaks','swiss pairing','Hard','High',None,'V2'),
('League','tournament','4-16','Any','Round robin, points per win/draw','Most league points',None,'League points',None,'Medium','Medium',None,'V1 · round robin'),
('Seasonal Championship','tournament','any','Solo','Season points across all events','Most season points',None,'Season points from every event','season leaderboards','Easy','Low',None,'V1 · season leaderboard'),
('Grand Final','tournament','2-16','Any','Final match/series between qualifiers','Win final',None,'Tournament points','manual seeding from leaderboard','Medium','Low',None,'V1 · tournament seeded from leaderboard (manual)'),
('Best-of-3','tournament','2+','Any','Series: first to 2 match wins','Win series',None,'Series wins',None,'Easy','Low',None,'V1 · series option'),
('Best-of-5','tournament','2+','Any','Series: first to 3 match wins','Win series',None,'Series wins',None,'Easy','Low',None,'V1 · series option'),
('Points Championship','tournament','any','Any','Fixed list of events, points accumulate','Most points',None,'Championship points','championship grouping','Medium','Medium',None,'V2 · championship object (season tags)'),
]

def status_tag(s):
    if s.startswith('V1'): return 'V1'
    if s.startswith('V2'): return 'V2'
    return 'Future'

out = []
w = out.append
w('# EVENT STUDIO — Event Catalog\n')
w('> Generated from structured data (source: `tools/gen_catalog.py`). Every entry is a **preset or option of a reusable mode**, not a separate script.\n')
w('> Status: **V1** = playable in V1 via the named mode · **V2** = architecture-ready, needs a new component/option · **Future** = later expansion.\n')
counts = {'V1':0,'V2':0,'Future':0}
for e in E: counts[status_tag(e[12])] += 1
w(f'**Totals:** {len(E)} events · V1 {counts["V1"]} · V2 {counts["V2"]} · Future {counts["Future"]}\n')
w('## V1 modes (the reusable engine modes)\n')
w('| Mode | Category | Components | Catalog entries served |')
w('|---|---|---|---|')
modes = [
 ('race','racing / obstacle','vehicles, checkpoints, spawns, combat(off), bounds(optional)'),
 ('sumo','vehicle','vehicles, bounds, zones(shrink), spawns'),
 ('deathmatch','combat','combat, spawns, teams, rounds'),
 ('gungame','combat','combat, spawns'),
 ('koth','objective / vehicle','zones, teams, combat, spawns'),
 ('ctf','objective','teams, zones, combat, spawns (carriable flags)'),
 ('zone_survival','survival','zones(shrink), combat, bounds, spawns'),
 ('hunt','hunt','checkpoints(unordered/hidden), spawns'),
 ('redlight','social','zones(finish), server displacement check'),
 ('trivia','social','server rounds, NUI input'),
 ('reaction','social','server rounds, NUI input'),
 ('custom','social / any','manual scoring by staff, API scoring'),
 ('juggernaut','combat','roles, combat, spawns'),
 ('vip','combat','teams, roles, combat, zones'),
 ('hunters','combat','roles, combat, spawns'),
 ('keep_moving','vehicle','vehicles, server velocity, bounds'),
 ('musical_chairs','social','dynamic zones, rounds'),
]
for m,c,comp in modes:
    served = sum(1 for e in E if f'`{m}`' in e[12] and status_tag(e[12])=='V1')
    w(f'| `{m}` | {c} | {comp} | {served} |')
w('')
for key,meta in CAT.items():
    w(f'## {meta["title"]}\n')
    n=0
    for i,e in enumerate(E,1):
        if e[1]!=key: continue
        name,cat,players,teams,mech,win,lose,scoring,systems,diff,cx,expl,status=e
        lose = lose or meta['lose']; systems = systems or meta['sys']; expl = expl if expl else meta['exploits']
        w(f'### {i}. {name}  ·  **{status_tag(status)}**\n')
        w('| Field | Value |')
        w('|---|---|')
        rows = [('Category',meta['title']),('Players',players),('Teams',teams),('Core mechanic',mech),('Win condition',win),
                ('Lose condition',lose),('Scoring',scoring),('Required systems',systems),('Dependencies',meta['deps']),
                ('Difficulty (player)',diff),('Development complexity',cx),('Potential exploits',expl),('Status',status)]
        for k,v in rows: w(f'| {k} | {v} |')
        w('')
open(sys.argv[1],'w').write('\n'.join(out)+'\n')
print(len(E), counts)
