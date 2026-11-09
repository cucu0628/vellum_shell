#version 440
#extension GL_GOOGLE_include_directive : require
// Monitorokon atnyulo jelenet: egyetlen kep az osszes monitort befoglalo
// vasznon. A gyurus bolygo a vaszon kozepen all (ket monitornal pont a
// hataron), a hold korbejarja, egy ustokos atrepul az egeszen, a csillagmezo
// lassan sodrodik. Minden monitor ugyanazt az idot es koordinatat latja, ezert
// a hataron a kep folytonos.
// Anyag: 0 = bolygo, 1 = gyuru, 2 = hold, 3 = csillagok, 4 = ustokos.

#include "common.glsl"

const float PLANET = 0.0;
const float RING = 1.0;
const float MOON = 2.0;
const float STARS = 3.0;
const float COMET = 4.0;

// A rendszer dolese a kep sikjaban.
const float ROLL = 0.32;
const float MOON_ORBIT = 3.6;

vec3 moonCentre = vec3(0.0);

float planet(vec3 p) {
    return length(p) - 1.0;
}

// Lapos gyuru a bolygo egyenliti sikjaban, a Cassini-reessel.
float ring(vec3 p) {
    float r = length(p.xz);
    float band = abs(r - 1.78) - 0.42;
    band = max(band, -(abs(r - 1.9) - 0.04));
    return max(band, abs(p.y) - 0.012);
}

float moon(vec3 p) {
    return length(p - moonCentre) - 0.3;
}

vec3 tilted(vec3 p) {
    p.xy = rotation(ROLL) * p.xy;
    return p;
}

float map(vec3 p) {
    vec3 q = tilted(p);
    return min(min(planet(q), ring(q)), moon(q));
}

float materialAt(vec3 p) {
    vec3 q = tilted(p);
    float best = planet(q);
    float result = PLANET;
    float r = ring(q);
    if (r < best) { best = r; result = RING; }
    if (moon(q) < best) result = MOON;
    return result;
}

void main() {
    vec2 uv = qt_TexCoord0;
    // A kozos vaszon pontja; minden ebbol szamol, nem a monitor sajat uv-jebol.
    vec2 point = canvasPoint(uv);
    vec2 centre = canvasSize * 0.5;
    float unit = canvasSize.y * 0.5;
    vec2 ndc = (point - centre) / unit;
    ndc.y = -ndc.y;
    // Egy karaktercella logikai pixelben: a vaszon racsa igy monitorokon at is
    // egyben van.
    vec2 cellPixels = screenSize / gridSize;
    vec2 cell = floor(point / cellPixels);

    // A hold a gyuru sikjaban kering; a pozitiv z a bolygo mogotti fel.
    float orbit = time * 0.11;
    moonCentre = vec3(cos(orbit) * MOON_ORBIT, 0.0, sin(orbit) * MOON_ORBIT);

    marchNear = 0.4;
    marchFar = 8.0;

    View view;
    view.drift = vec2(0.0);
    view.spinA = 0.0;
    view.spinB = 0.0;
    // Kisse felulrol: a gyuru ellipszisnek latszik.
    view.tilt = -0.27;
    view.scale = 0.74;

    // Nagyon lassu vandorlas, hogy semmi ne egjen be; minden monitoron ugyanaz.
    ndc -= vec2(sin(time * 0.013) * 0.12, sin(time * 0.017) * 0.04);

    Hit hit = renderObjectAt(ndc, view);
    if (hit.hit) {
        float tone = hit.tone;
        if (hit.material == PLANET) {
            // Felhosavok a szelesseg szerint, lassan aramolva.
            vec3 q = tilted(hit.p);
            float band = sin(q.y * 11.0 + sin(atan(q.z, q.x) * 3.0 + time * 0.05) * 0.4);
            tone *= 0.82 + 0.18 * band;
        } else if (hit.material == RING) {
            // A gyuru ket oldala ugyanugy fenyes, a fenyirany nem szamit.
            vec3 q = tilted(hit.p);
            float r = length(q.xz);
            tone = 0.36 + 0.22 * sin(r * 26.0) * 0.5 + 0.22 * hit.depth;
        }
        fragColor = surface(tone, hit.material, hit.depth);
        return;
    }

    // Ustokos: kb. 40 masodpercenkent atrepul az egesz vasznon, balrol jobbra
    // enyhen lefele; a csova mogotte halvanyul.
    float columns = canvasSize.x / cellPixels.x;
    float rows = canvasSize.y / cellPixels.y;
    float period = 40.0;
    float pass = floor(time / period);
    float travel = fract(time / period) * (columns + 120.0) - 60.0;
    float startRow = rows * (0.12 + 0.3 * hash(vec2(pass, 3.7)));
    float slope = 0.12;
    float along = travel - cell.x;
    float pathRow = floor(startRow + slope * cell.x);
    if (cell.y == pathRow && along >= 0.0 && along < 46.0) {
        float glyph = along < 1.0 ? 12.0 : (along < 4.0 ? GLYPH_DOUBLE : (along < 22.0 ? GLYPH_DASH : 1.0));
        fragColor = sprite(glyph, 0.55 - 0.009 * along, COMET);
        return;
    }

    // Csillagmezo a kozos racson, lassan balra sodrodva: a hataron at is.
    vec2 starCell = floor(cell + vec2(time * 0.25, 0.0));
    float h = hash(starCell * 0.0137 + 0.71);
    if (h > 0.985) {
        float twinkle = 0.5 + 0.5 * sin(time * (0.5 + fract(h * 53.0)) + h * 211.0);
        bool bright = fract(h * 977.0) > 0.85;
        fragColor = sprite(bright ? GLYPH_STAR : 1.0, 0.18 + 0.2 * twinkle, STARS);
        return;
    }
    fragColor = backdrop(0.0, STARS);
}
