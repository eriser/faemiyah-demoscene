/** \file
 * One-quad example.
 */

//######################################
// Define ##############################
//######################################

/** Screen width. */
#define SCREEN_W 1280

/** Screen heigth. */
#define SCREEN_H 720

/** Fullscreen on/off. */
#define FLAG_FULLSCREEN 0

/** Audio channels. */
#define AUDIO_CHANNELS 1

/** Audio samplerate. */
#define AUDIO_SAMPLERATE 8000

/** Audio byterate. */
#define AUDIO_BYTERATE (AUDIO_CHANNELS * AUDIO_SAMPLERATE * sizeof(uint8_t))

/** Intro length (in bytes of audio). */
#define INTRO_LENGTH (16 * AUDIO_BYTERATE)

//######################################
// Include #############################
//######################################

#include "dnload.h"

//######################################
// Global data #########################
//######################################

/** Audio buffer for output. */
static uint8_t g_audio_buffer[INTRO_LENGTH * 9 / 8 / sizeof(uint8_t)];

/** Current audio position. */
static uint8_t *g_audio_position = reinterpret_cast<uint8_t*>(&g_audio_buffer);

//######################################
// Music ###############################
//######################################

/** \brief Update audio stream.
 *
 * \param userdata Not used.
 * \param stream Target stream.
 * \param len Number of bytes to write.
 */
static void audio_callback(void *userdata, Uint8 *stream, int len)
{
  (void)userdata;

  while(len--)
  {
    *stream++ = *g_audio_position++;
  }
}

/** SDL audio specification struct. */
static SDL_AudioSpec audio_spec =
{
  AUDIO_SAMPLERATE,
  AUDIO_U8,
  AUDIO_CHANNELS,
  0,
  256, // ~172.3Hz
  0,
  0,
  audio_callback,
  NULL
};

//######################################
// Shaders #############################
//######################################

/** Quad vertex shader. */
static const char *g_shader_vertex_quad = ""
"#version 430\n"
"in vec2 a;"
"out gl_PerVertex"
"{"
"vec4 gl_Position;"
"};"
"out vec2 b;"
"void main()"
"{"
"b=a;"
"gl_Position=vec4(a,0,1);"
"}";

/** Quad fragment shader. */
static const char *g_shader_fragment_quad = ""
"#version 430\n"
"layout(location=0)uniform float t;"
"in vec2 b;"
"out vec4 o;"
"void main()"
"{"
"o=vec4(b.x,sin(t/7777)*.5+.5,b.y,1);"
"}";

/** \cond */
static GLuint g_program_quad;
/** \endcond */

//######################################
// Draw ################################
//######################################

/** \brief Draw the world.
 *
 * \param ticks Milliseconds.
 * \param aspec Screen aspect.
 */
static void draw(unsigned ticks)
{
  dnload_glProgramUniform1f(g_program_quad, 0, ticks);

  dnload_glRects(-1, -1, 1, 1);
}

//######################################
// Main ################################
//######################################

#if defined(USE_LD)
int main()
#else
void _start()
#endif
{
  dnload();
  dnload_SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
  dnload_SDL_SetVideoMode(SCREEN_W, SCREEN_H, 0, SDL_OPENGL | (FLAG_FULLSCREEN ? SDL_FULLSCREEN : 0));
  dnload_SDL_ShowCursor(0);
#if defined(USE_LD)
  glewInit();
#endif

  // Shader generation inline.
  {
    GLuint pipeline;
    GLuint program_vert = dnload_glCreateShaderProgramv(GL_VERTEX_SHADER, 1, &g_shader_vertex_quad);
    g_program_quad = dnload_glCreateShaderProgramv(GL_FRAGMENT_SHADER, 1, &g_shader_fragment_quad);

    dnload_glGenProgramPipelines(1, &pipeline);
    dnload_glUseProgramStages(pipeline, 1, program_vert);
    dnload_glUseProgramStages(pipeline, 2, g_program_quad);
    dnload_glBindProgramPipeline(pipeline);
  }

  {
    unsigned ii;

    // Example by "bst", taken from "Music from very short programs - the 3rd iteration" by viznut.
    for(ii = 0; (INTRO_LENGTH / sizeof(uint8_t) > ii); ++ii)
    {
      g_audio_buffer[ii] = (int)(ii / 70000000 * ii * ii + ii) % 127 | ii >> 4 | ii >> 5 | (ii % 127 + (ii >> 17)) | ii;
    }
  }

  dnload_SDL_OpenAudio(&audio_spec, NULL);
  dnload_SDL_PauseAudio(0);

  for(;;)
  {
    SDL_Event event;
    unsigned currtick = static_cast<unsigned>(g_audio_position - reinterpret_cast<uint8_t*>(g_audio_buffer));

    if((currtick >= INTRO_LENGTH) || (dnload_SDL_PollEvent(&event) && (event.type == SDL_KEYDOWN)))
    {
      break;
    }

    draw(currtick);
    dnload_SDL_GL_SwapBuffers();
  }

  dnload_SDL_Quit();
#if defined(USE_LD)
  return 0;
#else
  asm_exit();
#endif
}

//######################################
// End #################################
//######################################

