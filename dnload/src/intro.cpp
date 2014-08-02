/** \file
 * Very small intro stub.
 */

//######################################
// Define ##############################
//######################################

/** Screen width. */
#define SCREEN_W 1280

/** Screen heigth. */
#define SCREEN_H 720

/** Audio channels. */
#define AUDIO_CHANNELS 2

/** Audio samplerate. */
#define AUDIO_SAMPLERATE 44100

/** Audio byterate. */
#define AUDIO_BYTERATE (AUDIO_CHANNELS * AUDIO_SAMPLERATE * sizeof(int16_t))

/** Intro length (in bytes of audio). */
#define INTRO_LENGTH (16 * AUDIO_BYTERATE)

/** Intro start position (in seconds). */
#define INTRO_START (0 * AUDIO_BYTERATE)

/** \cond */
#define STARTING_POS_X 0.0f
#define STARTING_POS_Y 0.0f
#define STARTING_POS_Z 2.0f
#define STARTING_FW_X 0.0f
#define STARTING_FW_Y 0.0f
#define STARTING_FW_Z -1.0f
#define STARTING_UP_X 0.0f
#define STARTING_UP_Y 1.0f
#define STARTING_UP_Z 0.0f
/** \endcond */

//######################################
// Include #############################
//######################################

#include "dnload.h"
#include "intro.hpp"

//######################################
// Global data #########################
//######################################

/** Audio buffer for output. */
static int16_t g_audio_buffer[INTRO_LENGTH * 9 / 8 / sizeof(int16_t)];

/** Current audio position. */
static uint8_t *g_audio_position = reinterpret_cast<uint8_t*>(&g_audio_buffer[INTRO_START]);

#if defined(USE_LD)

/** \cond */
static float g_pos_x = STARTING_POS_X;
static float g_pos_y = STARTING_POS_Y;
static float g_pos_z = STARTING_POS_Z;
static float g_fw_x = STARTING_FW_X;
static float g_fw_y = STARTING_FW_Y;
static float g_fw_z = STARTING_FW_Z;
static float g_up_x = STARTING_UP_X;
static float g_up_y = STARTING_UP_Y;
static float g_up_z = STARTING_UP_Z;
/** \endcond */

/** Developer mode global toggle. */
static uint8_t g_flag_developer = 0;

#endif

//######################################
// rand() ##############################
//######################################

/** Random number -op to op.
 *
 * \param op Limit.
 * \return Random number [-op, op[
 */
static float frand(float op)
{
  uint16_t ret = static_cast<uint16_t>(dnload_rand() & 0xFFFF);
  return static_cast<float>(*(reinterpret_cast<int16_t*>(&ret))) / 32768.0f * op;
}

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
  AUDIO_S16,
  AUDIO_CHANNELS,
  0,
#if defined(USE_LD)
  4096,
#else
  256, // ~172.3Hz, lower values seem to cause underruns
#endif
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
"uniform vec3 f;"
"uniform vec2 t;"
"uniform vec3 u;"
"varying vec3 b;"
"void main()"
"{"
"vec3 g=normalize(f);"
"vec3 r=normalize(cross(g,u));"
"vec3 v=normalize(cross(r,g));"
"vec2 m=a;"
"if(t.y>1.) m.x*=t.y;"
"else m.y/=t.y;"
"b=m.x*r+m.y*v+f;"
"gl_Position=vec4(a,0,1);"
"}";

/** Quad fragment shader. */
static const char g_shader_fragment_quad[] = ""
"uniform vec3 p;"
"uniform vec2 t;"
"varying vec3 b;"
"float f(vec3 p)"
"{"
"return dot(p,p)-1.+sin(t.x/44444.)*.1;"
"}"
"vec3 g(vec3 n,float N)"
"{"
"vec3 d=vec3(.01,0,0);"
"return normalize(vec3(f(n+d.xyy),f(n+d.yxy),f(n+d.yyx))-N);"
"}"
"void main()"
"{"
"vec4 o=vec4(0,0,0,1);"
"vec3 c=p;"
"vec3 d=normalize(b)*.01;"
"for(int i=0;i<555;++i)"
"{"
"vec3 n=c+d;"
"float N=f(n);"
"if(0.>N)"
"{"
"o.xyz=vec3(1)*dot(g(n,N),normalize(vec3(1)));"
"break;"
"}"
"c=n;"
"}"
"gl_FragColor=o;"
"}";

/** \cond */
GLuint g_program_quad;
GLint g_attribute_quad_a;
/** \endcond */

#if defined(USE_LD)

/** \brief Prints an indent.
 *
 * \param indent Number of characters to draw.
 */
static void print_indent(unsigned indent)
{
  unsigned ii;
  for(ii = 0; (ii < indent); ++ii)
  {
    putc(' ', stdout);
  }
}

/** \brief Perform a set regex on a string.
 *
 * \return True if matches, false if not.
 */
static bool regex_space_plus_alpha_plus_semicolon(const char *op)
{
  for(;;)
  {
    if(' ' != *op)
    {
      for(;;)
      {
        if(!isalpha(*op))
        {
          for(;;)
          {
            char cc = *op;

            if(' ' != cc)
            {
              return (';' == cc);
            }

            ++op;
          }
        }

        ++op;
      }
    }

    ++op;
  }
}

/** \brief Print a shader and make the output neater.
 *
 * \param shader Shader to print.
 * \param indent Indent to use.
 * \return Indent after print operation.
 */
static unsigned print_shader(const char *shader, unsigned indent)
{
  char *iter = const_cast<char*>(shader);

  for(;;)
  {		
    char cc = *iter;

    switch(cc)
    {
      case '\0':
        return indent;

      case ';':
        {
          puts(";");
          print_indent(indent);
        }
        break;

      case '{':
        puts("");
        print_indent(indent);
        puts("{");
        indent += 2;
        print_indent(indent);
        break;

      case '}':
        putc('\r', stdout);
        indent -= 2;
        print_indent(indent);
        putc('}', stdout);
        if(!regex_space_plus_alpha_plus_semicolon(iter + 1))
        {
          puts("");
          print_indent(indent);
        }
        break;

      default:
        putc(cc, stdout);
        break;
    }

    ++iter;
  }

  return indent;
}			

#endif

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
#if defined(USE_LD)
  {
    unsigned ii;
    unsigned indent;
    char slog[4096];
    GLsizei len;
    GLint status;

    for(ii = 0, indent = 0; (ii < 1); ++ii)
    {
      indent = print_shader(&source[ii], indent);
    }

    glGetShaderInfoLog(ret, 4096, &len, slog);
    if(strlen(slog) > 0)
    {
      puts(slog);
    }

    glGetShaderiv(ret, GL_COMPILE_STATUS, &status);
    if(status != GL_TRUE)
    {
      SDL_Quit();
      exit(1);
    }
  }
#endif
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
#if defined(USE_LD)
  {
    char slog[4096];
    GLsizei len;
    GLint status;
    glGetProgramInfoLog(ret, 4096, &len, slog);
    if(strlen(slog) > 0)
    {
      puts(slog);
    }

    glGetProgramiv(ret, GL_LINK_STATUS, &status);
    if(status != GL_TRUE)
    {
      SDL_Quit();
      exit(1);
    }
    printf("GLSL program compiles to: %u\n", ret);
  }
#endif
  return ret;
}

//######################################
// Draw ################################
//######################################

/** \brief Uniforms.
 *
 * 0: X position.
 * 1: Y position.
 * 2: Z position.
 * 3: X forward.
 * 4: Y forward.
 * 5: Z forward.
 * 6: X up.
 * 7: Y up.
 * 8: Z up.
 * 9: Time.
 * 10: Screen aspect ratio x/y.
 */
static float g_uniform_array[11] =
{
  STARTING_POS_X, STARTING_POS_Y, STARTING_POS_Z,
  STARTING_FW_X, STARTING_FW_Y, STARTING_FW_Z,
  STARTING_UP_X, STARTING_UP_Y, STARTING_UP_Z,
  0.0f, 0.0f,
};

/** \brief Draw the world.
 *
 * \param ticks Tick count.
 * \param aspec Screen aspect.
 */
static void draw(unsigned ticks, float aspect)
{
  dnload_glDisable(GL_DEPTH_TEST);
  dnload_glClear(GL_DEPTH_BUFFER_BIT);
  dnload_glDisable(GL_BLEND);

  dnload_glUseProgram(g_program_quad);
  dnload_glEnableVertexAttribArray(static_cast<GLuint>(g_attribute_quad_a));

#if defined(USE_LD)
  if(g_flag_developer)
  {
    g_uniform_array[0] = g_pos_x;
    g_uniform_array[1] = g_pos_y;
    g_uniform_array[2] = g_pos_z;
    g_uniform_array[3] = g_fw_x;
    g_uniform_array[4] = g_fw_y;
    g_uniform_array[5] = g_fw_z;
    g_uniform_array[6] = g_up_x;
    g_uniform_array[7] = g_up_y;
    g_uniform_array[8] = g_up_z;
  }
#endif
  g_uniform_array[9] = static_cast<float>(ticks);
  g_uniform_array[10] = aspect;
  dnload_glUniform3fv(dnload_glGetUniformLocation(g_program_quad, "p"), 1, g_uniform_array + 0);
  dnload_glUniform3fv(dnload_glGetUniformLocation(g_program_quad, "f"), 1, g_uniform_array + 3);
  dnload_glUniform3fv(dnload_glGetUniformLocation(g_program_quad, "u"), 1, g_uniform_array + 6);
  dnload_glUniform2fv(dnload_glGetUniformLocation(g_program_quad, "t"), 1, g_uniform_array + 9);

  dnload_glRects(-1, -1, 1, 1);
}

//######################################
// Main ################################
//######################################

#if defined(USE_LD)
int intro(unsigned screen_w, unsigned screen_h, uint8_t flag_developer, uint8_t flag_fullscreen,
    uint8_t flag_record)
{
#else
/** \cond */
#define screen_w SCREEN_W
#define screen_h SCREEN_H
#define flag_developer 0
#define flag_fullscreen 0
/** \endcond */
void _start()
{
#endif

  dnload();
  dnload_SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO);
  dnload_SDL_SetVideoMode(static_cast<int>(screen_w), static_cast<int>(screen_h), 0,
      SDL_OPENGL | (flag_fullscreen ? SDL_FULLSCREEN : 0));
  dnload_SDL_ShowCursor(flag_developer);
#if defined(USE_LD)
  {
    GLenum err = glewInit();
    if(GLEW_OK != err)
    {
      SDL_Quit();
      fprintf(stderr, "glewInit(): %s", glewGetErrorString(err));
      exit(1);
    }
  }
#endif

  g_program_quad = program_create(g_shader_vertex_quad, g_shader_fragment_quad);
  g_attribute_quad_a = dnload_glGetAttribLocation(g_program_quad, "a");
#if defined(USE_LD)
  printf("Quad program: %u\nAttributes:\na: %i\n",
      g_program_quad, g_attribute_quad_a);
#endif

#if defined(USE_LD)
  if(flag_record)
  {
    SDL_Event event;
    unsigned frame_idx = 0;

    // audio
    SDL_PauseAudio(1);

    write_audio_callback(g_audio_buffer, static_cast<unsigned>(INTRO_LENGTH * sizeof(uint16_t) * AUDIO_CHANNELS));

    // video
    for(;;)
    {
      unsigned ticks = static_cast<unsigned>(static_cast<float>(frame_idx) / 60.0f *
          static_cast<float>(AUDIO_BYTERATE));

      if(ticks > INTRO_LENGTH)
      {
        break;
      }

      if(SDL_PollEvent(&event) && (event.type == SDL_KEYDOWN) && (event.key.keysym.sym == SDLK_ESCAPE))
      {
        break;
      }

      draw(ticks, static_cast<float>(screen_w) / static_cast<float>(screen_h));
      write_frame_callback(screen_w, screen_h, frame_idx);
      SDL_GL_SwapBuffers();
      ++frame_idx;
    }

    SDL_Quit();
    return 0;
  }

  if(!flag_developer)
  {
    SDL_OpenAudio(&audio_spec, NULL);
    SDL_PauseAudio(0);
  }
  g_flag_developer = flag_developer;
#else
  dnload_SDL_OpenAudio(&audio_spec, NULL);
  dnload_SDL_PauseAudio(0);
#endif

#if defined(USE_LD)
  uint32_t starttick = SDL_GetTicks();	
#endif

  for(;;)
  {
#if defined(USE_LD)
    static float move_speed = 1.0f / 60.0f;
    static float current_time = 0.0f;
    static uint8_t mouse_look = 0;
    static int8_t move_backward = 0;
    static int8_t move_down = 0;
    static int8_t move_forward = 0;
    static int8_t move_left = 0;
    static int8_t move_right = 0;
    static int8_t move_up = 0;
    static int8_t time_delta = 0;
    int mouse_look_x = 0;
    int mouse_look_y = 0;
    bool quit = false;
#endif
    SDL_Event event;
    unsigned currtick;

#if defined(USE_LD)
    while(SDL_PollEvent(&event))
    {
      if(SDL_QUIT == event.type)
      {
        quit = true;
      }
      else if(SDL_KEYDOWN == event.type)
      {
        switch(event.key.keysym.sym)
        {
          case SDLK_a:
            move_left = 1;
            break;

          case SDLK_d:
            move_right = 1;
            break;

          case SDLK_e:
            move_up = 1;
            break;

          case SDLK_q:
            move_down = 1;
            break;

          case SDLK_s:
            move_backward = 1;
            break;

          case SDLK_w:
            move_forward = 1;
            break;

          case SDLK_LSHIFT:
          case SDLK_RSHIFT:
            move_speed = 1.0f / 5.0f;
            break;            

          case SDLK_LALT:
            time_delta = -1;
            break;

          case SDLK_MODE:
          case SDLK_RALT:
            time_delta = 1;
            break;

          case SDLK_ESCAPE:
            quit = true;
            break;

          default:
            break;
        }
      }
      else if(SDL_KEYUP == event.type)
      {
        switch(event.key.keysym.sym)
        {
          case SDLK_a:
            move_left = 0;
            break;

          case SDLK_d:
            move_right = 0;
            break;

          case SDLK_e:
            move_up = 0;
            break;

          case SDLK_q:
            move_down = 0;
            break;

          case SDLK_s:
            move_backward = 0;
            break;

          case SDLK_w:
            move_forward = 0;
            break;

          case SDLK_LSHIFT:
          case SDLK_RSHIFT:
            move_speed = 1.0f / 60.0f;
            break;            

          case SDLK_MODE:
          case SDLK_LALT:
          case SDLK_RALT:
            time_delta = 0;
            break;

          default:
            break;
        }
      }
      else if(SDL_MOUSEBUTTONDOWN == event.type)
      {
        if(1 == event.button.button)
        {
          mouse_look = 1;
        }
      }
      else if(SDL_MOUSEBUTTONUP == event.type)
      {
        if(1 == event.button.button)
        {
          mouse_look = 0;
        }
      }
      else if(SDL_MOUSEMOTION == event.type)
      {
        if(0 != mouse_look)
        {
          mouse_look_x += event.motion.xrel;
          mouse_look_y += event.motion.yrel;
        }
      }
    }

    if(g_flag_developer)
    {
      float uplen = sqrtf(g_up_x * g_up_x + g_up_y * g_up_y + g_up_z * g_up_z);
      float fwlen = sqrtf(g_fw_x * g_fw_x + g_fw_y * g_fw_y + g_fw_z * g_fw_z);
      float rt_x;
      float rt_y;
      float rt_z;
      float movement_rt = static_cast<float>(move_right - move_left) * move_speed;
      float movement_up = static_cast<float>(move_up - move_down) * move_speed;
      float movement_fw = static_cast<float>(move_forward - move_backward) * move_speed;

      g_up_x /= uplen;
      g_up_y /= uplen;
      g_up_z /= uplen;

      g_fw_x /= fwlen;
      g_fw_y /= fwlen;
      g_fw_z /= fwlen;

      rt_x = g_fw_y * g_up_z - g_fw_z * g_up_y;
      rt_y = g_fw_z * g_up_x - g_fw_x * g_up_z;
      rt_z = g_fw_x * g_up_y - g_fw_y * g_up_x;

      if(0 != mouse_look_x)
      {
        float angle = static_cast<float>(mouse_look_x) / static_cast<float>(screen_h / 4) * 0.25f;
        float ca = cosf(angle);
        float sa = sinf(angle);
        float new_rt_x = ca * rt_x + sa * g_fw_x;
        float new_rt_y = ca * rt_y + sa * g_fw_y;
        float new_rt_z = ca * rt_z + sa * g_fw_z;
        float new_fw_x = ca * g_fw_x - sa * rt_x;
        float new_fw_y = ca * g_fw_y - sa * rt_y;
        float new_fw_z = ca * g_fw_z - sa * rt_z;

        rt_x = new_rt_x;          
        rt_y = new_rt_y;
        rt_z = new_rt_z;
        g_fw_x = new_fw_x;
        g_fw_y = new_fw_y;
        g_fw_z = new_fw_z;
      }
      if(0 != mouse_look_y)
      {
        float angle = static_cast<float>(mouse_look_y) / static_cast<float>(screen_h / 4) * 0.25f;
        float ca = cosf(angle);
        float sa = sinf(angle);
        float new_fw_x = ca * g_fw_x + sa * g_up_x;
        float new_fw_y = ca * g_fw_y + sa * g_up_y;
        float new_fw_z = ca * g_fw_z + sa * g_up_z;
        float new_up_x = ca * g_up_x - sa * g_fw_x;
        float new_up_y = ca * g_up_y - sa * g_fw_y;
        float new_up_z = ca * g_up_z - sa * g_fw_z;

        g_fw_x = new_fw_x;
        g_fw_y = new_fw_y;
        g_fw_z = new_fw_z;
        g_up_x = new_up_x;
        g_up_y = new_up_y;
        g_up_z = new_up_z;
      }

      g_pos_x += movement_rt * rt_x + movement_up * g_up_x + movement_fw * g_fw_x;
      g_pos_y += movement_rt * rt_y + movement_up * g_up_y + movement_fw * g_fw_y;
      g_pos_z += movement_rt * rt_z + movement_up * g_up_z + movement_fw * g_fw_z;
    }

    if(g_flag_developer)
    {
      current_time += static_cast<float>(AUDIO_BYTERATE) / 60.0f * static_cast<float>(time_delta);

      currtick = static_cast<unsigned>(current_time);
    }
    else
    {
      float seconds_elapsed = static_cast<float>(SDL_GetTicks() - starttick) / 1000.0f;

      currtick = static_cast<unsigned>(seconds_elapsed * static_cast<float>(AUDIO_BYTERATE)) + INTRO_START;
    }

    if((currtick >= INTRO_LENGTH) || quit)
    {
      break;
    }
#else
    currtick = g_audio_position - reinterpret_cast<uint8_t*>(g_audio_buffer);

    if((currtick >= INTRO_LENGTH) || (dnload_SDL_PollEvent(&event) && (event.type == SDL_KEYDOWN)))
    {
      break;
    }
#endif

    draw(currtick, static_cast<float>(screen_w) / static_cast<float>(screen_h));
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

