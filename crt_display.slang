#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#define CORE_GAIN       1.1
#define HBLEED_BASE     0.35
#define BLEED_LUMA_GAIN 0.35
#define HMASK_MULT      0.7

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
    const int CELL_W = 4;
    const int CELL_H = 4;

    vec2 o = params.SourceSize.zw;

    ivec2 gridSize = ivec2(params.SourceSize.xy) * ivec2(CELL_W, CELL_H);
    ivec2 offset   = (ivec2(params.OutputSize.xy) - gridSize) / 2;
    ivec2 outPx    = ivec2(floor(vTexCoord * params.OutputSize.xy)) - offset;

    if (outPx.x < 0 || outPx.y < 0 || outPx.x >= gridSize.x || outPx.y >= gridSize.y) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    ivec2 srcPixel = outPx / ivec2(CELL_W, CELL_H);
    ivec2 cellPos  = outPx - srcPixel * ivec2(CELL_W, CELL_H);

    bool isStaggerCol = (srcPixel.x % 2) == 0;
    bool isUpperLine  = cellPos.y < (CELL_H / 4);
    bool isMidLine    = cellPos.y >= (CELL_H / 2) && cellPos.y < ((CELL_H * 3) / 4);
    bool isVEdge      = cellPos.x == (CELL_W - 1);

    vec2 tc    = (vec2(srcPixel) + 0.5) * o;
    vec3 own   = texture(Source, tc).rgb;
    vec3 right = texture(Source, tc + vec2(o.x,  0.0)).rgb;
    vec3 above = texture(Source, tc + vec2(0.0, -o.y)).rgb;
    vec3 below = texture(Source, tc + vec2(0.0,  o.y)).rgb;

    float luma       = dot(own, vec3(0.299, 0.587, 0.114));
    float bleedBoost = 1.0 + luma * BLEED_LUMA_GAIN;

    vec3 color;

    if (isVEdge) {
        color = (own + right) * (HBLEED_BASE * bleedBoost) * HMASK_MULT;
    }
    else if (isUpperLine) {
        if (isStaggerCol)
            color = (above + own) * 0.5;
        else
            color = (own + above) * (HBLEED_BASE * bleedBoost);
    }
    else if (isMidLine) {
        if (isStaggerCol)
            color = own * (HBLEED_BASE * bleedBoost);
        else
            color = own;
    }
    else {
        color = own * CORE_GAIN;
    }

    FragColor = vec4(color, 1.0);
}
