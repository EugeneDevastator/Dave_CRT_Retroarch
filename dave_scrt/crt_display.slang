#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

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

    // kernel coords [0,6) x [0,5)
    float kx = p.x * 6.0;

    // stagger odd columns by half kernel height (0.5 in p-space)
    float stagger      = mod(colIndex, 2.0) * 0.5;
    float pY_staggered = fract(p.y + stagger);
    float ky           = pY_staggered * 5.0;

    // vertical neighbor direction
    float neighborYDir = ((p.y + stagger) >= 1.0) ? 1.0 : -1.0;

    vec2 texCenter = (floor(pixelPos) + 0.5) * o;

    vec3 C     = texture(Source, texCenter).rgb;
    vec3 right = texture(Source, texCenter + vec2( o.x, 0.0)).rgb;
    vec3 above = texture(Source, texCenter + vec2(0.0, neighborYDir * o.y)).rgb;

    bool isVBleed = (ky < 1.0);
    bool isHBleed = (kx >= 5.0);

    vec3 hBleed = (C + right) * 0.35;
    vec3 vBleed = (C + above) * 0.35;

    vec3 color;
    if      (isVBleed && isHBleed) color = vec3(0.0);
    else if (isVBleed)             color = vBleed;
    else if (isHBleed)             color = hBleed;
    else                           color = C;

    FragColor = vec4(color, 1.0);
}
