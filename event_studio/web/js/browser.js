// EVENT STUDIO — player event browser (live & open, upcoming, leaderboard, tournaments)
import { h, $, mount, show, t, errText, fmtClock, fmtDate, fmtRace, categoryOf, placeBadge, statusChip, store, badge, ico } from './ui.js';
import { rpc, closePanels, embed } from './app.js';
import { toast } from './hud.js';
import { confirmDialog, brandLogo } from './admin/admin.js';

let tab = 'live';
let data = null;
let selected = null;
let details = null;
let refreshTimer = null;
let board = { category: '*', rows: [] };

export function open() {
    show($('browser'), true);
    tab = 'live';
    selected = null;
    details = null;
    load();
    clearInterval(refreshTimer);
    refreshTimer = setInterval(() => { if (tab === 'live') load(true); }, 5000);
}

export function onClose() { clearInterval(refreshTimer); refreshTimer = null; }

export function onState() {
    if (!$('browser').classList.contains('hidden')) load(true);
}

async function load(silent) {
    const r = await rpc('browser:list');
    if (!r.ok) { if (!silent) toast({ text: errText(r.res), kind: 'error' }); return; }
    data = r.res;
    if (selected && !data.live.find((c) => c.id === selected)) { selected = null; details = null; }
    if (selected) await loadDetails(selected, true);
    render();
}

async function loadDetails(id, silent) {
    const r = await rpc('browser:details', { id });
    if (r.ok) details = r.res; else if (!silent) toast({ text: errText(r.res), kind: 'error' });
}

async function loadBoard() {
    const r = await rpc('leaderboard:get', { category: board.category === '*' ? undefined : board.category });
    if (r.ok) board = { ...board, ...r.res };
    render();
}

async function act(name, payload, okKey) {
    const r = await rpc(name, payload);
    if (!r.ok) { toast({ text: errText(r.res), kind: 'error' }); return false; }
    if (okKey) toast({ text: t(okKey), kind: 'success' });
    await load(true);
    return true;
}

function header() {
    const brand = store.ui.brand || {};
    const tabs = [['live', t('live')], ['upcoming', t('upcoming')], ['leaderboard', t('leaderboard')], ['tournaments', t('tournaments')]];
    return h('div.shell-head',
        h('div.brand', brandLogo(), h('div', h('h1.display', brand.title || 'Event Studio'), h('small', brand.subtitle || t('events')))),
        h('div.tabs', tabs.map(([k, label]) => h(`button.tab${tab === k ? '.active' : ''}`, {
            onclick: () => { tab = k; if (k === 'leaderboard') loadBoard(); render(); },
        }, label))),
        embed ? null : h('button.close-x', { onclick: closePanels, 'aria-label': t('close') }, ico('close')));
}

function card(c) {
    const cat = categoryOf(c.category);
    const pct = Math.min(100, Math.round((c.players / Math.max(1, c.maxPlayers)) * 100));
    return h(`div.card${selected === c.id ? '.selected' : ''}`, {
        vars: { '--c': c.color || cat.color },
        onclick: async () => { selected = c.id; await loadDetails(c.id); render(); },
    },
        h('div.card-banner', c.banner ? { style: { backgroundImage: `url("${encodeURI(c.banner)}")` } } : null,
            badge(c.category, c.icon, 'icon'), statusChip(c.status)),
        h('div.card-body',
            h('div.card-title', c.name),
            h('div.card-meta',
                h('div', `${t('players')}: `, h('b', `${c.players}/${c.maxPlayers}`)),
                h('div', `${t('difficulty')}: `, h('b', t('diff_' + c.difficulty))),
                h('div', `${t('duration')}: `, h('b', c.duration ? fmtClock(c.duration * 1000) : '—')),
                h('div', `${t('reward')}: `, h('b', c.reward || '—')),
            ),
            h('div.card-foot',
                h('div.fill', h('i', { style: { width: `${pct}%` } })),
                c.status === 'open' && c.remainingMs !== null ? h('span.faint.mono', fmtClock(c.remainingMs)) : null,
                c.joined ? h('span.chip.open', ico('check', 12)) : null)));
}

function detailPanel() {
    const d = details;
    if (!d) return h('div.detail', h('div.empty', t('details')));
    const cat = categoryOf(d.category);
    const current = data && data.current;
    const canJoin = d.status === 'open' && !d.joined && !current;
    const canSpectate = d.spectators && (d.status === 'live' || d.status === 'starting') && !d.joined && !current;
    return h('div.detail',
        h('div.scroll.pad.grow', { style: { display: 'flex', flexDirection: 'column', gap: '14px' } },
            h('div.row', badge(d.category, d.icon, 'badge-lg'), h('div.grow', h('div.eyebrow', d.modeLabel), h('h2.display', d.name)), statusChip(d.status)),
            d.description ? h('div.muted', d.description) : null,
            h('div.kv',
                h('span', t('players')), h('b', `${d.players}/${d.maxPlayers} (min ${d.minPlayers})`),
                h('span', t('difficulty')), h('b', t('diff_' + d.difficulty)),
                h('span', t('duration')), h('b', d.duration ? fmtClock(d.duration * 1000) : '—'),
                d.teams ? [h('span', t('teams')), h('b', String(d.teams))] : null,
                d.status === 'open' && d.remainingMs !== null ? [h('span', t('starts_in')), h('b.mono', fmtClock(d.remainingMs))] : null),
            d.rules ? h('div', h('div.section-title', t('rules')), h('div.muted', d.rules)) : null,
            d.rewards && d.rewards.length ? h('div', h('div.section-title', t('rewards')), h('div.list-plain', d.rewards.map((r) => h('div', h('b', r.label === 'participation' ? t('participation') : r.label), ' ', r.items.join(', '))))) : null,
            d.bests && d.bests.length ? h('div', h('div.section-title', t('best_times')), h('div.list-plain', d.bests.map((b) => h('div.row', placeBadge(b.rank), h('span.grow', b.name), h('span.mono', fmtRace(b.best_ms)))))) : null,
            h('div', h('div.section-title', `${t('participants')} (${d.participants.length})`),
                h('div.list-plain', d.participants.length ? d.participants.map((p) => h('div.row', h('span.grow', p.name), p.team && d.teamsInfo ? h('span.faint', d.teamsInfo[p.team - 1].name) : null)) : h('div.faint', '—')))),
        h('div.pad.row', { style: { borderTop: '1px solid var(--line)' } }, actions(d)));
}

function actions(d) {
    const current = data && data.current;
    const canJoin = d.status === 'open' && !d.joined && !current;
    const canSpectate = d.spectators && (d.status === 'live' || d.status === 'starting') && !d.joined && !current;
    return [
        d.joined ? h('span.chip.open', t('joined')) : null,
        h('div.spacer'),
        canSpectate ? h('button.btn', { onclick: () => act('event:spectate', { id: d.id }).then((ok) => ok && closePanels()) }, ico('eye', 15), t('spectate')) : null,
        d.joined ? h('button.btn.danger', { onclick: () => confirmDialog(t('leave'), t('leave_confirm'), () => act('event:leave', {})) }, t('leave')) : null,
        canJoin ? h('button.btn.primary', { onclick: () => act('event:join', { id: d.id }, 'joined_toast') }, t('join')) : null,
    ];
}

// Compact / docked layouts: one slim list, the selected event opens in place.
function metaLine(c) {
    return [c.modeLabel, `${c.players}/${c.maxPlayers}`, c.duration ? fmtClock(c.duration * 1000) : null].filter(Boolean).join(' · ');
}

function listRow(c) {
    const open = selected === c.id;
    const head = h('div.erow-head',
        badge(c.category, c.icon, 'badge'),
        h('div.grow', h('b.erow-name', c.name), h('small.faint', metaLine(c),
            c.status === 'open' && c.remainingMs !== null ? [' · ', h('span.mono.accent', fmtClock(c.remainingMs))] : null)),
        c.reward ? h('b.erow-prize', c.reward) : null,
        statusChip(c.status));
    if (!open) {
        return h('button.erow', { onclick: async () => { selected = c.id; await loadDetails(c.id); render(); } }, head);
    }
    const d = details && details.id === c.id ? details : null;
    return h('div.erow.open', head,
        d && d.description ? h('div.muted.erow-desc', d.description) : null,
        d && d.rewards && d.rewards.length ? h('div.erow-rewards', d.rewards.slice(0, 4).map((r, i) => h('span',
            h(`span.medal.m${i + 1}`), h('b', r.label === 'participation' ? t('participation') : r.label), ' ', r.items.join(', ')))) : null,
        d ? h('div.row.erow-actions', actions(d)) : h('div.faint', '…'));
}

function listView() {
    const live = (data && data.live) || [];
    const openCount = live.filter((c) => c.status === 'open').length;
    return [
        h('div.scroll.grow.elist', live.length ? live.map(listRow) : h('div.empty', t('no_events'))),
        h('div.efoot', h('span', t('events_summary', live.length, openCount)), embed ? null : h('span', t('close_hint', (store.ui.keys && store.ui.keys.browser) || 'F7')))];
}

function liveView() {
    const live = (data && data.live) || [];
    return h('div.shell-body',
        h('div.scroll.pad.grow', live.length ? h('div.cards', live.map(card)) : h('div.empty', t('no_events'))),
        detailPanel());
}

function upcomingView() {
    const list = (data && data.upcoming) || [];
    return h('div.shell-body', h('div.scroll.pad.grow',
        list.length ? list.map((u) => {
            const when = fmtDate(u.at);
            const cat = categoryOf(u.category);
            return h('div.upcoming-row', h('div.when', when.time, h('small', when.day)), badge(u.category),
                h('div.grow', h('b', u.name), h('div.faint', u.category ? u.category : '')), h('span.chip.upcoming', t('status_upcoming')));
        }) : h('div.empty', '—')));
}

function leaderboardView() {
    const cats = ['*', ...Object.keys(store.ui.categories || {})];
    return h('div.shell-body', h('div.scroll.pad.grow',
        h('div.row', { style: { marginBottom: '14px' } },
            h('select', { style: { width: '220px' }, onchange: (e) => { board.category = e.target.value; loadBoard(); } },
                cats.map((c) => h('option', { value: c, selected: board.category === c ? 'selected' : null }, c === '*' ? t('all_categories') : c))),
            h('span.muted', `${t('season')}: ${board.season || ''}`)),
        board.rows && board.rows.length ? h('table.tbl',
            h('tr', h('th', '#'), h('th', t('name')), h('th.num', t('points')), h('th.num', t('wins')), h('th.num', t('podiums')), h('th.num', t('events_joined')), h('th.num', t('kills'))),
            board.rows.map((r) => h('tr', h('td', placeBadge(r.rank)), h('td', r.name), h('td.num', String(r.points)), h('td.num', String(r.wins)),
                h('td.num', String(r.podiums)), h('td.num', String(r.joined)), h('td.num', String(r.kills))))) : h('div.empty', '—')));
}

function tournamentsView() {
    const list = (data && data.tournaments) || [];
    return h('div.shell-body', h('div.scroll.pad.grow',
        list.length ? list.map((tt) => h('div.upcoming-row',
            badge('tournament'),
            h('div.grow', h('b', tt.name), h('div.faint', `${t('format_' + tt.format)} · ${t('best_of')} ${tt.bestOf} · ${t('entrants')}: ${tt.entrants}`)),
            tt.status === 'registration' ? h('button.btn.primary', { onclick: () => act('tournament:join', { id: tt.id }, 'joined_toast') }, t('register')) : h('span.chip.live', t('status_live')))) : h('div.empty', '—')));
}

const layout = () => {
    if (embed) return embed === 'tablet' ? 'compact' : 'docked'; // phone / tablet app
    return ['compact', 'docked', 'full'].includes(store.ui.browserLayout) ? store.ui.browserLayout : 'compact';
};

function render() {
    const views = { live: layout() === 'full' ? liveView : listView, upcoming: upcomingView, leaderboard: leaderboardView, tournaments: tournamentsView };
    mount($('browser'), h(`div.shell.shell-${layout()}`, header(), views[tab]()));
}

/** Appearance changed while the window is open. */
export function onUI() {
    if (!$('browser').classList.contains('hidden')) render();
}
