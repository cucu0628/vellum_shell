// Betolto: a shell inditokepernyoje (features/splash/SplashRoot.qml) a weben,
// ugyanazzal az idovonallal, csak valamivel gyorsabban.
//
//   1. a papir tuscseppkent terul szet a feketen, mogotte felizzik az akcentus;
//   2. a logo ket vonasban megirodik, kozben korbefut az enso;
//   3. alatta a nev es egy udvozles;
//   4. amig az oldal (betutipus, hero-kep) toltodik, az enso lassan forog;
//   5. kilepeskor a jel felemelkedik, a papir a kozeprol kifele felszakad.
//
// Munkamenetenkent egyszer fut (a theme.js donti el); kattintas, billentyu
// vagy gorgetes atugorja. A papir a shell shaderenek WebGL-portja; WebGL nelkul
// sima atusztatas.
(function () {
    'use strict';

    var root = document.documentElement;
    var splash = document.getElementById('splash');
    if (!splash || !root.classList.contains('splash-on')) {
        if (splash) splash.remove();
        return;
    }

    // A shell idozitesei (ms) ennyivel szorozva: a weben rovidebb a varakozas.
    var PACE = 0.8;
    var SAFETY = 6000;

    function outCubic(t) { return 1 - Math.pow(1 - t, 3); }
    function inCubic(t) { return t * t * t; }
    function inOutCubic(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
    function outQuart(t) { return 1 - Math.pow(1 - t, 4); }

    // [kezdes, hossz, gorbe] a SplashRoot.qml `intro` es `outro` animacioibol.
    var INTRO = {
        spread: [0, 1150, outCubic],
        glow: [220, 1000, outCubic],
        leftStroke: [320, 440, inOutCubic],
        rightStroke: [760, 540, outQuart],
        enso: [420, 1080, inOutCubic],
        words: [1050, 800, outCubic]
    };
    var HELD = 2200;
    var OUTRO = {
        lift: [0, 480, inCubic],
        open: [200, 1050, inOutCubic]
    };
    var OUTRO_END = 1250;

    function progress(spec, elapsed) {
        var t = (elapsed - spec[0] * PACE) / (spec[1] * PACE);
        return spec[2](Math.max(0, Math.min(1, t)));
    }

    var $ = function (selector) { return splash.querySelector(selector); };
    var canvas = $('.splash-ink');
    var paper = $('.splash-paper');
    var night = $('.splash-night');
    var mark = $('.splash-mark');
    var glow = $('.splash-glow');
    var enso = $('.splash-enso');
    var rings = splash.querySelectorAll('.splash-ring');
    var leftClip = $('#splash-left rect');
    var rightClip = $('#splash-right rect');
    var words = $('.splash-words');
    var name = $('.splash-name');

    try {
        if (localStorage.getItem('vellum-site-visited')) $('.splash-greeting').textContent = 'Welcome back';
        localStorage.setItem('vellum-site-visited', '1');
    } catch (e) { /* private mode: a first visit every time */ }

    // -- A papir: a splash-ink.frag WebGL 1-re forditva ----------------------

    var ink = (function () {
        var gl = null;
        try {
            gl = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false, depth: false });
        } catch (e) { gl = null; }
        if (!gl) return null;

        var vertex = 'attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }';
        var fragment = [
            '#ifdef GL_FRAGMENT_PRECISION_HIGH',
            'precision highp float;',
            '#else',
            'precision mediump float;',
            '#endif',
            'uniform vec2 resolution;',
            'uniform float spread, open, seed;',
            'uniform vec2 origin;',
            'uniform vec3 paperColor, rimColor;',
            'const float NOISE_AMOUNT = 0.2;',
            'const float FIBRE_AMOUNT = 0.025;',
            'const float FEATHER = 0.03;',
            'const float RIM_WIDTH = 0.08;',
            'float hash(vec2 p) {',
            '    p = fract(p * vec2(123.34, 456.21));',
            '    p += dot(p, p + 45.32);',
            '    return fract(p.x * p.y);',
            '}',
            'float valueNoise(vec2 p) {',
            '    vec2 i = floor(p);',
            '    vec2 f = fract(p);',
            '    vec2 u = f * f * (3.0 - 2.0 * f);',
            '    float a = hash(i);',
            '    float b = hash(i + vec2(1.0, 0.0));',
            '    float c = hash(i + vec2(0.0, 1.0));',
            '    float d = hash(i + vec2(1.0, 1.0));',
            '    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);',
            '}',
            'float fbm(vec2 p) {',
            '    float sum = 0.0;',
            '    float amplitude = 0.5;',
            '    for (int octave = 0; octave < 5; octave++) {',
            '        sum += amplitude * valueNoise(p);',
            '        p = p * 2.03 + vec2(17.1, 9.2);',
            '        amplitude *= 0.5;',
            '    }',
            '    return sum;',
            '}',
            'void main() {',
            '    vec2 uv = vec2(gl_FragCoord.x / resolution.x, 1.0 - gl_FragCoord.y / resolution.y);',
            '    vec2 scaleVec = vec2(resolution.x / resolution.y, 1.0);',
            '    vec2 delta = (uv - origin) * scaleVec;',
            '    vec2 corner = max(origin, 1.0 - origin) * scaleVec;',
            '    float dist = length(delta) / length(corner);',
            '    float grain = fbm(uv * scaleVec * 3.2 + seed * 7.13);',
            '    float fibre = fbm(uv * scaleVec * 14.0 - seed * 3.7);',
            '    float shaped = dist + (grain - 0.5) * NOISE_AMOUNT * 2.0 + (fibre - 0.5) * FIBRE_AMOUNT * 2.0;',
            '    float margin = NOISE_AMOUNT + FIBRE_AMOUNT + FEATHER;',
            '    float spreadFront = mix(-margin, 1.0 + margin, spread);',
            '    float openFront = mix(-margin, 1.0 + margin, open);',
            '    float covered = 1.0 - smoothstep(spreadFront - FEATHER, spreadFront + FEATHER, shaped);',
            '    float torn = 1.0 - smoothstep(openFront - FEATHER, openFront + FEATHER, shaped);',
            '    float alpha = covered * (1.0 - torn);',
            '    float behindSpread = clamp((spreadFront - shaped) / RIM_WIDTH, 0.0, 1.0);',
            '    float spreadRim = covered * (1.0 - behindSpread) * (1.0 - spread * spread);',
            '    float aheadOpen = clamp((shaped - openFront) / (RIM_WIDTH * 1.4), 0.0, 1.0);',
            '    float openRim = (1.0 - torn) * (1.0 - aheadOpen) * smoothstep(0.0, 0.08, open) * (1.0 - open * open);',
            '    vec3 color = paperColor;',
            '    color = mix(color, rimColor, 0.22 * spreadRim);',
            '    color = mix(color, rimColor, 0.5 * openRim);',
            '    gl_FragColor = vec4(color * alpha, alpha);',
            '}'
        ].join('\n');

        function compile(type, source) {
            var shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);
            return gl.getShaderParameter(shader, gl.COMPILE_STATUS) ? shader : null;
        }
        var vs = compile(gl.VERTEX_SHADER, vertex);
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
        ['resolution', 'spread', 'open', 'seed', 'origin', 'paperColor', 'rimColor'].forEach(function (key) {
            u[key] = gl.getUniformLocation(program, key);
        });
        // Kijelzonkent ugyanaz a zaj a shellben; itt latogatasonkent mas.
        gl.uniform1f(u.seed, Math.random() * 100);

        function color(variable) {
            var hex = getComputedStyle(root).getPropertyValue(variable).trim().replace('#', '');
            if (hex.length === 3) hex = hex.replace(/./g, '$&$&');
            return [0, 2, 4].map(function (i) { return parseInt(hex.slice(i, i + 2), 16) / 255 || 0; });
        }
        gl.uniform3fv(u.paperColor, color('--bg'));
        gl.uniform3fv(u.rimColor, color('--accent'));

        return {
            // A szelek ugyis puhak: CSS-pixelnel tobb felbontas nem kell.
            resize: function (width, height, origin) {
                canvas.width = Math.max(1, Math.round(width));
                canvas.height = Math.max(1, Math.round(height));
                gl.viewport(0, 0, canvas.width, canvas.height);
                gl.uniform2f(u.resolution, canvas.width, canvas.height);
                gl.uniform2f(u.origin, origin[0], origin[1]);
            },
            draw: function (spread, open) {
                gl.uniform1f(u.spread, spread);
                gl.uniform1f(u.open, open);
                gl.drawArrays(gl.TRIANGLES, 0, 3);
            }
        };
    })();
    splash.classList.toggle('splash-gl', !!ink);

    // -- Elrendezes: a SplashView.qml aranyai ---------------------------------

    function layout() {
        var width = window.innerWidth;
        var height = window.innerHeight;
        var logo = Math.round(Math.max(56, Math.min(96, Math.min(width, height) * 0.085)));
        var centerY = Math.round(height / 2 - logo * 0.35);
        splash.style.setProperty('--logo', logo + 'px');
        splash.style.setProperty('--center-y', centerY + 'px');
        if (ink) ink.resize(width, height, [0.5, centerY / height]);
    }
    layout();
    window.addEventListener('resize', layout);

    // -- Idovonal -------------------------------------------------------------

    var started = performance.now();
    // ?splash=<ms> megallitja az idovonalat ott: a fazisok igy nezhetok meg.
    var frozen = /[?&]splash=(\d+)/.exec(window.location.search);
    frozen = frozen ? Number(frozen[1]) : null;
    var leftAt = 0;
    var ready = false;
    var leaving = false;
    var openNotified = false;

    function draw(now) {
        if (frozen !== null) {
            now = started + frozen;
            if (frozen >= HELD * PACE && !leaving) {
                leaving = true;
                leftAt = started + HELD * PACE;
            }
        }
        var elapsed = now - started;
        var v = {};
        Object.keys(INTRO).forEach(function (key) { v[key] = progress(INTRO[key], elapsed); });
        var out = leaving ? now - leftAt : 0;
        var lift = leaving ? progress(OUTRO.lift, out) : 0;
        var open = leaving ? progress(OUTRO.open, out) : 0;
        // Kilepeskor a lap mindenkeppen teljesen beteritve indul.
        if (leaving) v.spread = 1;

        if (ink) ink.draw(v.spread, open);
        else paper.style.opacity = v.spread * (1 - open);
        // A fekete csak addig kell, amig a papir be nem teritett mindent.
        night.style.opacity = v.spread < 1 ? 1 : 0;

        mark.style.opacity = 1 - lift;
        mark.style.transform = 'scale(' + (1 + lift * 0.08) + ')';
        glow.style.opacity = 0.22 * v.glow;
        glow.style.transform = 'scale(' + (0.7 + 0.3 * v.glow + 0.25 * lift) + ')';

        // Varakozas kozben az enso lassan forog (2,6 s / kor).
        var turning = Math.max(0, elapsed - HELD * PACE);
        enso.setAttribute('transform', 'rotate(' + (turning / 2600 * 360 % 360) + ') scale(' + (1 + lift * 0.3) + ')');
        rings[0].style.strokeDasharray = (318 * v.enso) + ' 360';
        rings[1].style.strokeDasharray = (290 * v.enso) + ' 360';

        // A bal vonas fentrol lefele, a jobb a kozos labatol felfele irodik.
        var left = v.leftStroke >= 1 ? 16 : 2.7 + 11.6 * v.leftStroke;
        leftClip.setAttribute('height', left);
        var rightTop = v.rightStroke >= 1 ? 0 : 14.3 - 12.6 * v.rightStroke;
        rightClip.setAttribute('y', rightTop);
        rightClip.setAttribute('height', 16 - rightTop);

        words.style.opacity = v.words * (1 - lift);
        words.style.transform = 'translateY(' + ((1 - v.words) * 8) + 'px)';
        name.style.letterSpacing = (2 + 10 * (1 - v.words)) + 'px';

        if (!leaving && ready && elapsed >= HELD * PACE) leave(now);
        if (leaving && open > 0 && !openNotified) {
            openNotified = true;
            // Az oldal ismet gorgetheto, a hero bevezeto animacioi indulhatnak.
            root.classList.remove('splash-on');
            root.classList.add('splash-leaving');
            document.dispatchEvent(new CustomEvent('vellum:splash-open'));
        }
        if (frozen !== null) return;
        if (leaving && out >= OUTRO_END * PACE) return finish();
        requestAnimationFrame(draw);
    }

    function leave(now) {
        if (leaving) return;
        leaving = true;
        leftAt = now || performance.now();
    }

    function finish() {
        window.removeEventListener('resize', layout);
        ['pointerdown', 'keydown', 'wheel', 'touchmove'].forEach(function (type) {
            window.removeEventListener(type, skip, true);
        });
        root.classList.remove('splash-on', 'splash-leaving');
        splash.remove();
        if (!openNotified) document.dispatchEvent(new CustomEvent('vellum:splash-open'));
    }

    // Barmilyen bemenet: azonnal felszakad, nem kell kivarni.
    function skip() { leave(); }
    ['pointerdown', 'keydown', 'wheel', 'touchmove'].forEach(function (type) {
        window.addEventListener(type, skip, { capture: true, passive: true });
    });

    // Kesz az oldal, ha a betuk es a hero kepe megvan; egy elakado kep se tartsa
    // itt a lapot.
    var waits = [];
    if (document.fonts && document.fonts.ready) waits.push(document.fonts.ready);
    var poster = document.querySelector('.stage video[poster]');
    if (poster) {
        waits.push(new Promise(function (resolve) {
            var image = new Image();
            image.onload = image.onerror = resolve;
            image.src = poster.getAttribute('poster');
        }));
    }
    Promise.all(waits).then(function () { ready = true; }, function () { ready = true; });
    setTimeout(function () { ready = true; }, SAFETY);

    requestAnimationFrame(draw);
})();
