// EVENT STUDIO — NUI entry: message bus, NUI callbacks, theme/branding, panel routing.
import { store, $, show } from './ui.js';
import * as hud from './hud.js';
import * as browser from './browser.js';
import * as admin from './admin/admin.js';
import { applyUI } from './theme.js';

// Inside a phone or tablet the page is an iframe on cfx-nui-<resource>; the resource name comes from the address.
const hostResource = (location.hostname.match(/^cfx-nui-(.+)$/) || [])[1];
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : (hostResource || 'event_studio');
export const inGame = typeof GetParentResourceName === 'function' || Boolean(hostResource);

/** Phone / tablet app mode (web/phone.html): 'phone' | 'tablet' | 'npwd', or null for the normal overlay. */
export const embed = document.body.dataset.embed ? (new URLSearchParams(location.search).get('device') || 'phone') : null;

/** POST to a Lua NUI callback. */
export async function post(name, data = {}) {
    if (!inGame) return (window.__devPost ? window.__devPost(name, data) : { ok: false, res: 'dev' });
    try {
        const r = await fetch(`https://${resource}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
        return await r.json();
    } catch (e) {
        return { ok: false, res: 'timeout' };
    }
}

/** Call a server RPC through the client passthrough. */
export async function rpc(name, payload = {}) {
    const r = await post('rpc', { name, payload });
    return r || { ok: false, res: 'timeout' };
}

export function closePanels() {
    if (embed) { post('phone:close'); return; } // the phone owns the window: ask it to close
    show($('browser'), false);
    show($('admin'), false);
    browser.onClose();
    admin.onClose();
    post('close');
}

function applyLocale(locale) {
    const l = locale || {};
    document.documentElement.lang = l.code || 'en';
    document.documentElement.dir = l.dir === 'rtl' ? 'rtl' : 'ltr';
}

export function applyBranding(ui) {
    applyUI(ui);
    hud.setPosition(ui.hudPosition);
}

const handlers = {
    init(d) {
        Object.assign(store, { strings: d.strings || {}, ui: d.ui || {}, staff: d.staff, role: d.role, scoring: d.scoring || {}, commands: d.commands || {} });
        applyBranding(store.ui);
        applyLocale(d.locale);
    },
    // live appearance change from the Admin Center
    ui(d) {
        store.ui = d || {};
        applyBranding(store.ui);
        browser.onUI();
        admin.onUI();
    },
    // staff picked another language
    locale(d) {
        if (d.strings) store.strings = d.strings;
        applyLocale(d.locale);
        browser.onUI();
        admin.onUI();
    },
    close: () => closePanels(),
    arenaCheck: (d) => admin.onArenaCheck(d),
    arenaRecorded: (d) => admin.onArenaRecorded(d),
    open(d) {
        if (d.view === 'browser') browser.open();
        if (d.view === 'admin') admin.open(d.data);
    },
    state: (d) => { hud.onState(d); browser.onState(d); },
    scoreboard: (d) => hud.onScoreboard(d),
    scoreboardExpand: (d) => hud.expandBoard(d.open),
    toast: (d) => hud.toast(d),
    results: (d) => hud.onResults(d),
    left: (d) => hud.onLeft(d),
    mode: (d) => hud.onMode(d),
    checkpoints: (d) => hud.onCheckpoints(d),
    zones: () => {},
    zoneProgress: (d) => hud.onZoneProgress(d),
    zoneWarning: (d) => hud.warning('zone', d.outside),
    boundsWarning: (d) => hud.warning('bounds', d.outside),
    spectate: (d) => hud.onSpectate(d),
    role: (d) => hud.onRole(d),
};

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    const fn = handlers[action];
    if (fn) {
        try { fn(data || {}); } catch (err) { console.error('[event_studio]', action, err); }
    }
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !embed) {
        if (!$('confirm').classList.contains('hidden')) return;
        if (!$('browser').classList.contains('hidden') || !$('admin').classList.contains('hidden')) closePanels();
    }
});

// Phone / tablet app: no messages reach an iframe inside another resource, so the page asks for its data and
// checks for appearance changes itself (a local call, nothing goes to the server).
async function startEmbedded() {
    document.body.classList.add('embed', `embed-${embed}`);
    let last = '';
    const sync = async (first) => {
        const d = await post('phone:init', { device: embed });
        if (!d || !d.ui) return;
        const sig = JSON.stringify([d.ui, d.locale && d.locale.code]);
        if (first) { handlers.init(d); browser.open(); } else if (sig !== last) { handlers.init(d); browser.onUI(); }
        last = sig;
    };
    await sync(true);
    setInterval(() => sync(false), 10000);
}

if (embed && inGame) startEmbedded();
else if (!embed) post('ready');
if (embed) document.body.classList.add('embed', `embed-${embed}`);
if (!inGame) import('./dev.js').catch(() => {});
