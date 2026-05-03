#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#define CORE_GAIN       1.1
#define HBLEED_BASE     0.35
#define VBLEED_BASE     0.45
#define BLEED_LUMA_GAIN 0.35
#define HMASK_MULT      0.9
#define VMASK_MULT      0.7
#define TJUNC_MULT      0.6

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

    // cell size in output pixels derived from scale ratios
    vec2 cellSize = params.OutputSize.xy * params.SourceSize.zw;

    // position in output pixels
    vec2 outPos   = vTexCoord * params.OutputSize.xy;

    // which source pixel we're in
    vec2 srcPixel = floor(outPos / cellSize);

    // position within cell, in output pixels
    vec2 cellPos  = fract(outPos / cellSize) * cellSize;

    float colIndex = srcPixel.x;

    // vertical stagger (same as before, in cell-pixel units)
    float stagger      = mod(colIndex, 2.0) * (cellSize.y * 0.5);
    float cellPosYStag = mod(cellPos.y + stagger, cellSize.y);

    float neighborYDir = ((cellPos.y + stagger) >= cellSize.y) ? 1.0 : -1.0;

    vec2 texCenter = (srcPixel + 0.5) * o;

    vec3 C     = texture(Source, texCenter).rgb;
    vec3 right = texture(Source, texCenter + vec2( o.x, 0.0)).rgb;
    vec3 above = texture(Source, texCenter + vec2(0.0, neighborYDir * o.y)).rgb;

    // 1 output pixel thick masks
    bool isVBleed = (cellPosYStag < 1.0);
    bool isHBleed = (cellPos.x >= (cellSize.x - 1.0) && cellPos.x < cellSize.x);

    float luma       = dot(C, vec3(0.299, 0.587, 0.114));
    float bleedBoost = 1.0 + luma * BLEED_LUMA_GAIN;

    vec3 hBleed = (C + right) * (HBLEED_BASE * bleedBoost);
    vec3 vBleed = (C + above) * (VBLEED_BASE * bleedBoost) * vec3(1.0, 0.7, 1.0);

    vec3 color;

    if (isVBleed && isHBleed)
        color = (hBleed + vBleed) * 0.5 * TJUNC_MULT;
    else if (isVBleed)
        color = vBleed * VMASK_MULT;
    else if (isHBleed)
        color = hBleed * HMASK_MULT;
    else
        color = C * CORE_GAIN;

    FragColor = vec4(color, 1.0);
}
