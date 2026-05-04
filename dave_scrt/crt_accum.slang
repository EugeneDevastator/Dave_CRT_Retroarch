#version 450

layout(push_constant) uniform Push {
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO { mat4 MVP; } global;

#define DECAY          0.70
#define DECAY_EXPONENT 1.2

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
    vec3 decayed = pow(prev * DECAY, vec3(DECAY_EXPONENT));
    FragColor    = vec4(max(decayed, current), 1.0);
}
