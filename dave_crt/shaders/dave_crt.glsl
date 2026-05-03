#version 130

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out mediump vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

#define Source Texture
#define vTexCoord TEX0.xy

void main()
{
    vec2 o = 1.0 / TextureSize;

    // pixel-space coords (continuous)
    vec2 pixelPos = vTexCoord * TextureSize;

    // which source pixel column are we in (integer)
    float colIndex = floor(pixelPos.x);

    // sub-texel position [0,1)
    vec2 p = fract(pixelPos);

    // kernel coords [0,6) x [0,5)
    vec2 K;
    K.x = p.x * 6.0;

    // stagger: odd columns shift Y by half kernel (2.5 / 5.0 = 0.5 in p-space)
    float stagger = mod(colIndex, 2.0) * 0.5;
    float pY_staggered = fract(p.y + stagger);
    K.y = pY_staggered * 5.0;

    // when staggered, the vertical neighbor shifts too
    // if stagger pushed us into the next pixel row, sample below instead of above
    float yShifted = p.y + stagger;
    float neighborYDir = (yShifted >= 1.0) ? 1.0 : -1.0;

    vec2 texCenter = (floor(pixelPos) + 0.5) * o;

    vec3 C     = COMPAT_TEXTURE(Source, texCenter).rgb;
    vec3 right = COMPAT_TEXTURE(Source, texCenter + vec2( o.x, 0.0)).rgb;
    vec3 above = COMPAT_TEXTURE(Source, texCenter + vec2(0.0, neighborYDir * o.y)).rgb;

    bool isVBleed = K.y < 1.0;
    bool isHBleed = K.x >= 5.0;

    // bleed = (C + neighbor) * 0.5 * 0.7
    vec3 hBleed = (C + right) * 0.35;
    vec3 vBleed = (C + above) * 0.35;

    vec3 color;
    if      (isVBleed && isHBleed) color = vec3(0.0);
    else if (isVBleed)             color = vBleed;
    else if (isHBleed)             color = hBleed;
    else                           color = C;

    FragColor = vec4(color, 1.0);
}
#endif
