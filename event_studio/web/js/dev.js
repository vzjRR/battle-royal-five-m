// EVENT STUDIO — development preview (loaded only outside FiveM). Open web/index.html#browser|admin|hud|results|trivia
// in a normal browser to work on the UI without a server. Not used in-game.
const strings = {};
const send = (action, data) => window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
const now = Math.floor(Date.now() / 1000);

const cards = [
    { id: 1001, name: 'Downtown Street Circuit', category: 'racing', icon: '🏁', color: '#ff6b3d', mode: 'race', modeLabel: 'Race', difficulty: 'medium', status: 'open', state: 'REGISTRATION', players: 5, maxPlayers: 8, minPlayers: 2, remainingMs: 94000, duration: 600, reward: '$10,000', spectators: true },
    { id: 1002, name: 'Team Deathmatch', category: 'combat', icon: '🎯', color: '#ff3d71', mode: 'deathmatch', modeLabel: 'Deathmatch', difficulty: 'medium', status: 'live', state: 'ACTIVE', players: 12, maxPlayers: 16, minPlayers: 4, remainingMs: 312000, duration: 900, reward: '$5,000', teams: 2, spectators: true },
    { id: 1003, name: 'Trivia Night', category: 'social', icon: '🎲', color: '#ff6bd6', mode: 'trivia', modeLabel: 'Trivia', difficulty: 'easy', status: 'starting', state: 'COUNTDOWN', players: 22, maxPlayers: 64, minPlayers: 2, remainingMs: 4000, duration: 0, reward: '$7,500' },
    { id: 1004, name: 'Sumo', category: 'vehicle', icon: '🚙', color: '#ffb020', mode: 'sumo', modeLabel: 'Sumo / Derby', difficulty: 'hard', status: 'full', state: 'REGISTRATION', players: 8, maxPlayers: 8, minPlayers: 2, remainingMs: 40000, duration: 300, reward: '$7,500' },
];

const responses = {
    'browser:list': { live: cards, upcoming: [
        { at: now + 3600 * 5, name: 'Friday Street Race', category: 'racing' },
        { at: now + 86400 + 3600, name: 'Saturday TDM', category: 'combat' },
        { at: now + 2 * 86400, name: 'City Scavenger Hunt', category: 'hunt' }],
        tournaments: [{ id: 't1', name: 'Pistol Duel Cup', status: 'registration', format: 'single_elimination', bestOf: 3, entrants: 6 }] },
    'browser:details': { ...cards[0], description: 'Three laps through the heart of the city. Traffic is disabled in the event instance.',
        rules: 'Vehicles are provided and you cannot leave them. Checkpoints must be passed in order.',
        rewards: [{ label: '#1', items: ['$10,000'] }, { label: '#2', items: ['$6,000'] }, { label: '#3', items: ['$3,000'] }, { label: 'participation', items: ['$500'] }],
        participants: [{ name: 'Nova' }, { name: 'Kai' }, { name: 'Rook' }, { name: 'Vega' }, { name: 'Juno' }],
        bests: [{ rank: 1, name: 'Nova', best_ms: 187432 }, { rank: 2, name: 'Rook', best_ms: 190110 }] },
    'leaderboard:get': { season: '2026-09', rows: [
        { rank: 1, name: 'Nova', points: 1240, wins: 9, podiums: 17, joined: 31, kills: 88 }, { rank: 2, name: 'Rook', points: 1105, wins: 7, podiums: 15, joined: 29, kills: 120 },
        { rank: 3, name: 'Kai', points: 990, wins: 5, podiums: 12, joined: 33, kills: 61 }, { rank: 4, name: 'Vega', points: 812, wins: 3, podiums: 9, joined: 25, kills: 45 }] },
};

const adminData = {
    version: '0.1.0-alpha', role: 'admin', level: 40, framework: 'standalone', inventory: 'standalone', storage: 'kvp', season: '2026-09', director: false,
    perms: Object.fromEntries(['admin.open', 'logs.view', 'definition.view', 'definition.edit', 'definition.delete', 'arena.edit', 'schedule.view', 'schedule.edit', 'director.toggle',
        'instance.create', 'instance.start', 'instance.pause', 'instance.stop', 'instance.cancel', 'instance.restart', 'instance.announce', 'instance.manualScore',
        'player.add', 'player.remove', 'player.teleport', 'player.reset', 'player.disqualify', 'player.reward', 'spectate.any', 'tournament.edit'].map((k) => [k, true])),
    modes: [
        { id: 'race', label: 'Race', category: 'racing', teams: 'none', needsArena: true, requires: ['checkpoints'], description: 'Ordered checkpoints with laps.',
          options: [{ key: 'laps', type: 'integer', label: 'Laps', min: 1, max: 50, default: 1 }, { key: 'onFoot', type: 'boolean', label: 'On foot', default: false },
                    { key: 'vehicle', type: 'object', label: 'Vehicle', fields: [{ key: 'model', type: 'string', label: 'model', default: 'sultan' }, { key: 'type', type: 'enum', label: 'type', values: ['automobile', 'bike', 'boat'], default: 'automobile' }] },
                    { key: 'eliminateEvery', type: 'integer', label: 'Eliminate last place every N seconds', default: 0 }] },
        { id: 'deathmatch', label: 'Deathmatch', category: 'combat', teams: 'optional', needsArena: true, requires: ['spawns'], description: 'FFA or teams.',
          options: [{ key: 'weapons', type: 'list', item: 'string', label: 'Weapons', default: ['WEAPON_PISTOL', 'WEAPON_SMG'] }, { key: 'killTarget', type: 'integer', label: 'Kill target', default: 30 }] },
    ],
    definitions: cards.map((c) => ({ id: `def_${c.id}`, name: c.name, mode: c.mode, category: c.category, minPlayers: c.minPlayers, maxPlayers: c.maxPlayers, visibility: 'public', enabled: true, status: 'published', source: 'config' })),
    arenas: [{ id: 'downtown_circuit', name: 'Downtown Circuit', source: 'config', counts: { spawns: 0, checkpoints: 8, zones: 0, targets: 0, vehicleSpawns: 8 } },
             { id: 'docks_yard', name: 'Docks Container Yard', source: 'config', counts: { spawns: 8, checkpoints: 0, zones: 1, targets: 0, vehicleSpawns: 0 } }],
    instances: cards, schedules: [{ id: 'friday_street_race', definition: 'street_circuit', rule: { type: 'weekly', days: [5], time: '21:00' }, enabled: true, source: 'config', nextAt: now + 3600 * 5 }],
    upcoming: responses['browser:list'].upcoming, scoringProfiles: ['standard', 'casual', 'competitive'],
    categories: ['racing', 'vehicle', 'combat', 'objective', 'survival', 'hunt', 'obstacle', 'social', 'tournament'],
    definitionDefaults: { players: { min: 2, max: 16, reconnectGrace: 60 }, timing: { registration: 120, lobby: 10, countdown: 5, duration: 600, grace: 30, results: 15, extendOnce: 60 } },
    tournaments: [{ id: 't1', name: 'Pistol Duel Cup', format: 'single_elimination', bestOf: 3, status: 'running',
        entrants: [{ key: 'a', name: 'Nova' }, { key: 'b', name: 'Rook' }, { key: 'c', name: 'Kai' }, { key: 'd', name: 'Vega' }],
        rounds: [[{ id: 'r1m1', a: 'a', b: 'd', winner: 'a', wins: { a: 2, b: 0 } }, { id: 'r1m2', a: 'c', b: 'b', winner: 'b', wins: { a: 1, b: 2 } }], [{ id: 'r2m1', a: 'a', b: 'b', wins: { a: 1, b: 1 } }]] }],
};
responses['admin:instances'] = cards;
responses['admin:history'] = [{ name: 'Airport Time Trial', finalState: 'COMPLETED', winner: 'Nova', participants: 7, endedAt: now - 3600 }];
responses['admin:instance:detail'] = { card: cards[1], state: 'ACTIVE', remainingMs: 312000, bucket: 7101, leader: 'Rook',
    teams: [{ index: 1, name: 'Red', color: '#ff4d5e', score: 23 }, { index: 2, name: 'Blue', color: '#3d8bff', score: 19 }],
    spectators: [{ src: 9, name: 'StaffMember' }], participants: [
        { src: 2, name: 'Rook', status: 'active', team: 1, score: 9, stats: { kills: 9, deaths: 3 }, ping: 34 },
        { src: 3, name: 'Nova', status: 'active', team: 2, score: 8, stats: { kills: 8, deaths: 5 }, ping: 52 },
        { src: 4, name: 'Kai', status: 'disconnected', team: 1, score: 3, stats: { kills: 3, deaths: 6 } }] };
responses['admin:players:online'] = [{ src: 5, name: 'Juno' }, { src: 6, name: 'Orion' }];
responses['admin:logs'] = [{ created_at: now - 60, level: 'audit', action: 'instance.start', actor: 'Admin (license:x) [1]', instance_id: 1002 },
    { created_at: now - 120, level: 'security', action: 'checkpoint_too_fast', actor: 'Cheater (license:y) [7]', data: { ms: 120, minMs: 900 } }];
responses['admin:leaderboard'] = responses['leaderboard:get'];

window.__devPost = async (name, data) => {
    if (name === 'rpc') return { ok: true, res: responses[data.name] ?? true };
    return { ok: true };
};

const en = await fetch('../locales/en.lua').then((r) => r.text()).catch(() => '');
for (const m of en.matchAll(/\['ui\.([\w]+)'\] = '((?:[^'\\]|\\.)*)'/g)) strings[m[1]] = m[2].replace(/\\'/g, "'");

send('init', { strings, staff: true, role: 'admin', ui: {
    theme: 'default', brand: { title: 'Event Studio', subtitle: 'Community Events' }, hudPosition: 'top-right', scoreboardRows: 5, dateFormat: 'en-GB',
    categories: { racing: { icon: '🏁', color: '#ff6b3d' }, vehicle: { icon: '🚙', color: '#ffb020' }, combat: { icon: '🎯', color: '#ff3d71' }, objective: { icon: '🚩', color: '#3dd6ff' },
        survival: { icon: '🛡️', color: '#7cff6b' }, hunt: { icon: '🧭', color: '#c36bff' }, obstacle: { icon: '🧗', color: '#6b8cff' }, social: { icon: '🎲', color: '#ff6bd6' }, tournament: { icon: '🏆', color: '#ffd23d' } } } });

document.body.style.background = 'linear-gradient(135deg, #2b3a4a, #1a2230 60%, #3a2b2b)';
const scene = location.hash.slice(1) || 'browser';
const race = { id: 1001, name: 'Downtown Street Circuit', mode: 'race', category: 'racing', state: 'ACTIVE', remainingMs: 402000, role: 'participant', selfSrc: 3,
    objective: 'Pass every checkpoint and finish first.', you: { status: 'active', score: 0 }, hud: { lap: 2, laps: 3, checkpoint: 5, checkpoints: 8, position: 2, racers: 6 } };
const rows = [{ src: 2, name: 'Rook', placement: 1, status: 'active', score: 0, extra: 'L2 · 6/8' }, { src: 3, name: 'Nova', placement: 2, status: 'active', score: 0, extra: 'L2 · 5/8' },
    { src: 4, name: 'Kai', placement: 3, status: 'active', score: 0, extra: 'L2 · 3/8' }, { src: 5, name: 'Vega', placement: 4, status: 'active', score: 0, extra: 'L1 · 8/8' },
    { src: 6, name: 'Juno', placement: 5, status: 'eliminated', score: 0, extra: 'L1 · 4/8' }];
if (scene === 'browser') send('open', { view: 'browser' });
if (scene === 'admin' || scene === 'live' || scene === 'builder' || scene === 'tournaments') {
    send('open', { view: 'admin', data: adminData });
    if (scene !== 'admin') setTimeout(() => document.querySelectorAll('.nav').forEach((b) => { if (b.textContent.toLowerCase().includes(scene === 'live' ? 'live' : scene === 'builder' ? 'builder' : 'tournament')) b.click(); }), 50);
}
if (scene === 'hud') { send('state', race); send('scoreboard', { rows }); send('toast', { text: 'Registration open: Trivia Night (#1003). Use /events to join!', kind: 'global' }); }
if (scene === 'results') send('results', { name: 'Downtown Street Circuit', winner: 'Rook', remainingMs: 60000, rows: [
    { src: 2, name: 'Rook', placement: 1, status: 'finished', score: 0, kills: 0, finishMs: 187432, points: 110 },
    { src: 3, name: 'Nova', placement: 2, status: 'finished', score: 0, kills: 0, finishMs: 189001, points: 85 },
    { src: 4, name: 'Kai', placement: 3, status: 'finished', score: 0, kills: 0, finishMs: 193870, points: 60 },
    { src: 6, name: 'Juno', placement: null, status: 'left', score: 0, kills: 0, points: -10 }] });
if (scene === 'trivia') {
    send('state', { ...race, name: 'Trivia Night', mode: 'trivia', category: 'social', hud: { question: 3, questions: 10 }, objective: 'Answer quickly and correctly.' });
    send('mode', { trivia: { phase: 'question', index: 3, total: 10, text: 'Which planet is known as the Red Planet?', answers: ['Venus', 'Jupiter', 'Mars', 'Mercury'], remainingMs: 15000 } });
}
if (scene === 'tdm') {
    send('state', { ...race, name: 'Team Deathmatch', mode: 'deathmatch', category: 'combat', objective: 'Eliminate opponents.', hud: { kills: 7, deaths: 3, target: 50 },
        teams: [{ index: 1, name: 'Red', color: '#ff4d5e', score: 23 }, { index: 2, name: 'Blue', color: '#3d8bff', score: 19 }] });
    send('scoreboard', { rows: rows.map((r, i) => ({ ...r, team: (i % 2) + 1, extra: `${9 - i} / ${i + 2}` })), teams: [{ index: 1, name: 'Red', color: '#ff4d5e', score: 23 }, { index: 2, name: 'Blue', color: '#3d8bff', score: 19 }] });
    send('mode', { banner: { text: 'RED LIGHT', color: '#ff3d5e' } });
}
