// EVENT STUDIO — Admin Center. Controls are hidden when the server says the role lacks a permission;
// the server still enforces every action.
import { h, $, mount, show, t, errText, fmtClock, fmtDate, fmtRace, categoryOf, placeBadge, statusChip, store, badge, ico } from '../ui.js';
import { rpc, closePanels } from '../app.js';
import { toast } from '../hud.js';
import { builderView } from './builder.js';
import { arenaView, onArenaCheck, onArenaRecorded } from './arenas.js';
export { onArenaCheck, onArenaRecorded };
import { appearanceView, onAppearanceUI, discardPreview } from './appearance.js';
import { logoOf } from '../theme.js';
import { flagOman } from '../icons.js';

export const A = { data: null, section: 'dashboard', liveId: null, liveTimer: null, logs: [], history: [], players: [], editing: null, board: [] };

const sections = [
    ['dashboard', 'home', 'dashboard'], ['definitions', 'list', 'definitions'], ['builder', 'pencil', 'builder'], ['arenas', 'pin', 'arenas'],
    ['scheduler', 'clock', 'scheduler'], ['live', 'live', 'live_events'], ['tournaments', 'trophy', 'tournaments'], ['leaderboard', 'star', 'leaderboard'],
    ['logs', 'logs', 'logs'], ['appearance', 'palette', 'appearance'], ['settings', 'settings', 'settings'],
];

export const can = (action) => !!(A.data && A.data.perms && A.data.perms[action]);

export function confirmDialog(title, text, onOk) {
    const el = $('confirm');
    mount(el, h('div.box', h('h3', title), h('p', text || t('dangerous_action')),
        h('div.row', h('button.btn', { onclick: () => show(el, false) }, t('cancel')),
            h('button.btn.danger', { onclick: () => { show(el, false); onOk(); } }, t('confirm')))));
    show(el, true);
}

export async function call(name, payload, okText) {
    const r = await rpc(name, payload);
    if (!r.ok) { toast({ text: errText(r.res), kind: 'error' }); return null; }
    if (okText) toast({ text: okText, kind: 'success' });
    return r.res === undefined ? true : r.res;
}

/** Dangerous action wrapper: confirm dialog + confirm flag for the server. */
export function danger(name, payload, label, after) {
    confirmDialog(label, t('are_you_sure'), async () => {
        const res = await call(name, { ...payload, confirm: true }, t('saved'));
        if (res && after) after(res);
    });
}

export async function refresh() {
    const r = await rpc('admin:bootstrap');
    if (r.ok) A.data = r.res;
    render();
}

export function open(data) {
    A.data = data;
    show($('admin'), true);
    render();
}

export function onClose() { clearInterval(A.liveTimer); A.liveTimer = null; discardPreview(); }

export function go(section, extra) {
    if (A.section === 'appearance' && section !== 'appearance') discardPreview();
    A.section = section;
    clearInterval(A.liveTimer);
    A.liveTimer = null;
    if (extra) Object.assign(A, extra);
    if (section === 'logs') loadLogs();
    if (section === 'dashboard') loadHistory();
    if (section === 'leaderboard') loadBoard('*');
    if (section === 'live') startLive();
    render();
}

// Sections -------------------------------------------------------------------

function dashboard() {
    const d = A.data;
    const live = d.instances.filter((i) => i.status === 'live' || i.status === 'starting');
    const open = d.instances.filter((i) => i.status === 'open');
    return h('div.scroll.pad',
        h('div.stats',
            h('div.stat', h('b', String(live.length)), h('span', t('live_events'))),
            h('div.stat', h('b', String(open.length)), h('span', t('status_open'))),
            h('div.stat', h('b', String(d.definitions.filter((x) => x.enabled).length)), h('span', t('definitions'))),
            h('div.stat', h('b', String(d.schedules.filter((s) => s.enabled).length)), h('span', t('scheduler')))),
        h('div.grid2',
            h('div.box', h('div.box-head', t('live_events'), h('div.spacer'), h('button.btn.sm', { onclick: () => go('live') }, document.documentElement.dir === 'rtl' ? '←' : '→')),
                d.instances.length ? h('table.tbl', d.instances.map((i) => h('tr', { style: { cursor: 'pointer' }, onclick: () => go('live', { liveId: i.id }) },
                    h('td', h('span.row', badge(i.category, null, 'badge-sm'), i.name)), h('td', statusChip(i.status)), h('td.num', `${i.players}/${i.maxPlayers}`)))) : h('div.empty', '—')),
            h('div.box', h('div.box-head', t('upcoming')),
                d.upcoming.length ? h('table.tbl', d.upcoming.map((u) => { const w = fmtDate(u.at); return h('tr', h('td', u.name), h('td.num', `${w.day} ${w.time}`)); })) : h('div.empty', '—'))),
        h('div.box', { style: { marginTop: '14px' } }, h('div.box-head', t('history')),
            A.history.length ? h('table.tbl', A.history.map((s) => s && h('tr', h('td', s.name || s.definitionId), h('td', s.finalState), h('td', s.winner || '—'),
                h('td.num', String(s.participants || 0)), h('td.num', s.endedAt ? `${fmtDate(s.endedAt).day} ${fmtDate(s.endedAt).time}` : '')))) : h('div.empty', '—')));
}

function definitions() {
    const list = A.data.definitions;
    return h('div.scroll.pad',
        h('table.tbl',
            h('tr', h('th', t('name')), h('th', t('mode')), h('th', t('category')), h('th', t('players')), h('th', t('visibility')), h('th', t('status')), h('th', '')),
            list.map((d) => h('tr',
                h('td', h('b', d.name), h('div.faint.mono', d.id)),
                h('td', d.mode), h('td', h('span.row', badge(d.category, null, 'badge-sm'), d.category)), h('td', `${d.minPlayers}-${d.maxPlayers}${d.teams ? ` · ${d.teams}T` : ''}`),
                h('td', d.visibility), h('td', d.status === 'draft' ? h('span.chip', t('draft')) : (d.enabled ? h('span.chip.open', t('enabled')) : h('span.chip.full', t('disabled')))),
                h('td', h('div.controls',
                    can('instance.create') ? h('button.btn.sm.primary', { onclick: async () => { const r = await call('admin:instance:create', { definition: d.id }, t('saved')); if (r) go('live', { liveId: r.id }); } }, t('run_now')) : null,
                    can('definition.edit') ? h('button.btn.sm', { onclick: async () => { const def = await call('admin:definition:get', { id: d.id }); if (def) go('builder', { editing: def }); } }, t('edit')) : null,
                    can('definition.edit') ? h('button.btn.sm', { onclick: async () => { const def = await call('admin:definition:get', { id: d.id }); if (def) go('builder', { editing: { ...def, id: def.id + '_copy', name: def.name + ' (copy)' } }); } }, t('duplicate')) : null,
                    can('definition.edit') ? h('button.btn.sm', { onclick: async () => { if (await call('admin:definition:toggle', { id: d.id, enabled: !d.enabled })) refresh(); } }, d.enabled ? t('disabled') : t('enabled')) : null,
                    can('definition.delete') && d.source === 'storage' ? h('button.btn.sm.danger', { onclick: () => danger('admin:definition:delete', { id: d.id }, t('delete'), refresh) }, t('delete')) : null))))));
}

function ruleText(r) {
    if (!r) return '';
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (r.type === 'weekly') return `weekly ${r.days.map((d) => days[d]).join(', ')} ${r.time}`;
    if (r.type === 'monthly') return `monthly day ${r.day} ${r.time}`;
    if (r.type === 'once') return `once ${r.date} ${r.time}`;
    if (r.type === 'interval') return `every ${r.minutes} min ${r.from || ''}-${r.to || ''}`;
    return `${r.type} ${r.time || ''}`;
}

function scheduler() {
    const defs = A.data.definitions;
    const f = { id: '', definition: defs[0] && defs[0].id, type: 'weekly', days: '5', time: '21:00', day: 1, date: '', minutes: 90, lead: 5 };
    const input = (key, attrs = {}) => h('input', { value: f[key], oninput: (e) => { f[key] = e.target.value; }, ...attrs });
    const save = async () => {
        const rule = { type: f.type };
        if (f.type === 'interval') Object.assign(rule, { minutes: Number(f.minutes), from: '12:00', to: '23:59' });
        else rule.time = f.time;
        if (f.type === 'weekly') rule.days = String(f.days).split(',').map((x) => Number(x.trim())).filter(Boolean);
        if (f.type === 'monthly') rule.day = Number(f.day);
        if (f.type === 'once') rule.date = f.date;
        const res = await call('admin:schedule:save', { schedule: { id: f.id || `s_${Date.now().toString(36)}`, definition: f.definition, rule, leadMinutes: Number(f.lead) } }, t('saved'));
        if (res) refresh();
    };
    return h('div.scroll.pad',
        h('div.box', h('div.box-head', t('scheduler'), h('div.spacer'),
            can('director.toggle') ? h('label.row', h('input', { type: 'checkbox', checked: A.data.director, onchange: async (e) => { await call('admin:director:toggle', { enabled: e.target.checked }, t('saved')); refresh(); } }), t('director')) : null),
            h('table.tbl', h('tr', h('th', t('id')), h('th', t('definitions')), h('th', t('rule')), h('th', t('next_run')), h('th', '')),
                A.data.schedules.map((s) => h('tr', h('td.mono', s.id), h('td', s.definition || `rotation: ${s.rotation}`), h('td', ruleText(s.rule)),
                    h('td', s.nextAt ? `${fmtDate(s.nextAt).day} ${fmtDate(s.nextAt).time}` : '—'),
                    h('td', h('div.controls',
                        can('schedule.edit') ? h('button.btn.sm', { onclick: async () => { if (await call('admin:schedule:toggle', { id: s.id, enabled: !s.enabled })) refresh(); } }, s.enabled ? t('enabled') : t('disabled')) : null,
                        can('schedule.edit') && s.source !== 'config' ? h('button.btn.sm.danger', { onclick: () => danger('admin:schedule:delete', { id: s.id }, t('delete'), refresh) }, t('delete')) : null)))))),
        can('schedule.edit') ? h('div.box', { style: { marginTop: '14px' } }, h('div.box-head', t('new_schedule')),
            h('div.pad.form',
                h('div.field', h('label', t('id')), input('id', { placeholder: 'friday_race' })),
                h('div.field', h('label', t('definitions')), h('select', { onchange: (e) => { f.definition = e.target.value; } }, defs.map((d) => h('option', { value: d.id }, d.name)))),
                h('div.field', h('label', t('type')), h('select', { onchange: (e) => { f.type = e.target.value; } }, ['weekly', 'daily', 'monthly', 'once', 'interval'].map((x) => h('option', { value: x }, x)))),
                h('div.field', h('label', 'HH:MM'), input('time')),
                h('div.field', h('label', 'Days (1=Mon … 7=Sun, comma separated)'), input('days')),
                h('div.field', h('label', 'Day of month / Date (YYYY-MM-DD) / Interval minutes'), h('div.row', input('day', { type: 'number' }), input('date', { placeholder: '2026-12-31' }), input('minutes', { type: 'number' }))),
                h('div.field', h('label', 'Lead minutes (registration opens before start)'), input('lead', { type: 'number' })),
                h('div.field', h('label', ' '), h('button.btn.primary', { onclick: save }, t('save'))))) : null);
}

// Live ------------------------------------------------------------------------

async function startLive() {
    const tickLive = async () => {
        const r = await rpc('admin:instances');
        if (r.ok) A.data.instances = r.res;
        if (!A.liveId && A.data.instances.length) {
            const pick = A.data.instances.find((i) => i.status === 'live') || A.data.instances[0];
            A.liveId = pick.id;
        }
        if (A.liveId) {
            const d = await rpc('admin:instance:detail', { id: A.liveId });
            A.liveDetail = d.ok ? d.res : null;
            if (!d.ok) A.liveId = null;
        }
        if (A.section === 'live' && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'SELECT') render();
    };
    await tickLive();
    A.liveTimer = setInterval(tickLive, 2000);
    const p = await rpc('admin:players:online');
    if (p.ok) A.players = p.res;
}

function liveControls(d) {
    const id = d.card.id;
    const st = d.state;
    const btn = (label, rpcName, perm, cls = '', dangerous = false, show_ = true) => (can(perm) && show_) ? h(`button.btn.sm${cls}`, {
        onclick: () => dangerous ? danger(rpcName, { id }, label) : call(rpcName, { id }, t('saved')),
    }, label) : null;
    return h('div.controls',
        btn(t('start'), 'admin:instance:start', 'instance.start', '.primary', false, st === 'REGISTRATION' || st === 'SCHEDULED'),
        btn(t('force_start'), 'admin:instance:forceStart', 'instance.start', '', true, st === 'REGISTRATION' || st === 'SCHEDULED'),
        btn(t('pause'), 'admin:instance:pause', 'instance.pause', '', false, st === 'ACTIVE'),
        btn(t('resume'), 'admin:instance:resume', 'instance.pause', '.good', false, st === 'PAUSED'),
        btn(t('stop'), 'admin:instance:stop', 'instance.stop', '.danger', true, st === 'ACTIVE' || st === 'PAUSED' || st === 'FINISHING'),
        btn(t('restart'), 'admin:instance:restart', 'instance.restart', '', true),
        btn(t('cancel'), 'admin:instance:cancel', 'instance.cancel', '.danger', true, !['RESULTS', 'REWARDS', 'ARCHIVED', 'CANCELLED'].includes(st)),
        can('spectate.any') ? h('button.btn.sm', { onclick: async () => { if (await call('admin:spectate', { id })) closePanels(); } }, t('spectate')) : null);
}

function liveDetail() {
    const d = A.liveDetail;
    if (!d) return h('div.empty', t('live_events'));
    const id = d.card.id;
    let announce = '';
    let addTarget = A.players[0] && A.players[0].src;
    const pAction = (label, name, target, perm, dangerous, extra = {}) => can(perm) ? h('button.btn.sm' + (dangerous ? '.danger' : ''), {
        onclick: () => dangerous ? danger(name, { id, target, ...extra }, label) : call(name, { id, target, ...extra }, t('saved')),
    }, label) : null;
    return h('div.col', { style: { gap: '14px' } },
        h('div.box', h('div.box-head', badge(d.card.category, null, 'badge-sm'), d.card.name, h('span.faint.mono', `#${id}`), h('div.spacer'), statusChip(d.card.status), h('span.mono', { style: { marginInlineStart: '10px' } }, d.state)),
            h('div.pad',
                h('div.kv',
                    h('span', t('time_left')), h('b.mono', fmtClock(d.remainingMs)),
                    h('span', t('players')), h('b', `${d.participants.length}`),
                    h('span', t('spectators')), h('b', String(d.spectators.length)),
                    h('span', t('leader')), h('b', d.leader || '—'),
                    h('span', t('bucket')), h('b.mono', String(d.bucket ?? '—')),
                    d.tournament ? [h('span', t('tournaments')), h('b', d.tournament)] : null),
                d.teams ? h('div.hud-teams', d.teams.map((tm) => h('div.hud-team', { vars: { '--c': tm.color } }, h('b', String(tm.score)), h('span', tm.name)))) : null,
                d.zones ? h('div.row', { style: { marginTop: '10px', flexWrap: 'wrap' } }, d.zones.map((z) => h('span.chip', `${z.label}: ${z.owner ?? '—'}${z.contested ? ' ⚔' : ''}`))) : null,
                h('div', { style: { marginTop: '12px' } }, liveControls(d)))),
        h('div.box', h('div.box-head', t('participants')),
            h('table.tbl', h('tr', h('th', t('name')), h('th', t('status')), h('th', t('team')), h('th.num', t('score')), h('th.num', 'K/D'), h('th.num', 'ping'), h('th', '')),
                d.participants.map((p) => h('tr', h('td', p.name), h('td', p.status), h('td', p.team ? (d.teams ? d.teams[p.team - 1].name : p.team) : '—'),
                    h('td.num', String(p.score)), h('td.num', `${p.stats.kills}/${p.stats.deaths}`), h('td.num', p.ping ?? '—'),
                    h('td', p.src ? h('div.controls',
                        pAction(t('teleport'), 'admin:player:teleport', p.src, 'player.teleport', false, { to: 'spawn' }),
                        pAction(t('reset'), 'admin:player:reset', p.src, 'player.reset', false),
                        can('instance.manualScore') ? h('button.btn.sm', { onclick: () => call('admin:instance:score', { id, target: p.src, amount: 10, reason: 'staff' }, '+10') }, '+10') : null,
                        pAction(t('remove'), 'admin:player:remove', p.src, 'player.remove', true),
                        pAction(t('disqualify'), 'admin:player:disqualify', p.src, 'player.disqualify', true)) : null))))),
        h('div.grid2',
            can('player.add') ? h('div.box', h('div.box-head', t('add_player')), h('div.pad.row',
                h('select', { onchange: (e) => { addTarget = Number(e.target.value); } }, A.players.filter((p) => !p.inEvent).map((p) => h('option', { value: p.src }, `${p.name} [${p.src}]`))),
                h('button.btn.primary', { onclick: () => addTarget && call('admin:player:add', { id, target: Number(addTarget) }, t('saved')) }, t('add_player')))) : null,
            can('instance.announce') ? h('div.box', h('div.box-head', t('announce')), h('div.pad.row',
                h('input', { placeholder: t('text'), oninput: (e) => { announce = e.target.value; } }),
                h('button.btn.primary', { onclick: () => announce && call('admin:instance:announce', { id, text: announce }, t('saved')) }, t('announce')))) : null),
        d.results ? h('div.box', h('div.box-head', t('results')), h('table.tbl', d.results.map((r) => h('tr', h('td', placeBadge(r.placement)), h('td', r.name), h('td.num', String(r.score)), h('td.num', `${r.points} pts`))))) : null);
}

function live() {
    const list = A.data.instances;
    return h('div.shell-body',
        h('div.side', { style: { width: '260px' } }, list.length ? list.map((i) => h(`button.nav${A.liveId === i.id ? '.active' : ''}`, {
            onclick: () => { A.liveId = i.id; A.liveDetail = null; startLiveNow(); },
        }, badge(i.category, null, 'badge-sm'), h('span.grow', i.name, h('div.faint', { style: { fontSize: '11px' } }, `#${i.id} · ${i.state} · ${i.players}/${i.maxPlayers}`)))) : h('div.empty', '—'),
            can('instance.announce') ? h('div.foot', h('button.btn.sm', { onclick: () => globalAnnounce() }, `📢 ${t('everyone')}`)) : null),
        h('div.scroll.pad.grow', liveDetail()));
}

function startLiveNow() { clearInterval(A.liveTimer); startLive(); }

function globalAnnounce() {
    const el = $('confirm');
    let text = '';
    let chat = false;
    mount(el, h('div.box', h('h3', `${t('announce')} · ${t('everyone')}`),
        h('input', { placeholder: t('text'), oninput: (e) => { text = e.target.value; } }),
        h('label.row', { style: { margin: '10px 0' } }, h('input', { type: 'checkbox', onchange: (e) => { chat = e.target.checked; } }), t('also_chat')),
        h('div.row', h('button.btn', { onclick: () => show(el, false) }, t('cancel')), h('button.btn.primary', { onclick: async () => { show(el, false); if (text) await call('admin:instance:announce', { text, chat }, t('saved')); } }, t('announce')))));
    show(el, true);
}

// Tournaments -------------------------------------------------------------------

function tournaments() {
    const list = A.data.tournaments || [];
    const f = { name: '', definitionId: (A.data.definitions.find((d) => d.id === 'pistol_duel_cup') || A.data.definitions[0] || {}).id, format: 'single_elimination', bestOf: 1, seeding: 'registration', registrationSeconds: 180 };
    const entrantName = (tt, key) => { if (key === false) return 'BYE'; if (key == null) return '—'; const e = tt.entrants.find((x) => x.key === key); return e ? e.name : '?'; };
    return h('div.scroll.pad',
        list.map((tt) => h('div.box', { style: { marginBottom: '14px' } },
            h('div.box-head', ico('trophy'), tt.name, h('span.chip', tt.status), h('span.faint', `${t('format_' + tt.format)} · Bo${tt.bestOf} · ${tt.entrants.length} ${t('entrants')}`), h('div.spacer'),
                tt.status === 'registration' && can('tournament.edit') ? h('button.btn.sm.primary', { onclick: async () => { if (await call('admin:tournament:begin', { id: tt.id }, t('saved'))) refresh(); } }, t('begin')) : null),
            h('div.pad', tt.rounds && tt.rounds.length ? h('div.bracket', tt.rounds.map((round, ri) => h('div.round', h('div.section-title', (tt.roundLabels && tt.roundLabels[ri]) || `${t('round')} ${ri + 1}`),
                round.map((m) => h('div.match', h('div', { class: m.winner && m.winner === m.a ? 'w' : '' }, entrantName(tt, m.a), h('span', String(m.wins ? m.wins.a : 0))),
                    h('div', { class: m.winner && m.winner === m.b ? 'w' : '' }, entrantName(tt, m.b), h('span', String(m.wins ? m.wins.b : 0)))))))) :
                h('div.list-plain', tt.entrants.map((e) => h('div', e.name)))))),
        can('tournament.edit') ? h('div.box', h('div.box-head', t('new_tournament')), h('div.pad.form',
            h('div.field', h('label', t('name')), h('input', { oninput: (e) => { f.name = e.target.value; } })),
            h('div.field', h('label', t('definitions')), h('select', { onchange: (e) => { f.definitionId = e.target.value; } }, A.data.definitions.map((d) => h('option', { value: d.id, selected: d.id === f.definitionId ? 'selected' : null }, d.name)))),
            h('div.field', h('label', t('format')), h('select', { onchange: (e) => { f.format = e.target.value; } }, ['single_elimination', 'double_elimination', 'round_robin', 'swiss'].map((x) => h('option', { value: x }, t('format_' + x))))),
            h('div.field', h('label', t('best_of')), h('select', { onchange: (e) => { f.bestOf = Number(e.target.value); } }, [1, 3, 5].map((x) => h('option', { value: x }, String(x))))),
            h('div.field', h('label', t('seeding')), h('select', { onchange: (e) => { f.seeding = e.target.value; } }, ['registration', 'random'].map((x) => h('option', { value: x }, x)))),
            h('div.field', h('label', t('registration')), h('input', { type: 'number', value: 180, oninput: (e) => { f.registrationSeconds = Number(e.target.value); } })),
            h('div.field', h('button.btn.primary', { onclick: async () => { if (await call('admin:tournament:create', { ...f, name: f.name || undefined }, t('saved'))) refresh(); } }, t('create'))))) : null);
}

// Leaderboard / logs / settings -----------------------------------------------------

async function loadBoard(category) {
    const r = await rpc('admin:leaderboard', { category });
    A.board = r.ok ? r.res.rows : [];
    A.boardCat = category;
    render();
}

function leaderboard() {
    const cats = ['*', ...(A.data.categories || [])];
    return h('div.scroll.pad',
        h('div.row', { style: { marginBottom: '14px' } }, h('select', { style: { width: '220px' }, onchange: (e) => loadBoard(e.target.value) },
            cats.map((c) => h('option', { value: c, selected: A.boardCat === c ? 'selected' : null }, c === '*' ? t('all_categories') : c))), h('span.muted', `${t('season')}: ${A.data.season}`)),
        A.board.length ? h('table.tbl', h('tr', h('th', '#'), h('th', t('name')), h('th.num', t('points')), h('th.num', t('wins')), h('th.num', t('podiums')), h('th.num', t('events_joined')), h('th.num', t('kills')), h('th.num', t('deaths'))),
            A.board.map((r) => h('tr', h('td', placeBadge(r.rank)), h('td', r.name), h('td.num', String(r.points)), h('td.num', String(r.wins)), h('td.num', String(r.podiums)),
                h('td.num', String(r.joined)), h('td.num', String(r.kills)), h('td.num', String(r.deaths))))) : h('div.empty', '—'));
}

async function loadLogs(level) {
    const r = await rpc('admin:logs', { limit: 150, level: level || undefined });
    A.logs = r.ok ? r.res : [];
    A.logLevel = level;
    render();
}

async function loadHistory() {
    const r = await rpc('admin:history');
    A.history = r.ok ? r.res : [];
    render();
}

function logs() {
    return h('div.col.grow', { style: { minHeight: 0 } },
        h('div.pad.row', h('select', { style: { width: '200px' }, onchange: (e) => loadLogs(e.target.value) },
            ['', 'audit', 'security', 'lifecycle', 'info'].map((l) => h('option', { value: l, selected: A.logLevel === l ? 'selected' : null }, l || t('level_filter')))),
            h('button.btn', { onclick: () => loadLogs(A.logLevel) }, t('refresh'))),
        h('div.scroll.grow', A.logs.length ? A.logs.map((l) => {
            const w = l.created_at ? fmtDate(l.created_at) : { day: '', time: '' };
            return h('div.log-line', h('span.faint', `${w.day} ${w.time}`), h(`span.lvl-${l.level}`, l.level), h('span', l.action), h('span.muted', `${l.actor || ''}${l.instance_id ? ` #${l.instance_id}` : ''} ${l.data ? JSON.stringify(l.data) : ''}`));
        }) : h('div.empty', '—')));
}

function settings() {
    return h('div.scroll.pad', h('div.about',
        h('div.about-card',
            brandLogo(),
            h('h2.display', 'EVENT STUDIO'),
            h('p.muted', t('about_tagline')),
            h('div.about-rows',
                h('div.about-row', h('span.faint', t('about_developer')), h('b.row', 'vzjRR', h('span.faint', '·'), 'Krovix Team', flagOman(13))),
                h('div.about-row', h('span.faint', t('about_publisher')), h('b', 'Krovix Store'))),
            h('p.about-rights', `© ${new Date().getFullYear()} Krovix Store. ${t('about_rights')}`))));
}

// Shell --------------------------------------------------------------------------

export function brandLogo() {
    const src = logoOf(store.ui);
    return h('div.logo', src ? h('img', { src, alt: '' }) : (store.ui.brand && store.ui.brand.title ? store.ui.brand.title.slice(0, 2).toUpperCase() : 'ES'));
}

/** Appearance changed (live push): redraw if the Admin Center is open. */
export function onUI() {
    onAppearanceUI();
    if (!$('admin').classList.contains('hidden')) render();
}

export function render() {
    if (!A.data) return;
    const views = { dashboard, definitions, builder: builderView, arenas: arenaView, scheduler, live, tournaments, leaderboard, logs, appearance: appearanceView, settings };
    const brand = store.ui.brand || {};
    const titleKey = (sections.find((s) => s[0] === A.section) || [])[2];
    mount($('admin'), h('div.shell',
        h('div.shell-head',
            h('div.brand', brandLogo(), h('div', h('h1.display', t('admin')), h('small', brand.title || 'Event Studio'))),
            h('button.close-x', { onclick: closePanels, 'aria-label': t('close') }, ico('close'))),
        h('div.shell-body',
            h('div.side', sections.map(([key, icon, label]) => h(`button.nav${A.section === key ? '.active' : ''}`, { onclick: () => go(key) }, h('span.ico', ico(icon, 17)), t(label))),
                h('div.foot', '© Krovix Store')),
            h('div.main', h('div.main-head', h('h2', t(titleKey)), h('div.spacer'), h('button.btn.sm', { onclick: refresh }, t('refresh'))),
                h('div.grow', { style: { display: 'flex', flexDirection: 'column', minHeight: 0 } }, views[A.section]())))));
}
