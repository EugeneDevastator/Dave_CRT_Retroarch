#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float DECAY;
    float DECAY_EXPONENT;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#pragma parameter DECAY          "Phosphor Decay"          0.70 0.0 1.0  0.01
#pragma parameter DECAY_EXPONENT "Phosphor Decay Exponent" 1.2  0.5 3.0  0.05

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
layout(set = 0, binding = 3) uniform sampler2D PassFeedback0;

void main() {
    vec3 current = texture(Source, vTexCoord).rgb;
    vec3 prev    = texture(PassFeedback0, vTexCoord).rgb;
    vec3 decayed = pow(prev * params.DECAY, vec3(params.DECAY_EXPONENT));
    FragColor    = vec4(max(decayed, current), 1.0);
}
