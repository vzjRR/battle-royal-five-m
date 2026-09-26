// EVENT STUDIO — Admin Center → Arenas: route list with checks, the route check report, and the arena / route editor.
import { h, t, fmtDate, ico } from '../ui.js';
import { post } from '../app.js';
import { A, can, call, refresh, render, go } from './admin.js';
import { toast } from '../hud.js';

const pointLists = [
    ['checkpoints', 'list_checkpoints'], ['vehicleSpawns', 'list_vehicle_spawns'], ['spawns', 'list_spawns'], ['zones', 'list_zones'],
    ['targets', 'list_targets'], ['objectives', 'list_objectives'], ['spectator', 'list_spectator'],
];
const ROUTES = ['road', 'water', 'open', 'foot', 'air'];
const SPACING = { road: 80, water: 120, open: 60, foot: 25, air: 150 };

// state kept on A (created on first use) so it survives re-renders and closing the panel:
// A.arenaCheck = { id, progress, total, report }, A.recorded = points waiting for the editor

async function myPosition() {
    const r = await post('admin:position');
    if (!r || !r.ok) { toast({ text: t('err_forbidden'), kind: 'error' }); return null; }
    return r.res;
}

function chip(status) {
    const cls = { ok: '.open', fixed: '.upcoming', problem: '.full', warn: '.starting' }[status] || '';
    return h(`span.chip${cls}`, t('chk_' + status));
}

function routeChip(route) { return h('span.chip', t('route_' + route)); }

function checkedLine(a) {
    if (!a.checked) return h('span.chip.starting', t('not_checked'));
    const w = fmtDate(a.checked.at);
    return a.checked.problems > 0
        ? h('span.chip.full', t('check_problems', a.checked.problems))
        : h('span.row', h('span.chip.open', t('check_ok')), h('small.faint', `${w.day} ${w.time}`));
}

/** NUI message from the client checker. */
export function onArenaCheck(d) {
    if (!d || !d.id) return;
    if (d.error) { A.arenaCheck = null; toast({ text: d.error, kind: 'error' }); render(); return; }
    A.arenaCheck = { ...(A.arenaCheck || {}), id: d.id, progress: d.progress, total: d.total, report: d.done ? d : (A.arenaCheck && A.arenaCheck.report) };
    if (A.section === 'arenas') render();
}

/** NUI message: a recorded route is ready. */
export function onArenaRecorded(d) {
    if (!d || d.cancelled || !Array.isArray(d.points)) return;
    A.recorded = d;
    if (A.arenaEdit) applyRecorded();
}

function applyRecorded() {
    const ar = A.arenaEdit;
    const d = A.recorded;
    if (!ar || !d) return;
    const r = ar.route === 'water' ? 18 : ar.route === 'foot' ? 4 : 12;
    ar.checkpoints = d.points.map((p, i) => ({ x: p.x, y: p.y, z: p.z, radius: i === d.points.length - 1 ? r + 2 : r }));
    ar.checkpoints[ar.checkpoints.length - 1].label = 'Finish';
    if (!ar.center) ar.center = { x: d.points[0].x, y: d.points[0].y, z: d.points[0].z };
    A.recorded = null;
    toast({ text: t('recorded_ready', ar.checkpoints.length), kind: 'success' });
}

async function startCheck(id) {
    A.arenaCheck = { id, progress: 0, total: 0, report: null };
    render();
    await post('arena:check', { id });
}

async function applyFixes() {
    const rep = A.arenaCheck && A.arenaCheck.report;
    if (!rep) return;
    const res = await call('admin:arena:applyFix', { id: rep.id, fixes: rep.fixes, problems: rep.problems }, t('fixes_applied', rep.fixes.length));
    if (res) { A.arenaCheck = null; await refresh(); }
}

function checkPanel() {
    const c = A.arenaCheck;
    if (!c) return null;
    const rep = c.report;
    if (!rep) {
        const pct = c.total ? Math.round((c.progress / c.total) * 100) : 0;
        return h('div.box.check-box', h('div.box-head', ico('refresh', 15), t('checking'), h('div.spacer'), h('span.mono', c.total ? `${c.progress}/${c.total}` : '')),
            h('div.pad', h('div.fill', h('i', { style: { width: `${pct}%` } })), h('p.faint', { style: { marginTop: '8px', fontSize: '12px' } }, t('check_running_help'))));
    }
    const counts = { ok: 0, fixed: 0, problem: 0, kept: 0 };
    rep.points.forEach((p) => { counts[p.status] = (counts[p.status] || 0) + 1; });
    return h('div.box.check-box',
        h('div.box-head', ico('shield', 15), `${t('check_route')}: ${rep.name}`, routeChip(rep.route), h('div.spacer'),
            h('span.chip.open', `${counts.ok} ${t('chk_ok')}`), h('span.chip.upcoming', `${counts.fixed} ${t('chk_fixed')}`),
            rep.problems ? h('span.chip.full', t('check_problems', rep.problems)) : null),
        h('div.check-grid',
            h('table.tbl', h('tr', h('th', t('points_list')), h('th', t('status')), h('th', '')),
                rep.points.map((p) => h('tr', h('td', h('span.mono', p.label)), h('td', chip(p.status)), h('td.faint', p.note || '')))),
            rep.legs && rep.legs.length ? h('table.tbl', h('tr', h('th', t('legs')), h('th', t('status')), h('th', '')),
                rep.legs.map((l) => h('tr', h('td.mono', `${l.from} → ${l.to}`), h('td', chip(l.status)), h('td.faint', l.note || '')))) : null),
        h('div.pad.row', { style: { borderTop: '1px solid var(--line)' } },
            h('span.faint', { style: { fontSize: '12px' } }, rep.problems ? t('check_problems_help') : t('check_clean_help')),
            h('div.spacer'),
            h('button.btn', { onclick: () => { A.arenaCheck = null; render(); } }, t('close')),
            can('arena.edit') ? h('button.btn.primary', { onclick: applyFixes }, rep.fixes.length ? t('apply_fixes_n', rep.fixes.length) : t('mark_checked')) : null));
}

function arenaList() {
    return h('div.scroll.pad.col', { style: { gap: '14px' } },
        h('div.row', h('p.faint', { style: { fontSize: '12px', maxWidth: '640px' } }, t('arena_help')), h('div.spacer'),
            can('arena.edit') ? h('button.btn.primary', { onclick: () => { A.arenaEdit = { id: '', name: '', radius: 150, route: 'road' }; render(); } }, t('new_route')) : null),
        checkPanel(),
        h('table.tbl',
            h('tr', h('th', t('name')), h('th', t('route')), h('th', t('points_list')), h('th', t('check_route')), h('th', '')),
            A.data.arenas.map((a) => {
                const n = a.counts;
                const pts = [n.checkpoints ? `${n.checkpoints} ${t('list_checkpoints_short')}` : null, n.spawns ? `${n.spawns} ${t('list_spawns_short')}` : null,
                    n.vehicleSpawns ? `${n.vehicleSpawns} ${t('list_vehicle_spawns_short')}` : null, n.zones ? `${n.zones} ${t('list_zones_short')}` : null,
                    n.targets ? `${n.targets} ${t('list_targets_short')}` : null].filter(Boolean).join(' · ');
                const running = A.arenaCheck && A.arenaCheck.id === a.id && !A.arenaCheck.report;
                return h('tr', h('td', h('b', a.name), h('div.faint.mono', a.id)), h('td', routeChip(a.route || 'open')), h('td.faint', pts || '—'),
                    h('td', checkedLine(a)),
                    h('td', h('div.row', { style: { justifyContent: 'flex-end' } },
                        can('arena.edit') ? h('button.btn.sm', { disabled: running || A.arenaCheck && !A.arenaCheck.report ? true : null, onclick: () => startCheck(a.id) }, ico('shield', 14), t('check_route')) : null,
                        can('arena.edit') ? h('button.btn.sm', { onclick: async () => { const full = await call('admin:arena:get', { id: a.id }); if (full) { A.arenaEdit = full; if (A.recorded) applyRecorded(); render(); } } }, ico('pencil', 14), t('edit')) : null)));
            })));
}

function fmtPoint(p) {
    return `${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)}`;
}

function pointRow(ar, key, p, i) {
    const list = ar[key];
    const move = (d) => { const j = i + d; if (j < 0 || j >= list.length) return; [list[i], list[j]] = [list[j], list[i]]; render(); };
    return h('div.point-row',
        h('span.mono.pr-num', `${i + 1}`),
        h('span.mono.grow', fmtPoint(p), p.w !== undefined ? h('span.faint', `  ${Math.round(p.w)}°`) : null, p.label ? h('span.accent', `  ${p.label}`) : null, p.team ? h('span.faint', `  team ${p.team}`) : null),
        p.radius !== undefined ? h('input.pr-radius', { type: 'number', min: 1, max: 500, value: p.radius, 'aria-label': t('radius'), title: t('radius'),
            onchange: (e) => { p.radius = Number(e.target.value) || p.radius; } }) : null,
        h('button.btn.sm.ghost', { title: t('go_there'), 'aria-label': t('go_there'), onclick: () => post('route:teleport', p) }, ico('pin', 14)),
        h('button.btn.sm.ghost', { title: t('move_here'), 'aria-label': t('move_here'), onclick: async () => { const q = await myPosition(); if (q) { Object.assign(p, { x: q.x, y: q.y, z: q.z, w: q.w }); render(); } } }, ico('arrow', 14)),
        h('button.btn.sm.ghost', { title: t('insert_after'), 'aria-label': t('insert_after'), onclick: async () => { const q = await myPosition(); if (q) { list.splice(i + 1, 0, { x: q.x, y: q.y, z: q.z, w: q.w, ...(p.radius !== undefined ? { radius: p.radius } : {}) }); render(); } } }, ico('plus', 14)),
        h('button.btn.sm.ghost', { title: t('move_up'), 'aria-label': t('move_up'), disabled: i === 0 ? true : null, onclick: () => move(-1) }, '↑'),
        h('button.btn.sm.ghost', { title: t('move_down'), 'aria-label': t('move_down'), disabled: i === list.length - 1 ? true : null, onclick: () => move(1) }, '↓'),
        h('button.btn.sm.danger', { title: t('remove'), 'aria-label': t('remove'), onclick: () => { list.splice(i, 1); render(); } }, ico('close', 14)));
}

function defaultsFor(ar, key) {
    const n = (ar[key] || []).length;
    if (key === 'checkpoints') return { radius: ar.route === 'water' ? 18 : ar.route === 'foot' ? 4 : 12 };
    if (key === 'zones') return { radius: 15, id: String.fromCharCode(65 + n), label: `Zone ${String.fromCharCode(65 + n)}` };
    if (key === 'targets') return { radius: 10, label: `Target ${n + 1}` };
    if (key === 'objectives') return { team: n + 1 };
    return {};
}

function pointBox(ar, key, labelKey) {
    const list = ar[key] || [];
    const add = async () => { const p = await myPosition(); if (!p) return; ar[key] = ar[key] || []; ar[key].push({ x: p.x, y: p.y, z: p.z, w: p.w, ...defaultsFor(ar, key) }); render(); };
    const extra = [];
    if (key === 'checkpoints') {
        extra.push(h('button.btn.sm', { onclick: () => post('route:record', { spacing: A.recSpacing || SPACING[ar.route] || 80, target: ar.id }) }, ico('play', 13), t('record_route')));
        if (ar.route === 'road') {
            extra.push(h('button.btn.sm', { onclick: async () => {
                const r = await post('route:fromWaypoint', { spacing: A.recSpacing || 120 });
                if (!r || !r.ok) { toast({ text: t('err_' + ((r && r.res) || 'error')), kind: 'error' }); return; }
                ar.checkpoints = r.res.map((p, i) => ({ ...p, radius: i === r.res.length - 1 ? 14 : 12 }));
                ar.checkpoints[ar.checkpoints.length - 1].label = 'Finish';
                toast({ text: t('recorded_ready', ar.checkpoints.length), kind: 'success' });
                render();
            } }, ico('pin', 13), t('from_waypoint')));
        }
    }
    if (key === 'vehicleSpawns' || key === 'spawns') {
        extra.push(h('button.btn.sm', { onclick: async () => {
            const r = await post('route:grid', { count: 8 });
            if (!r || !r.ok) { toast({ text: t('err_forbidden'), kind: 'error' }); return; }
            ar[key] = r.res;
            render();
        } }, ico('grid', 13), t('start_grid')));
    }
    if (key !== 'checkpoints' && list.length === 0 && !extra.length) {
        return h('div.box.point-box.empty-box', h('div.box-head', t(labelKey), h('span.faint', '(0)'), h('div.spacer'),
            h('button.btn.sm', { onclick: add }, ico('plus', 13), t('add_point_here'))));
    }
    return h('div.box.point-box',
        h('div.box-head', t(labelKey), h('span.faint', `(${list.length})`), h('div.spacer'), ...extra,
            h('button.btn.sm', { onclick: add }, ico('plus', 13), t('add_point_here'))),
        key === 'checkpoints' ? h('div.pad.faint', { style: { fontSize: '12px', paddingBottom: '0' } }, t('record_help')) : null,
        h('div.point-list', list.map((p, i) => pointRow(ar, key, p, i))));
}

function editor() {
    const ar = A.arenaEdit;
    const back = A.returnTo;
    const close = () => { post('route:previewStop'); A.arenaEdit = null; A.previewing = false; if (back) { A.returnTo = null; go(back); } else render(); };
    const save = async () => {
        const payload = JSON.parse(JSON.stringify(ar));
        if (!payload.id) payload.id = (payload.name || 'route').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 48);
        if (!payload.center) {
            const first = (payload.checkpoints || payload.spawns || payload.vehicleSpawns || [])[0];
            if (first) payload.center = { x: first.x, y: first.y, z: first.z };
        }
        delete payload.checked;
        for (const k of Object.keys(payload)) if (Array.isArray(payload[k]) && payload[k].length === 0) delete payload[k];
        const res = await call('admin:arena:save', { arena: payload }, t('saved'));
        if (res) {
            await refresh();
            if (A.editing && back === 'builder') A.editing.arena = res;
            close();
        }
    };
    const togglePreview = () => {
        A.previewing = !A.previewing;
        if (A.previewing) {
            const lists = {};
            pointLists.forEach(([k]) => { if (ar[k] && ar[k].length) lists[k] = ar[k]; });
            post('route:preview', { lists });
        } else post('route:previewStop');
        render();
    };
    return h('div.scroll.pad.col', { style: { gap: '12px' } },
        h('div.form',
            h('div.field', h('label', t('name')), h('input', { value: ar.name || '', maxlength: 64, oninput: (e) => { ar.name = e.target.value; } })),
            h('div.field', h('label', t('id')), h('input', { value: ar.id || '', placeholder: t('auto_from_name'), maxlength: 48, oninput: (e) => { ar.id = e.target.value; } })),
            h('div.field', h('label', t('route')), h('select', { onchange: (e) => { ar.route = e.target.value; render(); } },
                ROUTES.map((r) => h('option', { value: r, selected: (ar.route || 'road') === r ? 'selected' : null }, t('route_' + r)))), h('div.help', t('route_help_' + (ar.route || 'road')))),
            h('div.field', h('label', t('spacing')), h('input', { type: 'number', min: 10, max: 400, value: A.recSpacing || SPACING[ar.route || 'road'], oninput: (e) => { A.recSpacing = Number(e.target.value) || null; } }), h('div.help', t('spacing_help'))),
            h('div.field', h('label', t('center')), h('div.row', h('span.mono.grow', ar.center ? fmtPoint(ar.center) : '—'),
                h('button.btn.sm', { onclick: async () => { const p = await myPosition(); if (p) { ar.center = { x: p.x, y: p.y, z: p.z }; render(); } } }, t('add_point_here')))),
            h('div.field', h('label', t('area_radius')), h('div.row',
                h('input', { type: 'number', value: ar.radius || 150, oninput: (e) => { ar.radius = Number(e.target.value); } }),
                h('label.row', h('input', { type: 'checkbox', checked: !!ar.bounds, onchange: (e) => { ar.bounds = e.target.checked ? { radius: ar.radius } : undefined; } }), t('keep_inside')))),
            h('div.field', h('label', t('finish_line')), h('div.row', h('span.mono.grow', ar.finish ? fmtPoint(ar.finish) : '—'),
                h('button.btn.sm', { onclick: async () => { const p = await myPosition(); if (p) { ar.finish = { x: p.x, y: p.y, z: p.z, radius: 10 }; render(); } } }, t('add_point_here'))))),
        pointLists.map(([k, label]) => pointBox(ar, k, label)),
        h('div.row.editor-foot', {},
            h('button.btn', { onclick: togglePreview }, ico('eye', 14), A.previewing ? t('hide_in_world') : t('show_in_world')),
            h('div.spacer'),
            h('button.btn', { onclick: close }, t('cancel')),
            can('arena.edit') ? h('button.btn.primary', { onclick: save }, t('save')) : null));
}

export function arenaView() {
    return A.arenaEdit ? editor() : arenaList();
}
