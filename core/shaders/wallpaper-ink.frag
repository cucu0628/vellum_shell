#version 440
// Hatterkep-atmenet: az uj kep tuscseppkent terul szet a regin. A perem
// szabalytalan (fbm zaj), es egy keskeny, sotetebb "nedves" savot hagy maga
// utan, ami a terules vegere felszarad. Az uj kep kozben enyhen
// visszaskalazodik, a regi alig eszrevehetoen tavolodik.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    float seed;
    vec2 origin;
    // A ket kep sajat aranya: az Image textura a teljes kep, a
    // PreserveAspectCrop vagast itt kell elvegezni.
    float fromAspect;
    float toAspect;
};

layout(binding = 1) uniform sampler2D fromTexture;
layout(binding = 2) uniform sampler2D toTexture;

const float NOISE_AMOUNT = 0.22;
const float FIBRE_AMOUNT = 0.02;
const float FEATHER = 0.035;
const float RIM_WIDTH = 0.09;

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

// PreserveAspectCrop kozepre igazitva, plusz egy kozeppontos nagyitas.
vec2 cover(vec2 uv, float imageAspect, float scale) {
    vec2 centered = (uv - 0.5) / scale;
    if (imageAspect > aspect) centered.x *= aspect / imageAspect;
    else centered.y *= imageAspect / aspect;
    return centered + 0.5;
}

void main() {
    vec2 uv = qt_TexCoord0;

    // Tavolsag az origotol, a kepernyo aranyaval korrigalva, ugy normalva, hogy
    // a legtavolabbi sarok is 1 legyen.
    vec2 scaleVec = vec2(aspect, 1.0);
    vec2 delta = (uv - origin) * scaleVec;
    vec2 corner = max(origin, 1.0 - origin) * scaleVec;
    float dist = length(delta) / length(corner);

    // Szabalytalan perem: a zaj a kepernyon all, nem forog az origoval, igy
    // a terulo folt "szalai" a papir rostjait kovetik.
    float grain = fbm(uv * scaleVec * 3.2 + seed * 7.13);
    float fibre = fbm(uv * scaleVec * 14.0 - seed * 3.7);
    float shaped = dist + (grain - 0.5) * NOISE_AMOUNT * 2.0 + (fibre - 0.5) * FIBRE_AMOUNT * 2.0;

    // A front a zaj szelsoertekein is tulfut, igy 0-nal pontosan a regi, 1-nel
    // pontosan az uj kep latszik: a szerepcserekor nincs ugras.
    float margin = NOISE_AMOUNT + FIBRE_AMOUNT + FEATHER;
    float front = mix(-margin, 1.0 + margin, progress);
    float reveal = 1.0 - smoothstep(front - FEATHER, front + FEATHER, shaped);

    vec4 fromColor = texture(fromTexture, cover(uv, fromAspect, 1.0 + 0.02 * progress));
    vec4 toColor = texture(toTexture, cover(uv, toAspect, 1.035 - 0.035 * progress));

    // Nedves perem: a front mogotti keskeny sav sotetebb, a vegere felszarad.
    float behind = clamp((front - shaped) / RIM_WIDTH, 0.0, 1.0);
    float rim = reveal * (1.0 - behind) * (1.0 - progress * progress);
    toColor.rgb *= 1.0 - 0.28 * rim;

    fragColor = mix(fromColor, toColor, reveal) * qt_Opacity;
}
