// EVENT STUDIO — Event Builder (form generated from the mode's option schema) and Arena editor.
import { h, mount, t, categoryOf, ico } from '../ui.js';
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

const REWARD_TYPES = ['cash', 'bank', 'item', 'xp'];

/** Editable list of reward entries (several per place: e.g. cash + an item). */
function rewardList(def, path, label) {
    const list = Array.isArray(getPath(def, path)) ? getPath(def, path) : [];
    const commit = (next) => setPath(def, path, next.length ? next : undefined);
    const rows = list.map((e, i) => {
        const upd = (patch) => { list[i] = { ...e, ...patch }; if (list[i].type !== 'item') { delete list[i].name; delete list[i].count; } else delete list[i].amount; commit(list); render(); };
        return h(`div.reward-entry${e.type === 'item' ? '.item' : ''}`,
            h('select', { 'aria-label': t('type'), onchange: (ev) => upd({ type: ev.target.value }) },
                REWARD_TYPES.map((v) => h('option', { value: v, selected: e.type === v ? 'selected' : null }, t('reward_' + v)))),
            e.type === 'item'
                ? [h('input', { placeholder: t('item_name'), value: e.name ?? '', 'aria-label': t('item_name'), oninput: (ev) => { e.name = ev.target.value.trim() || undefined; commit(list); } }),
                   h('input', { type: 'number', min: 1, placeholder: t('amount'), value: e.count ?? 1, 'aria-label': t('amount'), oninput: (ev) => { e.count = Number(ev.target.value) || 1; commit(list); } })]
                : h('input', { type: 'number', min: 0, placeholder: t('amount'), value: e.amount ?? '', 'aria-label': t('amount'), oninput: (ev) => { e.amount = Number(ev.target.value) || 0; commit(list); } }),
            h('button.btn.sm.danger', { 'aria-label': t('remove'), onclick: () => { list.splice(i, 1); commit(list); render(); } }, ico('close', 13)));
    });
    return h('div.reward-place',
        h('div.reward-head', h('b', label), h('div.spacer'),
            h('button.btn.sm', { onclick: () => { list.push({ type: 'cash', amount: 1000 }); commit(list); render(); } }, ico('plus', 13), t('add_reward'))),
        rows.length ? rows : h('div.faint.reward-none', t('no_reward')));
}

function rewardsEditor(def, mode) {
    const placement = def.rewards.placement || {};
    const places = Math.max(3, ...Object.keys(placement).map(Number).filter((n) => n > 0));
    const ordinal = (n) => (n <= 3 ? t(['first_place', 'second_place', 'third_place'][n - 1]) : t('nth_place', n));
    return h('div.field.full', h('div.rewards-grid',
        Array.from({ length: places }, (_, i) => rewardList(def, `rewards.placement.${i + 1}`, ordinal(i + 1))),
        rewardList(def, 'rewards.participation', t('participation')),
        mode.teams !== 'none' ? rewardList(def, 'rewards.winnerTeam', t('winner_team_reward')) : null),
        h('div.row', { style: { marginTop: '8px' } },
            h('button.btn.sm', { onclick: () => { def.rewards.placement = { ...placement, [places + 1]: [] }; render(); } }, ico('plus', 13), t('add_place')),
            h('span.faint', { style: { fontSize: '12px' } }, t('rewards_help'))));
}

/** Route / location picker with shortcuts into the route editor. */
function routePicker(def, arenas, mode) {
    const cur = A.data.arenas.find((a) => a.id === def.arena);
    const openEditor = async (id) => {
        A.returnTo = 'builder';
        if (id) { const full = await call('admin:arena:get', { id }); if (!full) return; A.arenaEdit = full; }
        else A.arenaEdit = { id: '', name: def.name ? `${def.name} route` : '', radius: 300, route: (mode.requires || []).includes('checkpoints') ? 'road' : 'open' };
        go('arenas');
    };
    return field(t('route'), h('div.col', { style: { gap: '6px' } },
        h('select', { onchange: (e) => { setPath(def, 'arena', e.target.value); render(); } },
            h('option', { value: '' }, '—'),
            arenas.map((a) => h('option', { value: a.id, selected: a.id === def.arena ? 'selected' : null },
                `${a.name} · ${t('route_' + (a.route || 'open'))}${a.checked ? (a.checked.problems ? ` · ${t('check_problems', a.checked.problems)}` : ` · ${t('check_ok')}`) : ` · ${t('not_checked')}`}`))),
        h('div.row',
            cur && can('arena.edit') ? h('button.btn.sm', { onclick: () => openEditor(cur.id) }, ico('pencil', 13), t('edit_route')) : null,
            can('arena.edit') ? h('button.btn.sm', { onclick: () => openEditor(null) }, ico('plus', 13), t('new_route')) : null)),
        { help: (mode.requires || []).length ? `${t('route_needs')}: ${mode.requires.map((r) => t('list_' + r.replace(/([A-Z])/g, '_$1').toLowerCase() + '_short')).join(', ')}` : '' });
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
        // drop empty reward rows and places so the server stores only what pays something
        const cleanList = (l) => (Array.isArray(l) ? l.filter((e) => e && (e.type === 'item' ? e.name : Number(e.amount) > 0)) : []);
        if (payload.rewards) {
            const pl = {};
            for (const [k, v] of Object.entries(payload.rewards.placement || {})) { const c = cleanList(v); if (c.length) pl[k] = c; }
            payload.rewards.placement = Object.keys(pl).length ? pl : undefined;
            for (const k of ['participation', 'winnerTeam']) { const c = cleanList(payload.rewards[k]); payload.rewards[k] = c.length ? c : undefined; }
        }
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
        field(t('mode'), selectIn(def, 'mode', A.data.modes.map((m) => [m.id, m.label]), () => { def.options = {}; render(); }), { help: mode.description }),
        mode.needsArena ? routePicker(def, arenas, mode) : field(t('route'), h('div.faint', t('no_route_needed'))),
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
        rewardsEditor(def, mode),

        h('div.field.full', h('div.row', h('div.spacer'),
            h('button.btn', { onclick: () => { A.editing = null; go('definitions'); } }, t('cancel')),
            can('definition.edit') ? h('button.btn.primary', { onclick: save }, t('save')) : null))));
}

