#ifndef DNLOAD_H
#define DNLOAD_H

/** \file
 * \brief Dynamic loader header stub.
 *
 * This file was automatically generated by 'dnload.py'.
 */

#if defined(WIN32)
/** \cond */
#define _USE_MATH_DEFINES
#define NOMINMAX
/** \endcond */
#endif

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

#if defined(__cplusplus)
#include <cmath>
#else
#include <math.h>
#endif

#if (defined(_LP64) && _LP64) || (defined(__LP64__) && __LP64__)
/** Size of pointer in bytes (64-bit). */
#define DNLOAD_POINTER_SIZE 8
#else
/** Size of pointer in bytes (32-bit). */
#define DNLOAD_POINTER_SIZE 4
#endif

#if !defined(USE_LD)
#if defined(__x86_64)
#if defined(__FreeBSD__)
/** Assembler exit syscall macro. */
#define asm_exit() asm("syscall" : /* no output */ : "a"(1))
#elif defined(__linux__)
/** Assembler exit syscall macro. */
#define asm_exit() asm("syscall" : /* no output */ : "a"(60))
#endif
#elif defined(__i386)
#if defined(__FreeBSD__) || defined(__linux__)
/** Assembler exit syscall macro. */
#define asm_exit() asm("int $128" : /* no output */ : "a"(1))
#endif
#endif
#if !defined(asm_exit)
#error "no assembler exit procedure defined for current operating system or architecture"
#endif
#endif

#if defined(__cplusplus)
extern "C" {
#endif

#if !defined(USE_LD)
#if defined(__FreeBSD__)
#if defined(__clang__)
/** Symbol required by libc. */
void *environ;
/** Symbol required by libc. */
void *__progname;
#else
/** Symbol required by libc. */
void *environ __attribute__((externally_visible));
/** Symbol required by libc. */
void *__progname __attribute__((externally_visible));
#endif
#endif
#if defined(__clang__)
/** Program entry point. */
void _start();
#else
/** Program entry point. */
void _start() __attribute__((externally_visible));
#endif
#endif

#if defined(USE_LD)
/** \cond */
#define dnload_rand bsd_rand
#define dnload_glGenProgramPipelines glGenProgramPipelines
#define dnload_SDL_GL_SwapBuffers SDL_GL_SwapBuffers
#define dnload_glRects glRects
#define dnload_SDL_SetVideoMode SDL_SetVideoMode
#define dnload_glBindProgramPipeline glBindProgramPipeline
#define dnload_SDL_ShowCursor SDL_ShowCursor
#define dnload_glProgramUniform2fv glProgramUniform2fv
#define dnload_glCreateShaderProgramv glCreateShaderProgramv
#define dnload_SDL_PollEvent SDL_PollEvent
#define dnload_SDL_Init SDL_Init
#define dnload_SDL_PauseAudio SDL_PauseAudio
#define dnload_glProgramUniform3fv glProgramUniform3fv
#define dnload_SDL_Quit SDL_Quit
#define dnload_glUseProgramStages glUseProgramStages
#define dnload_SDL_OpenAudio SDL_OpenAudio
/** \endcond */
#else
/** \cond */
#define dnload_rand g_symbol_table.rand
#define dnload_glGenProgramPipelines g_symbol_table.glGenProgramPipelines
#define dnload_SDL_GL_SwapBuffers g_symbol_table.SDL_GL_SwapBuffers
#define dnload_glRects g_symbol_table.glRects
#define dnload_SDL_SetVideoMode g_symbol_table.SDL_SetVideoMode
#define dnload_glBindProgramPipeline g_symbol_table.glBindProgramPipeline
#define dnload_SDL_ShowCursor g_symbol_table.SDL_ShowCursor
#define dnload_glProgramUniform2fv g_symbol_table.glProgramUniform2fv
#define dnload_glCreateShaderProgramv g_symbol_table.glCreateShaderProgramv
#define dnload_SDL_PollEvent g_symbol_table.SDL_PollEvent
#define dnload_SDL_Init g_symbol_table.SDL_Init
#define dnload_SDL_PauseAudio g_symbol_table.SDL_PauseAudio
#define dnload_glProgramUniform3fv g_symbol_table.glProgramUniform3fv
#define dnload_SDL_Quit g_symbol_table.SDL_Quit
#define dnload_glUseProgramStages g_symbol_table.glUseProgramStages
#define dnload_SDL_OpenAudio g_symbol_table.SDL_OpenAudio
/** \endcond */
#endif

#if !defined(USE_LD)
/** \brief Symbol table structure.
 *
 * Contains all the symbols required for dynamic linking.
 */
static struct SymbolTableStruct
{
  int (*rand)(void);
  void (GLAPIENTRY *glGenProgramPipelines)(GLsizei, GLuint*);
  void (*SDL_GL_SwapBuffers)(void);
  void (GLAPIENTRY *glRects)(GLshort, GLshort, GLshort, GLshort);
  SDL_Surface* (*SDL_SetVideoMode)(int, int, int, Uint32);
  void (GLAPIENTRY *glBindProgramPipeline)(GLuint);
  int (*SDL_ShowCursor)(int);
  void (GLAPIENTRY *glProgramUniform2fv)(GLuint, GLint, GLsizei, const GLfloat*);
  GLuint (GLAPIENTRY *glCreateShaderProgramv)(GLenum, GLsizei, const char**);
  int (*SDL_PollEvent)(SDL_Event*);
  int (*SDL_Init)(Uint32);
  void (*SDL_PauseAudio)(int);
  void (GLAPIENTRY *glProgramUniform3fv)(GLuint, GLint, GLsizei, const GLfloat*);
  void (*SDL_Quit)(void);
  void (GLAPIENTRY *glUseProgramStages)(GLuint, GLbitfield, GLuint);
  int (*SDL_OpenAudio)(SDL_AudioSpec*, SDL_AudioSpec*);
} g_symbol_table =
{
  (int (*)(void))0xe83af065L,
  (void (GLAPIENTRY *)(GLsizei, GLuint*))0x75e35418L,
  (void (*)(void))0xda43e6eaL,
  (void (GLAPIENTRY *)(GLshort, GLshort, GLshort, GLshort))0xd419e20aL,
  (SDL_Surface* (*)(int, int, int, Uint32))0x39b85060L,
  (void (GLAPIENTRY *)(GLuint))0x2386bc04L,
  (int (*)(int))0xb88bf697L,
  (void (GLAPIENTRY *)(GLuint, GLint, GLsizei, const GLfloat*))0xc8ebc2cdL,
  (GLuint (GLAPIENTRY *)(GLenum, GLsizei, const char**))0xa4fd03d8L,
  (int (*)(SDL_Event*))0x64949d97L,
  (int (*)(Uint32))0x70d6574L,
  (void (*)(int))0x29f14a4L,
  (void (GLAPIENTRY *)(GLuint, GLint, GLsizei, const GLfloat*))0xc969d24eL,
  (void (*)(void))0x7eb657f3L,
  (void (GLAPIENTRY *)(GLuint, GLbitfield, GLuint))0x212d8ad7L,
  (int (*)(SDL_AudioSpec*, SDL_AudioSpec*))0x46fd70c8L,
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
#if defined(__FreeBSD__)
#include <sys/link_elf.h>
#elif defined(__linux__)
#include <link.h>
#else
#error "no elf header location known for current platform"
#endif
#if (8 == DNLOAD_POINTER_SIZE)
/** Elf header type. */
typedef Elf64_Ehdr dnload_elf_ehdr_t;
/** Elf program header type. */
typedef Elf64_Phdr dnload_elf_phdr_t;
/** Elf dynamic structure type. */
typedef Elf64_Dyn dnload_elf_dyn_t;
/** Elf symbol table entry type. */
typedef Elf64_Sym dnload_elf_sym_t;
/** Elf dynamic structure tag type. */
typedef Elf64_Sxword dnload_elf_tag_t;
#else
/** Elf header type. */
typedef Elf32_Ehdr dnload_elf_ehdr_t;
/** Elf program header type. */
typedef Elf32_Phdr dnload_elf_phdr_t;
/** Elf dynamic structure type. */
typedef Elf32_Dyn dnload_elf_dyn_t;
/** Elf symbol table entry type. */
typedef Elf32_Sym dnload_elf_sym_t;
/** Elf dynamic structure tag type. */
typedef Elf32_Sword dnload_elf_tag_t;
#endif
/** \brief ELF base address. */
#define ELF_BASE_ADDRESS 0x2000000
/** \brief Get the address associated with given tag in a dynamic section.
 *
 * \param dyn Dynamic section.
 * \param tag Tag to look for.
 * \return Address matching given tag.
 */
static const void* elf_get_dynamic_address_by_tag(const void *dyn, dnload_elf_tag_t tag)
{
  const dnload_elf_dyn_t *dynamic = (const dnload_elf_dyn_t*)dyn;
  for(;;)
  {
#if defined(__linux__)
    if(0 == dynamic->d_tag)
    {
      return NULL;
    }
#endif
    if(dynamic->d_tag == tag)
    {
      return (const void*)dynamic->d_un.d_ptr;
    }
    ++dynamic;
  }
}
/** \brief Get the program link map.
 *
 * \return Link map struct.
 */
static const struct link_map* elf_get_link_map()
{
  // ELF header is in a fixed location in memory.
  // First program header is located directly afterwards.
  const dnload_elf_ehdr_t *ehdr = (const dnload_elf_ehdr_t*)ELF_BASE_ADDRESS;
  const dnload_elf_phdr_t *phdr = (const dnload_elf_phdr_t*)((size_t)ehdr + (size_t)ehdr->e_phoff);
  // Find the dynamic header by traversing the phdr array.
  for(; (phdr->p_type != PT_DYNAMIC); ++phdr) { }
  // Find the debug entry in the dynamic header array.
  {
    const struct r_debug *debug = (const struct r_debug*)elf_get_dynamic_address_by_tag((const void*)phdr->p_vaddr, DT_DEBUG);
    return debug->r_map;
  }
}
/** \brief Get address of one dynamic section corresponding to given library.
 *
 * \param lmap Link map.
 * \param tag Tag to look for.
 */
static const void* elf_get_library_dynamic_section(const struct link_map *lmap, dnload_elf_tag_t tag)
{
  const void *ret = elf_get_dynamic_address_by_tag(lmap->l_ld, tag);
  // Sometimes the value is an offset instead of a naked pointer.
#if defined(__linux__)
  if((NULL != ret) && (ret < (const void*)lmap->l_addr))
#else
  if(ret < (const void*)lmap->l_addr)
#endif
  {
    return (uint8_t*)ret + (size_t)lmap->l_addr;
  }
  return ret;
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
  const struct link_map* lmap = elf_get_link_map();
#if defined(__linux__) && (8 == DNLOAD_POINTER_SIZE)
  // On 64-bit Linux, the second entry is not usable.
  lmap = lmap->l_next;
#endif
  for(;;)
  {
    // First entry is this object itself, safe to advance first.
    lmap = lmap->l_next;
    // Find symbol from link map. We need the string table and a corresponding symbol table.
    const char* strtab = (const char*)elf_get_library_dynamic_section(lmap, DT_STRTAB);
    const dnload_elf_sym_t* symtab = (const dnload_elf_sym_t*)elf_get_library_dynamic_section(lmap, DT_SYMTAB);
    const uint32_t* hashtable = (const uint32_t*)elf_get_library_dynamic_section(lmap, DT_HASH);
    unsigned dynsymcount;
    unsigned ii;
#if defined(__linux__)
    if(NULL == hashtable)
    {
      hashtable = (const uint32_t*)elf_get_library_dynamic_section(lmap, DT_GNU_HASH);
      // DT_GNU_HASH symbol counter borrows from FreeBSD rtld-elf implementation.
      dynsymcount = 0;
      {
        unsigned bucket_count = hashtable[0];
        const uint32_t* buckets = hashtable + 4 + ((sizeof(void*) / 4) * hashtable[2]);
        const uint32_t* chain_zero = buckets + bucket_count + hashtable[1];
        for(ii = 0; (ii < bucket_count); ++ii)
        {
          unsigned bkt = buckets[ii];
          if(bkt == 0)
          {
            continue;
          }
          {
            const uint32_t* hashval = chain_zero + bkt;
            do {
              ++dynsymcount;
            } while(0 == (*hashval++ & 1u));
          }
        }
      }
    }
    else
#endif
    {
      dynsymcount = hashtable[1];
    }
    for(ii = 0; (ii < dynsymcount); ++ii)
    {
      const dnload_elf_sym_t* sym = &symtab[ii];
      const char *name = &strtab[sym->st_name];
      if(sdbm_hash((const uint8_t*)name) == hash)
      {
        return (void*)((const uint8_t*)sym->st_value + (size_t)lmap->l_addr);
      }
    }
  }
}
/** \brief Perform init.
 *
 * Import by hash - style.
 */
static void dnload(void)
{
  unsigned ii;
  for(ii = 0; (16 > ii); ++ii)
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
