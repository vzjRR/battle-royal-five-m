// EVENT STUDIO — in-game HUD. Timers count down locally from `remainingMs`; the server never sends per-second updates.
import { h, $, mount, show, t, errText, fmtClock, fmtRace, categoryOf, placeBadge, store, badge, ico } from './ui.js';
import { post } from './app.js';

let snap = null;          // latest state snapshot
let rows = [];            // scoreboard rows
let teams = null;
let deadline = null;      // Date.now() based
let ticker = null;
let expanded = false;
let lastState = null;
let progress = [];
let mySrc = null;

const statDefs = [
    ['position', (v, x) => x.racers ? `${v}/${x.racers}` : v, 'position'],
    ['lap', (v, x) => `${v}/${x.laps}`, 'lap'],
    ['checkpoint', (v, x) => `${v}/${x.checkpoints}`, 'checkpoint'],
    ['round', (v, x) => `${v}/${x.rounds}`, 'round'],
    ['level', (v, x) => `${v}/${x.levels}`, 'level'],
    ['found', (v, x) => `${v}/${x.total}`, 'found'],
    ['question', (v, x) => `${v}/${x.questions}`, 'question'],
    ['phase', (v, x) => `${v}/${x.phases}`, 'phase'],
    ['kills', (v) => v, 'kills'],
    ['knockouts', (v) => v, 'kills'],
    ['deaths', (v) => v, 'deaths'],
    ['lives', (v) => v, 'lives'],
    ['alive', (v) => v, 'alive'],
    ['target', (v) => v, 'target'],
    ['best', (v) => `${v}ms`, 'best'],
    ['score', (v) => v, 'score'],
];

export function setPosition(pos) { $('hud').classList.toggle('left', pos === 'top-left'); }

function remaining() { return deadline === null ? null : Math.max(0, deadline - Date.now()); }

function startTicker() {
    if (ticker) return;
    ticker = setInterval(tick, 250);
}
function stopTicker() { clearInterval(ticker); ticker = null; }

function tick() {
    const timer = document.querySelector('.hud-timer');
    const r = remaining();
    if (timer) {
        timer.textContent = fmtClock(r);
        timer.classList.toggle('low', r !== null && r < 30000 && snap && snap.state === 'ACTIVE');
    }
    if (snap && snap.state === 'COUNTDOWN') renderCountdown();
    const qbar = document.querySelector('#modepanel .bar > i');
    if (qbar && modeDeadline) qbar.style.width = `${Math.max(0, (modeDeadline - Date.now()) / modeTotal) * 100}%`;
}

function renderCountdown() {
    const r = remaining();
    const n = r === null ? 0 : Math.ceil(r / 1000);
    const el = $('countdown');
    if (el.dataset.n === String(n)) return;
    el.dataset.n = String(n);
    mount(el, h('div.num', n > 0 ? String(n) : t('countdown_go')));
    show(el, true);
}

function flashGo() {
    const el = $('countdown');
    el.dataset.n = 'go';
    mount(el, h('div.num', t('countdown_go')));
    show(el, true);
    setTimeout(() => show(el, false), 900);
}

let hintText = null;

export function onState(d) {
    snap = d;
    if (d.selfSrc) mySrc = d.selfSrc;
    if (d.remainingMs !== null && d.remainingMs !== undefined) deadline = Date.now() + d.remainingMs; else deadline = null;
    const was = lastState;
    lastState = d.state;
    if (d.state === 'LOBBY') {
        mount($('countdown'), h('div.label', d.awaitingStart ? t('waiting_host') : t('lobby')));
        show($('countdown'), true);
    } else if (d.state === 'COUNTDOWN') {
        renderCountdown();
    } else if (d.state === 'ACTIVE' && (was === 'COUNTDOWN' || was === 'LOBBY')) {
        flashGo();
    } else if (d.state !== 'COUNTDOWN') {
        show($('countdown'), false);
    }
    if (d.state === 'PAUSED') banner(t('paused'), 'var(--warn)'); else if (was === 'PAUSED') show($('banner'), false);
    if (d.state === 'REGISTRATION' || d.state === 'SCHEDULED') { show($('hud'), false); return; }
    if (d.state === 'ARCHIVED') { onLeft(); return; }
    renderHud();
    startTicker();
}

function statTiles() {
    const x = (snap && snap.hud) || {};
    const tiles = [];
    for (const [key, fmt, label] of statDefs) {
        if (x[key] !== undefined && x[key] !== null && x[key] !== false && tiles.length < 3) {
            tiles.push(h('div.hud-stat', h('b', String(fmt(x[key], x))), h('span', t(label))));
        }
    }
    if (tiles.length === 0 && snap.you) tiles.push(h('div.hud-stat', h('b', String(snap.you.score ?? 0)), h('span', t('score'))));
    return tiles;
}

function boardRows(limit) {
    const out = [];
    const list = rows.slice(0, limit);
    const meIdx = rows.findIndex((r) => r.src === mySrc);
    if (limit && meIdx >= limit) list.push(rows[meIdx]);
    for (const r of list) {
        const team = teams && r.team ? teams[r.team - 1] : null;
        const out_ = r.status === 'eliminated' || r.status === 'left' || r.status === 'disconnected' || r.status === 'disqualified';
        out.push(h(`div.board-row${r.src === mySrc ? '.me' : ''}${out_ ? '.out' : ''}`,
            placeBadge(r.placement),
            h('div.name', team ? h('span.dot', { style: { background: team.color } }) : null, r.name),
            h('div.val', r.finishMs ? fmtRace(r.finishMs) : (r.extra || String(r.score ?? 0)))));
    }
    return out;
}

function renderHud() {
    if (!snap) return;
    const cat = categoryOf(snap.category);
    const x = snap.hud || {};
    const you = snap.you || {};
    const cards = [];
    cards.push(h('div.hud-card',
        h('div.hud-head',
            badge(snap.category, snap.icon),
            h('div', h('div.hud-title', snap.name), h('div.hud-sub', snap.role === 'spectator' ? t('spectating') : (you.status === 'eliminated' ? t('eliminated') : (you.status === 'finished' ? t('finished') : t('status_live'))))),
            h('div.hud-timer', fmtClock(remaining()))),
        snap.objective ? h('div.hud-objective', snap.objective) : null,
        snap.role === 'participant' ? h('div.hud-stats', statTiles()) : null,
        snap.teams ? h('div.hud-teams', snap.teams.map((tm) => h('div.hud-team', { vars: { '--c': tm.color } }, h('b', String((teams && teams[tm.index - 1] ? teams[tm.index - 1].score : tm.score) ?? 0)), h('span', tm.name)))) : null,
        x.clue ? h('div.hud-clue', x.clue) : null,
        x.instructions ? h('div.hud-clue', x.instructions) : null,
        x.holding ? h('div.hud-clue', `${t('holding')}: ${x.holding}`) : null,
        hintText ? h('div.hud-clue', hintText) : null,
        role && snap.role === 'participant' ? h('div.hud-clue', { style: { borderColor: role.color || 'var(--accent-line)' } }, `${t('role')}: ${role.label}`) : null,
        progress.length ? progress.map((p) => h('div', h('div.muted', { style: { fontSize: '11px', marginTop: '8px' } }, `${p.id} · ${Math.round(p.value * 100)}%`), h('div.bar', h('i', { style: { width: `${p.value * 100}%` } })))) : null,
    ));
    if (rows.length) cards.push(h('div.hud-card.board', { style: { padding: '6px 0' } }, boardRows(store.ui.scoreboardRows || 5)));
    mount($('hud'), cards);
    show($('hud'), true);
}

export function onScoreboard(d) {
    rows = d.rows || [];
    if (d.teams) teams = d.teams;
    if (snap && snap.you) {
        // identify self: the row whose name/status matches `you` is ambiguous, so the client includes our src via state of rows
        const me = rows.find((r) => r.src === mySrc);
        if (!me && snap.selfSrc) mySrc = snap.selfSrc;
    }
    renderHud();
    if (expanded) expandBoard(true);
}

export function expandBoard(open) {
    expanded = open;
    let el = document.querySelector('.board-expanded');
    if (!open) { if (el) el.remove(); return; }
    if (!el) { el = h('div.hud-card.board-expanded'); document.body.appendChild(el); }
    mount(el, h('div.section-title', { style: { padding: '8px 14px 0' } }, snap ? snap.name : ''), boardRows(0));
}

/** Checkpoint passed: update the lap / checkpoint tiles at once (the full state snapshot follows from the server). */
export function onCheckpoints(d) {
    const pr = d && d.personal;
    if (!pr || !snap || !snap.hud) return;
    if (snap.hud.checkpoints !== undefined) Object.assign(snap.hud, { checkpoint: pr.passed ?? snap.hud.checkpoint, checkpoints: pr.total ?? snap.hud.checkpoints });
    if (snap.hud.laps !== undefined) Object.assign(snap.hud, { lap: pr.lap ?? snap.hud.lap, laps: pr.laps ?? snap.hud.laps });
    renderHud();
}

export function onZoneProgress(list) { progress = list || []; renderHud(); }

export function onLeft() {
    snap = null; rows = []; teams = null; deadline = null; progress = []; expanded = false; hintText = null; role = null;
    stopTicker();
    ['hud', 'countdown', 'banner', 'warning', 'modepanel', 'spectate'].forEach((id) => show($(id), false));
    expandBoard(false);
    post('focus', { on: false });
}

// Toasts & banners -----------------------------------------------------------

export function toast(d) {
    const text = d.key ? errText(String(d.text).replace(/^err_/, '')) : (store.strings[d.text] ? t(d.text) : d.text);
    const el = h(`div.toast.${d.kind || 'info'}`, text);
    $('toasts').appendChild(el);
    while ($('toasts').children.length > 4) $('toasts').firstChild.remove();
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 350); }, d.kind === 'global' ? 7000 : 4500);
}

let bannerTimer = null;
function banner(text, color, ms) {
    const el = $('banner');
    el.style.setProperty('--c', color || '#fff');
    mount(el, text);
    show(el, true);
    clearTimeout(bannerTimer);
    if (ms) bannerTimer = setTimeout(() => show(el, false), ms);
}

export function warning(kind, on) {
    const el = $('warning');
    if (on) { mount(el, t(kind === 'zone' ? 'outside_zone' : 'outside_bounds')); show(el, true); } else show(el, false);
}

// Results --------------------------------------------------------------------

export function onResults(d) {
    const el = $('results');
    const teamsById = {};
    (d.teams || []).forEach((tm) => { teamsById[tm.index] = tm; });
    mount(el, h('div.card',
        h('div.top', h('div.muted', t('results')), h('h1', d.name), d.winner ? h('div.winner', ico('trophy', 16), ` ${t('winner')}: ${d.winner}`) : null),
        d.teams ? h('div.pad', { style: { display: 'flex', gap: '8px' } }, d.teams.map((tm) => h('div.hud-team', { vars: { '--c': tm.color } }, h('b', `#${tm.placement} · ${tm.score}`), h('span', tm.name)))) : null,
        h('table.tbl',
            h('tr', h('th', t('place')), h('th', t('name')), h('th.num', t('score')), h('th.num', t('kills')), h('th.num', t('time')), h('th.num', t('points'))),
            (d.rows || []).map((r) => h(`tr${r.src === mySrc ? '.me' : ''}`,
                h('td', placeBadge(r.placement)),
                h('td', r.name, r.team && teamsById[r.team] ? h('span.faint', ` · ${teamsById[r.team].name}`) : null),
                h('td.num', String(r.score ?? 0)), h('td.num', String(r.kills ?? 0)),
                h('td.num', r.finishMs ? fmtRace(r.finishMs) : '—'), h('td.num', String(r.points ?? 0))))),
    ));
    show(el, true);
    setTimeout(() => show(el, false), Math.max(4000, (d.remainingMs || 10000) - 500));
}

// Spectator ------------------------------------------------------------------

export function onSpectate(d) {
    const el = $('spectate');
    if (!d.active) { show(el, false); return; }
    mount(el, h('div.muted', t('spectating')), h('b', d.free ? t('free_cam') : (d.target || '—')),
        d.count ? h('div.faint', `${d.index}/${d.count}`) : null, h('div.muted', t('spec_controls')));
    show(el, true);
}

// Mode panels (trivia, reaction, hunt hints, red light banner) --------------------

let modeDeadline = null;
let modeTotal = 1;
let picked = null;

function closeModePanel() { show($('modepanel'), false); post('focus', { on: false }); modeDeadline = null; }

function trivia(q) {
    const el = $('modepanel');
    if (q.phase === 'memorize') {
        modeTotal = q.remainingMs; modeDeadline = Date.now() + q.remainingMs;
        mount(el, h('div.muted', `${t('question')} ${q.index}/${q.total} · ${t('memorize')}`),
            h('h2', { style: { fontSize: '30px', letterSpacing: '.12em', textAlign: 'center' } }, (q.items || []).join('  ')),
            h('div.bar', h('i', { style: { width: '100%' } })));
        show(el, true);
        startTicker();
        return;
    }
    if (q.phase === 'question') {
        picked = null;
        modeTotal = q.remainingMs; modeDeadline = Date.now() + q.remainingMs;
        const send = (data, btn) => {
            post('action', { action: 'answer', data }).then((r) => {
                if (r && r.ok) { picked = data.choice; if (btn) btn.classList.add('picked'); toast({ text: 'answer_sent', kind: 'info' }); post('focus', { on: false }); }
            });
        };
        let body;
        if (q.numeric) {
            const input = h('input', { type: 'number', placeholder: t('your_answer') });
            body = h('div.row', input, h('button.btn.primary', { onclick: () => send({ value: Number(input.value) }) }, t('submit')));
            setTimeout(() => input.focus(), 50);
        } else {
            body = h('div.answers', q.answers.map((a, i) => {
                const b = h('button.answer', { 'data-i': i + 1, onclick: () => picked === null && send({ choice: i + 1 }, b) }, `${i + 1}. `, a);
                return b;
            }));
        }
        mount(el, h('div.muted', `${t('question')} ${q.index}/${q.total}`), h('h2', q.text), body, h('div.bar', h('i', { style: { width: '100%' } })));
        show(el, true);
        post('focus', { on: true });
        startTicker();
    } else if (q.phase === 'reveal') {
        modeDeadline = null;
        post('focus', { on: false });
        el.querySelectorAll('.answer').forEach((b) => {
            const i = Number(b.dataset.i);
            if (i === q.correct) b.classList.add('correct'); else if (i === picked) b.classList.add('wrong');
        });
        el.appendChild(h('div', { style: { marginTop: '12px', fontWeight: '700' } },
            q.gained ? `${t('correct')} +${q.gained}` : (q.answered ? t('wrong') : ''), ' ', h('span.muted', `${t('correct_was')} ${q.correctText}`)));
        setTimeout(() => { if (!modeDeadline) show(el, false); }, 3800);
    }
}

function reaction(r) {
    const el = $('modepanel');
    const press = () => post('action', { action: 'react' });
    if (r.phase === 'ready') {
        mount(el, h('div.muted', `${t('round')} ${r.round}/${r.rounds}`), h('div.react', { onclick: press }, t('react_wait')));
        show(el, true);
        post('focus', { on: true });
    } else if (r.phase === 'go') {
        const pad = el.querySelector('.react');
        if (pad) { pad.classList.add('go'); pad.textContent = t('react_go'); }
    } else if (r.phase === 'early') {
        const pad = el.querySelector('.react');
        if (pad) pad.textContent = t('react_early');
    } else if (r.phase === 'recorded') {
        const pad = el.querySelector('.react');
        if (pad) pad.textContent = `${r.ms} ms`;
        post('focus', { on: false });
    } else if (r.phase === 'results') {
        post('focus', { on: false });
        mount(el, h('div.muted', `${t('round')} ${r.round} · ${t('results')}`),
            h('table.tbl', (r.rows || []).slice(0, 8).map((x, i) => h('tr', h('td', placeBadge(i + 1)), h('td', x.name), h('td.num', `${x.ms} ms`), h('td.num', `+${x.points}`)))));
    }
}

window.addEventListener('keydown', (e) => {
    const panel = $('modepanel');
    if (panel.classList.contains('hidden')) return;
    const pad = panel.querySelector('.react');
    if (pad && (e.key === 'Enter' || e.key === ' ')) post('action', { action: 'react' });
    if (/^[1-4]$/.test(e.key)) { const b = panel.querySelector(`.answer[data-i="${e.key}"]`); if (b) b.click(); }
});

export function onMode(d) {
    if (d.banner) banner(d.banner.text, d.banner.color, d.banner.untilMs ? Math.min(d.banner.untilMs, 8000) : 0);
    if (d.hint) { hintText = `${t('hint_' + d.hint.band)}${d.hint.distance ? ` · ~${d.hint.distance} m` : ''}`; renderHud(); }
    if (d.trivia) trivia(d.trivia);
    if (d.reaction) reaction(d.reaction);
}

export function setSelf(src) { mySrc = src; }

let role = null;
export function onRole(d) {
    const changed = !role || role.role !== d.role;
    role = d;
    if (changed && !d.silent) banner(d.label.toUpperCase(), d.color || 'var(--accent)', 2500);
    renderHud();
}
