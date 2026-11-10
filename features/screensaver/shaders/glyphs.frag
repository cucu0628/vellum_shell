#version 440
// Masodik menet: a jelenet-shader adatabol (lasd common.glsl) karakterracs. A
// tonus a ritkatol a suruig tarto karaktersorbol valaszt. Kontur csak ott van,
// ahol a melyseg ugrik (a forma szele, vagy ahol egy resze takar egy masikat);
// a sima felulet fenyvaltozasa nem rajzol vonalat.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 pixelSize;
    vec2 cellSize;
    vec2 gridSize;
    float rampLength;
    float glyphCount;
    float reveal;
    float highlight;
    vec4 backgroundColor;
    vec4 lightColor;
    vec4 palette0;
    vec4 palette1;
    vec4 palette2;
    vec4 palette3;
    vec4 palette4;
    vec4 palette5;
};

layout(binding = 1) uniform sampler2D field;
layout(binding = 2) uniform sampler2D atlas;

const float DEPTH_STEP = 0.14;
// A kontur karakterei a sor vegen; a felso vizszintes szelnek kulon jel van.
const float TOP_EDGE = 4.0;

vec4 fieldAt(vec2 cell) {
    return texture(field, (clamp(cell, vec2(0.0), gridSize - 1.0) + 0.5) / gridSize);
}

float hash(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

vec3 paletteColor(float material) {
    if (material < 0.5) return palette0.rgb;
    if (material < 1.5) return palette1.rgb;
    if (material < 2.5) return palette2.rgb;
    if (material < 3.5) return palette3.rgb;
    if (material < 4.5) return palette4.rgb;
    return palette5.rgb;
}

// Sotettol vilagosig mindig monoton: a sotet vege a hatter es az anyag
// kozott van, igy egy sotet szinu anyag arnyeka sem vilagosabb a kozeptonusnal.
vec3 surfaceInk(vec3 color, float tone) {
    vec3 shade = mix(backgroundColor.rgb, color, 0.5);
    if (tone < 0.45) return mix(shade, color, tone / 0.45);
    return mix(color, mix(color, lightColor.rgb, highlight), (tone - 0.45) / 0.55);
}

// A hatter karakterei (por, ho, hullam): halvanyabbak, csak a legfenyesebbek
// vilagosodnak ki.
vec3 backdropInk(vec3 color, float tone) {
    vec3 base = mix(backgroundColor.rgb, color, 0.6 + 0.4 * clamp(tone * 2.5, 0.0, 1.0));
    return mix(base, lightColor.rgb, highlight * clamp((tone - 0.6) / 0.4, 0.0, 1.0));
}

void main() {
    vec2 pixel = qt_TexCoord0 * pixelSize;
    vec2 cell = floor(pixel / cellSize);
    vec2 inside = fract(pixel / cellSize);

    // Be- es kilepes: a racscellak veletlen sorrendben jelennek meg, kozottuk
    // az asztal latszik.
    if (hash(cell) > reveal) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 here = fieldAt(cell);
    float material = floor(here.g * 8.0);
    float glyph = floor(clamp(here.r, 0.0, 1.0) * (rampLength - 1.0) + 0.5);
    // A jelenet maga is kerhet karaktert (hullam, madar, level).
    if (here.a < 0.998) glyph = floor(here.a * 255.0 + 0.5) - 1.0;

    if (here.b > 0.0) {
        float tl = fieldAt(cell + vec2(-1.0, -1.0)).b;
        float tc = fieldAt(cell + vec2(0.0, -1.0)).b;
        float tr = fieldAt(cell + vec2(1.0, -1.0)).b;
        float cl = fieldAt(cell + vec2(-1.0, 0.0)).b;
        float cr = fieldAt(cell + vec2(1.0, 0.0)).b;
        float bl = fieldAt(cell + vec2(-1.0, 1.0)).b;
        float bc = fieldAt(cell + vec2(0.0, 1.0)).b;
        float br = fieldAt(cell + vec2(1.0, 1.0)).b;
        // A vonal a kozelebbi oldalra kerul, es csak a negy kozvetlen szomszed
        // dont rola, ezert egy cella vastag marad.
        float nearest = min(tc, min(bc, min(cl, cr)));
        if (here.b - nearest > DEPTH_STEP) {
            // Az irany mar mind a nyolc szomszedbol jon (Sobel), igy sima. A
            // gradiens a konturra meroleges, y lefele no; a cella magasabb, mint
            // szeles, ezert pixelre valtva szamolunk.
            vec2 gradient = vec2(tr + 2.0 * cr + br - tl - 2.0 * cl - bl,
                                 bl + 2.0 * bc + br - tl - 2.0 * tc - tr);
            float angle = atan(gradient.y * cellSize.x / cellSize.y, gradient.x);
            float sector = mod(floor(angle / 0.78539816 + 0.5), 4.0);
            // A szektor sorrendje az AsciiScene.edges sorrendje. Felul a forma a
            // cella aljahoz simul, ezert ott a _ a jo vizszintes.
            glyph = rampLength + (sector == 2.0 && gradient.y > 0.0 ? TOP_EDGE : sector);
        }
    }

    float coverage = texture(atlas, vec2((glyph + inside.x) / glyphCount, inside.y)).a;
    vec3 color = paletteColor(material);
    vec3 ink = here.b > 0.0 ? surfaceInk(color, here.r) : backdropInk(color, here.r);
    fragColor = vec4(mix(backgroundColor.rgb, ink, coverage), 1.0) * qt_Opacity;
}
