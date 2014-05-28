/** \file
 * "Hello World!" example.
 */

//######################################
// Include #############################
//######################################

#include "dnload.h"

//######################################
// Main ################################
//######################################

#if !defined(USE_LD)
#if defined(__clang__)
void *environ;
void *__progname;
extern "C" void _start();
#else
void *environ __attribute__((externally_visible));
void *__progname __attribute__((externally_visible));
extern "C" void _start() __attribute__((externally_visible));
#endif
#endif

/** \brief Object file starting point. */
#if defined(USE_LD)
int main()
#else
void _start()
#endif
{
  dnload();
  dnload_puts("Hello World!");

#if defined(USE_LD)
  return 0;
#else
  asm_exit();
#endif
}

//######################################
// End #################################
//######################################

