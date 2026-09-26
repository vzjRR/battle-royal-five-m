// EVENT STUDIO — NUI entry: message bus, NUI callbacks, theme/branding, panel routing.
import { store, $, show } from './ui.js';
import * as hud from './hud.js';
import * as browser from './browser.js';
import * as admin from './admin/admin.js';

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'event_studio';
export const inGame = typeof GetParentResourceName === 'function';

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

function applyBranding(ui) {
    if (ui.theme && ui.theme !== 'default') $('theme').setAttribute('href', `themes/${ui.theme}.css`);
    if (ui.brand && ui.brand.accent) document.documentElement.style.setProperty('--accent', ui.brand.accent);
    hud.setPosition(ui.hudPosition);
}

const handlers = {
    init(d) {
        Object.assign(store, { strings: d.strings || {}, ui: d.ui || {}, staff: d.staff, role: d.role, scoring: d.scoring || {}, commands: d.commands || {} });
        applyBranding(store.ui);
        applyLocale(d.locale);
    },
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
    if (e.key === 'Escape') {
        if (!$('confirm').classList.contains('hidden')) return;
        if (!$('browser').classList.contains('hidden') || !$('admin').classList.contains('hidden')) closePanels();
    }
});

post('ready');
if (!inGame) import('./dev.js').catch(() => {});
