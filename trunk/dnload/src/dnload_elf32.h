#ifndef DNLOAD_ELF32_H
#define DNLOAD_ELF32_H

/** \file dnload_elf32.h
 *
 * Provides functionality to locate symbols from program memory by only examining the linked shared libraries.
 *
 * Adapted from 'proof of concept' sources published by parcelshit and las/Mercury.
 */

#if defined(__FreeBSD__)
#include <sys/link_elf.h>
#elif defined(__linux__)
#include <link.h>
#else
#error "no elf header location known for current platform"
#endif

#include "dnload_hash.h"

/** \brief ELF base address. */
#define ELF_BASE_ADDRESS 0x08048000

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

#endif
