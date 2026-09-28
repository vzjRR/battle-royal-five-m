// EVENT STUDIO — built-in line icons (24×24, stroke = currentColor). Built with createElementNS from static
// path data only, so no markup is ever parsed. Config.UI.categories[*].icon and definition icons use these names;
// anything that is not a known name (an emoji, a letter) is shown as text.

const P = {
    flag: ['M5 21V4', 'M5 4h11l-2 4 2 4H5'],
    car: ['M5 17h14', 'M3 17v-4l2-5h14l2 5v4', 'M7 17v2M17 17v2', 'M7 13h.01M17 13h.01'],
    crosshair: ['c12,12,7', 'c12,12,2', 'M12 2v4M12 18v4M2 12h4M18 12h4'],
    target: ['c12,12,9', 'c12,12,5', 'c12,12,1'],
    shield: ['M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6z'],
    compass: ['c12,12,9', 'M15.5 8.5l-2 5-5 2 2-5z'],
    mountain: ['M3 20l6-11 4 7 2-3 6 7z'],
    dice: ['M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z', 'M8.5 8.5h.01M15.5 15.5h.01M12 12h.01M15.5 8.5h.01M8.5 15.5h.01'],
    trophy: ['M8 4h8v5a4 4 0 0 1-8 0z', 'M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4', 'M12 13v4M8 20h8'],
    anchor: ['c12,5,2', 'M12 7v14', 'M5 13a7 7 0 0 0 14 0', 'M8 10h8'],
    bolt: ['M13 2L4 14h7l-1 8 9-12h-7z'],
    star: ['M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z'],
    question: ['c12,12,9', 'M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.5V14', 'M12 17h.01'],
    users: ['c9,8,3', 'M3 20a6 6 0 0 1 12 0', 'M16 5a3 3 0 0 1 0 6', 'M21 20a6 6 0 0 0-4-5.6'],
    clock: ['c12,12,9', 'M12 7v5l3 2'],
    calendar: ['M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z', 'M8 3v4M16 3v4M3 10h18'],
    chart: ['M6 20V10M12 20V4M18 20v-7'],
    list: ['M8 6h13M8 12h13M8 18h13', 'M3 6h.01M3 12h.01M3 18h.01'],
    grid: ['M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z'],
    pencil: ['M4 20h4L19 9l-4-4L4 16z', 'M13.5 6.5l4 4'],
    pin: ['M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z', 'c12,9,2.5'],
    timer: ['c12,13,8', 'M12 9v4l2 2', 'M9 2h6'],
    live: ['c12,12,3', 'M6.3 6.3a8 8 0 0 0 0 11.4M17.7 6.3a8 8 0 0 1 0 11.4'],
    logs: ['M6 3h9l4 4v14H6z', 'M15 3v4h4', 'M9 12h7M9 16h7'],
    settings: ['c12,12,3', 'M12 2v3M12 19v3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M2 12h3M19 12h3M4.9 19.1L7 17M17 7l2.1-2.1'],
    palette: ['M12 3a9 9 0 1 0 0 18c1.1 0 1.5-.8 1.5-1.5 0-1.3-1-1.6-1-2.8 0-1 .8-1.7 1.8-1.7H17a4 4 0 0 0 4-4c0-4.4-4-8-9-8z', 'M7.5 11h.01M10 7.5h.01M14.5 7.5h.01'],
    close: ['M6 6l12 12M18 6L6 18'],
    check: ['M5 12l5 5L20 7'],
    play: ['M7 4l13 8-13 8z'],
    pause: ['M8 5v14M16 5v14'],
    stop: ['M6 6h12v12H6z'],
    refresh: ['M20 11a8 8 0 1 0-2.3 5.7', 'M20 4v7h-7'],
    eye: ['M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z', 'c12,12,3'],
    arrow: ['M5 12h14', 'M13 6l6 6-6 6'],
    home: ['M3 11l9-8 9 8', 'M5 10v10h14V10'],
    gauge: ['M4 16a8 8 0 1 1 16 0', 'M12 16l4-5'],
    medal: ['c12,15,5', 'M8.5 3L12 10l3.5-7'],
    signin: ['M12 3v12', 'M7 10l5 5 5-5', 'M5 21h14'],
    plus: ['M12 5v14', 'M5 12h14'],
    info: ['c12,12,9', 'M12 11v6', 'M12 7.5h.01'],
};

const NS = 'http://www.w3.org/2000/svg';

export function hasIcon(name) { return typeof name === 'string' && Object.prototype.hasOwnProperty.call(P, name); }

/** icon('flag', 18) → <svg>; unknown names return null. */
export function icon(name, size = 18) {
    if (!hasIcon(name)) return null;
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', size);
    svg.setAttribute('height', size);
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '1.8');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    svg.classList.add('ico');
    for (const d of P[name]) {
        let el;
        if (d[0] === 'c') {
            const [cx, cy, r] = d.slice(1).split(',');
            el = document.createElementNS(NS, 'circle');
            el.setAttribute('cx', cx); el.setAttribute('cy', cy); el.setAttribute('r', r);
        } else {
            el = document.createElementNS(NS, 'path');
            el.setAttribute('d', d);
        }
        svg.appendChild(el);
    }
    return svg;
}

/** Icon if the name is known, otherwise the text itself (emoji / letters). */
export function glyph(name, size) {
    return icon(name, size) || document.createTextNode(String(name ?? '★'));
}

export const ICON_NAMES = Object.keys(P);

/** Flag of the United Kingdom (Union Jack), for the English side of the language switch. */
export function flagUK(height = 14) {
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 60 30');
    svg.setAttribute('height', height);
    svg.setAttribute('width', height * 2);
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'United Kingdom');
    svg.classList.add('flag');
    const add = (tag, attrs) => { const el = document.createElementNS(NS, tag); for (const k in attrs) el.setAttribute(k, attrs[k]); svg.appendChild(el); };
    add('rect', { width: 60, height: 30, fill: '#012169' });
    add('path', { d: 'M0 0L60 30M60 0L0 30', stroke: '#ffffff', 'stroke-width': 6 });
    add('path', { d: 'M0 0L60 30M60 0L0 30', stroke: '#C8102E', 'stroke-width': 2 });
    add('path', { d: 'M30 0V30M0 15H60', stroke: '#ffffff', 'stroke-width': 10 });
    add('path', { d: 'M30 0V30M0 15H60', stroke: '#C8102E', 'stroke-width': 6 });
    return svg;
}

/** Flag of Oman (emoji flags do not render in FiveM's browser on Windows). */
export function flagOman(height = 14) {
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 12');
    svg.setAttribute('height', height);
    svg.setAttribute('width', height * 2);
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'Oman');
    svg.classList.add('flag');
    for (const [x, y, w, hh, fill] of [[0, 0, 24, 4, '#ffffff'], [0, 4, 24, 4, '#db161b'], [0, 8, 24, 4, '#008000'], [0, 0, 7, 12, '#db161b']]) {
        const r = document.createElementNS(NS, 'rect');
        r.setAttribute('x', x); r.setAttribute('y', y); r.setAttribute('width', w); r.setAttribute('height', hh); r.setAttribute('fill', fill);
        svg.appendChild(r);
    }
    return svg;
}
