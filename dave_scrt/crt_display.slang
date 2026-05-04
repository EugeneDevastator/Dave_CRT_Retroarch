#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float CORE_GAIN;
    float HBLEED_MULT;
    float VBLEED_MULT;
    float TJUNC_MULT;
    float CELL_W;
    float CELL_H;
    float CELL_MID;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#pragma parameter CORE_GAIN   "Cell Core Gain"       1.0  0.0 3.0  0.05
#pragma parameter HBLEED_MULT "Horizontal Bleed"     0.35 0.0 0.5  0.01
#pragma parameter VBLEED_MULT "Vertical Bleed"       0.44 0.0 0.5  0.01
#pragma parameter TJUNC_MULT  "Junction Bleed"       0.3  0.0 0.5  0.01
#pragma parameter CELL_W      "Cell Width px"        6.0  1.0 10.0 1.0
#pragma parameter CELL_H      "Cell Height px"       6.0  1.0 10.0 1.0
#pragma parameter CELL_MID    "Cell Midline px pos"  3.0  0.0 9.0  1.0

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
	int CELL_MID = int(params.CELL_MID);
    vec2 o = params.SourceSize.zw;

    ivec2 gridSize = ivec2(params.SourceSize.xy) * ivec2(params.CELL_W, params.CELL_H);
    ivec2 offset   = (ivec2(params.OutputSize.xy) - gridSize) / 2;
    ivec2 outPx    = ivec2(floor(vTexCoord * params.OutputSize.xy)) - offset;

    if (outPx.x < 0 || outPx.y < 0 || outPx.x >= gridSize.x || outPx.y >= gridSize.y) {
        FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    ivec2 srcPixel = outPx / ivec2(params.CELL_W, params.CELL_H);
    ivec2 cellPos  = outPx - srcPixel * ivec2(params.CELL_W, params.CELL_H);

    int midFrom = CELL_MID - 1;
    int midTo   = CELL_MID;

    bool isStaggerCol = (srcPixel.x % 2) == 0;
    bool isUpperLine  = cellPos.y == 0;
    bool isMidLine    = float(cellPos.y) >= midFrom && float(cellPos.y) < midTo;
    bool isVEdge      = cellPos.x > (int(params.CELL_W) - 2);

    vec2 tc    = (vec2(srcPixel) + 0.5) * o;
    vec3 own   = texture(Source, tc).rgb                     * params.CORE_GAIN;
    vec3 right = texture(Source, tc + vec2(o.x,  0.0)).rgb  * params.CORE_GAIN;
    vec3 above = texture(Source, tc + vec2(0.0, -o.y)).rgb  * params.CORE_GAIN;

    vec3 color;
    bool usejunct = isStaggerCol ? isMidLine : isUpperLine;
    if (isVEdge && usejunct) {
        color = (own + right) * params.TJUNC_MULT * vec3(1,0.8,1);
    } else if (isVEdge) {
        color = (own + right) * params.VBLEED_MULT* vec3(1,0.8,1);
    } else if (isUpperLine) {
        if (isStaggerCol)
            color = (above + own) * 0.5;
        else
            color = (own + above) * params.HBLEED_MULT;
    } else if (isMidLine) {
        if (isStaggerCol)
            color = own * params.HBLEED_MULT * 2.0;
        else
            color = own;
    } else {
        color = own;
    }

    FragColor = vec4(color, 1.0);
}
