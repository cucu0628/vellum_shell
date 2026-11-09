#version 440
#extension GL_GOOGLE_include_directive : require
// Tel: lassan forgo, hatagu jegkristaly csovekbol, mogotte havazas.
// Anyag: 0 = jeg, 1 = ho.

#include "common.glsl"

const float ICE = 0.0;
const float SNOW = 1.0;

float flakeSpin = 0.0;

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Hatszoros szimmetria: a szoget 30 fokos szeletbe tukrozzuk, igy eleg egy
// kar a mellekagaival. Minden vonal kerek keresztmetszetu cso.
float map(vec3 p) {
    p.xy = rotation(flakeSpin) * p.xy;
    float angle = atan(p.y, p.x);
    float sector = TAU / 6.0;
    angle = abs(mod(angle + sector * 0.5, sector) - sector * 0.5);
    vec2 q = length(p.xy) * vec2(cos(angle), sin(angle));

    vec2 branch = vec2(0.5, 0.8660254);
    float arm = segment(q, vec2(0.0), vec2(1.18, 0.0));
    float side = segment(q, vec2(0.4, 0.0), vec2(0.4, 0.0) + branch * 0.36);
    side = min(side, segment(q, vec2(0.7, 0.0), vec2(0.7, 0.0) + branch * 0.26));
    side = min(side, segment(q, vec2(0.92, 0.0), vec2(0.92, 0.0) + branch * 0.15));
    // A kozepso hatszog: a szeletben egy fuggoleges szakasz.
    side = min(side, segment(q, vec2(0.22, 0.0), vec2(0.22, 0.127)));

    float z = p.z;
    return min(length(vec2(arm, z)) - 0.095, length(vec2(side, z)) - 0.07);
}

float materialAt(vec3 p) {
    return ICE;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;
    flakeSpin = t * 0.07;

    View view;
    view.drift = vec2(0.4, 0.08);
    // Csak billeg: igy a kristaly majdnem mindig szemben all, megsem lapos.
    view.spinA = sin(t * 0.13) * 0.6;
    view.spinB = sin(t * 0.09 + 1.0) * 0.4;
    view.tilt = 0.0;
    view.scale = 1.0;

    Hit hit = renderObject(uv, view);
    if (hit.hit) {
        fragColor = surface(hit.tone, ICE, hit.depth);
        return;
    }
    vec2 flake = snowfall(uv, 0.009);
    fragColor = flake.x > 0.0 ? sprite(flake.y, flake.x, SNOW) : backdrop(0.0, SNOW);
}
