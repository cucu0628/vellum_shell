#version 440
#extension GL_GOOGLE_include_directive : require
// Nyar: naplemente a tenger folott. A nap a horizontra ul, a vizen hullamok es
// a nap csillogo csikja, az egen nehany felhocsik es siraly.
// Anyag: 0 = nap, 1 = tenger, 2 = hullamtaraj, 3 = csillogas, 4 = felho, siraly.

#include "common.glsl"

const float SUN = 0.0;
const float SEA = 1.0;
const float CREST = 2.0;
const float GLITTER = 3.0;
const float SKY = 4.0;

// Ebben a jelenetben nincs 3D forma; a kozos resz megis igenyli.
float map(vec3 p) {
    return 1e3;
}

float materialAt(vec3 p) {
    return SUN;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 cell = gridCell(uv);
    float shape = cellShape();
    float t = time + seed * 40.0;

    // Sor-egysegben: x = oszlop * cellaszelesseg, igy a nap kerek.
    vec2 pos = vec2((cell.x + 0.5) * shape, cell.y + 0.5);
    float width = gridSize.x * shape;
    float horizon = floor(gridSize.y * 0.56);
    // A nap nagyon lassan vandorol, hogy semmi ne egjen be.
    vec2 sun = vec2(width * (0.5 + 0.22 * sin(t * 0.011)), horizon - 4.0);
    float sunRadius = gridSize.y * 0.2;

    if (cell.y < horizon) {
        // Felhocsikok: hosszu, vekony, lassan uszo savok, a nap elott is.
        for (int i = 0; i < 3; i++) {
            float f = float(i);
            float row = floor(horizon * (0.18 + 0.27 * f + 0.03 * f * f));
            float span = 18.0 + 10.0 * f;
            float start = mod(t * (0.35 + 0.12 * f) + f * 71.0, width + span * 2.0) - span;
            if (cell.y == row && pos.x > start && pos.x < start + span) {
                float edge = min(pos.x - start, start + span - pos.x);
                fragColor = sprite(edge < 2.0 ? GLYPH_DASH : GLYPH_DOUBLE, 0.3, SKY);
                return;
            }
        }
        // Siralyok: egy-egy v, lassan lebegve.
        for (int i = 0; i < 3; i++) {
            float f = float(i);
            float x = floor(mod(t * (1.1 + 0.4 * f) + f * 53.0, gridSize.x + 20.0) - 10.0);
            float y = floor(horizon * (0.18 + 0.17 * f) + 2.0 * sin(t * (0.3 + 0.1 * f) + f * 2.0));
            if (cell.x == x && cell.y == y) {
                fragColor = sprite(GLYPH_BIRD, 0.35, SKY);
                return;
            }
        }
        // A nap korong: kozepen a legvilagosabb.
        float d = length(pos - sun);
        if (d < sunRadius) {
            float core = 1.0 - d / sunRadius;
            float tone = 0.55 + 0.4 * core * core;
            fragColor = surface(tone, SUN, 0.8);
            return;
        }
        fragColor = backdrop(dust(uv) * 0.8, SKY);
        return;
    }

    // Tenger: a horizont kozeleben surubb a hullam (perspektiva). A fazis a
    // sor logaritmusa szerint no, igy kozel par soros, tavol egysoros a taraj;
    // a taraj vizszintesen rovid szakaszokra torik.
    float k = cell.y - horizon + 1.0;
    float far = clamp(1.0 - k / (gridSize.y - horizon), 0.0, 1.0);
    float across = (pos.x - sun.x) * 12.0 / k;
    float along = 40.0 * log(k);
    float wave = sin(across * 0.9 + along - time * 0.55)
        + 0.6 * sin(-across * 0.6 + along * 1.37 - time * 0.8 + 1.3)
        + 0.35 * sin(across * 2.3 + along * 0.5 + time * 0.4);

    // A nap csikja a vizen: kozel szelesebb, a hullamok szaggatjak.
    float glitterWidth = sunRadius * 0.4 + k * 0.3;
    float offset = abs(pos.x - sun.x) / glitterWidth;
    if (offset < 1.0 && wave > 0.15 + 0.7 * offset) {
        float glyph = wave > 1.1 ? GLYPH_DOUBLE : GLYPH_DASH;
        fragColor = sprite(glyph, 0.3 + 0.4 * (1.0 - offset), GLITTER);
        return;
    }

    // A tavoli sorokban ritkabb taraj, kulonben a horizont egy tomb lenne.
    float threshold = 1.05 + 0.45 * far;
    if (wave > threshold) {
        fragColor = sprite(GLYPH_WAVE, 0.32 + 0.18 * (1.0 - far), CREST);
        return;
    }
    if (wave > threshold - 0.8 && hash(cell + floor(time * 0.5)) > 0.8) {
        fragColor = backdrop(0.12, SEA);
        return;
    }
    fragColor = backdrop(0.0, SEA);
}
