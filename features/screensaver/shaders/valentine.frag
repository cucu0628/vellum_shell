#version 440
#extension GL_GOOGLE_include_directive : require
// Valentin-nap: lassan dobogo, parnas 3D sziv, mogotte felszallo <3 jelek.
// Anyag: 0 = sziv, 1 = lebego szivek.

#include "common.glsl"

const float HEART = 0.0;
const float FLOATING = 1.0;

float beat = 1.0;

float dot2(vec2 v) {
    return dot(v, v);
}

// iq: sziv sik tavolsaga; a csucs az origoban, a teteje kb. y = 1.1.
float heart2d(vec2 p) {
    p.x = abs(p.x);
    if (p.y + p.x > 1.0) return sqrt(dot2(p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
    return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// Parnas: a vastagsag a szeltol befele kor-iv szerint no.
float map(vec3 p) {
    p /= beat;
    const float size = 1.95;
    float d2 = heart2d(p.xy / size + vec2(0.0, 0.56)) * size;
    float inside = clamp(-d2 / 0.62, 0.0, 1.0);
    float thickness = 0.5 * sqrt(inside * (2.0 - inside));
    float d = d2 < 0.0 ? max(abs(p.z) - thickness, d2) : length(vec2(d2, p.z));
    return d * 0.6 * beat;
}

float materialAt(vec3 p) {
    return HEART;
}

// Lassan felszallo "<3" parok ket retegben; a ket cella mindig egyutt mozog.
vec2 floatingHearts(vec2 uv) {
    vec2 grid = uv * gridSize;
    vec2 result = vec2(0.0);
    for (int i = 0; i < 2; i++) {
        float layer = float(i);
        float rise = time * (0.7 + 0.6 * layer);
        float row = floor(grid.y + rise);
        float sway = floor(sin(time * 0.17 + row * 0.21 + layer * 3.0) * 2.0 + 0.5);
        float column = floor(grid.x) + sway + layer * 7.0;
        float pair = floor(column / 2.0);
        float h = hash(vec2(pair, row) * 0.0191 + layer * 0.37 + seed);
        if (h > 1.0 - 0.0016 * (1.0 + layer)) {
            float left = mod(column, 2.0) < 0.5 ? 1.0 : 0.0;
            result = vec2(0.24 + 0.16 * layer, left > 0.5 ? GLYPH_HEART_LEFT : GLYPH_HEART_RIGHT);
        }
    }
    return result;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;
    // Dobbanas: ket gyors lukes, utana szunet.
    float cycle = fract(time / 1.6);
    beat = 1.0 + 0.035 * (exp(-cycle * 30.0) + 0.6 * exp(-max(cycle - 0.22, 0.0) * 30.0) * step(0.22, cycle));

    View view;
    view.drift = vec2(0.36, 0.08);
    // Nagyreszt szemben all, csak lassan elfordul.
    view.spinA = sin(t * 0.15) * 0.75;
    view.spinB = sin(t * 0.11 + 0.5) * 0.2;
    view.tilt = 0.0;
    view.scale = 0.95;

    Hit hit = renderObject(uv, view);
    if (hit.hit) {
        fragColor = surface(hit.tone, HEART, hit.depth);
        return;
    }
    vec2 floating = floatingHearts(uv);
    fragColor = floating.x > 0.0 ? sprite(floating.y, floating.x, FLOATING) : backdrop(0.0, FLOATING);
}
