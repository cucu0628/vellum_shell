(function () {
    'use strict';

    var V = window.Vellum;
    if (!V) return;

    var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function $(selector, scope) { return (scope || document).querySelector(selector); }
    function $$(selector, scope) { return Array.prototype.slice.call((scope || document).querySelectorAll(selector)); }
    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }
    // Media URLs carry a content hash (themes.js), so a re-recorded file is never
    // served from a stale browser cache.
    function media(url) {
        var versions = window.VELLUM_MEDIA || {};
        return versions[url] ? url + '?v=' + versions[url] : url;
    }
    function onTheme(handler) {
        document.addEventListener('vellum:theme', function (event) { handler(event.detail); });
    }

    // The wallpaper each theme was recorded with (all public-domain paintings).
    var PAINTINGS = {
        'japanese-ink': 'Frederic Edwin Church, Twilight in the Wilderness (1860)',
        'tokyo-night': 'Johan Christian Dahl, View of Dresden by Moonlight (1839)',
        'kanagawa-wave': 'Ivan Aivazovsky, Sunset at Sea',
        'rose-pine': 'Frederic Edwin Church, Aurora Borealis (1865)',
        'catppuccin-mocha': 'Arnold Böcklin, Isle of the Dead',
        'gruvbox-material': 'Thomas Cole, The Course of Empire: Desolation (1836)',
        'monochrome': 'Caspar David Friedrich, The Abbey in the Oakwood (1810)',
        'sakura-blossom': 'Albert Bierstadt, Among the Sierra Nevada, California (1868)',
        'varnished-horizon': 'Thomas Cole, The Course of Empire: The Savage State (1834)',
        'dynamic-matugen': 'John Atkinson Grimshaw, Shipping on the Clyde'
    };

    // -- Theme menu in the top bar -------------------------------------------

    function initThemeMenu() {
        var button = $('.theme-button');
        var popover = $('.theme-popover');
        if (!button || !popover) return;

        V.themes.forEach(function (theme) {
            var item = el('button', 'theme-option');
            item.type = 'button';
            item.setAttribute('role', 'option');
            item.dataset.id = theme.id;
            var strip = el('span', 'theme-strip');
            strip.setAttribute('aria-hidden', 'true');
            ['bg', 'surface', 'accent', 'fg'].forEach(function (key) {
                var swatch = el('i');
                swatch.style.background = theme.colors[key];
                strip.appendChild(swatch);
            });
            item.appendChild(strip);
            item.appendChild(el('span', 'theme-option-name', theme.name));
            item.addEventListener('click', function () {
                V.commit(theme.id);
                close(true);
            });
            popover.appendChild(item);
        });

        function options() { return $$('.theme-option', popover); }
        function open() {
            popover.hidden = false;
            button.setAttribute('aria-expanded', 'true');
            var current = popover.querySelector('[aria-selected="true"]') || options()[0];
            if (current) current.focus();
        }
        function close(refocus) {
            if (popover.hidden) return;
            popover.hidden = true;
            button.setAttribute('aria-expanded', 'false');
            if (refocus) button.focus();
        }

        button.addEventListener('click', function () { if (popover.hidden) open(); else close(false); });
        document.addEventListener('click', function (event) { if (!event.target.closest('.theme-menu')) close(false); });
        popover.addEventListener('keydown', function (event) {
            var list = options();
            var index = list.indexOf(document.activeElement);
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                event.preventDefault();
                list[(index + (event.key === 'ArrowDown' ? 1 : -1) + list.length) % list.length].focus();
            } else if (event.key === 'Home' || event.key === 'End') {
                event.preventDefault();
                list[event.key === 'Home' ? 0 : list.length - 1].focus();
            } else if (event.key === 'Escape') {
                close(true);
            } else if (event.key === 'Tab') {
                close(false);
            }
        });

        function sync() {
            var committed = V.committed;
            var applied = V.applied;
            $('.theme-button-name', button).textContent = committed ? committed.name : 'Theme';
            var dots = $$('.theme-dots i', button);
            if (applied) {
                dots[0].style.background = applied.colors.accent;
                dots[1].style.background = applied.colors.fg;
                dots[2].style.background = applied.colors.muted;
            }
            options().forEach(function (item) {
                item.setAttribute('aria-selected', committed && item.dataset.id === committed.id ? 'true' : 'false');
            });
        }
        onTheme(sync);
        sync();
    }

    // -- Hero: the caption follows the theme in the recording ------------------

    function initHero() {
        var video = $('.stage-video');
        if (!video) return;

        // The recording switched theme every 2.2 seconds, starting at 1.5 s.
        var timeline = [
            [0, 'japanese-ink'], [1.5, 'tokyo-night'], [3.7, 'rose-pine'], [5.9, 'kanagawa-wave'],
            [8.1, 'catppuccin-mocha'], [10.3, 'gruvbox-material'], [12.5, 'sakura-blossom'],
            [14.7, 'monochrome'], [16.9, 'varnished-horizon'], [19.1, 'japanese-ink']
        ];
        var nameNode = $('.stage-theme');
        var paintingNode = $('.stage-painting');
        var caption = $('.stage-caption');
        var shown = null;
        function sync() {
            var time = video.currentTime;
            var id = timeline[0][1];
            for (var i = 0; i < timeline.length; i++) if (time >= timeline[i][0]) id = timeline[i][1];
            if (id !== shown) {
                shown = id;
                var theme = V.byId(id);
                nameNode.textContent = theme ? theme.name : id;
                paintingNode.textContent = PAINTINGS[id] || '';
                if (theme) caption.style.setProperty('--stage-accent', theme.colors.accent);
            }
            if (video.requestVideoFrameCallback) video.requestVideoFrameCallback(sync);
        }
        if (video.requestVideoFrameCallback) video.requestVideoFrameCallback(sync);
        else video.addEventListener('timeupdate', sync);
        sync();
        if (reduceMotion) video.pause();
    }

    // -- Videos below the fold load and play only while visible ---------------

    function initLazyVideos() {
        var videos = $$('video[data-lazy-video]');
        if (!videos.length) return;
        function load(video) {
            if (video.dataset.loaded) return;
            video.dataset.loaded = '1';
            $$('source', video).forEach(function (source) { source.src = source.dataset.src; });
            video.load();
        }
        if (!window.IntersectionObserver) {
            videos.forEach(function (video) { load(video); if (!reduceMotion) video.play(); });
            return;
        }
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                var video = entry.target;
                if (entry.isIntersecting) {
                    load(video);
                    if (!reduceMotion) {
                        var playing = video.play();
                        if (playing && playing.catch) playing.catch(function () {});
                    }
                } else if (!video.paused) {
                    video.pause();
                }
            });
        }, { rootMargin: '200px 0px', threshold: 0.25 });
        videos.forEach(function (video) { observer.observe(video); });
    }

    // -- Before/after slider ---------------------------------------------------

    function initCompare() {
        $$('.compare').forEach(function (compare) {
            var range = $('.compare-range', compare);
            var set = function () { compare.style.setProperty('--split', range.value + '%'); };
            range.addEventListener('input', set);
            set();
        });
    }

    // -- Settings tabs ---------------------------------------------------------

    function initTabs() {
        var tabs = $$('.tabs [role="tab"]');
        var img = $('.tab-stage img');
        if (!tabs.length || !img) return;
        tabs.forEach(function (tab, index) {
            tab.addEventListener('click', function () { select(index); });
            tab.addEventListener('keydown', function (event) {
                // A sidebar on wide screens, a row on narrow ones: both arrow pairs work.
                var step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
                if (!step) return;
                event.preventDefault();
                var next = (index + step + tabs.length) % tabs.length;
                select(next);
                tabs[next].focus();
            });
            tab.tabIndex = index === 0 ? 0 : -1;
            // Warm the cache so switching is instant.
            var preload = new Image();
            preload.src = media('/media/shots/settings-' + tab.dataset.shot + '.jpg');
        });
        function select(index) {
            tabs.forEach(function (tab, i) {
                tab.setAttribute('aria-selected', i === index ? 'true' : 'false');
                tab.tabIndex = i === index ? 0 : -1;
            });
            img.classList.add('swap');
            setTimeout(function () {
                img.src = media('/media/shots/settings-' + tabs[index].dataset.shot + '.jpg');
                img.alt = 'Vellum Settings: ' + tabs[index].textContent + ' page';
                img.classList.remove('swap');
            }, 180);
        }
    }

    // -- Theme gallery: real screenshots, and the site follows ---------------

    function initGallery() {
        var list = $('.gallery-list');
        if (!list) return;
        var image = $('.gallery-image');
        var name = $('.gallery-name');
        var painting = $('.gallery-painting');

        // The Appearance Studio's cards: each one drawn in its own palette.
        V.themes.forEach(function (theme) {
            var c = theme.colors;
            var item = el('button', 'studio-card');
            item.type = 'button';
            item.setAttribute('role', 'option');
            item.setAttribute('aria-label', theme.name);
            item.dataset.id = theme.id;
            item.style.setProperty('--card-bg', c.bg);
            item.style.setProperty('--card-fg', c.fg);
            item.style.setProperty('--card-line', c.surface);
            item.style.setProperty('--card-accent', c.accent);
            var inner = el('span', 'studio-card-inner');
            inner.setAttribute('aria-hidden', 'true');
            inner.appendChild(el('span', 'aa', 'Aa'));
            var swatches = el('span', 'swatches');
            ['accent', 'fg', 'muted', 'surface'].forEach(function (key) {
                var swatch = el('i');
                swatch.style.background = c[key];
                swatches.appendChild(swatch);
            });
            inner.appendChild(swatches);
            inner.appendChild(el('span', 'name', theme.name));
            item.appendChild(inner);
            item.addEventListener('click', function () { V.commit(theme.id); });
            list.appendChild(item);
        });

        var shown = null;
        function show(id) {
            if (id === shown) return;
            shown = id;
            var theme = V.byId(id);
            if (!theme) return;
            image.classList.add('swap');
            var next = new Image();
            next.onload = function () {
                image.src = next.src;
                image.alt = 'Vellum in ' + theme.name + ', over ' + (PAINTINGS[id] || 'a painting');
                image.classList.remove('swap');
            };
            next.src = media('/media/themes/' + id + '.jpg');
            name.textContent = theme.name;
            painting.textContent = theme.dynamic
                ? 'Palette derived from ' + (PAINTINGS[id] || 'the wallpaper')
                : (PAINTINGS[id] || '');
            $$('.studio-card', list).forEach(function (item) {
                var on = item.dataset.id === id;
                item.setAttribute('aria-selected', on ? 'true' : 'false');
                if (on && list.scrollWidth > list.clientWidth) {
                    list.scrollTo({
                        left: item.offsetLeft - (list.clientWidth - item.offsetWidth) / 2,
                        behavior: reduceMotion ? 'auto' : 'smooth'
                    });
                }
            });
        }
        onTheme(function (detail) { show(detail.id); });
        show(V.applied ? V.applied.id : V.themes[0].id);
    }

    // -- The session around the page: wallpaper, bar clock, lock field -----------

    function initSession() {
        if (!document.body.classList.contains('page-home')) return;

        // The wallpaper is the painting of the theme on show, as on the desktop.
        var wallpaper = $('.wallpaper');
        if (wallpaper) {
            var paint = function (id) {
                wallpaper.style.backgroundImage = 'url("' + media('/media/themes/' + id + '.jpg') + '")';
            };
            onTheme(function (detail) { paint(detail.id); });
            if (V.applied) paint(V.applied.id);
        }

        // The bar's clock: weekday and time, in the visitor's own locale.
        var inner = $('.topbar-inner');
        if (inner) {
            var clock = el('span', 'bar-clock');
            clock.setAttribute('aria-hidden', 'true');
            clock.appendChild(el('i'));
            var time = el('span');
            clock.appendChild(time);
            inner.insertBefore(clock, $('.topbar-actions', inner));
            var tick = function () {
                var now = new Date();
                time.textContent = now.toLocaleDateString('en-GB', { weekday: 'long' }) + ' '
                    + now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
                setTimeout(tick, 60000 - (now.getSeconds() * 1000 + now.getMilliseconds()));
            };
            tick();
        }

        // The lock screen's field holds the clone command; the arrow copies it.
        var go = $('.lock-go');
        var command = $('.lock-command');
        var hint = $('.lock-hint-text');
        if (go && command && hint) {
            go.addEventListener('click', function () {
                if (!navigator.clipboard) return;
                navigator.clipboard.writeText(command.textContent).then(function () {
                    hint.textContent = 'Copied. Then run ./setup.sh';
                    setTimeout(function () { hint.textContent = '↵ copies'; }, 2400);
                }, function () {});
            });
        }
    }

    // -- The guide as a launcher: type to filter, arrows to pick, Enter to open --

    function initLauncher() {
        var input = $('.launcher-field input');
        var rows = $$('.launcher-results .row');
        var count = $('.launcher-count');
        if (!input || !rows.length) return;
        var list = rows[0].closest('ol');
        var empty = el('p', 'launcher-empty', 'No chapter matches. Esc clears the search.');
        empty.hidden = true;
        list.parentNode.appendChild(empty);
        var visible = rows.slice();
        var selected = -1;

        function select(index) {
            rows.forEach(function (row) { row.classList.remove('selected'); });
            selected = visible.length ? Math.max(0, Math.min(index, visible.length - 1)) : -1;
            if (selected >= 0) visible[selected].classList.add('selected');
        }
        function filter() {
            var words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
            visible = rows.filter(function (row) {
                var text = row.textContent.toLowerCase();
                var match = words.every(function (word) { return text.indexOf(word) >= 0; });
                row.parentNode.hidden = !match;
                return match;
            });
            empty.hidden = visible.length > 0;
            count.textContent = words.length ? 'Guide · ' + visible.length : 'Guide';
            select(words.length ? 0 : -1);
        }
        input.addEventListener('input', filter);
        input.addEventListener('keydown', function (event) {
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                event.preventDefault();
                select(selected + (event.key === 'ArrowDown' ? 1 : -1));
                if (selected >= 0) visible[selected].scrollIntoView({ block: 'nearest' });
            } else if (event.key === 'Enter') {
                var target = visible[selected >= 0 ? selected : 0];
                if (target) window.location.href = target.href;
            } else if (event.key === 'Escape') {
                input.value = '';
                filter();
            }
        });
        rows.forEach(function (row) {
            row.addEventListener('mouseenter', function () {
                var index = visible.indexOf(row);
                if (index >= 0) select(index);
            });
        });
    }

    // -- Navigation state ------------------------------------------------------

    function initNav() {
        var links = $$('.topnav a');
        function mark(section) {
            links.forEach(function (link) {
                var on = link.dataset.section === section;
                link.classList.toggle('on', on);
                if (on) link.setAttribute('aria-current', 'page'); else link.removeAttribute('aria-current');
            });
        }
        if (document.body.classList.contains('page-guide')) { mark('guide'); return; }
        var sections = ['tour', 'themes', 'install'].map(function (id) { return document.getElementById(id); }).filter(Boolean);
        if (!sections.length || !window.IntersectionObserver) return;
        var visible = {};
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) { visible[entry.target.id] = entry.isIntersecting; });
            var active = null;
            sections.some(function (section) {
                if (visible[section.id]) { active = section.id; return true; }
                return false;
            });
            mark(active);
        }, { rootMargin: '-45% 0px -50% 0px' });
        sections.forEach(function (section) { observer.observe(section); });
    }

    // -- Guide pages -----------------------------------------------------------

    function initGuide() {
        var nav = $('.guide-nav');
        var toggle = $('.guide-nav-toggle');
        if (toggle) {
            toggle.addEventListener('click', function () {
                var open = nav.classList.toggle('open');
                toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
            });
        }

        // The current chapter's sections sit under it in the contents; mark the
        // one being read: the last section heading above the reading line.
        var prose = $('.prose');
        var sections = $('.guide-sections');
        if (!prose || !sections) return;
        var linkFor = {};
        $$('a', sections).forEach(function (link) { linkFor[link.getAttribute('href').slice(1)] = link; });
        var headings = $$('h2[id]', prose).filter(function (heading) { return linkFor[heading.id]; });
        if (!headings.length) return;
        var active = null;
        var pending = false;
        function update() {
            pending = false;
            var current = null;
            headings.forEach(function (heading) {
                if (heading.getBoundingClientRect().top <= 140) current = heading;
            });
            // At the very end of the page the last section counts as reached.
            if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) {
                current = headings[headings.length - 1];
            }
            var link = current ? linkFor[current.id] : null;
            if (link === active) return;
            if (active) { active.classList.remove('active'); active.removeAttribute('aria-current'); }
            active = link;
            if (active) { active.classList.add('active'); active.setAttribute('aria-current', 'location'); }
        }
        window.addEventListener('scroll', function () {
            if (!pending) { pending = true; window.requestAnimationFrame(update); }
        }, { passive: true });
        update();
    }

    function initCopy() {
        $$('.prose pre, .terminal pre').forEach(function (pre) {
            var wrap = el('div', 'pre-wrap');
            pre.parentNode.insertBefore(wrap, pre);
            wrap.appendChild(pre);
            var button = el('button', 'copy', 'Copy');
            button.type = 'button';
            button.setAttribute('aria-label', 'Copy code to clipboard');
            button.addEventListener('click', function () {
                var text = pre.innerText.replace(/\n$/, '');
                if (pre.closest('.terminal')) {
                    // Only the commands: no prompts, no comments.
                    text = text.split('\n').map(function (line) {
                        return line.replace(/^\$ /, '').replace(/\s+#.*$/, '');
                    }).join('\n');
                }
                var done = function () {
                    button.textContent = 'Copied';
                    setTimeout(function () { button.textContent = 'Copy'; }, 1400);
                };
                if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () {});
            });
            wrap.appendChild(button);
        });
    }

    initThemeMenu();
    initHero();
    initLazyVideos();
    initCompare();
    initTabs();
    initGallery();
    initSession();
    initLauncher();
    initNav();
    initGuide();
    initCopy();
})();
