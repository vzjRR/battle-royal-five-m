// EVENT STUDIO — applies the appearance settings: theme file, shape, artwork, logo and color overrides.
// Settings come from the server (Config.UI merged with what staff saved in Admin Center → Settings).

const root = document.documentElement;
const OVERRIDDEN = new Set();

function hexToRgb(hex) {
    let h = String(hex || '').trim().replace('#', '');
    if (h.length === 3) h = h.split('').map((c) => c + c).join('');
    if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(h)) return null;
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}

const rgba = (c, a) => `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${a})`;
const mix = (c, target, t) => c.map((v, i) => Math.round(v + (target[i] - v) * t));
const luminance = (c) => (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]) / 255;
const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');

function setVar(name, value) {
    root.style.setProperty(name, value);
    OVERRIDDEN.add(name);
}

/** Every color override plus the shades derived from it. */
export function colorVars(colors = {}) {
    const out = {};
    const W = [255, 255, 255], K = [0, 0, 0];
    const acc = hexToRgb(colors.accent);
    if (acc) {
        out['--accent'] = hex(acc);
        out['--accent-soft'] = rgba(acc, 0.13);
        out['--accent-line'] = rgba(acc, 0.5);
        out['--grad-accent'] = `linear-gradient(180deg, ${hex(mix(acc, W, 0.35))} 0%, ${hex(acc)} 55%, ${hex(mix(acc, K, 0.22))} 100%)`;
        out['--title-grad'] = `linear-gradient(180deg, ${hex(mix(acc, W, 0.45))} 0%, ${hex(acc)} 50%, ${hex(mix(acc, K, 0.3))} 100%)`;
        out['--accent-text'] = luminance(acc) > 0.55 ? '#0b0f16' : '#ffffff';
        out['--edge'] = rgba(acc, 0.42);
        out['--icon-edge'] = hex(acc);
        out['--glow'] = `0 0 0 3px ${rgba(acc, 0.16)}`;
    }
    const acc2 = hexToRgb(colors.accent2);
    if (acc2) { out['--accent-2'] = hex(acc2); out['--icon-ink'] = hex(acc2); }
    const bg = hexToRgb(colors.background);
    if (bg) {
        out['--bg'] = rgba(bg, 0.93);
        out['--bg-solid'] = hex(bg);
        out['--shell-bg'] = rgba(bg, 0.95);
        out['--hud-bg'] = rgba(bg, 0.88);
        out['--icon-bg'] = hex(bg);
    }
    const panel = hexToRgb(colors.panel);
    if (panel) {
        const light = luminance(panel) > 0.5;
        out['--panel'] = rgba(panel, 0.94);
        out['--panel-2'] = rgba(mix(panel, light ? K : W, 0.05), 0.94);
        out['--panel-3'] = rgba(mix(panel, light ? K : W, 0.1), 0.94);
    }
    const text = hexToRgb(colors.text);
    if (text) {
        const base = bg || hexToRgb(getComputedStyle(root).getPropertyValue('--bg-solid')) || [12, 14, 20];
        out['--text'] = hex(text);
        out['--text-dim'] = hex(mix(text, base, 0.28));
        out['--text-faint'] = hex(mix(text, base, 0.48));
    }
    for (const k of ['good', 'warn', 'bad']) {
        const c = hexToRgb(colors[k]);
        if (c) { out[`--${k}`] = hex(c); out[`--${k}-soft`] = rgba(c, 0.12); out[`--${k}-line`] = rgba(c, 0.5); }
    }
    return out;
}

/** Only local web/ paths and https URLs are used as images. */
function safeImage(src) {
    if (typeof src !== 'string') return null;
    if (/^img\/[\w\-/]+\.(png|svg|webp|jpe?g)$/i.test(src) && !src.includes('..')) return src;
    if (/^https:\/\/[\w\-.~:/%?#@!$&*+,;=]+$/i.test(src)) return src;
    return null;
}

export function themeOf(ui) {
    const list = ui.themes || [];
    return list.find((t) => t.id === ui.theme) || list.find((t) => t.id === 'krovix-gilded') || { id: 'classic', file: 'classic', shape: 'round', title: 'plain' };
}

export function logoOf(ui) {
    const brand = ui.brand || {};
    if (brand.logo === false || brand.logo === null || brand.logo === undefined) return null;
    if (brand.logo === 'auto') return safeImage(themeOf(ui).logo || null);
    return safeImage(brand.logo);
}

export function applyUI(ui) {
    const theme = themeOf(ui);
    const link = document.getElementById('theme');
    const href = `themes/${theme.file}.css`;
    if (link && link.getAttribute('href') !== href) link.setAttribute('href', href);
    root.dataset.shape = theme.shape === 'cut' ? 'cut' : 'round';
    root.dataset.title = theme.title === 'metal' ? 'metal' : 'plain';
    root.dataset.theme = theme.id;

    for (const name of OVERRIDDEN) root.style.removeProperty(name);
    OVERRIDDEN.clear();

    const art = ui.artwork === 'auto' || ui.artwork === undefined ? theme.art : ui.artwork;
    const artSrc = safeImage(art);
    // resolve against the page, not the stylesheet that uses the variable (web/css/)
    setVar('--art', artSrc ? `url("${encodeURI(new URL(artSrc, document.baseURI).href)}")` : 'none');

    for (const [k, v] of Object.entries(colorVars(ui.colors || {}))) setVar(k, v);

    const browser = document.getElementById('browser');
    if (browser) {
        browser.classList.remove('layout-compact', 'layout-docked', 'layout-full');
        browser.classList.add(`layout-${['compact', 'docked', 'full'].includes(ui.browserLayout) ? ui.browserLayout : 'compact'}`);
    }
}
