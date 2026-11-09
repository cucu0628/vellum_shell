#version 440
#extension GL_GOOGLE_include_directive : require
// Karacsony: forgo fenyofa gombokkel es csillaggal, havazas, hobuckak.
// Anyag: 0 = fenyo, 1 = piros gomb, 2 = arany (gomb, csillag), 3 = torzs,
// 4 = ho.

#include "common.glsl"

const float TREE = 0.0;
const float RED = 1.0;
const float GOLD = 2.0;
const float TRUNK = 3.0;
const float SNOW = 4.0;

// A csillag mindig a nezo fele fordul; a fa forgasat ez kompenzalja.
float treeSpin = 0.0;

// iq: csonkakup, h = fel magassag, r1 = also, r2 = felso sugar.
float cappedCone(vec3 p, float h, float r1, float r2) {
    vec2 q = vec2(length(p.xz), p.y);
    vec2 k1 = vec2(r2, h);
    vec2 k2 = vec2(r2 - r1, 2.0 * h);
    vec2 ca = vec2(q.x - min(q.x, q.y < 0.0 ? r1 : r2), abs(q.y) - h);
    vec2 cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

const int TIERS = 4;

// A szintek alulrol: kozeppont y, fel magassag, also es felso sugar.
vec4 tier(int i) {
    if (i == 0) return vec4(-0.62, 0.3, 1.0, 0.4);
    if (i == 1) return vec4(-0.2, 0.3, 0.82, 0.29);
    if (i == 2) return vec4(0.2, 0.28, 0.64, 0.18);
    return vec4(0.56, 0.26, 0.45, 0.03);
}

float branches(vec3 p) {
    float angle = atan(p.z, p.x);
    float d = 1e3;
    for (int i = 0; i < TIERS; i++) {
        vec4 t = tier(i);
        vec3 q = p - vec3(0.0, t.x, 0.0);
        // Fodros also szel es agak: a karakterracson tuleveles textura.
        float ruffle = 0.035 * sin(angle * 11.0 + float(i) * 1.3) * smoothstep(t.y, -t.y, q.y);
        d = min(d, (cappedCone(q, t.y, t.z, t.w) + ruffle) * 0.8);
    }
    return d;
}

float trunk(vec3 p) {
    vec2 q = vec2(length(p.xz) - 0.15, abs(p.y + 1.06) - 0.17);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0));
}

// Gombok szintenkent egy korben, a kup also feleben.
float baubles(vec3 p, out float material) {
    float d = 1e3;
    material = RED;
    float radius = length(p.xz);
    float angle = atan(p.z, p.x);
    for (int i = 0; i < TIERS; i++) {
        vec4 t = tier(i);
        float count = 8.0 - float(i) * 1.5;
        count = floor(count);
        float sector = TAU / count;
        float a = angle + float(i) * 0.6;
        float index = floor(a / sector + 0.5);
        float local = a - index * sector;
        float y = t.x - t.y * 0.45;
        float r = mix(t.z, t.w, 0.275) + 0.04;
        vec3 q = vec3(radius * cos(local) - r, p.y - y, radius * sin(local));
        float b = length(q) - 0.085;
        if (b < d) {
            d = b;
            material = mod(index + float(i), 2.0) < 0.5 ? RED : GOLD;
        }
    }
    return d;
}

float star2d(vec2 p, float r, float inner) {
    // iq: otagu csillag.
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = inner * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float topStar(vec3 p) {
    vec3 q = p - vec3(0.0, 0.97, 0.0);
    q.xz = rotation(-treeSpin) * q.xz;
    float d2 = star2d(q.xy, 0.17, 0.42);
    vec2 w = vec2(d2, abs(q.z) - 0.035);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - 0.02;
}

float map(vec3 p) {
    float material;
    float d = min(branches(p), trunk(p));
    d = min(d, baubles(p, material));
    return min(d, topStar(p));
}

float materialAt(vec3 p) {
    float material;
    float best = branches(p);
    float result = TREE;
    float t = trunk(p);
    if (t < best) { best = t; result = TRUNK; }
    float b = baubles(p, material);
    if (b < best) { best = b; result = material; }
    if (topStar(p) < best) result = GOLD;
    return result;
}

// Hobuckak a kepernyo aljan: alacsony, lassan valtozo dombok, a tetejukon
// egy vonallal. Visszaad: tonus (0 ha nincs ho) es a karakter.
vec2 snowBank(vec2 uv) {
    vec2 cell = gridCell(uv);
    float x = cell.x / gridSize.x;
    float height = floor(2.6 + 1.3 * sin(x * 9.0 + seed * 5.0) + 0.8 * sin(x * 23.0 + 1.7));
    float fromBottom = gridSize.y - cell.y;
    if (fromBottom > height) return vec2(0.0);
    if (fromBottom > height - 1.0) return vec2(0.32, GLYPH_UNDERLINE);
    return vec2(0.2, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;
    treeSpin = t * 0.22;

    View view;
    view.drift = vec2(0.34, 0.03);
    view.spinA = treeSpin;
    view.spinB = 0.0;
    // Kisse felulrol: latszanak a szintek.
    view.tilt = -0.36;
    view.scale = 0.88;

    Hit hit = renderObject(uv, view);
    if (hit.hit) {
        float tone = hit.tone;
        if (hit.material == GOLD && hit.p.y > 0.78) {
            // A csillag vilagit.
            tone = max(tone, 0.82);
        } else if (hit.material == RED || hit.material == GOLD) {
            // A gombok lassan, egymastol fuggetlenul csillannak.
            tone = max(tone, 0.5 + 0.18 * sin(time * 0.9 + hit.p.y * 9.0 + atan(hit.p.z, hit.p.x) * 3.0));
        }
        fragColor = surface(tone, hit.material, hit.depth);
        return;
    }

    vec2 bank = snowBank(uv);
    if (bank.x > 0.0) {
        fragColor = sprite(bank.y, bank.x, SNOW);
        return;
    }
    vec2 flake = snowfall(uv, 0.018);
    fragColor = flake.x > 0.0 ? sprite(flake.y, flake.x, SNOW) : backdrop(0.0, SNOW);
}
