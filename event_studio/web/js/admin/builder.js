// EVENT STUDIO — Event Builder (form generated from the mode's option schema) and Arena editor.
import { h, mount, t, categoryOf } from '../ui.js';
import { post } from '../app.js';
import { A, can, call, refresh, render, go } from './admin.js';
import { toast } from '../hud.js';

// ---------------------------------------------------------------------------------
// Event builder
// ---------------------------------------------------------------------------------

function blankDefinition() {
    const mode = A.data.modes[0];
    return { id: '', name: '', description: '', mode: mode.id, arena: '', visibility: 'public', status: 'published', enabled: true, difficulty: 'medium',
        players: { min: 2, max: 16 }, timing: {}, gameplay: {}, options: {}, scoring: A.data.scoringProfiles.includes('standard') ? 'standard' : A.data.scoringProfiles[0], rewards: {} };
}

function setPath(obj, path, value) {
    const keys = path.split('.');
    let o = obj;
    for (let i = 0; i < keys.length - 1; i++) { o[keys[i]] = o[keys[i]] ?? {}; o = o[keys[i]]; }
    if (value === '' || value === undefined || (typeof value === 'number' && Number.isNaN(value))) delete o[keys[keys.length - 1]];
    else o[keys[keys.length - 1]] = value;
}
function getPath(obj, path) { return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj); }

function field(label, control, opts = {}) {
    return h(`div.field${opts.full ? '.full' : ''}${opts.check ? '.check' : ''}`, opts.check ? [control, h('label', label)] : [h('label', label), control], opts.help ? h('div.help', opts.help) : null);
}

function textIn(def, path, attrs = {}) {
    return h('input', { value: getPath(def, path) ?? '', oninput: (e) => setPath(def, path, e.target.value), ...attrs });
}
function numIn(def, path, attrs = {}) {
    return h('input', { type: 'number', value: getPath(def, path) ?? '', oninput: (e) => setPath(def, path, e.target.value === '' ? undefined : Number(e.target.value)), ...attrs });
}
function selectIn(def, path, options, onchange) {
    const cur = getPath(def, path);
    return h('select', { onchange: (e) => { setPath(def, path, e.target.value); if (onchange) onchange(e.target.value); } },
        options.map(([v, label]) => h('option', { value: v, selected: String(v) === String(cur) ? 'selected' : null }, label)));
}
function checkIn(def, path, dflt) {
    const cur = getPath(def, path);
    return h('input', { type: 'checkbox', checked: cur === undefined ? dflt : cur, onchange: (e) => setPath(def, path, e.target.checked) });
}

/** Render a control for one schema field description (from the server). */
function optionControl(def, base, spec) {
    const path = `${base}.${spec.key}`;
    const label = spec.label || spec.key;
    const dflt = spec.default;
    const cur = getPath(def, path);
    const help = [spec.help, (spec.min !== undefined || spec.max !== undefined) ? `${spec.min ?? ''} – ${spec.max ?? ''}` : null].filter(Boolean).join(' · ');
    switch (spec.type) {
        case 'boolean':
            return field(label, checkIn(def, path, dflt === true), { check: true });
        case 'integer': case 'number':
            return field(label, h('input', { type: 'number', step: spec.type === 'integer' ? 1 : 'any', placeholder: dflt ?? '', value: cur ?? '',
                oninput: (e) => setPath(def, path, e.target.value === '' ? undefined : Number(e.target.value)) }), { help });
        case 'enum':
            return field(label, h('select', { onchange: (e) => setPath(def, path, isNaN(Number(e.target.value)) ? e.target.value : Number(e.target.value)) },
                spec.values.map((v) => h('option', { value: v, selected: String(cur ?? dflt) === String(v) ? 'selected' : null }, String(v)))));
        case 'list':
            if (spec.item === 'string' || spec.item === 'integer' || spec.item === 'number') {
                const val = (cur ?? dflt ?? []).join(', ');
                return field(label, h('input', { value: val, placeholder: 'a, b, c', oninput: (e) => {
                    const parts = e.target.value.split(',').map((s) => s.trim()).filter(Boolean);
                    setPath(def, path, parts.length ? (spec.item === 'string' ? parts : parts.map(Number)) : undefined);
                } }), { full: true, help: 'comma separated' });
            }
            return jsonField(def, path, label, cur ?? dflt);
        case 'object':
            if (spec.fields) {
                return [h('div.fieldset', label), spec.fields.map((f) => optionControl(def, path, f))];
            }
            return jsonField(def, path, label, cur ?? dflt);
        case 'string': default:
            return field(label, h('input', { value: cur ?? '', placeholder: dflt ?? '', oninput: (e) => setPath(def, path, e.target.value || undefined) }), { help });
    }
}

function jsonField(def, path, label, value) {
    return field(label, h('textarea', { rows: 4, class: 'mono', oninput: (e) => {
        try { setPath(def, path, e.target.value.trim() ? JSON.parse(e.target.value) : undefined); e.target.style.borderColor = ''; }
        catch { e.target.style.borderColor = 'var(--bad)'; }
    } }, value !== undefined ? JSON.stringify(value, null, 1) : ''), { full: true, help: 'JSON' });
}

function rewardRow(def, label, key, place) {
    const path = place ? `rewards.placement.${place}` : `rewards.${key}`;
    const list = getPath(def, path);
    const first = (Array.isArray(list) && list[0]) || {};
    const update = (patch) => {
        const e = { ...first, ...patch };
        if (!e.type || e.type === 'none' || (!e.amount && !e.name)) { setPath(def, path, undefined); return; }
        setPath(def, path, [e, ...((Array.isArray(list) && list.slice(1)) || [])]);
    };
    return h('div.field', h('label', label), h('div.row',
        h('select', { style: { width: '110px' }, onchange: (e) => update({ type: e.target.value }) },
            ['none', 'cash', 'bank', 'item', 'xp'].map((v) => h('option', { value: v, selected: (first.type || 'none') === v ? 'selected' : null }, v))),
        h('input', { type: 'number', placeholder: t('amount'), value: first.amount ?? first.count ?? '', oninput: (e) => update(first.type === 'item' ? { count: Number(e.target.value) } : { amount: Number(e.target.value) }) }),
        h('input', { placeholder: 'item name', value: first.name ?? '', oninput: (e) => update({ name: e.target.value || undefined }) })));
}

export function builderView() {
    if (!A.editing) A.editing = blankDefinition();
    const def = A.editing;
    def.players = def.players || {}; def.timing = def.timing || {}; def.gameplay = def.gameplay || {}; def.options = def.options || {}; def.rewards = def.rewards || {};
    if (def.rewards.placement && Array.isArray(def.rewards.placement)) {
        const obj = {}; def.rewards.placement.forEach((v, i) => { if (v) obj[i + 1] = v; }); def.rewards.placement = obj;
    }
    const mode = A.data.modes.find((m) => m.id === def.mode) || A.data.modes[0];
    const arenas = A.data.arenas.filter((a) => (mode.requires || []).every((r) => (a.counts[r] ?? 1) > 0));
    const dd = A.data.definitionDefaults || { players: {}, timing: {} };
    const save = async () => {
        if (!def.id) def.id = (def.name || 'event').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 48);
        const payload = JSON.parse(JSON.stringify(def));
        if (!payload.arena) delete payload.arena;
        if (payload.players && !payload.players.teamsEnabled) delete payload.players.teams;
        else if (payload.players && !payload.players.teams) payload.players.teams = { count: 2 };
        if (payload.players) delete payload.players.teamsEnabled;
        const res = await call('admin:definition:save', { def: payload }, t('saved'));
        if (res) { A.editing = null; await refresh(); go('definitions'); }
    };
    const teamsAllowed = mode.teams !== 'none';
    if (def.players.teams && def.players.teamsEnabled === undefined) def.players.teamsEnabled = true;
    return h('div.scroll.pad', h('div.form',
        h('div.fieldset', t('builder')),
        field(t('name'), textIn(def, 'name', { maxlength: 64 })),
        field(t('id'), textIn(def, 'id', { placeholder: 'auto from name', maxlength: 64 })),
        field(t('description'), h('textarea', { rows: 2, oninput: (e) => setPath(def, 'description', e.target.value) }, def.description || ''), { full: true }),
        field(t('mode'), selectIn(def, 'mode', A.data.modes.map((m) => [m.id, `${categoryOf(m.category).icon} ${m.label}`]), () => { def.options = {}; render(); }), { help: mode.description }),
        mode.needsArena ? field(t('arena'), selectIn(def, 'arena', [['', '—'], ...arenas.map((a) => [a.id, a.name])]), { help: (mode.requires || []).length ? `requires: ${mode.requires.join(', ')}` : '' }) : field(t('arena'), h('div.faint', '—')),
        field(t('category'), selectIn(def, 'category', [['', `(${mode.category})`], ...A.data.categories.map((c) => [c, c])])),
        field(t('visibility'), selectIn(def, 'visibility', [['public', 'public'], ['hidden', 'hidden'], ['staff', 'staff']])),
        field(t('difficulty'), selectIn(def, 'difficulty', ['easy', 'medium', 'hard', 'extreme'].map((d) => [d, t('diff_' + d)]))),
        field(t('status'), selectIn(def, 'status', [['published', t('published')], ['draft', t('draft')]])),
        field('Icon (emoji or URL)', textIn(def, 'icon', { maxlength: 128 })),
        field('Banner image URL', textIn(def, 'banner', { maxlength: 256 })),

        h('div.fieldset', t('players')),
        field(t('min_players'), numIn(def, 'players.min', { placeholder: dd.players.min })),
        field(t('max_players'), numIn(def, 'players.max', { placeholder: dd.players.max })),
        teamsAllowed ? field(t('teams'), checkIn(def, 'players.teamsEnabled', mode.teams === 'required'), { check: true }) : null,
        teamsAllowed ? field(`${t('teams')} #`, numIn(def, 'players.teams.count', { placeholder: 2, min: 2, max: 8 })) : null,
        field(t('spectators'), checkIn(def, 'players.spectators', dd.players.spectators !== false), { check: true }),
        field('Reconnect grace (s)', numIn(def, 'players.reconnectGrace', { placeholder: dd.players.reconnectGrace })),

        h('div.fieldset', t('timing')),
        ...['registration', 'lobby', 'countdown', 'duration', 'grace', 'results', 'extendOnce'].map((k) => field(k, numIn(def, `timing.${k}`, { placeholder: dd.timing[k] }))),

        h('div.fieldset', t('gameplay')),
        field('Health', numIn(def, 'gameplay.health', { placeholder: 200 })),
        field('Armor', numIn(def, 'gameplay.armor', { placeholder: 0 })),
        field('Friendly fire', checkIn(def, 'gameplay.friendlyFire', false), { check: true }),
        field('Restore weapons afterwards', checkIn(def, 'gameplay.restoreWeapons', true), { check: true }),

        h('div.fieldset', `${t('options')} · ${mode.label}`),
        ...mode.options.map((spec) => optionControl(def, 'options', spec)),

        h('div.fieldset', `${t('scoring')} & ${t('rewards')}`),
        field(t('scoring_profile'), selectIn(def, 'scoring', A.data.scoringProfiles.map((p) => [p, p]))),
        h('div'),
        rewardRow(def, t('first_place'), null, 1), rewardRow(def, t('second_place'), null, 2),
        rewardRow(def, t('third_place'), null, 3), rewardRow(def, t('participation'), 'participation'),

        h('div.field.full', h('div.row', h('div.spacer'),
            h('button.btn', { onclick: () => { A.editing = null; go('definitions'); } }, t('cancel')),
            can('definition.edit') ? h('button.btn.primary', { onclick: save }, t('save')) : null))));
}

// ---------------------------------------------------------------------------------
// Arena editor
// ---------------------------------------------------------------------------------

const pointLists = [
    ['spawns', 'Spawns'], ['vehicleSpawns', 'Vehicle spawns'], ['checkpoints', 'Checkpoints (ordered)'], ['zones', 'Zones'],
    ['targets', 'Hunt targets'], ['objectives', 'Objectives (flag bases: team 1 / 2)'], ['spectator', 'Spectator points'],
];

async function myPosition() {
    const r = await post('admin:position');
    if (!r || !r.ok) { toast({ text: 'forbidden', kind: 'error' }); return null; }
    return r.res;
}

export function arenaView() {
    const ar = A.arenaEdit;
    if (!ar) {
        return h('div.scroll.pad',
            h('div.row', { style: { marginBottom: '12px' } }, h('div.spacer'), can('arena.edit') ? h('button.btn.primary', { onclick: () => { A.arenaEdit = { id: '', name: '', radius: 150, spawns: [] }; render(); } }, t('new_arena')) : null),
            h('table.tbl', h('tr', h('th', t('name')), h('th', 'spawns'), h('th', 'checkpoints'), h('th', 'zones'), h('th', 'targets'), h('th', 'source'), h('th', '')),
                A.data.arenas.map((a) => h('tr', h('td', h('b', a.name), h('div.faint.mono', a.id)), h('td', String(a.counts.spawns)), h('td', String(a.counts.checkpoints)),
                    h('td', String(a.counts.zones)), h('td', String(a.counts.targets)), h('td', a.source),
                    h('td', can('arena.edit') ? h('button.btn.sm', { onclick: async () => { const full = await call('admin:arena:get', { id: a.id }); if (full) { A.arenaEdit = full; render(); } } }, t('edit')) : null)))));
    }
    const addPoint = async (key, extra = {}) => {
        const p = await myPosition();
        if (!p) return;
        ar[key] = ar[key] || [];
        ar[key].push({ x: p.x, y: p.y, z: p.z, w: p.w, ...extra });
        render();
    };
    const save = async () => {
        const payload = JSON.parse(JSON.stringify(ar));
        for (const k of Object.keys(payload)) if (Array.isArray(payload[k]) && payload[k].length === 0) delete payload[k];
        const res = await call('admin:arena:save', { arena: payload }, t('saved'));
        if (res) { A.arenaEdit = null; refresh(); }
    };
    const list = (key, label) => h('div.box', { style: { marginBottom: '10px' } },
        h('div.box-head', label, h('span.faint', `(${(ar[key] || []).length})`), h('div.spacer'),
            h('button.btn.sm', { onclick: () => addPoint(key, key === 'checkpoints' ? { radius: 12 } : key === 'zones' ? { radius: 15, id: String.fromCharCode(65 + (ar.zones || []).length) } : key === 'targets' ? { radius: 10, label: `Target ${(ar.targets || []).length + 1}` } : key === 'objectives' ? { team: (ar.objectives || []).length + 1 } : {}) }, `＋ ${t('add_point_here')}`)),
        h('div.point-list', (ar[key] || []).map((p, i) => h('div.row', { style: { padding: '4px 14px' } },
            h('span.grow', `#${i + 1}  ${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}${p.w !== undefined ? `  h${Math.round(p.w)}` : ''}${p.radius ? `  r${p.radius}` : ''}${p.team ? `  team ${p.team}` : ''}${p.label ? `  ${p.label}` : ''}`),
            h('button.btn.sm.ghost', { onclick: () => post('waypoint', p) }, '⌖'),
            h('button.btn.sm.danger', { onclick: () => { ar[key].splice(i, 1); render(); } }, '✕')))));
    return h('div.scroll.pad',
        h('div.form', { style: { marginBottom: '14px' } },
            h('div.field', h('label', t('name')), h('input', { value: ar.name || '', oninput: (e) => { ar.name = e.target.value; } })),
            h('div.field', h('label', t('id')), h('input', { value: ar.id || '', oninput: (e) => { ar.id = e.target.value; } })),
            h('div.field', h('label', 'Center'), h('div.row', h('span.mono.grow', ar.center ? `${Number(ar.center.x).toFixed(1)}, ${Number(ar.center.y).toFixed(1)}, ${Number(ar.center.z).toFixed(1)}` : '—'),
                h('button.btn.sm', { onclick: async () => { const p = await myPosition(); if (p) { ar.center = { x: p.x, y: p.y, z: p.z }; render(); } } }, t('add_point_here')))),
            h('div.field', h('label', 'Radius / bounds'), h('div.row',
                h('input', { type: 'number', value: ar.radius || 150, oninput: (e) => { ar.radius = Number(e.target.value); } }),
                h('label.row', h('input', { type: 'checkbox', checked: !!ar.bounds, onchange: (e) => { ar.bounds = e.target.checked ? { radius: ar.radius } : undefined; } }), 'bounds'))),
            h('div.field', h('label', 'Finish line (red light)'), h('div.row', h('span.mono.grow', ar.finish ? `${Number(ar.finish.x).toFixed(1)}, ${Number(ar.finish.y).toFixed(1)}` : '—'),
                h('button.btn.sm', { onclick: async () => { const p = await myPosition(); if (p) { ar.finish = { x: p.x, y: p.y, z: p.z, radius: 10 }; render(); } } }, t('add_point_here'))))),
        pointLists.map(([k, label]) => list(k, label)),
        h('div.row', h('div.spacer'), h('button.btn', { onclick: () => { A.arenaEdit = null; render(); } }, t('cancel')), h('button.btn.primary', { onclick: save }, t('save'))));
}
