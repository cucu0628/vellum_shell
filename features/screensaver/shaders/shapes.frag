#version 440
#extension GL_GOOGLE_include_directive : require
// Alapjelenet: negy forma valtja egymast (cseppek, csomo, racs, kristaly), a
// shell temajanak szineivel. Anyag: 0 = forma, 1 = por.

#include "common.glsl"

const float FORM_SECONDS = 30.0;
const int FORM_COUNT = 4;

// Lassan keringo, egymasba olvado cseppek.
float droplets(vec3 p) {
    float d = length(p) - 0.62;
    for (int i = 0; i < 5; i++) {
        float f = float(i);
        float t = time * (0.19 + 0.03 * f) + f * 1.7;
        vec3 center = vec3(sin(t), sin(t * 0.73 + f), cos(t * 1.19)) * (0.72 + 0.1 * sin(f * 2.3));
        d = smoothMin(d, length(p - center) - (0.3 + 0.03 * f), 0.34);
    }
    return d;
}

// (2,3) torusz-csomo: a kor keresztmetszet 1.5-szeres szoggel fordul.
float knot(vec3 p) {
    float angle = atan(p.z, p.x);
    vec2 q = vec2(length(p.xz) - 0.86, p.y);
    q = rotation(1.5 * angle) * q;
    q.x = abs(q.x) - 0.34;
    return (length(q) - 0.19) * 0.72;
}

// Gombbe vagott giroid: sok kis nyilas, a karakterracson szep textura.
float lattice(vec3 p) {
    vec3 s = p * 4.4;
    float gyroid = abs(dot(sin(s), cos(s.zxy))) / 4.4 - 0.042;
    return max(length(p) - 1.22, gyroid) * 0.62;
}

// Csonkolt oktaeder: sok lap, mindegyik mas fenyt kap, mint egy csiszolt ko.
float gem(vec3 p) {
    vec3 a = abs(p);
    float octahedron = (a.x + a.y + a.z - 1.42) * 0.577;
    float cube = max(a.x, max(a.y, a.z)) - 0.86;
    return max(octahedron, cube) - 0.03;
}

float form(int index, vec3 p) {
    if (index == 0) return droplets(p);
    if (index == 1) return knot(p);
    if (index == 2) return lattice(p);
    return gem(p);
}

float map(vec3 p) {
    float clock = time / FORM_SECONDS;
    float phase = fract(clock);
    int index = int(floor(clock)) % FORM_COUNT;
    // Az ido nagy reszeben felismerheto a forma; csak a vegen alakul at.
    float blend = smoothstep(0.78, 1.0, phase);
    float d = form(index, p);
    if (blend > 0.0) d = mix(d, form((index + 1) % FORM_COUNT, p), blend);
    return d;
}

float materialAt(vec3 p) {
    return 0.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;

    View view;
    view.drift = vec2(0.46, 0.12);
    // Lassu forgas: gyorsabban a felulet karakterei "forrnak".
    view.spinA = t * 0.12;
    view.spinB = t * 0.075 + 0.7;
    view.tilt = 0.0;
    view.scale = 1.0;

    Hit hit = renderObject(uv, view);
    if (hit.hit) fragColor = surface(hit.tone, 0.0, hit.depth);
    else fragColor = backdrop(dust(uv), 1.0);
}
