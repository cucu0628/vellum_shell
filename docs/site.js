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

    // -- The wallpaper: core/shaders/wallpaper-ink.frag, ported to WebGL 1 -------
    // A new painting spreads over the old one like a drop of ink: an irregular
    // front (fbm noise) with a darker wet rim that dries as it settles.

    function createInk(canvas) {
        var gl = null;
        try { gl = canvas.getContext('webgl', { antialias: false, depth: false, alpha: false }); } catch (e) { gl = null; }
        if (!gl) return null;
        var fragment = [
            '#ifdef GL_FRAGMENT_PRECISION_HIGH',
            'precision highp float;',
            '#else',
            'precision mediump float;',
            '#endif',
            'uniform vec2 resolution, origin;',
            'uniform float progress, seed, fromAspect, toAspect;',
            'uniform sampler2D fromTexture, toTexture;',
            'const float NOISE_AMOUNT = 0.22;',
            'const float FIBRE_AMOUNT = 0.02;',
            'const float FEATHER = 0.035;',
            'const float RIM_WIDTH = 0.09;',
            'float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }',
            'float valueNoise(vec2 p) {',
            '    vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);',
            '    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);',
            '}',
            'float fbm(vec2 p) {',
            '    float sum = 0.0; float amplitude = 0.5;',
            '    for (int octave = 0; octave < 5; octave++) { sum += amplitude * valueNoise(p); p = p * 2.03 + vec2(17.1, 9.2); amplitude *= 0.5; }',
            '    return sum;',
            '}',
            'vec2 cover(vec2 uv, float aspect, float imageAspect, float scale) {',
            '    vec2 centered = (uv - 0.5) / scale;',
            '    if (imageAspect > aspect) centered.x *= aspect / imageAspect; else centered.y *= imageAspect / aspect;',
            '    return centered + 0.5;',
            '}',
            'void main() {',
            '    vec2 uv = vec2(gl_FragCoord.x / resolution.x, 1.0 - gl_FragCoord.y / resolution.y);',
            '    float aspect = resolution.x / resolution.y;',
            '    vec2 scaleVec = vec2(aspect, 1.0);',
            '    vec2 corner = max(origin, 1.0 - origin) * scaleVec;',
            '    float dist = length((uv - origin) * scaleVec) / length(corner);',
            '    float grain = fbm(uv * scaleVec * 3.2 + seed * 7.13);',
            '    float fibre = fbm(uv * scaleVec * 14.0 - seed * 3.7);',
            '    float shaped = dist + (grain - 0.5) * NOISE_AMOUNT * 2.0 + (fibre - 0.5) * FIBRE_AMOUNT * 2.0;',
            '    float margin = NOISE_AMOUNT + FIBRE_AMOUNT + FEATHER;',
            '    float front = mix(-margin, 1.0 + margin, progress);',
            '    float reveal = 1.0 - smoothstep(front - FEATHER, front + FEATHER, shaped);',
            '    vec4 fromColor = texture2D(fromTexture, cover(uv, aspect, fromAspect, 1.0 + 0.02 * progress));',
            '    vec4 toColor = texture2D(toTexture, cover(uv, aspect, toAspect, 1.035 - 0.035 * progress));',
            '    float behind = clamp((front - shaped) / RIM_WIDTH, 0.0, 1.0);',
            '    float rim = reveal * (1.0 - behind) * (1.0 - progress * progress);',
            '    toColor.rgb *= 1.0 - 0.28 * rim;',
            '    gl_FragColor = vec4(mix(fromColor.rgb, toColor.rgb, reveal), 1.0);',
            '}'
        ].join('\n');
        function compile(type, source) {
            var shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);
            return gl.getShaderParameter(shader, gl.COMPILE_STATUS) ? shader : null;
        }
        var vs = compile(gl.VERTEX_SHADER, 'attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }');
        var fs = compile(gl.FRAGMENT_SHADER, fragment);
        if (!vs || !fs) return null;
        var program = gl.createProgram();
        gl.attachShader(program, vs);
        gl.attachShader(program, fs);
        gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return null;
        gl.useProgram(program);
        gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
        var position = gl.getAttribLocation(program, 'p');
        gl.enableVertexAttribArray(position);
        gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
        var u = {};
        ['resolution', 'origin', 'progress', 'seed', 'fromAspect', 'toAspect', 'fromTexture', 'toTexture'].forEach(function (key) {
            u[key] = gl.getUniformLocation(program, key);
        });
        gl.uniform1i(u.fromTexture, 0);
        gl.uniform1i(u.toTexture, 1);
        var textures = [gl.createTexture(), gl.createTexture()];
        textures.forEach(function (texture) {
            gl.bindTexture(gl.TEXTURE_2D, texture);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        });
        function upload(unit, image) {
            gl.activeTexture(gl.TEXTURE0 + unit);
            gl.bindTexture(gl.TEXTURE_2D, textures[unit]);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, image);
        }
        return {
            start: function (from, to, origin) {
                // The edges are soft anyway: no more than 1.5 device pixels per CSS pixel.
                var scale = Math.min(window.devicePixelRatio || 1, 1.5);
                canvas.width = Math.round(canvas.clientWidth * scale) || 1;
                canvas.height = Math.round(canvas.clientHeight * scale) || 1;
                gl.viewport(0, 0, canvas.width, canvas.height);
                gl.uniform2f(u.resolution, canvas.width, canvas.height);
                gl.uniform2f(u.origin, origin[0], origin[1]);
                gl.uniform1f(u.seed, Math.random() * 100);
                upload(0, from);
                upload(1, to);
                gl.uniform1f(u.fromAspect, from.naturalWidth / from.naturalHeight);
                gl.uniform1f(u.toAspect, to.naturalWidth / to.naturalHeight);
            },
            draw: function (progress) {
                gl.uniform1f(u.progress, progress);
                gl.drawArrays(gl.TRIANGLES, 0, 3);
            }
        };
    }

    // The shell's timing: 1100 ms, InOutSine, from just below the centre unless
    // a click says where the drop fell.
    var INK_DURATION = 1100;
    var inkOrigin = null;

    function initWallpaper() {
        var wallpaper = $('.wallpaper');
        if (!wallpaper) return;
        var paint = $('.wallpaper-paint', wallpaper);
        var canvas = $('.wallpaper-ink', wallpaper);
        var desk = $$('.wallpaper-desk i', wallpaper);
        var ink = reduceMotion ? null : createInk(canvas);
        var images = {};
        var shown = null;      // the image on the wall
        var wanted = null;     // the theme asked for last
        var frame = 0;
        var deskIndex = 0;

        document.addEventListener('pointerdown', function (event) {
            inkOrigin = [event.clientX / window.innerWidth, event.clientY / window.innerHeight];
        }, true);

        function load(id) {
            if (!images[id]) {
                images[id] = new Promise(function (resolve, reject) {
                    var image = new Image();
                    image.decoding = 'async';
                    image.onload = function () {
                        (image.decode ? image.decode() : Promise.resolve()).then(function () { resolve(image); }, function () { resolve(image); });
                    };
                    image.onerror = reject;
                    image.src = media('/media/wallpapers/' + id + '.jpg');
                });
            }
            return images[id];
        }
        function hang(image) {
            var url = 'url("' + image.src + '")';
            paint.style.backgroundImage = url;
            deskIndex ^= 1;
            desk[deskIndex].style.backgroundImage = url;
            desk[deskIndex].classList.add('on');
            desk[deskIndex ^ 1].classList.remove('on');
            shown = image;
        }
        function spread(from, to, origin) {
            cancelAnimationFrame(frame);
            ink.start(from, to, origin);
            ink.draw(0);
            canvas.classList.add('inking');
            var began = performance.now();
            function step(now) {
                var t = Math.min(1, (now - began) / INK_DURATION);
                ink.draw(-(Math.cos(Math.PI * t) - 1) / 2);
                if (t < 1) { frame = requestAnimationFrame(step); return; }
                hang(to);
                // One more frame, so the plain background is painted before the canvas goes.
                frame = requestAnimationFrame(function () { canvas.classList.remove('inking'); });
            }
            frame = requestAnimationFrame(step);
        }
        function show(id) {
            if (id === wanted) return;
            wanted = id;
            var origin = inkOrigin || [0.5, 0.56];
            inkOrigin = null;
            load(id).then(function (image) {
                if (wanted !== id || image === shown) return;
                var unlocked = parseFloat(document.documentElement.style.getPropertyValue('--unlock')) >= 1;
                if (!shown || !ink || unlocked || document.hidden) hang(image);
                else spread(shown, image, origin);
            }, function () {});
        }
        onTheme(function (detail) { show(detail.id); });
        if (V.applied) show(V.applied.id);

        // Scrolling past the lock screen unlocks it: the painting blurs into the desktop.
        var lock = $('.lock');
        if (!lock || document.body.classList.contains('page-404')) return;
        var pending = false;
        function unlock() {
            pending = false;
            var progress = Math.max(0, Math.min(1, window.scrollY / (lock.offsetHeight * 0.7)));
            document.documentElement.style.setProperty('--unlock', progress.toFixed(3));
        }
        window.addEventListener('scroll', function () {
            if (!pending) { pending = true; requestAnimationFrame(unlock); }
        }, { passive: true });
        window.addEventListener('resize', unlock);
        unlock();
    }

    // -- The lock screen's palette card: pick one, or watch them all go by -------

    function initPalette() {
        var card = $('.lock-palette');
        var group = $('.lock-swatches');
        if (!card || !group) return;
        var nameNode = $('.lock-palette-name', card);
        var paintingNode = $('.lock-painting', card);
        var CYCLE = 6500;
        var buttons = V.themes.map(function (theme) {
            var button = el('button', 'lock-swatch');
            button.type = 'button';
            button.dataset.id = theme.id;
            button.setAttribute('role', 'radio');
            button.setAttribute('aria-label', theme.name);
            button.title = theme.name;
            button.style.setProperty('--sw-bg', theme.colors.bgDark);
            button.style.setProperty('--sw-surface', theme.colors.surface);
            button.style.setProperty('--sw-accent', theme.colors.accent);
            button.addEventListener('click', function () { stop(); V.commit(theme.id); });
            group.appendChild(button);
            return button;
        });
        group.addEventListener('keydown', function (event) {
            var step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
            if (!step) return;
            event.preventDefault();
            var index = buttons.indexOf(document.activeElement);
            var next = buttons[(index + step + buttons.length) % buttons.length];
            next.focus();
            next.click();
        });
        function sync(id) {
            var theme = V.byId(id);
            if (!theme) return;
            nameNode.textContent = theme.name;
            paintingNode.textContent = PAINTINGS[id] || '';
            buttons.forEach(function (button) {
                var on = button.dataset.id === id;
                button.setAttribute('aria-checked', on ? 'true' : 'false');
                button.tabIndex = on ? 0 : -1;
            });
        }
        onTheme(function (detail) { sync(detail.id); });
        if (V.applied) sync(V.applied.id);

        // A first visit plays through the palettes, like the Appearance Studio's
        // live preview: shown, never remembered. A choice, a remembered theme or
        // a ?theme= preview keeps the page still.
        var chosen = false;
        try { chosen = !!localStorage.getItem('vellum-site-theme'); } catch (e) { chosen = true; }
        if (chosen || reduceMotion || /[?&]theme=/.test(window.location.search)) return;
        card.style.setProperty('--cycle', CYCLE + 'ms');
        var timer = 0;
        var playing = true;
        var visible = true;
        function stop() {
            playing = false;
            clearTimeout(timer);
            card.classList.remove('playing');
        }
        function schedule() {
            clearTimeout(timer);
            card.classList.remove('playing');
            if (!playing || !visible || document.hidden || document.documentElement.classList.contains('splash-on')) return;
            void card.offsetWidth;  // restart the timer bar
            card.classList.add('playing');
            timer = setTimeout(function () {
                var index = V.themes.indexOf(V.applied);
                var next = buttons[(index + 1) % buttons.length];
                var box = next.getBoundingClientRect();
                inkOrigin = [(box.left + box.width / 2) / window.innerWidth, (box.top + box.height / 2) / window.innerHeight];
                V.apply(next.dataset.id);
                schedule();
            }, CYCLE);
        }
        // Any choice of theme elsewhere on the page ends the show.
        ['.theme-menu', '.studio'].forEach(function (selector) {
            var node = $(selector);
            if (!node) return;
            node.addEventListener('pointerdown', stop);
            node.addEventListener('keydown', stop);
        });
        if ('IntersectionObserver' in window) {
            new IntersectionObserver(function (entries) {
                visible = entries[0].isIntersecting;
                schedule();
            }, { threshold: 0.5 }).observe(card);
        }
        document.addEventListener('visibilitychange', schedule);
        document.addEventListener('vellum:splash-open', schedule);
        schedule();
    }

    // -- The session around the page: bar clock, lock field ---------------------

    function initSession() {
        if (!document.body.classList.contains('page-home')) return;

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
    initWallpaper();
    initPalette();
    initSession();
    initLauncher();
    initNav();
    initGuide();
    initCopy();
})();
