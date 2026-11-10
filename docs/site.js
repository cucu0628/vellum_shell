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

        button.addEventListener('click', function () {
            if (popover.hidden) open(); else close(false);
        });
        document.addEventListener('click', function (event) {
            if (!event.target.closest('.theme-menu')) close(false);
        });
        popover.addEventListener('keydown', function (event) {
            var list = options();
            var index = list.indexOf(document.activeElement);
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                event.preventDefault();
                var step = event.key === 'ArrowDown' ? 1 : -1;
                list[(index + step + list.length) % list.length].focus();
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

    // -- Theme carousel: the Appearance Studio, in a browser -----------------

    // [indent, [[colour, share of the line], ...]], the same made-up code as ThemeCard.qml.
    var CODE_ROWS = [
        [0, [['magenta', 0.16], ['blue', 0.3], ['fg', 0.07]]],
        [1, [['yellow', 0.18], ['fg', 0.05], ['green', 0.4]]],
        [1, [['muted', 0.56]]],
        [1, [['cyan', 0.16], ['red', 0.12], ['fg', 0.22]]],
        [2, [['blue', 0.22], ['green', 0.3]]],
        [1, [['magenta', 0.2], ['red', 0.1]]],
        [0, [['fg', 0.07]]]
    ];

    function themeCard(theme, index) {
        var c = theme.colors;
        var card = el('div', 'tcard' + (theme.dynamic ? ' tcard-dynamic' : ''));
        card.setAttribute('role', 'option');
        card.setAttribute('aria-label', theme.name);
        card.id = 'tcard-' + theme.id;
        card.dataset.index = index;
        var vars = {
            bg: c.bg, surface: c.surface, fg: c.fg, muted: c.muted, accent: c.accent,
            red: c.red, yellow: c.yellow, green: c.green, cyan: c.cyan, blue: c.blue, magenta: c.magenta
        };
        Object.keys(vars).forEach(function (key) { card.style.setProperty('--c-' + key, vars[key]); });

        var order = 0;
        var code = CODE_ROWS.map(function (row) {
            var segments = row[1].map(function (segment) {
                var html = '<i class="tc-seg tc-' + segment[0] + '" style="--w:' + (segment[1] * 100).toFixed(1) +
                    '%;--o:' + order + '"></i>';
                order += 1;
                return html;
            }).join('');
            return '<div class="tc-line" style="--indent:' + row[0] + '">' + segments + '</div>';
        }).join('');

        card.innerHTML =
            '<div class="tc-frame">' +
                '<div class="tc-backdrop"></div>' +
                '<div class="tc-bar"></div>' +
                '<div class="tc-bands"><i></i><i></i><i></i><i></i></div>' +
                '<div class="tc-upright">' +
                    '<div class="tc-ws"><i></i><i class="on"></i><i></i><i></i><i></i></div>' +
                    '<i class="tc-clock"></i>' +
                    '<div class="tc-term">' +
                        '<div class="tc-title"><i class="tc-red"></i><i class="tc-yellow"></i><i class="tc-green"></i><b></b></div>' +
                        '<div class="tc-code">' + code + '<div class="tc-prompt"><i></i><b class="tc-cursor"></b></div></div>' +
                    '</div>' +
                    '<div class="tc-spec"><span class="tc-aa">Aa</span><i class="tc-btn"></i><i class="tc-switch"></i></div>' +
                    '<div class="tc-ansi"><i class="tc-red"></i><i class="tc-yellow"></i><i class="tc-green"></i>' +
                        '<i class="tc-cyan"></i><i class="tc-blue"></i><i class="tc-magenta"></i></div>' +
                '</div>' +
            '</div>';
        return card;
    }

    function initCarousel() {
        var carousel = $('.carousel');
        if (!carousel || !V.themes.length) return;
        var track = $('.carousel-track', carousel);
        var nameNode = $('.carousel-name');
        var statusNode = $('.carousel-status');
        var swatchNode = $('.carousel-swatches');

        var themes = V.themes;
        var cards = themes.map(function (theme, index) {
            var card = themeCard(theme, index);
            track.appendChild(card);
            return card;
        });

        function indexOf(id) {
            for (var i = 0; i < themes.length; i++) if (themes[i].id === id) return i;
            return 0;
        }

        var current = indexOf(V.applied && V.applied.id);
        var fit = 1;

        function measure() {
            var width = carousel.clientWidth;
            fit = width < 520 ? 0.7 : width < 760 ? 0.85 : 1;
            layout();
        }

        function layout() {
            var slot = 214 * fit;
            cards.forEach(function (card, i) {
                var d = i - current;
                var falloff = 1 / (1 + d * d);
                var scale = (0.75 + (1.08 - 0.75) * falloff) * fit;
                card.style.transform = 'translate(-50%, -50%) translateX(' + (d * slot).toFixed(1) + 'px) scale(' + scale.toFixed(3) + ')';
                card.style.opacity = (0.12 + 0.88 * falloff).toFixed(3);
                card.style.zIndex = String(20 - Math.abs(d));
                card.classList.toggle('is-current', i === current);
                card.setAttribute('aria-selected', i === current ? 'true' : 'false');
            });
            carousel.setAttribute('aria-activedescendant', cards[current].id);
            caption();
        }

        function caption() {
            var theme = themes[current];
            var kept = V.committed && V.committed.id === theme.id;
            nameNode.textContent = theme.name;
            statusNode.textContent = theme.dynamic
                ? (kept ? 'Active · derived from the wallpaper in the shell, shown here with a sample'
                        : 'Previewing · derived from the wallpaper in the shell, shown here with a sample')
                : (kept ? 'Active theme' : 'Previewing · press Enter or click the card to keep it');
            swatchNode.textContent = '';
            [['Background', 'bg'], ['Surface', 'surface'], ['Accent', 'accent'], ['Muted', 'muted'], ['Foreground', 'fg']]
                .forEach(function (pair) {
                    var item = el('span', 'swatch');
                    var chip = el('i');
                    chip.style.background = theme.colors[pair[1]];
                    item.appendChild(chip);
                    item.appendChild(el('span', 'swatch-name', pair[0]));
                    item.appendChild(el('code', 'swatch-hex', theme.colors[pair[1]]));
                    swatchNode.appendChild(item);
                });
        }

        function go(index) {
            var next = (index + themes.length) % themes.length;
            if (next === current) return;
            current = next;
            layout();
            V.apply(themes[current].id);
        }

        function keep() {
            var card = cards[current];
            V.commit(themes[current].id);
            if (reduceMotion) return;
            carousel.classList.add('is-confirming');
            card.classList.add('confirming');
            setTimeout(function () {
                carousel.classList.remove('is-confirming');
                card.classList.remove('confirming');
            }, 460);
        }

        function restore() {
            var committed = V.committed;
            if (!committed) return;
            current = indexOf(committed.id);
            layout();
            V.restore();
        }

        var swiped = false;
        cards.forEach(function (card, index) {
            card.addEventListener('click', function () {
                if (swiped) return;
                if (index === current) keep(); else go(index);
                carousel.focus({ preventScroll: true });
            });
        });

        carousel.addEventListener('keydown', function (event) {
            switch (event.key) {
            case 'ArrowLeft': case 'h': go(current - 1); break;
            case 'ArrowRight': case 'l': go(current + 1); break;
            case 'Home': go(0); break;
            case 'End': go(themes.length - 1); break;
            case 'Enter': case ' ': keep(); break;
            case 'Escape': restore(); break;
            default: return;
            }
            event.preventDefault();
        });

        // Only horizontal wheel movement steps: vertical scrolling keeps scrolling the page.
        var wheel = 0;
        carousel.addEventListener('wheel', function (event) {
            if (Math.abs(event.deltaX) <= Math.abs(event.deltaY)) return;
            event.preventDefault();
            wheel += event.deltaX;
            while (wheel >= 80) { wheel -= 80; go(current + 1); }
            while (wheel <= -80) { wheel += 80; go(current - 1); }
        }, { passive: false });

        var startX = null;
        carousel.addEventListener('pointerdown', function (event) {
            startX = event.clientX;
            swiped = false;
        });
        carousel.addEventListener('pointerup', function (event) {
            if (startX === null) return;
            var dx = event.clientX - startX;
            startX = null;
            if (Math.abs(dx) > 40) {
                swiped = true;
                go(current + (dx < 0 ? 1 : -1));
                setTimeout(function () { swiped = false; }, 0);
            }
        });

        // A theme chosen in the top-bar menu moves the carousel to it.
        onTheme(function (detail) {
            if (detail.committed && detail.committed === detail.id) {
                var index = indexOf(detail.id);
                if (index !== current) { current = index; layout(); } else caption();
            }
        });

        if (window.ResizeObserver) new ResizeObserver(measure).observe(carousel);
        measure();
    }

    // -- Live mock-up of the bar and dashboard -------------------------------

    function initMock() {
        var mock = $('.mock');
        if (!mock) return;
        var scaler = $('.mock-scaler');

        function fit() {
            mock.style.transform = 'scale(' + (scaler.clientWidth / 1200).toFixed(4) + ')';
        }
        if (window.ResizeObserver) new ResizeObserver(fit).observe(scaler);
        fit();

        var clock = $('.mock-clock', mock);
        function tick() {
            var now = new Date();
            var day = now.toLocaleDateString('en-GB', { weekday: 'long' });
            var time = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
            clock.textContent = day + ' ' + time;
        }
        tick();
        setInterval(tick, 15000);

        var today = new Date();
        $('.mock-month', mock).textContent = today.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });
        var grid = $('.mock-cal-grid', mock);
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].forEach(function (name) {
            grid.appendChild(el('span', 'dow', name));
        });
        var first = new Date(today.getFullYear(), today.getMonth(), 1);
        var days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
        var lead = (first.getDay() + 6) % 7;
        for (var i = 0; i < lead; i++) grid.appendChild(el('span'));
        for (var d = 1; d <= days; d++) {
            var cell = el('span', d === today.getDate() ? 'today' : '', String(d));
            if (d === 3 || d === 12 || d === 24) cell.classList.add('event');
            grid.appendChild(cell);
        }

        var cava = $('.mock-cava', mock);
        for (var b = 0; b < 28; b++) {
            var bar = el('i');
            bar.style.setProperty('--h', (0.25 + Math.abs(Math.sin(b * 1.7)) * 0.75).toFixed(2));
            bar.style.animationDelay = (-(b * 137) % 900) + 'ms';
            cava.appendChild(bar);
        }

        var toast = $('.mock-toast', mock);
        var toastName = $('.mock-toast-theme', mock);
        function showToast(detail) {
            var theme = V.byId(detail.id);
            if (!theme) return;
            toastName.textContent = theme.name;
            toast.classList.remove('show');
            void toast.offsetWidth;
            toast.classList.add('show');
        }
        if (V.applied) toastName.textContent = V.applied.name;
        onTheme(showToast);
    }

    // -- Navigation state ----------------------------------------------------

    function initNav() {
        var links = $$('.topnav a');
        function mark(section) {
            links.forEach(function (link) {
                link.classList.toggle('on', link.dataset.section === section);
                if (link.dataset.section === section) link.setAttribute('aria-current', 'page');
                else link.removeAttribute('aria-current');
            });
        }
        if (document.body.classList.contains('page-docs')) { mark('docs'); return; }
        var sections = $$('main section[id]');
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

    function initDocs() {
        var prose = $('.prose');
        if (!prose) return;
        var details = $('.toc-details');
        var narrow = window.matchMedia('(max-width: 959px)');
        if (narrow.matches) details.open = false;
        $$('.docs-toc a').forEach(function (link) {
            link.addEventListener('click', function () { if (narrow.matches) details.open = false; });
        });

        var tocNav = $('.docs-toc nav');
        var headings = $$('h2[id], h3[id]', prose);
        if (!window.IntersectionObserver) return;
        var linkFor = {};
        $$('.docs-toc a').forEach(function (link) { linkFor[link.getAttribute('href').slice(1)] = link; });
        var active = null;
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) return;
                var link = linkFor[entry.target.id];
                if (!link || link === active) return;
                if (active) active.classList.remove('active');
                active = link;
                active.classList.add('active');
                if (!narrow.matches && tocNav) {
                    var top = link.offsetTop - tocNav.clientHeight / 3;
                    tocNav.scrollTo({ top: Math.max(0, top), behavior: reduceMotion ? 'auto' : 'smooth' });
                }
            });
        }, { rootMargin: '-72px 0px -70% 0px' });
        headings.forEach(function (heading) { observer.observe(heading); });
    }

    function initCopy() {
        $$('.prose pre, .code-card pre').forEach(function (pre) {
            var wrap = el('div', 'pre-wrap');
            pre.parentNode.insertBefore(wrap, pre);
            wrap.appendChild(pre);
            var button = el('button', 'copy', 'Copy');
            button.type = 'button';
            button.setAttribute('aria-label', 'Copy code to clipboard');
            button.addEventListener('click', function () {
                var text = pre.innerText.replace(/\n$/, '');
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
    initCarousel();
    initMock();
    initNav();
    initDocs();
    initCopy();
})();
