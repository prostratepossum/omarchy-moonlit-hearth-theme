#version 440
// Moonlit Hearth live background. Works on the wallpaper itself and adds:
// three layers of falling snow, a slowly breathing moon halo, a faint cloud
// veil drifting across the sky, the cabin window(s) glowing like a hearth
// fire, chimney smoke curling away on the wind, and frost glints that twinkle
// on the brightest snow. Positions come from HearthLayer.qml.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;        // seconds, wraps
    float aspect;      // width / height
    float snow;        // snowfall density, 0..1.5
    float smokeOn;     // 1 when the plate has a chimney
    vec4 moon;         // x, y (uv), radius (in uv height units), halo strength
    vec4 win0;         // window rect in uv: x0, y0, x1, y1 (zero = none)
    vec4 win1;
    vec4 chimney;      // x, y (uv) of the chimney top, wind, plume scale
    vec4 glowColor;    // hearth colour
    vec4 moonColor;    // moonlight colour
};

layout(binding = 1) uniform sampler2D source;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), u.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + 11.7; a *= 0.5; }
    return v;
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

// One layer of snow: a flake per cell, falling with a sideways sway.
float snowLayer(vec2 p, float scale, float speed, float size, float seed) {
    // uv.y grows downward, so subtracting time makes the flakes fall.
    vec2 g = p * scale + vec2(time * 0.05 * scale * 0.1, -time * speed);
    g.x += 0.35 * sin(g.y * 0.35 + seed);
    vec2 cell = floor(g);
    float h = hash21(cell + seed);
    if (h > 0.55 * (2.0 - snow)) return 0.0;
    vec2 f = fract(g) - 0.5;
    vec2 off = vec2(0.30 * sin(time * (0.6 + h) + h * 30.0), 0.30 * (hash21(cell + 7.0 + seed) - 0.5));
    float d = length(f - off);
    return smoothstep(size, size * 0.25, d) * (0.55 + 0.45 * h);
}

// Glow of a window rect: soft falloff outside, full inside.
float windowGlow(vec2 uv, vec4 r, out float inside) {
    inside = 0.0;
    if (r.z <= r.x) return 0.0;
    vec2 c = (r.xy + r.zw) * 0.5;
    vec2 hs = (r.zw - r.xy) * 0.5;
    vec2 d = abs(uv - c) - hs;
    float outside = length(max(d, 0.0));
    inside = step(max(d.x, d.y), 0.0);
    return exp(-outside * outside / (0.0009 + hs.x * hs.x * 2.0));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 base = texture(source, uv).rgb;
    vec3 c = base;
    vec2 p = vec2(uv.x * aspect, uv.y);
    float L = luma(base);

    // --- Moon halo: a soft breathing glow and a slow shimmer in the corona.
    if (moon.z > 0.0) {
        vec2 mp = vec2(moon.x * aspect, moon.y);
        float r = length(p - mp) / moon.z;
        float breathe = 0.75 + 0.25 * sin(time * 0.35) + 0.08 * sin(time * 1.1);
        float halo = exp(-max(r - 1.0, 0.0) * 1.6) * smoothstep(0.92, 1.15, r);
        float ang = atan(p.y - mp.y, p.x - mp.x);
        float shimmer = 0.6 + 0.4 * noise(vec2(ang * 3.0, time * 0.25 + r * 2.0));
        c += moonColor.rgb * halo * breathe * shimmer * 0.12 * moon.w;
    }

    // --- Cloud veil: faint moonlit mist drifting slowly left to right over
    // the upper sky, brightening clouds that are already lit.
    float sky = smoothstep(0.62, 0.15, uv.y);
    if (sky > 0.0) {
        float veil = fbm(vec2(p.x * 1.6 - time * 0.012, p.y * 2.4 + time * 0.004));
        veil = smoothstep(0.45, 0.85, veil);
        c += moonColor.rgb * veil * sky * (0.035 + 0.06 * L);
    }

    // --- Hearth windows: a fire flicker inside, warm light spilling out.
    float flick = 0.55 + 0.25 * sin(time * 2.3) + 0.15 * sin(time * 5.7 + 1.1)
                + 0.30 * (noise(vec2(time * 7.0, 3.0)) - 0.5);
    float in0, in1;
    float g0 = windowGlow(uv, win0, in0);
    float g1 = windowGlow(uv, win1, in1);
    float spill = max(g0, g1);
    float inside = max(in0, in1);
    vec3 glow = glowColor.rgb;
    c += glow * spill * flick * 0.10;
    c = mix(c, c * (0.82 + 0.40 * flick), inside * smoothstep(0.25, 0.6, L));

    // --- Chimney smoke: a plume rising and leaning with the wind, curling
    // through domain-warped noise and thinning as it climbs.
    if (smokeOn > 0.5) {
        vec2 cp = vec2(chimney.x * aspect, chimney.y);
        float up = cp.y - p.y;                       // height above the chimney
        if (up > -0.01) {
            float wind = chimney.z;
            float s = chimney.w;
            float cx = cp.x + wind * up * up * 2.2 / s + 0.015 * sin(up * 18.0 / s - time * 0.8);
            float width = 0.010 * s + up * 0.20;
            vec2 q = vec2((p.x - cx) / width, up * 8.0 / s - time * 0.35);
            vec2 warp = vec2(fbm(q * 0.8 + vec2(0.0, time * 0.10)), fbm(q * 0.8 + vec2(4.0, -time * 0.08)));
            float n = fbm(q * vec2(0.9, 1.0) + warp * 1.6);
            float body = exp(-pow((p.x - cx) / width, 2.0) * 1.2);
            float fade = smoothstep(-0.01, 0.02, up) * exp(-up * 3.2 / s);
            float smoke = smoothstep(0.35, 0.75, n) * body * fade;
            c = mix(c, mix(vec3(0.62, 0.70, 0.80), moonColor.rgb, 0.4), smoke * 0.32);
        }
    }

    // --- Frost glints: tiny sparkles that wink on the brightest snow.
    vec2 gg = p * vec2(140.0, 140.0);
    vec2 gc = floor(gg);
    float gh = hash21(gc);
    if (gh > 0.985 && uv.y > 0.45) {
        vec2 f = fract(gg) - 0.5;
        float tw = pow(max(0.0, sin(time * (0.7 + gh * 1.3) + gh * 80.0)), 24.0);
        float star = smoothstep(0.18, 0.0, abs(f.x) * abs(f.y) * 40.0 + length(f) * 0.6);
        c += vec3(0.85, 0.93, 1.0) * star * tw * smoothstep(0.45, 0.75, L) * 0.9;
    }

    // --- Snowfall: far, middle and near layers with parallax.
    if (snow > 0.0) {
        float far = snowLayer(p, 46.0, 0.9, 0.065, 1.0);
        float mid = snowLayer(p, 24.0, 1.1, 0.07, 7.0);
        float near = snowLayer(p, 11.0, 1.35, 0.06, 13.0);
        vec3 flake = vec3(0.90, 0.95, 1.0);
        c = mix(c, flake, clamp(far * 0.35 + mid * 0.55 + near * 0.80, 0.0, 1.0) * min(snow, 1.0));
    }

    fragColor = vec4(c, 1.0) * qt_Opacity;
}
