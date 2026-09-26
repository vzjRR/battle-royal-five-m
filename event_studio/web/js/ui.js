// EVENT STUDIO — tiny DOM + i18n helpers. All user-provided text is inserted as text nodes (never innerHTML).
import { glyph, icon } from './icons.js';

export const store = { strings: {}, ui: {}, staff: false, role: null, scoring: {}, commands: {} };

/** h('div.class#id', { onclick, style, ... }, ...children) */
export function h(sel, attrs, ...children) {
    const m = sel.match(/^([a-z0-9]+)?((?:[.#][\w-]+)*)$/i);
    const el = document.createElement((m && m[1]) || 'div');
    if (m && m[2]) {
        for (const part of m[2].match(/[.#][\w-]+/g)) {
            if (part[0] === '.') el.classList.add(part.slice(1)); else el.id = part.slice(1);
        }
    }
    if (attrs && (typeof attrs !== 'object' || attrs instanceof Node || Array.isArray(attrs))) { children.unshift(attrs); attrs = null; }
    for (const [k, v] of Object.entries(attrs || {})) {
        if (v === undefined || v === null || v === false) continue;
        if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
        else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
        else if (k === 'vars') for (const [vk, vv] of Object.entries(v)) el.style.setProperty(vk, vv);
        else if (k === 'value') el.value = v;
        else if (k === 'checked') el.checked = !!v;
        else el.setAttribute(k, v === true ? '' : v);
    }
    append(el, children);
    return el;
}

function append(el, children) {
    for (const c of children.flat(Infinity)) {
        if (c === null || c === undefined || c === false) continue;
        el.appendChild(c instanceof Node ? c : document.createTextNode(String(c)));
    }
}

export function clear(el) { while (el.firstChild) el.removeChild(el.firstChild); return el; }
export function mount(el, ...children) { clear(el); append(el, children); return el; }
export const $ = (id) => document.getElementById(id);
export const show = (el, on = true) => el.classList.toggle('hidden', !on);

/** Translate a key with %s / %d placeholders. */
export function t(key, ...args) {
    let s = store.strings[key];
    if (s === undefined) return key.replace(/_/g, ' ');
    let i = 0;
    return s.replace(/%[sd]/g, () => (args[i++] ?? ''));
}

export function errText(code) {
    const key = 'err_' + String(code || 'error').split(':')[0];
    return store.strings[key] ? t(key) : String(code);
}

export function fmtClock(ms) {
    if (ms === null || ms === undefined) return '--:--';
    const s = Math.max(0, Math.ceil(ms / 1000));
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export function fmtRace(ms) {
    if (ms === null || ms === undefined) return '';
    const m = Math.floor(ms / 60000), s = Math.floor(ms / 1000) % 60, r = ms % 1000;
    return `${m}:${String(s).padStart(2, '0')}.${String(r).padStart(3, '0')}`;
}

export function fmtDate(unix) {
    const d = new Date(unix * 1000);
    const loc = store.ui.dateFormat || undefined;
    return {
        day: d.toLocaleDateString(loc, { weekday: 'short', day: 'numeric', month: 'short' }),
        time: d.toLocaleTimeString(loc, { hour: '2-digit', minute: '2-digit', hour12: !!store.ui.hour12 }),
    };
}

export function categoryOf(cat) {
    return (store.ui.categories && store.ui.categories[cat]) || { icon: 'star', color: 'var(--accent)' };
}

/** Icon badge for a category (or an explicit icon name / emoji). */
export function badge(cat, override, cls = 'badge') {
    const c = categoryOf(cat);
    return h(`span.${cls}`, { vars: { '--c': c.color } }, glyph(override || c.icon, cls === 'badge-lg' ? 22 : 18));
}

/** Inline icon (null-safe) for buttons and headings. */
export const ico = (name, size = 16) => icon(name, size);

export function placeBadge(p) {
    return h(`span.place${p && p <= 3 ? '.p' + p : ''}`, p ?? '–');
}

export function statusChip(status) {
    return h(`span.chip.${status}`, t('status_' + status));
}
