#version 440
#extension GL_GOOGLE_include_directive : require
// Husvet: forgo, himes tojas cikk-cakk savokkal es pottyokkel; hullo sziromok,
// alul szelben hajlo fu.
// Anyag: 0-3 = a tojas savjai, 4 = pottyok es sziromok, 5 = fu.

#include "common.glsl"

const float DOTS = 4.0;
const float PETAL = 4.0;
const float GRASS = 5.0;

// A tojas: also fele szelesebb, a teteje keskenyebb ellipszoid (iq kozelites).
float map(vec3 p) {
    float width = 0.84 - 0.1 * clamp(p.y, -1.2, 1.2);
    vec3 r = vec3(width, 1.18, width);
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / k1 * 0.85;
}

// A minta: x = anyag, y = tonus-szorzo. A savok kozott sotet cikk-cakk
// varrat, minden masodik savban egy sor feher potty.
vec2 pattern(vec3 p) {
    float angle = atan(p.z, p.x);
    float zigzag = abs(fract(angle * 9.0 / TAU) * 2.0 - 1.0);
    float v = p.y * 2.4 + 0.34 * zigzag + 10.0;
    float band = floor(v);
    float local = fract(v);
    if (local < 0.13) return vec2(mod(band, 4.0), 0.3);
    vec2 spot = vec2((fract(angle * 12.0 / TAU) - 0.5) * 1.1, local - 0.56);
    if (mod(band, 2.0) < 0.5 && length(spot) < 0.2) return vec2(DOTS, 1.15);
    return vec2(mod(band, 4.0), 1.0);
}

float materialAt(vec3 p) {
    return pattern(p).x;
}

// Fu a kepernyo aljan: oszloponkent mas magassag, a szel hullamban hajlitja.
vec2 grass(vec2 uv) {
    vec2 cell = gridCell(uv);
    float fromBottom = gridSize.y - cell.y;
    float height = 1.0 + floor(hash(vec2(cell.x * 0.137, 3.1)) * 3.0);
    if (fromBottom > height + 0.5) return vec2(0.0);
    float wind = sin(time * 0.6 - cell.x * 0.11);
    float glyph = wind > 0.35 ? 14.0 : (wind < -0.35 ? 16.0 : 13.0);
    // Itt-ott egy virag a fu tetejen.
    if (fromBottom > height - 0.5 && hash(vec2(cell.x * 0.071, 9.7)) > 0.9) return vec2(0.5, 8.0);
    return vec2(0.3 + 0.05 * height, glyph);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = time + seed * 40.0;

    View view;
    view.drift = vec2(0.38, 0.06);
    view.spinA = t * 0.2;
    // Enyhen billeg, mint egy asztalon ringo tojas.
    view.spinB = sin(t * 0.31) * 0.12;
    view.tilt = -0.12;
    view.scale = 0.95;

    Hit hit = renderObject(uv, view);
    if (hit.hit) {
        fragColor = surface(hit.tone * pattern(hit.p).y, hit.material, hit.depth);
        return;
    }

    vec2 blade = grass(uv);
    if (blade.x > 0.0) {
        bool flower = blade.y == 8.0;
        fragColor = sprite(blade.y, blade.x, flower ? 2.0 : GRASS);
        return;
    }
    vec2 petal = snowfall(uv, 0.007);
    fragColor = petal.x > 0.0 ? sprite(petal.y, petal.x, PETAL) : backdrop(0.0, PETAL);
}
