uniform sampler2D sampler;

in vec2 tex_coord;
out vec4 colour_out;

#if GLSL_VERSION >= 420
#define A_GPU 1
#define A_GLSL 1
#include "lib/ffx_a.h"
#define FSR_RCAS_F 1
#define FSR_RCAS_PASSTHROUGH_ALPHA 1
AU4 con0;
AF4 FsrRcasLoadF(ASU2 p) { return AF4(texelFetch(sampler, p, 0)); }
void FsrRcasInputF(inout AF1 r, inout AF1 g, inout AF1 b) {}
#include "lib/ffx_fsr1.h"
#endif /* GLSL_VERSION >= 420 */

// prng: A simple but effective pseudo-random number generator [0;1[
float prng(vec2 uv, float time) {
   return fract(sin(dot(uv + fract(time), vec2(12.9898, 78.233))) * 43758.5453);
}

// pdf: [-0.5;0.5[
// Removes noise modulation effect by reshaping the uniform/rectangular noise
// distribution (RPDF) into a Triangular (TPDF) or Gaussian Probability Density
// Function (GPDF).
// shape = 1.0: Rectangular
// shape = 0.5: Triangular
// shape < 0.5: Gaussian (0.2~0.4)
float pdf(float noise, float shape) {
   float orig = noise * 2.0 - 1.0;
   noise = pow(abs(orig), shape);
   noise *= sign(orig);
   noise -= sign(orig);
   return noise * 0.5;
}

void main()
{
#if GLSL_VERSION > 420
   vec2 texSize = textureSize(sampler, 0);
   FsrRcasCon(con0, 0.0);

   AU2 gxy = AU2(tex_coord.xy * texSize);
   AF4 Gamma2Color = AF4(0.0);
   FsrRcasF(Gamma2Color.r, Gamma2Color.g, Gamma2Color.b, Gamma2Color.a, gxy, con0);

   // FSR - [LFGA] LINEAR FILM GRAIN APPLICATOR
#if 0
   if (params.FSR_FILMGRAIN > 0.0) {
      if (params.FSR_GRAINCOLOR == 0.0) {
         float noise = pdf(prng(tex_coord, params.FrameCount * 0.11), params.FSR_GRAINPDF);
         FsrLfgaF(Gamma2Color, vec3(noise), params.FSR_FILMGRAIN);
      } else {
         vec3 rgbNoise = vec3(
               pdf(prng(tex_coord, params.FrameCount * 0.11), params.FSR_GRAINPDF),
               pdf(prng(tex_coord, params.FrameCount * 0.13), params.FSR_GRAINPDF),
               pdf(prng(tex_coord, params.FrameCount * 0.17), params.FSR_GRAINPDF)
               );
         FsrLfgaF(Gamma2Color, rgbNoise, params.FSR_FILMGRAIN);
      }
   }
#endif

   colour_out = Gamma2Color;

#else /* GLSL_VERSION > 420 */
   /* mpv's unsharpen mask. */
   const float PARAM = 0.5; /**< Sharpening strength. */
   vec2 d = vec2(1.0) / textureSize( sampler, 0 );
   float st1 = 1.2;
   vec4 p = texture( sampler, tex_coord );
   vec4 sum1 = texture( sampler, st1 * vec2(+d.x, +d.yy) )
      + texture( sampler, st1 * vec2(+d.x, -d.y))
      + texture( sampler, st1 * vec2(-d.x, +d.y))
      + texture( sampler, st1 * vec2(-d.x, -d.y));
   float st2 = 1.5;
   vec4 sum2 = texture( sampler, st2 * vec2(+d.x,  0.0))
      + texture( sampler, st2 * vec2( 0.0, +d.y))
      + texture( sampler, st2 * vec2(-d.x,  0.0))
      + texture( sampler, st2 * vec2( 0.0, -d.y));
   vec4 t = p * 0.859375 + sum2 * -0.1171875 + sum1 * -0.09765625;
   colour_out = p + t * PARAM;
#endif /* GLSL_VERSION > 420 */
}
