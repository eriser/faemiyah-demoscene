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

  do {
    *stream = *g_audio_position;
    ++stream;
    ++g_audio_position;
  } while(len--);
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
static const char g_shader_vertex_quad[] = ""
"attribute vec2 a;"
"varying vec2 b;"
"void main()"
"{"
"gl_Position=vec4(a,0,1);"
"b=a;"
"}";

/** Quad fragment shader. */
static const char g_shader_fragment_quad[] = ""
"uniform float t;"
"varying vec2 b;"
"void main()"
"{"
"gl_FragColor=vec4(b.x,sin(t/7777)*.5+.5,b.y,0);"
"}";

/** \cond */
GLuint g_program_quad;
GLint g_attribute_quad_a;
/** \endcond */

/** \brief Create a shader.
 *
 * \param sh Shader content.
 * \param st Shader type.
 * \return Compiled shader.
 */
static GLuint shader_create(const char *source, GLenum st)
{
  GLuint ret = dnload_glCreateShader(st);

  dnload_glShaderSource(ret, 1, static_cast<const GLchar**>(&source), NULL);
  dnload_glCompileShader(ret);

  return ret;
}

/** \brief Create a program.
 *
 * Create a shader program using one vertex shader and one fragment shader.
 *
 * \param vs Vertex shader.
 * \param fs Fragement shader.
 * \return The compiled and linked program.
 */
static GLuint program_create(const char *vertex, const char* fragment)
{
  GLuint ret = dnload_glCreateProgram();

  dnload_glAttachShader(ret, shader_create(vertex, GL_VERTEX_SHADER));
  dnload_glAttachShader(ret, shader_create(fragment, GL_FRAGMENT_SHADER));
  dnload_glLinkProgram(ret);

  return ret;
}

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
  dnload_glDisable(GL_DEPTH_TEST);
  dnload_glDisable(GL_BLEND);

  dnload_glUseProgram(g_program_quad);
  dnload_glUniform1f(dnload_glGetUniformLocation(g_program_quad, "t"), ticks);
  dnload_glEnableVertexAttribArray(static_cast<GLuint>(g_attribute_quad_a));
  dnload_glRectf(-1.0f, -1.0f, 1.0f, 1.0f);
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

  g_program_quad = program_create(g_shader_vertex_quad, g_shader_fragment_quad);
  g_attribute_quad_a = dnload_glGetAttribLocation(g_program_quad, "a");

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
    unsigned currtick = g_audio_position - reinterpret_cast<uint8_t*>(g_audio_buffer);

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

