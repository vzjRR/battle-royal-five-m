// EVENT STUDIO — NPWD 4 app. NPWD loads this file after server/core/phone.lua registers the app
// (RegisterExternalApp). It only shows web/phone.html, the same page the other phones use.
// Plain JavaScript on purpose: NPWD provides React as window.__npwd_React, so nothing needs building.
var __npwd_ext_eventstudio = (function () {
    var React = window.__npwd_React;
    var host = (document.currentScript && document.currentScript.src.match(/^https:\/\/cfx-nui-([^/]+)\//)) || [];
    var base = 'https://cfx-nui-' + (host[1] || 'event_studio') + '/';

    function EventsApp() {
        return React.createElement('iframe', {
            src: base + 'web/phone.html?device=npwd',
            title: 'Events',
            style: { border: 0, width: '100%', height: '100%', display: 'block', background: 'transparent' },
        });
    }

    function EventsIcon(props) {
        var size = (props && (props.size || props.width)) || 24;
        return React.createElement('img', {
            src: base + 'web/img/app-icon.png', alt: '', width: size, height: size,
            style: { borderRadius: '22%', objectFit: 'cover' },
        });
    }

    return { default: EventsApp, icon: EventsIcon };
})();
