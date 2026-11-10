#version 440
#extension GL_GOOGLE_include_directive : require
// Szilveszter: tuzijatek egy varos folott. A raketa felszall, szetrobban, a
// szikrak a repules iranyaba mutato karakterrel huznak csikot es lehullanak.
// Anyag: 0 = epuletek, 1 = ablakok, 2-5 = a tuzijatek szinei.

#include "common.glsl"

const float BUILDING = 0.0;
const float WINDOW = 1.0;
const int BURSTS = 4;
const float SPARKS = 26.0;
const float PERIOD = 6.5;
const float LAUNCH = 1.1;

// Ebben a jelenetben nincs 3D forma; a kozos resz megis igenyli.
float map(vec3 p) {
    return 1e3;
}

float materialAt(vec3 p) {
    return BUILDING;
}

// A repules iranyabol kontur-karakter: - \ | / (y lefele no).
float streakGlyph(vec2 direction) {
    float angle = atan(direction.y, direction.x);
    float sector = mod(floor(angle / 0.78539816 + 0.5), 4.0);
    if (sector < 0.5) return 15.0;
    if (sector < 1.5) return 16.0;
    if (sector < 2.5) return 13.0;
    return 14.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 cell = gridCell(uv);
    float shape = cellShape();
    vec2 pos = vec2((cell.x + 0.5) * shape, cell.y + 0.5);
    float width = gridSize.x * shape;

    // Varos: kulonbozo magassagu es melysegu hazak, igy a hatarukon kontur van.
    float street = cell.x + floor(seed * 37.0);
    float block = floor(street / 9.0);
    float tall = hash(vec2(block, 4.2));
    float height = 3.0 + floor(tall * tall * 14.0);
    float fromBottom = gridSize.y - cell.y;
    if (fromBottom <= height) {
        float depth = 0.35 + 0.4 * hash(vec2(block, 8.9));
        float local = mod(street, 9.0);
        bool windowCell = local > 1.0 && local < 8.0 && mod(local, 2.0) < 0.5
            && mod(fromBottom, 2.0) < 0.5 && fromBottom < height - 0.5;
        // Az ablakok lassan, egyenkent kapcsolnak.
        float lit = hash(cell * 0.37 + floor(time / 23.0 + hash(cell) * 5.0));
        if (windowCell && lit > 0.55) {
            fragColor = surfaceSprite(2.0, 0.55, WINDOW, depth);
            return;
        }
        fragColor = surface(0.04, BUILDING, depth);
        return;
    }

    for (int i = 0; i < BURSTS; i++) {
        float f = float(i);
        float clock = time + f * PERIOD / float(BURSTS) + seed * 13.0;
        float cycle = floor(clock / PERIOD);
        float age = mod(clock, PERIOD);
        vec2 key = vec2(cycle, f * 7.3);
        vec2 burst = vec2(width * (0.12 + 0.76 * hash(key + 0.11)), gridSize.y * (0.14 + 0.26 * hash(key + 0.53)));
        float color = 2.0 + floor(hash(key + 0.97) * 4.0);

        if (age < LAUNCH) {
            // Raketa: alulrol a robbanas helyere, mogotte par pont.
            float progress = age / LAUNCH;
            float y = mix(gridSize.y - 1.0, burst.y, 1.0 - (1.0 - progress) * (1.0 - progress));
            if (abs(pos.x - burst.x) < shape * 0.5) {
                if (abs(pos.y - y) < 0.5) {
                    fragColor = sprite(13.0, 0.45, color);
                    return;
                }
                if (pos.y > y && pos.y < y + 3.0) {
                    fragColor = sprite(1.0, 0.25, color);
                    return;
                }
            }
            continue;
        }

        float spread = age - LAUNCH;
        float life = PERIOD - LAUNCH - 1.2;
        if (spread > life) continue;
        // A szikrak egy lassulo korben repulnek, kozben lefele huzza oket a gravitacio.
        float reach = 13.0 * (1.0 - exp(-spread * 1.6));
        float fall = 0.9 * spread * spread;
        vec2 rel = pos - (burst + vec2(0.0, fall));
        float radius = length(rel);
        float angle = atan(rel.y, rel.x);
        float index = floor(angle / TAU * SPARKS + 0.5);
        float fade = 1.0 - spread / life;
        for (int j = -1; j <= 1; j++) {
            float sparkIndex = index + float(j);
            float sparkAngle = sparkIndex / SPARKS * TAU;
            float speed = 0.75 + 0.35 * hash(key + vec2(sparkIndex, 2.0));
            float head = reach * speed;
            float tail = head * (0.55 + 0.25 * fade);
            float across = radius * abs(sin(angle - sparkAngle));
            if (across > 0.55 || cos(angle - sparkAngle) < 0.0) continue;
            float along = radius * cos(angle - sparkAngle);
            if (along > head + 0.5 || along < tail) continue;
            vec2 direction = vec2(cos(sparkAngle), sin(sparkAngle));
            // A fej csillag, a csik a repules iranyaba mutat; a vegen csak pont.
            float glyph = along > head - 0.7 ? GLYPH_STAR : streakGlyph(direction);
            if (fade < 0.25) glyph = 1.0;
            fragColor = sprite(glyph, 0.25 + 0.3 * fade, color);
            return;
        }
    }

    fragColor = backdrop(dust(uv) * 0.7, BUILDING);
}
