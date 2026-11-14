// Site theme: the shell's own palettes (themes.js, generated from theme.conf)
// as CSS variables. Loaded synchronously in <head>, so the page is painted in
// the remembered theme from the first frame.
//
// Like the Appearance Studio, there are two states: the applied palette (what
// the page shows right now, e.g. while browsing the carousel) and the committed
// one (what is remembered and restored on every page).
(function () {
    'use strict';

    var KEY = 'vellum-site-theme';
    var data = window.VELLUM_THEMES || { defaultTheme: '', themes: [] };
    var themes = data.themes;
    var root = document.documentElement;
    // Scroll reveals hide content only when the script that shows it again runs.
    root.classList.add('js');

    // The loader (splash.js): once per browser session, never with reduced
    // motion. ?splash forces it, for showing it off.
    (function () {
        var forced = /[?&]splash\b/.test(window.location.search);
        var calm = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        var seen = false;
        try { seen = sessionStorage.getItem('vellum-splash') === '1'; sessionStorage.setItem('vellum-splash', '1'); } catch (e) { seen = true; }
        if (forced || (!seen && !calm)) root.classList.add('splash-on');
    })();
    var applied = null;
    var committed = null;

    function rgb(hex) {
        var h = hex.replace('#', '');
        return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
    }
    function toHex(c) {
        return '#' + c.map(function (v) {
            return Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0');
        }).join('');
    }
    function luminance(c) {
        var a = c.map(function (v) {
            v /= 255;
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        });
        return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
    }
    function contrast(a, b) {
        var x = luminance(a), y = luminance(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }
    function mix(a, b, t) {
        return a.map(function (v, i) { return v + (b[i] - v) * t; });
    }
    // The palettes are made for a desktop, where MUTED may be a decoration
    // colour. Text on the site must stay readable, so text variants are pulled
    // towards the foreground until they reach the target contrast.
    function readable(color, bg, toward, target) {
        var c = rgb(color), g = rgb(bg), f = rgb(toward);
        for (var t = 0; t <= 1.0001; t += 0.05) {
            var m = mix(c, f, t);
            if (contrast(m, g) >= target) return toHex(m);
        }
        return toward;
    }

    function byId(id) {
        for (var i = 0; i < themes.length; i++) if (themes[i].id === id) return themes[i];
        return null;
    }

    function read() {
        try { return localStorage.getItem(KEY); } catch (e) { return null; }
    }
    function write(id) {
        try { localStorage.setItem(KEY, id); } catch (e) { /* private mode: keep it for this page */ }
    }

    function kebab(name) {
        return name.replace(/[A-Z]/g, function (m) { return '-' + m.toLowerCase(); });
    }

    function apply(id) {
        var theme = byId(id) || byId(data.defaultTheme) || themes[0];
        if (!theme) return null;
        var c = theme.colors;
        var style = root.style;
        Object.keys(c).forEach(function (name) { style.setProperty('--' + kebab(name), c[name]); });

        var onAccent = contrast(rgb(c.fgBright), rgb(c.accent)) >= contrast(rgb(c.bgDarker), rgb(c.accent))
            ? c.fgBright : c.bgDarker;
        style.setProperty('--on-accent', onAccent);
        style.setProperty('--accent-text', readable(c.accent, c.bg, c.fgBright, 4.5));
        style.setProperty('--muted-text', readable(c.muted, c.bg, c.fg, 4.6));
        style.setProperty('--muted-text-surface', readable(c.muted, c.surface, c.fg, 4.5));

        if (applied && applied.id !== theme.id) {
            root.classList.add('theme-fade');
            clearTimeout(apply.timer);
            apply.timer = setTimeout(function () { root.classList.remove('theme-fade'); }, 420);
        }
        applied = theme;
        root.dataset.theme = theme.id;
        var meta = document.querySelector('meta[name="theme-color"]');
        if (meta) meta.setAttribute('content', c.bgDark);
        document.dispatchEvent(new CustomEvent('vellum:theme', {
            detail: { id: theme.id, committed: committed && committed.id }
        }));
        return theme;
    }

    function commit(id) {
        var theme = apply(id);
        if (!theme) return null;
        committed = theme;
        write(theme.id);
        document.dispatchEvent(new CustomEvent('vellum:theme', {
            detail: { id: theme.id, committed: theme.id }
        }));
        return theme;
    }

    function restore() {
        return committed ? apply(committed.id) : null;
    }

    committed = apply(read());

    // ?theme=<slug> shows a theme without remembering it, for sharing a preview.
    var requested = null;
    try { requested = new URLSearchParams(window.location.search).get('theme'); } catch (e) { /* old browser */ }
    if (requested && byId(requested) && requested !== committed.id) apply(requested);

    // Another tab changed the theme: follow it.
    window.addEventListener('storage', function (event) {
        if (event.key === KEY && event.newValue && byId(event.newValue)) commit(event.newValue);
    });

    window.Vellum = {
        themes: themes,
        byId: byId,
        apply: apply,
        commit: commit,
        restore: restore,
        get applied() { return applied; },
        get committed() { return committed; }
    };
})();
