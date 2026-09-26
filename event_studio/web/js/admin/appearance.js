// EVENT STUDIO — Admin Center → Appearance: theme gallery, player window layout, colors, branding, category icons.
// Changes preview instantly on this screen; Save stores them on the server and applies them for every player.
import { h, t, store, badge, ico } from '../ui.js';
import { ICON_NAMES } from '../icons.js';
import { applyBranding } from '../app.js';
import { can, call, render, danger } from './admin.js';

const COLOR_KEYS = ['accent', 'accent2', 'background', 'panel', 'text', 'good', 'warn', 'bad'];
const LAYOUTS = ['compact', 'docked', 'full'];
// Same list as server/core/ui.lua (F8 is the console and is never offered).
const KEYS = [...[1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12].map((n) => 'F' + n), ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split(''),
    ...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => 'NUMPAD' + n), 'HOME', 'END', 'INSERT', 'DELETE', 'PAGEUP', 'PAGEDOWN'];
const KEY_ACTIONS = ['browser', 'scoreboard', 'reset'];

const S = { loaded: false, loading: false, base: null, baseKeys: {}, draft: null, dirty: false };

const clone = (v) => JSON.parse(JSON.stringify(v ?? null));

function blankDraft(overrides) {
    const o = clone(overrides) || {};
    return { ...o, brand: { ...(o.brand || {}) }, colors: { ...(o.colors || {}) }, categories: { ...(o.categories || {}) }, keys: { ...(o.keys || {}) } };
}

async function load() {
    if (S.loading) return;
    S.loading = true;
    const res = await call('admin:ui:get', {});
    S.loading = false;
    if (!res) return;
    S.base = res.base;
    S.baseKeys = res.baseKeys || {};
    S.draft = blankDraft(res.overrides);
    S.loaded = true;
    S.dirty = false;
    render();
}

/** Base config + draft, in the same shape the server sends to players. */
function effective() {
    const base = clone(S.base) || {};
    const d = S.draft;
    const out = { ...base, ...d, brand: { ...(base.brand || {}), ...d.brand }, colors: { ...(base.colors || {}) }, categories: clone(base.categories) || {} };
    for (const [k, v] of Object.entries(d.colors)) if (v) out.colors[k] = v;
    for (const [cat, v] of Object.entries(d.categories)) out.categories[cat] = { ...(out.categories[cat] || {}), ...v };
    out.keys = keysOf();
    out.themes = store.ui.themes;
    return out;
}

function change(fn) {
    fn(S.draft);
    S.dirty = true;
    applyBranding(effective());
    render();
}

export function onAppearanceUI() {
    if (S.loaded && !S.dirty) S.loaded = false; // someone else saved: reload next time the page renders
}

function section(title, ...body) {
    return h('div.box', h('div.box-head', title), h('div.pad.col', { style: { gap: '14px' } }, ...body));
}

function themeGallery(eff) {
    return h('div.theme-grid', (store.ui.themes || []).map((th) => h(`button.theme-card${eff.theme === th.id ? '.active' : ''}`, {
        onclick: () => change((d) => { d.theme = th.id; }), 'aria-pressed': eff.theme === th.id ? 'true' : 'false',
    },
        h('span.swatches', (th.preview || []).map((c) => h('i', { style: { background: c } }))),
        h('b', th.name),
        h('small', `${th.shape === 'cut' ? t('shape_cut') : t('shape_round')}${eff.theme === th.id ? ` · ${t('selected')}` : ''}`))));
}

function layoutPicker(eff) {
    return h('div.col',
        h('div.layout-grid', LAYOUTS.map((l) => h(`button.layout-card${eff.browserLayout === l ? '.active' : ''}`, {
            onclick: () => change((d) => { d.browserLayout = l; }),
        }, h(`span.layout-mini.${l}`, h('i')), h('b', t('layout_' + l)), h('small', t('layout_' + l + '_help'))))),
        h('label.field.check', h('input', {
            type: 'checkbox', id: 'ap-keep', checked: eff.browserKeepMoving === true, disabled: eff.browserLayout !== 'docked' ? true : null,
            onchange: (e) => change((d) => { d.browserKeepMoving = e.target.checked; }),
        }), h('span', t('keep_moving'), h('div.help', t('keep_moving_help')))),
        h('div.field', h('label', { for: 'ap-hud' }, t('hud_position')),
            h('select', { id: 'ap-hud', style: { maxWidth: '240px' }, onchange: (e) => change((d) => { d.hudPosition = e.target.value; }) },
                ['top-right', 'top-left'].map((p) => h('option', { value: p, selected: eff.hudPosition === p ? 'selected' : null }, t('hud_' + p.replace('-', '_')))))));
}

function keysOf() {
    const out = {};
    for (const a of KEY_ACTIONS) out[a] = S.draft.keys[a] !== undefined ? S.draft.keys[a] : (S.baseKeys[a] ?? false);
    if (!out.browser) out.browser = 'F7';
    return out;
}

function duplicateKeys(keys) {
    const seen = new Set(), dup = new Set();
    for (const k of Object.values(keys)) if (k) { if (seen.has(k)) dup.add(k); seen.add(k); }
    return dup;
}

function playerControls() {
    const keys = keysOf();
    const dup = duplicateKeys(keys);
    return h('div.col', { style: { gap: '10px' } },
        h('div.key-grid', KEY_ACTIONS.map((a) => {
            const id = `ap-key-${a}`;
            const own = S.draft.keys[a] !== undefined;
            return h(`div.key-row${keys[a] && dup.has(keys[a]) ? '.bad' : ''}`,
                h('label', { for: id }, h('b', t('key_' + a)), h('small', t('key_' + a + '_help'))),
                h('select', { id, onchange: (e) => change((d) => { d.keys[a] = e.target.value === 'off' ? false : e.target.value; }) },
                    a === 'browser' ? null : h('option', { value: 'off', selected: keys[a] ? null : 'selected' }, t('key_off')),
                    KEYS.map((k) => h('option', { value: k, selected: keys[a] === k ? 'selected' : null }, k))),
                h('span.faint', { style: { fontSize: '12px' } }, own ? t('key_config', S.baseKeys[a] || t('key_off')) : t('key_default')),
                own ? h('button.btn.sm.ghost', { onclick: () => change((d) => { delete d.keys[a]; }), 'aria-label': t('reset') }, ico('refresh', 14)) : h('span'));
        })),
        dup.size ? h('div.chip.cancelled', t('err_duplicate_key')) : null,
        h('div.help', t('keys_help')));
}

function colorRow(key, eff) {
    const own = S.draft.colors[key];
    const shown = own || (S.base.colors || {})[key] || '';
    const id = `ap-color-${key}`;
    return h('div.color-row',
        h('label', { for: id }, t('color_' + key)),
        h('input', { type: 'color', id, value: /^#[0-9a-f]{6}$/i.test(shown) ? shown : '#888888',
            oninput: (e) => change((d) => { d.colors[key] = e.target.value; }) }),
        own ? h('span.mono.faint', own) : h('span.faint', { style: { fontSize: '12px' } }, t('theme_default')),
        own ? h('button.btn.sm.ghost', { onclick: () => change((d) => { delete d.colors[key]; }), 'aria-label': t('reset') }, ico('refresh', 14)) : h('span'));
}

function imageField(label, id, value, onPick) {
    const mode = value === false ? 'none' : (value === 'auto' || value === undefined ? 'auto' : 'custom');
    return h('div.field',
        h('label', { for: id }, label),
        h('div.row',
            h('select', { id, style: { maxWidth: '200px' }, onchange: (e) => onPick(e.target.value === 'auto' ? 'auto' : e.target.value === 'none' ? false : 'img/') },
                h('option', { value: 'auto', selected: mode === 'auto' ? 'selected' : null }, t('theme_default')),
                h('option', { value: 'none', selected: mode === 'none' ? 'selected' : null }, t('none')),
                h('option', { value: 'custom', selected: mode === 'custom' ? 'selected' : null }, t('custom'))),
            mode === 'custom' ? h('input', { id: id + '-src', value, placeholder: 'img/logo.png or https://…', onchange: (e) => onPick(e.target.value.trim()) }) : null),
        h('div.help', t('image_help')));
}

function branding(eff) {
    return h('div.form',
        h('div.field', h('label', { for: 'ap-title' }, t('brand_title')),
            h('input', { id: 'ap-title', value: eff.brand.title || '', maxlength: '48', onchange: (e) => change((d) => { d.brand.title = e.target.value; }) })),
        h('div.field', h('label', { for: 'ap-sub' }, t('brand_subtitle')),
            h('input', { id: 'ap-sub', value: eff.brand.subtitle || '', maxlength: '64', onchange: (e) => change((d) => { d.brand.subtitle = e.target.value; }) })),
        imageField(t('logo'), 'ap-logo', S.draft.brand.logo !== undefined ? S.draft.brand.logo : (S.base.brand || {}).logo, (v) => change((d) => { d.brand.logo = v; })),
        imageField(t('artwork'), 'ap-art', S.draft.artwork !== undefined ? S.draft.artwork : S.base.artwork, (v) => change((d) => { d.artwork = v; })));
}

function categories(eff) {
    return h('table.tbl',
        h('tr', h('th', t('category')), h('th', t('icon')), h('th', t('color'))),
        Object.keys(eff.categories || {}).map((cat) => {
            const c = eff.categories[cat];
            return h('tr',
                h('td', h('span.row', badge(cat, null, 'badge-sm'), cat)),
                h('td', h('select', { 'aria-label': `${cat} ${t('icon')}`, style: { maxWidth: '170px' },
                    onchange: (e) => change((d) => { d.categories[cat] = { ...(d.categories[cat] || {}), icon: e.target.value }; }) },
                    ICON_NAMES.map((n) => h('option', { value: n, selected: c.icon === n ? 'selected' : null }, n)))),
                h('td', h('input', { type: 'color', 'aria-label': `${cat} ${t('color')}`, value: /^#[0-9a-f]{6}$/i.test(c.color) ? c.color : '#888888',
                    oninput: (e) => change((d) => { d.categories[cat] = { ...(d.categories[cat] || {}), color: e.target.value }; }) })));
        }));
}

async function save() {
    if (duplicateKeys(keysOf()).size) return;
    const res = await call('admin:ui:save', { settings: S.draft }, t('saved'));
    if (res) { S.dirty = false; S.loaded = false; }
}

function discard() {
    S.loaded = false;
    S.dirty = false;
    applyBranding(store.ui);
    render();
}

export function appearanceView() {
    if (!S.loaded) { load(); return h('div.empty', '…'); }
    const eff = effective();
    const editable = can('ui.edit');
    return h('div.col.grow', { style: { minHeight: 0 } },
        h('div.scroll.pad.grow.col', { style: { gap: '16px' } },
            editable ? null : h('div.chip.starting', t('read_only')),
            section(t('theme'), themeGallery(eff)),
            section(t('player_window'), layoutPicker(eff)),
            section(t('player_controls'), playerControls()),
            section(t('colors'), h('div.color-grid', COLOR_KEYS.map((k) => colorRow(k, eff))), h('div.help', t('colors_help'))),
            section(t('branding'), branding(eff)),
            section(t('categories'), categories(eff))),
        editable ? h('div.pad.row', { style: { borderTop: '1px solid var(--line)' } },
            S.dirty ? h('span.chip.starting', t('unsaved')) : null,
            h('div.spacer'),
            h('button.btn.danger', { onclick: () => danger('admin:ui:reset', {}, t('reset_config'), () => { S.loaded = false; }) }, t('reset_config')),
            h('button.btn', { onclick: discard, disabled: S.dirty ? null : true }, t('discard')),
            h('button.btn.primary', { onclick: save, disabled: S.dirty ? null : true }, t('save'))) : null);
}

// leaving the Admin Center with unsaved changes restores the live look
export function discardPreview() { if (S.dirty) discard(); }
export { S as appearanceState };
