#version 440
// Az inditokepernyo papirja. Ket front, ugyanazzal a szabalytalan (fbm zaj)
// peremmel, mint a hatterkep tus-atmenete (core/shaders/wallpaper-ink.frag):
//
//   spread: a papir tuscseppkent terul szet a feketen, az origobol kifele;
//   open:   a papir az origobol kifele felszakad, alatta a kesz asztal.
//
// Mindket front mogott keskeny, akcentus-arnyalatu "nedves" sav fut, ami a
// mozgas vegere felszarad. Textura nincs: a kimenet a papir szine es alfaja.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float spread;
    float open;
    float aspect;
    float seed;
    vec2 origin;
    vec4 paperColor;
    vec4 rimColor;
};

const float NOISE_AMOUNT = 0.2;
const float FIBRE_AMOUNT = 0.025;
const float FEATHER = 0.03;
const float RIM_WIDTH = 0.08;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amplitude = 0.5;
    for (int octave = 0; octave < 5; octave++) {
        sum += amplitude * valueNoise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        amplitude *= 0.5;
    }
    return sum;
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec2 scaleVec = vec2(aspect, 1.0);
    vec2 delta = (uv - origin) * scaleVec;
    vec2 corner = max(origin, 1.0 - origin) * scaleVec;
    float dist = length(delta) / length(corner);

    float grain = fbm(uv * scaleVec * 3.2 + seed * 7.13);
    float fibre = fbm(uv * scaleVec * 14.0 - seed * 3.7);
    float shaped = dist + (grain - 0.5) * NOISE_AMOUNT * 2.0 + (fibre - 0.5) * FIBRE_AMOUNT * 2.0;

    // A frontok a zaj szelsoertekein is tulfutnak: 0-nal es 1-nel pontosan
    // ures, illetve teljes a lap.
    float margin = NOISE_AMOUNT + FIBRE_AMOUNT + FEATHER;
    float spreadFront = mix(-margin, 1.0 + margin, spread);
    float openFront = mix(-margin, 1.0 + margin, open);

    float covered = 1.0 - smoothstep(spreadFront - FEATHER, spreadFront + FEATHER, shaped);
    float torn = 1.0 - smoothstep(openFront - FEATHER, openFront + FEATHER, shaped);
    float alpha = covered * (1.0 - torn);

    // Nedves perem a terulo front mogott (befele) es a szakado front elott
    // (kifele, a meg megmaradt papiron).
    float behindSpread = clamp((spreadFront - shaped) / RIM_WIDTH, 0.0, 1.0);
    float spreadRim = covered * (1.0 - behindSpread) * (1.0 - spread * spread);
    float aheadOpen = clamp((shaped - openFront) / (RIM_WIDTH * 1.4), 0.0, 1.0);
    float openRim = (1.0 - torn) * (1.0 - aheadOpen) * smoothstep(0.0, 0.08, open) * (1.0 - open * open);

    vec3 color = paperColor.rgb;
    color = mix(color, rimColor.rgb, 0.22 * spreadRim);
    color = mix(color, rimColor.rgb, 0.5 * openRim);

    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
