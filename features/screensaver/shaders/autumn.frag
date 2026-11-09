#version 440
#extension GL_GOOGLE_include_directive : require
// Osz: faragott, belulrol vilagito tok, hullo levelek, ket denever.
// Anyag: 0 = tok, 1 = szar, 2 = belso feny, 3 = levelek, 4 = denever.

#include "common.glsl"

const float PUMPKIN = 0.0;
const float STEM = 1.0;
const float GLOW = 2.0;
const float LEAF = 3.0;
const float BAT = 4.0;

const float SHELL = 0.07;

// A tok kulso felulete: bordazott, lapitott gomb.
float body(vec3 p) {
    float angle = atan(p.z, p.x);
    float groove = 1.0 - smoothstep(0.0, 0.45, abs(sin(angle * 4.0)));
    float width = 1.08 * (1.0 - 0.07 * groove);
    vec3 r = vec3(width, 0.84, width);
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1;
}

// iq: egyenlo oldalu haromszog, csucsa felfele.
float triangle(vec2 p, float r) {
    const float k = 1.7320508;
    p.x = abs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}

float box(vec2 p, vec2 size) {
    vec2 d = abs(p) - size;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Az arc a nezo feloli (negativ z) oldalon: ket szem, orr, vigyor fogakkal.
float face(vec2 p) {
    vec2 eye = vec2(abs(p.x) - 0.38, p.y - 0.24);
    float d = triangle(eye, 0.2);
    d = min(d, triangle(p - vec2(0.0, -0.01), 0.1));
    float mouth = max(length(p - vec2(0.0, 0.1)) - 0.68, -(length(p - vec2(0.0, 0.38)) - 0.72));
    vec2 tooth = vec2(abs(p.x) - 0.2, p.y + 0.38);
    mouth = max(mouth, -box(tooth, vec2(0.065, 0.075)));
    return min(d, mouth);
}

float carve(vec3 p) {
    return max(face(p.xy), p.z);
}

float stem(vec3 p) {
    vec3 q = p - vec3(0.0, 0.8, 0.0);
    q.x -= 0.25 * q.y * q.y;
    vec2 w = vec2(length(q.xz) - 0.09, abs(q.y - 0.12) - 0.16);
    return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - 0.015;
}

float map(vec3 p) {
    float outer = body(p);
    // Ureges: a hej SHELL vastag, az arc atvagja.
    float shell = max(outer, -(outer + SHELL));
    shell = max(shell, -carve(p));
    return min(shell * 0.8, stem(p));
}

float materialAt(vec3 p) {
    if (stem(p) < 0.01) return STEM;
    // A hej belseje es a vagas fala a gyertya fenyet kapja.
    if (body(p) < -0.02) return GLOW;
    return PUMPKIN;
}

// Hullo levelek: lassabbak es jobban lengenek, mint a ho.
vec2 leaves(vec2 uv) {
    vec2 grid = uv * gridSize;
    vec2 result = vec2(0.0);
    for (int i = 0; i < 2; i++) {
        float layer = float(i);
        float sway = sin(time * 0.35 + grid.y * 0.13 + layer * 1.7) * (3.0 + 2.0 * layer);
        vec2 cell = floor(grid + vec2(sway + time * 0.6, -time * (0.6 + 0.5 * layer))) + vec2(layer * 53.0, seed * 29.0);
        float h = hash(cell * 0.0211 + layer * 0.41);
        if (h > 1.0 - 0.0035 * (1.0 + layer))
            result = vec2(0.3 + 0.14 * layer, fract(h * 977.0) > 0.5 ? GLYPH_LEAF : GLYPH_STAR);
    }
    return result;
}

// Ket denever (^v^) a felso reszen, lassan atrepulve; a szarny csapkod.
vec2 bats(vec2 uv) {
    vec2 cell = gridCell(uv);
    for (int i = 0; i < 2; i++) {
        float f = float(i);
        float span = gridSize.x + 40.0;
        float x = floor(mod(time * (2.4 + 0.9 * f) + f * 97.0 + seed * 61.0, span) - 20.0);
        float y = floor(gridSize.y * (0.14 + 0.12 * f) + 3.0 * sin(time * (0.5 + 0.2 * f) + f));
        if (cell.y != y) continue;
        float dx = cell.x - x;
        bool up = fract(time * 1.6 + f * 0.5) < 0.5;
        if (dx == 0.0) return vec2(0.4, GLYPH_BIRD);
        if (abs(dx) == 1.0) return vec2(0.4, up ? GLYPH_WING : GLYPH_DASH);
    }
    return vec2(0.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;

    View view;
    view.drift = vec2(0.36, 0.06);
    // Ide-oda fordul, de az arc mindig latszik.
    view.spinA = sin(t * 0.16) * 0.5;
    view.spinB = sin(t * 0.12) * 0.08;
    view.tilt = -0.18;
    view.scale = 0.9;

    Hit hit = renderObject(uv, view);
    if (hit.hit) {
        float tone = hit.tone;
        // Gyertyafeny: lassan, kicsit pislakol.
        if (hit.material == GLOW) tone = 0.8 + 0.08 * sin(time * 2.3) * sin(time * 1.3 + 1.0);
        fragColor = surface(tone, hit.material, hit.depth);
        return;
    }

    vec2 bat = bats(uv);
    if (bat.x > 0.0) {
        fragColor = sprite(bat.y, bat.x, BAT);
        return;
    }
    vec2 leaf = leaves(uv);
    fragColor = leaf.x > 0.0 ? sprite(leaf.y, leaf.x, LEAF) : backdrop(0.0, LEAF);
}
