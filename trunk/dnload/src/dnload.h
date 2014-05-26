#ifndef DNLOAD_H
#define DNLOAD_H

/** \file
 * \brief Dynamic loader header stub.
 *
 * This file was automatically generated by 'dnload.py'.
 */

#if defined(USE_LD)
#if defined(WIN32)
#include "windows.h"
#include "GL/glew.h"
#include "GL/glu.h"
#include "SDL.h"
#elif defined(__APPLE__)
#include "GL/glew.h"
#include "GL/glu.h"
#include "SDL/SDL.h"
#else
#include "GL/glew.h"
#include "GL/glu.h"
#include "SDL.h"
#endif
#include "bsd_rand.h"
#else
/** \cond */
#define GL_GLEXT_PROTOTYPES
/** \endcond */
#include "GL/gl.h"
#include "GL/glext.h"
#include "GL/glu.h"
#include "SDL.h"
#endif

#if defined(GLEWAPIENTRY)
/** \cond */
#define DNLOADAPIENTRY GLEWAPIENTRY
/** \endcond */
#else
/** \cond */
#define DNLOADAPIENTRY
/** \endcond */
#endif

#if defined(WIN32)
/** \cond */
#define _USE_MATH_DEFINES
/** \endcond */
#endif
#if defined(__cplusplus)
#include <cmath>
#else
#include <math.h>
#endif

#if !defined(USE_LD)
#if defined(__FreeBSD__) || defined(__linux__)
#if defined(__x86_64)
/** Assembler exit syscall macro. */
#define asm_exit() asm volatile("movq $1,%rax\nsyscall")
#elif defined(__i386)
/** Assembler exit syscall macro. */
#define asm_exit() asm volatile("movl $1,%eax\nint $128")
#else
#error "no assembler exit procedure defined for current architecture"
#endif
#else
#error "no assembler exit procerude defined for current operating system"
#endif
#endif

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(USE_LD)
/** \cond */
#define dnload_glCreateProgram glCreateProgram
#define dnload_rand bsd_rand
#define dnload_glUseProgram glUseProgram
#define dnload_glDisable glDisable
#define dnload_glLinkProgram glLinkProgram
#define dnload_glShaderSource glShaderSource
#define dnload_glGetUniformLocation glGetUniformLocation
#define dnload_glRects glRects
#define dnload_SDL_SetVideoMode SDL_SetVideoMode
#define dnload_SDL_ShowCursor SDL_ShowCursor
#define dnload_SDL_GL_SwapBuffers SDL_GL_SwapBuffers
#define dnload_SDL_PollEvent SDL_PollEvent
#define dnload_SDL_Init SDL_Init
#define dnload_glCompileShader glCompileShader
#define dnload_glClear glClear
#define dnload_SDL_PauseAudio SDL_PauseAudio
#define dnload_glUniform2fv glUniform2fv
#define dnload_SDL_Quit SDL_Quit
#define dnload_glEnableVertexAttribArray glEnableVertexAttribArray
#define dnload_glGetAttribLocation glGetAttribLocation
#define dnload_glUniform3fv glUniform3fv
#define dnload_SDL_OpenAudio SDL_OpenAudio
#define dnload_glAttachShader glAttachShader
#define dnload_glCreateShader glCreateShader
/** \endcond */
#else
/** \cond */
#define dnload_glCreateProgram g_symbol_table.glCreateProgram
#define dnload_rand g_symbol_table.rand
#define dnload_glUseProgram g_symbol_table.glUseProgram
#define dnload_glDisable g_symbol_table.glDisable
#define dnload_glLinkProgram g_symbol_table.glLinkProgram
#define dnload_glShaderSource g_symbol_table.glShaderSource
#define dnload_glGetUniformLocation g_symbol_table.glGetUniformLocation
#define dnload_glRects g_symbol_table.glRects
#define dnload_SDL_SetVideoMode g_symbol_table.SDL_SetVideoMode
#define dnload_SDL_ShowCursor g_symbol_table.SDL_ShowCursor
#define dnload_SDL_GL_SwapBuffers g_symbol_table.SDL_GL_SwapBuffers
#define dnload_SDL_PollEvent g_symbol_table.SDL_PollEvent
#define dnload_SDL_Init g_symbol_table.SDL_Init
#define dnload_glCompileShader g_symbol_table.glCompileShader
#define dnload_glClear g_symbol_table.glClear
#define dnload_SDL_PauseAudio g_symbol_table.SDL_PauseAudio
#define dnload_glUniform2fv g_symbol_table.glUniform2fv
#define dnload_SDL_Quit g_symbol_table.SDL_Quit
#define dnload_glEnableVertexAttribArray g_symbol_table.glEnableVertexAttribArray
#define dnload_glGetAttribLocation g_symbol_table.glGetAttribLocation
#define dnload_glUniform3fv g_symbol_table.glUniform3fv
#define dnload_SDL_OpenAudio g_symbol_table.SDL_OpenAudio
#define dnload_glAttachShader g_symbol_table.glAttachShader
#define dnload_glCreateShader g_symbol_table.glCreateShader
/** \endcond */
#endif

#if !defined(USE_LD)
/** \brief Symbol table structure.
 *
 * Contains all the symbols required for dynamic linking.
 */
static struct SymbolTableStruct
{
  GLuint (DNLOADAPIENTRY *glCreateProgram)(void);
  int (*rand)(void);
  void (DNLOADAPIENTRY *glUseProgram)(GLuint);
  void (DNLOADAPIENTRY *glDisable)(GLenum);
  void (DNLOADAPIENTRY *glLinkProgram)(GLuint);
  void (DNLOADAPIENTRY *glShaderSource)(GLuint, GLsizei, const GLchar**, const GLint*);
  GLint (DNLOADAPIENTRY *glGetUniformLocation)(GLuint, const GLchar*);
  void (DNLOADAPIENTRY *glRects)(GLshort, GLshort, GLshort, GLshort);
  SDL_Surface* (*SDL_SetVideoMode)(int, int, int, Uint32);
  int (*SDL_ShowCursor)(int);
  void (*SDL_GL_SwapBuffers)(void);
  int (*SDL_PollEvent)(SDL_Event*);
  int (*SDL_Init)(Uint32);
  void (DNLOADAPIENTRY *glCompileShader)(GLuint);
  void (DNLOADAPIENTRY *glClear)(GLbitfield);
  void (*SDL_PauseAudio)(int);
  void (DNLOADAPIENTRY *glUniform2fv)(GLint, GLsizei, const GLfloat*);
  void (*SDL_Quit)(void);
  void (DNLOADAPIENTRY *glEnableVertexAttribArray)(GLuint);
  GLint (DNLOADAPIENTRY *glGetAttribLocation)(GLuint, const GLchar*);
  void (DNLOADAPIENTRY *glUniform3fv)(GLint, GLsizei, const GLfloat*);
  int (*SDL_OpenAudio)(SDL_AudioSpec*, SDL_AudioSpec*);
  void (DNLOADAPIENTRY *glAttachShader)(GLuint, GLuint);
  GLuint (DNLOADAPIENTRY *glCreateShader)(GLenum);
} g_symbol_table =
{
  (GLuint (DNLOADAPIENTRY *)(void))0x78721c3L,
  (int (*)(void))0xe83af065L,
  (void (DNLOADAPIENTRY *)(GLuint))0xcc55bb62L,
  (void (DNLOADAPIENTRY *)(GLenum))0xb5f7c43L,
  (void (DNLOADAPIENTRY *)(GLuint))0x133a35c5L,
  (void (DNLOADAPIENTRY *)(GLuint, GLsizei, const GLchar**, const GLint*))0xc609c385L,
  (GLint (DNLOADAPIENTRY *)(GLuint, const GLchar*))0x25c12218L,
  (void (DNLOADAPIENTRY *)(GLshort, GLshort, GLshort, GLshort))0xd419e20aL,
  (SDL_Surface* (*)(int, int, int, Uint32))0x39b85060L,
  (int (*)(int))0xb88bf697L,
  (void (*)(void))0xda43e6eaL,
  (int (*)(SDL_Event*))0x64949d97L,
  (int (*)(Uint32))0x70d6574L,
  (void (DNLOADAPIENTRY *)(GLuint))0xc5165dd3L,
  (void (DNLOADAPIENTRY *)(GLbitfield))0x1fd92088L,
  (void (*)(int))0x29f14a4L,
  (void (DNLOADAPIENTRY *)(GLint, GLsizei, const GLfloat*))0x21b64a33L,
  (void (*)(void))0x7eb657f3L,
  (void (DNLOADAPIENTRY *)(GLuint))0xe9e99723L,
  (GLint (DNLOADAPIENTRY *)(GLuint, const GLchar*))0xceb27dd0L,
  (void (DNLOADAPIENTRY *)(GLint, GLsizei, const GLfloat*))0x223459b4L,
  (int (*)(SDL_AudioSpec*, SDL_AudioSpec*))0x46fd70c8L,
  (void (DNLOADAPIENTRY *)(GLuint, GLuint))0x30b3cfcfL,
  (GLuint (DNLOADAPIENTRY *)(GLenum))0x6b4ffac6L,
};
#endif

#if defined(USE_LD)
/** \cond */
#define dnload()
/** \endcond */
#else
#include <stdint.h>
/** \brief SDBM hash function.
 *
 * \param op String to hash.
 * \return Full hash.
 */
static uint32_t sdbm_hash(const uint8_t *op)
{
  uint32_t ret = 0;
  for(;;)
  {
    uint32_t cc = *op++;
    if(!cc)
    {
      return ret;
    }
    ret = ret * 65599 + cc;
  }
}
#if defined(__i386)
#if defined(__FreeBSD__)
#include <sys/link_elf.h>
#elif defined(__linux__)
#include <link.h>
#else
#error "no elf header location known for current platform"
#endif
/** \brief ELF base address. */
#define ELF_BASE_ADDRESS 0x8048000
/** \brief Get the program link map.
 *
 * \return Link map struct.
 */
static struct link_map* elf32_get_link_map()
{
  // ELF header is in a fixed location in memory.
  // First program header is located directly afterwards.
  Elf32_Ehdr *ehdr = (Elf32_Ehdr*)ELF_BASE_ADDRESS;
  Elf32_Phdr *phdr = (Elf32_Phdr*)((size_t)ehdr + (size_t)ehdr->e_phoff);
  // Find the dynamic header by traversing the phdr array.
  for(; (phdr->p_type != PT_DYNAMIC); ++phdr) { }
  // Find the debug entry in the dynamic header array.
  {
    Elf32_Dyn *dynamic = (Elf32_Dyn*)phdr->p_vaddr;
    for(; (dynamic->d_tag != DT_DEBUG); ++dynamic) { }
    return ((struct r_debug*)dynamic->d_un.d_ptr)->r_map;
  }
}
/** \brief Get address of one section.
 *
 * Dynamic object sections are identified by tags.
 *
 * \param lmap Link map.
 * \param op Tag to look for.
 */
static void* elf32_get_dynamic_section_value(struct link_map* lmap, int op)
{
  Elf32_Dyn* dynamic = (Elf32_Dyn*)lmap->l_ld;
  // Find the desired tag in the dynamic header.
  for(; (dynamic->d_tag != op); ++dynamic) { }
  {
    void* ret = (void*)dynamic->d_un.d_ptr;
    return (ret < (void*)lmap->l_addr) ? (uint8_t*)ret + (size_t)lmap->l_addr : ret;
  }
}
/** \brief Find a symbol in any of the link maps.
 *
 * Should a symbol with name matching the given hash not be present, this function will happily continue until
 * we crash. Size-minimal code has no room for error checking.
 *
 * \param hash Hash of the function name string.
 * \return Symbol found.
 */
static void* dnload_find_symbol(uint32_t hash)
{
  struct link_map* lmap = elf32_get_link_map();
  for(;;)
  {
    /* Find symbol from link map. We need the string table and a corresponding symbol table. */
    char* strtab = (char*)elf32_get_dynamic_section_value(lmap, DT_STRTAB);
    Elf32_Sym* symtab = (Elf32_Sym*)elf32_get_dynamic_section_value(lmap, DT_SYMTAB);
    uint32_t* hashtable = (uint32_t*)elf32_get_dynamic_section_value(lmap, DT_HASH);
    unsigned numchains = hashtable[1]; /* Number of symbols. */
    unsigned ii;
    for(ii = 0; (ii < numchains); ++ii)
    {
      Elf32_Sym* sym = &symtab[ii];
      char *name = &strtab[sym->st_name];
      if(sdbm_hash((uint8_t*)name) == hash)
      {
        return (uint8_t*)sym->st_value + (size_t)lmap->l_addr;
      }
    }
    lmap = lmap->l_next;
  }
}
#else
#error "no import by hash procedure defined for current architecture"
#endif
/** \brief Perform init.
 *
 * Import by hash - style.
 */
static void dnload(void)
{
  unsigned ii;
  for(ii = 0; (24 > ii); ++ii)
  {
    void **iter = ((void**)&g_symbol_table) + ii;
    *iter = dnload_find_symbol(*(uint32_t*)iter);
  }
}
#endif

#if defined(__cplusplus)
}
#endif

#endif
