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

    // -- Reveal on scroll ------------------------------------------------------

    function initReveal() {
        var items = $$('.reveal');
        if (!items.length) return;
        if (reduceMotion || !window.IntersectionObserver) {
            items.forEach(function (item) { item.classList.add('in'); });
            return;
        }
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                var siblings = $$('.reveal', entry.target.parentNode);
                var delay = Math.max(0, siblings.indexOf(entry.target)) * 70;
                entry.target.style.transitionDelay = Math.min(delay, 350) + 'ms';
                entry.target.classList.add('in');
                observer.unobserve(entry.target);
            });
        }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
        items.forEach(function (item) { observer.observe(item); });
    }

    // -- Hero: tilt that flattens on scroll, caption that follows the video ----

    function initHero() {
        var frame = $('.stage-frame');
        if (!frame) return;

        if (!reduceMotion) {
            var ticking = false;
            var update = function () {
                ticking = false;
                var rect = frame.getBoundingClientRect();
                var progress = Math.min(1, Math.max(0, 1 - (rect.top - window.innerHeight * 0.18) / (window.innerHeight * 0.7)));
                frame.style.setProperty('--tilt', (16 * (1 - progress)).toFixed(2) + 'deg');
                frame.style.setProperty('--zoom', (0.94 + 0.06 * progress).toFixed(3));
            };
            window.addEventListener('scroll', function () {
                if (!ticking) { ticking = true; requestAnimationFrame(update); }
            }, { passive: true });
            window.addEventListener('resize', update);
            update();
        }

        // The recording switched theme every 2.2 seconds, starting at 1.5 s.
        var timeline = [
            [0, 'japanese-ink'], [1.5, 'tokyo-night'], [3.7, 'rose-pine'], [5.9, 'kanagawa-wave'],
            [8.1, 'catppuccin-mocha'], [10.3, 'gruvbox-material'], [12.5, 'sakura-blossom'],
            [14.7, 'monochrome'], [16.9, 'varnished-horizon'], [19.1, 'japanese-ink']
        ];
        var video = $('.stage-video');
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

    // -- Marquee of real screenshots ------------------------------------------

    function initMarquee() {
        var track = $('[data-marquee]');
        if (!track) return;
        var list = V.themes.slice();
        // Twice the same row, so the loop is seamless at -50%.
        list.concat(list).forEach(function (theme, index) {
            var figure = el('figure');
            if (index >= list.length) figure.setAttribute('aria-hidden', 'true');
            var img = el('img');
            img.src = '/media/themes/' + theme.id + '-sm.jpg';
            img.width = 720;
            img.height = 405;
            img.loading = 'lazy';
            img.decoding = 'async';
            img.alt = index < list.length ? 'Vellum in ' + theme.name : '';
            figure.appendChild(img);
            figure.appendChild(el('figcaption', '', theme.name));
            track.appendChild(figure);
        });
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

    // -- Stats count up --------------------------------------------------------

    function initStats() {
        var values = $$('[data-count]');
        if (!values.length || reduceMotion || !window.IntersectionObserver) return;
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                observer.unobserve(entry.target);
                var node = entry.target;
                var target = parseInt(node.dataset.count, 10);
                if (!target) return;
                var start = performance.now();
                var step = function (now) {
                    var t = Math.min(1, (now - start) / 1200);
                    node.textContent = String(Math.round(target * (1 - Math.pow(1 - t, 3))));
                    if (t < 1) requestAnimationFrame(step);
                };
                node.textContent = '0';
                requestAnimationFrame(step);
            });
        }, { threshold: 0.6 });
        values.forEach(function (node) { observer.observe(node); });
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
                if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return;
                event.preventDefault();
                var next = (index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
                select(next);
                tabs[next].focus();
            });
            tab.tabIndex = index === 0 ? 0 : -1;
            // Warm the cache so switching is instant.
            var preload = new Image();
            preload.src = '/media/shots/settings-' + tab.dataset.shot + '.jpg';
        });
        function select(index) {
            tabs.forEach(function (tab, i) {
                tab.setAttribute('aria-selected', i === index ? 'true' : 'false');
                tab.tabIndex = i === index ? 0 : -1;
            });
            img.classList.add('swap');
            setTimeout(function () {
                img.src = '/media/shots/settings-' + tabs[index].dataset.shot + '.jpg';
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

        V.themes.forEach(function (theme) {
            var item = el('button', 'gallery-item');
            item.type = 'button';
            item.setAttribute('role', 'option');
            item.dataset.id = theme.id;
            var thumb = el('img');
            thumb.src = '/media/themes/' + theme.id + '-sm.jpg';
            thumb.alt = '';
            thumb.loading = 'lazy';
            item.appendChild(thumb);
            var label = el('span', '', theme.name);
            var swatches = el('small');
            ['accent', 'fg', 'muted', 'surface'].forEach(function (key) {
                var swatch = el('i');
                swatch.style.background = theme.colors[key];
                swatches.appendChild(swatch);
            });
            label.appendChild(swatches);
            item.appendChild(label);
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
            next.src = '/media/themes/' + id + '.jpg';
            name.textContent = theme.name;
            painting.textContent = theme.dynamic
                ? 'Palette derived from ' + (PAINTINGS[id] || 'the wallpaper')
                : (PAINTINGS[id] || '');
            $$('.gallery-item', list).forEach(function (item) {
                item.setAttribute('aria-selected', item.dataset.id === id ? 'true' : 'false');
            });
        }
        onTheme(function (detail) { show(detail.id); });
        show(V.applied ? V.applied.id : V.themes[0].id);
    }

    // -- Cards follow the pointer --------------------------------------------

    function initCards() {
        $$('.card').forEach(function (card) {
            card.addEventListener('pointermove', function (event) {
                var rect = card.getBoundingClientRect();
                card.style.setProperty('--mx', (event.clientX - rect.left) + 'px');
                card.style.setProperty('--my', (event.clientY - rect.top) + 'px');
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

        var prose = $('.prose');
        var toc = $('.guide-toc');
        if (!prose || !toc || !window.IntersectionObserver) return;
        var linkFor = {};
        $$('a', toc).forEach(function (link) { linkFor[link.getAttribute('href').slice(1)] = link; });
        var active = null;
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                var link = linkFor[entry.target.id];
                if (!link || link === active) return;
                if (active) active.classList.remove('active');
                active = link;
                active.classList.add('active');
            });
        }, { rootMargin: '-72px 0px -70% 0px' });
        $$('h2[id], h3[id]', prose).forEach(function (heading) { observer.observe(heading); });
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
    initReveal();
    initHero();
    initMarquee();
    initLazyVideos();
    initStats();
    initCompare();
    initTabs();
    initGallery();
    initCards();
    initNav();
    initGuide();
    initCopy();
})();
