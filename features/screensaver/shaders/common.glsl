// A jelenet-shaderek (shapes.frag, christmas.frag, ...) kozos resze. Nem
// onallo shader: a build-shaders csak a .frag fajlokat forditja, ez #include-dal
// kerul beljebb.
//
// Minden jelenet ugyanazt az adatot adja a masodik menetnek (glyphs.frag):
//   r = tonus (0 sotet - 1 vilagos)
//   g = anyag, a paletta indexe: (index + 0.5) / 8
//   b = melyseg a formaig (0.3 tavol - 1 kozel); 0 = hatter, nincs kontur
//   a = 1, vagy egy kotelezo karakter az atlaszbol: (index + 1) / 255

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float aspect;
    float seed;
    vec2 gridSize;
    // A monitor helye es merete az osszes monitort befoglalo vasznon, es a
    // vaszon merete (logikai pixel). Csak a monitorokon atnyulo jelenet
    // (orbit.frag) hasznalja; a tobbi monitoronkent kulon kepet rajzol.
    vec2 screenOrigin;
    vec2 screenSize;
    vec2 canvasSize;
};

const float TAU = 6.28318530718;

// Kotelezo karakterek indexe az atlaszban (AsciiScene.glyphs): a ramp 13, a
// konturok 5 karakter, utanuk jon az AsciiScene.extras.
const float GLYPH_STAR = 5.0;
const float GLYPH_DASH = 15.0;
const float GLYPH_UNDERLINE = 17.0;
const float GLYPH_BIRD = 18.0;
const float GLYPH_WAVE = 19.0;
const float GLYPH_DOUBLE = 20.0;
const float GLYPH_LEAF = 21.0;
const float GLYPH_WING = 22.0;
const float GLYPH_HEART_LEFT = 23.0;
const float GLYPH_HEART_RIGHT = 24.0;

// Egy cella szelessege a magassagahoz kepest (kb. 0.5). Ezzel a racs
// "sor-egysegben" szamolhato, igy a kor kor marad.
float cellShape() {
    return aspect * gridSize.y / gridSize.x;
}

mat2 rotation(float angle) {
    float s = sin(angle), c = cos(angle);
    return mat2(c, -s, s, c);
}

float smoothMin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec4 surface(float tone, float material, float depth) {
    return vec4(clamp(tone, 0.04, 1.0), (material + 0.5) / 8.0, 0.3 + 0.7 * depth, 1.0);
}

vec4 backdrop(float tone, float material) {
    return vec4(clamp(tone, 0.0, 1.0), (material + 0.5) / 8.0, 0.0, 1.0);
}

// Forma, de kotelezo karakterrel (pl. ablak az epuleten): a kontur nem
// rajzolodik kore, mert a melysege a formae.
vec4 surfaceSprite(float glyph, float tone, float material, float depth) {
    return vec4(clamp(tone, 0.04, 1.0), (material + 0.5) / 8.0, 0.3 + 0.7 * depth, (glyph + 1.0) / 255.0);
}

vec4 sprite(float glyph, float tone, float material) {
    return vec4(clamp(tone, 0.0, 1.0), (material + 0.5) / 8.0, 0.0, (glyph + 1.0) / 255.0);
}

// A karakterracs cellaja; y lefele no, mint a kepernyon.
vec2 gridCell(vec2 uv) {
    return floor(uv * gridSize);
}

// Ritka, lassan pislako por: mozgo hatter, igy semmi nem eg be.
float dust(vec2 uv) {
    vec2 cell = floor(uv * gridSize + vec2(time * 0.33, -time * 0.14)) + seed * 17.0;
    float h = hash(cell * 0.0131);
    if (h < 0.993) return 0.0;
    float twinkle = 0.5 + 0.5 * sin(time * (0.4 + fract(h * 91.0)) + h * 311.0);
    return 0.06 + 0.12 * twinkle * twinkle;
}

// Harom retegu havazas, cellankent lepve. A kozeli pelyhek gyorsabbak es
// fenyesebbek, ettol van melysege. Visszaad: tonus (0 ha nincs pehely) es a
// karakter: a tavoli pont, a kozeli csillag.
vec2 snowfall(vec2 uv, float density) {
    vec2 grid = uv * gridSize;
    vec2 flake = vec2(0.0);
    for (int i = 0; i < 3; i++) {
        float layer = float(i);
        float speed = 0.9 + 0.8 * layer;
        float sway = sin(time * (0.21 + 0.07 * layer) + grid.y * 0.09 + layer * 2.1) * (1.5 + layer);
        vec2 cell = floor(grid + vec2(sway, -time * speed)) + vec2(layer * 71.0, seed * 31.0);
        float h = hash(cell * 0.0173 + layer * 0.31);
        if (h > 1.0 - density * (1.0 - 0.25 * layer))
            flake = vec2(0.2 + 0.14 * layer, layer < 0.5 ? 1.0 : GLYPH_STAR);
    }
    return flake;
}

// A jelenet adja: a forma tavolsaga es az anyaga egy pontban.
float map(vec3 p);
float materialAt(vec3 p);

vec3 normalAt(vec3 p) {
    const vec2 e = vec2(1.0, -1.0) * 0.004;
    return normalize(e.xyy * map(p + e.xyy) + e.yyx * map(p + e.yyx)
        + e.yxy * map(p + e.yxy) + e.xxx * map(p + e.xxx));
}

// Takaras a normal menten: a melyedesek sotetebbek, igy a forma terbeli.
float ambientOcclusion(vec3 p, vec3 n) {
    float occluded = 0.0;
    for (int i = 1; i <= 3; i++) {
        float reach = 0.09 * float(i);
        occluded += max(reach - map(p + n * reach), 0.0) / reach;
    }
    return clamp(1.0 - occluded * 0.5, 0.0, 1.0);
}

// Egy forma a kozepen, lassan vandorolva es forogva. Sorrend: elobb a
// rogzitett doles, aztan a fuggoleges tengely koruli (spinA), vegul a
// vizszintes (spinB) forgas. y felfele no.
struct View {
    vec2 drift;      // vandorlas merteke (x, y)
    float spinA;     // szog a fuggoleges tengely korul
    float spinB;     // szog a vizszintes tengely korul
    float tilt;      // rogzitett elodoles
    float scale;     // nagyitas
};

struct Hit {
    bool hit;
    vec3 p;          // a forma sajat tereben
    vec3 normal;     // nezeti terben
    float tone;
    float depth;
    float material;
};

// A sugar elso es utolso vizsgalt pontja a kameratol (z = -4.1). A messze
// kinyulo jelenet (orbit.frag) tagabbra allitja.
float marchNear = 2.2;
float marchFar = 6.4;

// A ponthoz tartozo hely a kozos vasznon (logikai pixel).
vec2 canvasPoint(vec2 uv) {
    return screenOrigin + uv * screenSize;
}

Hit renderObjectAt(vec2 ndc, View view);

Hit renderObject(vec2 uv, View view) {
    vec2 ndc = (uv - 0.5) * 2.0;
    ndc.x *= aspect;
    ndc.y = -ndc.y;

    float t = time + seed * 40.0;
    ndc -= vec2(sin(t * 0.043) * view.drift.x * aspect, sin(t * 0.067 + 1.3) * view.drift.y);
    return renderObjectAt(ndc, view);
}

// ndc: y felfele no, a kep magassaga -1..1.
Hit renderObjectAt(vec2 ndc, View view) {
    Hit result;
    result.hit = false;
    ndc /= view.scale;

    vec3 origin = vec3(0.0, 0.0, -4.1);
    vec3 dir = normalize(vec3(ndc, 2.5));

    mat2 tilt = rotation(view.tilt);
    mat2 spinA = rotation(view.spinA);
    mat2 spinB = rotation(view.spinB);

    float travelled = marchNear;
    vec3 p = vec3(0.0);
    for (int i = 0; i < 80; i++) {
        p = origin + dir * travelled;
        p.yz = tilt * p.yz;
        p.xz = spinA * p.xz;
        p.yz = spinB * p.yz;
        float d = map(p);
        if (d < 0.0035) {
            result.hit = true;
            break;
        }
        travelled += d;
        if (travelled > marchFar) break;
    }
    if (!result.hit) return result;

    vec3 n = normalAt(p);
    float occlusion = ambientOcclusion(p, n);

    // A normalt visszaforgatjuk nezeti terbe: a feny all, a forma forog.
    n.yz = n.yz * spinB;
    n.xz = n.xz * spinA;
    n.yz = n.yz * tilt;

    vec3 light = normalize(vec3(-0.55, 0.7, -0.62));
    vec3 fill = normalize(vec3(0.7, -0.45, -0.5));
    float diffuse = max(dot(n, light), 0.0);
    float soft = max(dot(n, fill), 0.0);
    float rim = pow(1.0 - max(dot(n, -dir), 0.0), 3.0);
    float highlight = pow(max(dot(n, normalize(light - dir)), 0.0), 18.0);

    float tone = (0.13 + 0.62 * diffuse + 0.17 * soft) * occlusion + 0.1 * rim + 0.2 * highlight;
    // A kozelebbi resz fenyesebb: ettol latszik, mi van elol.
    float depth = 1.0 - clamp((travelled - 2.6) / 2.9, 0.0, 1.0);
    tone *= mix(0.72, 1.08, depth);

    result.p = p;
    result.normal = n;
    result.tone = tone;
    result.depth = depth;
    result.material = materialAt(p);
    return result;
}
