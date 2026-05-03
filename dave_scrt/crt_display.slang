#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

// --- tuning constants ---
#define CORE_GAIN       1.1   // core brightness multiplier
#define HBLEED_BASE     0.35  // base horizontal bleed factor
#define VBLEED_BASE     0.45  // base vertical bleed factor
#define BLEED_LUMA_GAIN 0.35  // luma-driven bleed boost (0=flat, 1=strong)

// --- mask line multipliers ---
#define HMASK_MULT      0.9   // horizontal mask line brightness
#define VMASK_MULT      0.7   // vertical mask line brightness
#define TJUNC_MULT      0.6  // T-junction dot brightness (was 0 = black bug)

#pragma stage vertex
layout(location = 0) in  vec4 Position;
layout(location = 1) in  vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord   = TexCoord;
}

#pragma stage fragment
layout(location = 0) in  vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    vec2 o        = params.SourceSize.zw;
    vec2 pixelPos = vTexCoord * params.SourceSize.xy;

    float colIndex = floor(pixelPos.x);
    vec2  p        = fract(pixelPos);

    // --- horizontal position within the 6-wide cell (0..6) ---
    float kx = p.x * 6.0;

    // --- vertical stagger and position within the 5-tall cell (0..5) ---
    float stagger      = mod(colIndex, 2.0) * 0.5;
    float pY_staggered = fract(p.y + stagger);
    float ky           = pY_staggered * 5.0;

    // which vertical neighbor to sample for vBleed
    float neighborYDir = ((p.y + stagger) >= 1.0) ? 1.0 : -1.0;

    vec2 texCenter = (floor(pixelPos) + 0.5) * o;

    // --- sample current pixel and its two neighbors ---
    vec3 C     = texture(Source, texCenter).rgb;
    vec3 right = texture(Source, texCenter + vec2( o.x, 0.0)).rgb;
    vec3 above = texture(Source, texCenter + vec2(0.0, neighborYDir * o.y)).rgb;

    // --- mask region flags ---
    bool isHBleed = (ky < 1.0);   // top strip of cell = vertical mask line
    bool isVBleed = (kx >= 5.0);  // right strip of cell = horizontal mask line

    // --- luma of current pixel drives bleed intensity ---
    float luma       = dot(C, vec3(0.299, 0.587, 0.114));
    float bleedBoost = 1.0 + luma * BLEED_LUMA_GAIN;

    // --- bleed colors ---
    vec3 hBleed = (C + right) * (HBLEED_BASE * bleedBoost);
    vec3 vBleed = (C + above) * (VBLEED_BASE * bleedBoost) * vec3(1,0.7,1);

    vec3 color;

    if (isVBleed && isHBleed)
    {
        // T-junction: was vec3(0) — now average both bleeds, dimmed by TJUNC_MULT
        // fixes the black pixel bug at mask line intersections
        color = (hBleed + vBleed) * 0.5 * TJUNC_MULT;
    }
    else if (isVBleed)
    {
        // vertical mask line strip
        color = vBleed * VMASK_MULT;
    }
    else if (isHBleed)
    {
        // horizontal mask line strip
        color = hBleed * HMASK_MULT;
    }
    else
    {
        // phosphor core
        color = C * CORE_GAIN;
    }

    FragColor = vec4(color, 1.0);
}
