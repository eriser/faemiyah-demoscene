#!/usr/bin/env python
"""Script to read C/C++ source input and generate a minimal program."""

import os
import re
import shutil
import subprocess
import stat
import sys

########################################
# Globals ##############################
########################################

assembler = None
compilation_mode = "maximum"
compiler = None
compression = "lzma"
default_assembler_list = ["/usr/local/bin/as", "as"]
default_compiler_list = ["g++49", "g++-4.9", "g++", "clang++"]
default_linker_list = ["/usr/local/bin/ld", "ld"]
default_strip_list = ["/usr/local/bin/strip", "strip"]
definition_ld = "USE_LD"
header_file = "dnload.h"
include_directories = ["/usr/include/SDL", "/usr/local/include", "/usr/local/include/SDL"]
libraries = []
library_directories = ["/lib", "/usr/lib", "/usr/local/lib"]
linker = None
output_file = None
source_files = []
strip = None
symbol_prefix = "dnload_"
target = None
target_search_path = []
verbose = False

string_help = """Usage: %s [args] <source file> [-c output]\n
Size-optimized executable generator for *nix platforms.\n
Preprocesses given source file(s) looking for specifically marked function
calls, then generates a dynamic loader header file that can be used within
these same source files to decrease executable size.\n
Optionally also perform the actual compilation of a size-optimized binary
after generating the header.\n
Command line options without arguments:
  -h, --help          Print this help string.
  -v, --verbose       Print more about what is being done.\n
Command line options with arguments:
  -A, --assembler           Try to use given assembler executable as opposed to
                            autodetect.
  -C, --compiler            Try to use given compiler executable as opposed to
                            autodetect.
  -d, --define              Definition to use for checking whether to use
                            'safe' mechanism instead of dynamic loading.
                            (default: %s)
  -I, --include             Add an include directory to be searched for header
                            files when preprocessing.
  -k, --linker              Try to use given linker executable as opposed to
                            autodetect.
  -l, --library             Add a library to be linked against.
  -L, --library-directory   Add a library directory to be searched for
                            libraries when linking.
  -m, --method              Method to use for decreasing output file size:
                              vanilla  Produce binary normally, use no tricks
                                       except unpack header.
                              dlfcn    Use dlopen/dlsym to decrease size
                                       without dependencies to any specific
                                       object format.
                              hash     Use knowledge of object file format to
                                       perform 'import by hash' loading, but do
                                       not break any specifications.
                              maximum  Use all available techniques to decrease
                                       output file size. Resulting file may
                                       violate object file specification.
                            (default: %s)
  -o, --output-file         Compile a named binary, do not only create a
                            header. If the name specified features a path, it
                            will be used verbatim. Otherwise the binary will be
                            created in the same path as source file(s)
                            compiled.
  -P, --call-prefix         Call prefix to identify desired calls.
                            (default: %s)
  -s, --search-directory    Directory to search for the header file to
                            generate. Current path will be used if not given.
  -S, --strip-binary        Try to use given strip executable as opposed to
                            autodetect.
  -t, --target              Target header file to look for.
                            (default: %s)
  -u, --unpack-header       Unpack header to use [lzma, xz].
                            (default: %s)""" % (sys.argv[0], definition_ld, compilation_mode, symbol_prefix, header_file, compression)

########################################
# PlatformVar ##########################
########################################

(osname, osignore1, osignore2, osignore3, osarch) = os.uname()

class PlatformVar:
  """Platform-dependent variable."""

  def __init__(self, name):
    """Initialize platform variable."""
    self.name = name

  def __str__(self):
    """Produce string of self."""
    if not self.name in platform_variables:
      raise RuntimeError("unknown platform variable '%s'" % (self.name))
    var = platform_variables[self.name]
    platform = (osname, osarch)
    for ii in platform:
      if ii in platform_mapping:
        ii = platform_mapping[ii]
      if ii in var:
        ret = var[ii]
        if isinstance(ret, int):
          return hex(ret)
        return ret
    if "default" in var:
      ret = var["default"]
      if isinstance(ret, int):
        return hex(ret)
      return ret
    raise RuntimeError("current platform %s not supported for variable '%s'" % (str(platform), self.name))

platform_mapping = { "i686" : "i386" }

platform_variables = {
    "e_machine" : { "i386" : 3 },
    "ei_osabi" : { "FreeBSD" : 9, "Linux" : 3 },
    "entry" : { "i386" : 0x08048000 },
    "interp" : { "FreeBSD" : "\"/libexec/ld-elf.so.1\"", "Linux" : "\"/lib/ld-linux.so.2\"" },
    "phdr_count" : { "default" : 3 },
    }

def replace_platform_variable(name, op):
  """Destroy platform variable, replace with default."""
  if not name in platform_variables:
    raise RuntimeError("trying to destroy nonexistent platform variable '%s'" % (name))
  platform_variables[name] = { "default" : op }

########################################
# Assembler ############################
########################################

class Assembler:
  """Class used to generate assembler output."""

  def __init__(self, op):
    """Constructor."""
    self.executable = op
    self.comment = "#"
    self.byte = ".byte"
    self.short = ".short"
    self.word = ".long"
    self.string = ".ascii"
    op = os.path.basename(op)
    if op.startswith("nasm"):
      self.comment = ";"
      self.byte = "db"
      self.short = "dw"
      self.word = "dd"
      self.string = "db"

  def assemble(self, src, dst):
    """Assemble a file."""
    cmd = [self.executable, src, "-o", dst]
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)

  def format_block_comment(self, desc, length = 40):
    """Get a block-formatted comment."""
    block_text = ""
    for ii in range(length):
      block_text += self.comment
    block_text += "\n"
    ret = self.comment
    if desc:
      ret += " " + desc + " "
    for ii in range(len(ret), length):
      ret += self.comment
    return block_text + ret + "\n" + block_text

  def format_comment(self, op, indent = ""):
    """Get comment string."""
    ret = ""
    if is_listing(op):
      for ii in op:
        if ii:
          ret += indent + self.comment + " " + ii + "\n"
    elif op:
      ret += indent + self.comment + " " + op + "\n"
    return ret

  def format_data(self, size, value, indent = ""):
    """Get data element."""
    if isinstance(value, int):
      value = hex(value)
    elif is_listing(value):
      value_strings = []
      for ii in value:
        if isinstance(ii, int):
          value_strings += [hex(ii)]
        else:
          value_strings += [str(ii)]
      value = ", ".join(value_strings)
    else:
      value = str(value)
      if value.startswith("\"") and 1 == size:
        return indent + self.string + " " + value + "\n"
    if 1 == size:
      return indent + self.byte + " " + value + "\n"
    elif 2 == size:
      return indent + self.short + " " + value + "\n"
    elif 4 == size:
      return indent + self.word + " " + value + "\n"
    else:
      raise NotImplementedError("exporting assembler value of size %i", size)

  def format_equ(self, name, value):
    return ".equ %s, %s\n" % (name, value)

  def format_label(self, op):
    """Generate name labels."""
    if not op:
      return ""
    ret = ""
    if is_listing(op):
      for ii in op:
        ret += ii + ":\n"
    else:
      ret += op + ":\n"
    return ret

########################################
# AssemblerFile ########################
########################################

class AssemblerFile:
  """Assembler file representation."""

  def __init__(self, filename):
    """Constructor, opens and reads a file."""
    fd = open(filename, "r")
    lines = fd.readlines()
    fd.close()
    self.sections = []
    current_section = AssemblerSection("text")
    ii = 0
    sectionre = re.compile(r'^\s+\.section\s+\"?\.([a-zA-Z0-9_]+)[\.\s]')
    for ii in lines:
      match = sectionre.match(ii)
      if match:
        self.sections += [current_section]
        current_section = AssemblerSection(match.group(1), ii)
      else:
        current_section.add_line(ii)
    if not current_section.empty():
      self.sections += [current_section]
    if verbose:
      section_names = map(lambda x: x.name, self.sections)
      print("Read %i sections in '%s': %s" % (len(self.sections), filename, ", ".join(section_names)))

  def generate_fake_bss(self, assembler):
    """Remove local labels that would seem to generate .bss, make a fake .bss section."""
    bss = AssemblerSection(".bss")
    bss.add_line("end:\n")
    bss.add_line(".balign 4\n")
    bss.add_line("aligned_end:\n")
    offset = 0
    size = 0
    for ii in self.sections:
      while True:
        entry = ii.extract_bss()
        if not entry:
          break
        name, size = entry
        bss.add_line(assembler.format_equ(name, "aligned_end + %i" % (offset)))
        offset += size
        size = offset
        if 0 < offset % 4:
          offset += 4 - (offset % 4)
    if verbose:
      outstr = "Constructed fake .bss segement: "
      if 1073741824 < size:
        print(outstr + "%1.1f Gbytes" % (float(size) / 1073741824.0))
      elif 1048576 < size:
        print(outstr + "%1.1f Mbytes" % (float(size) / 1048576.0))
      elif 1024 < size:
        print(outstr + "%1.1f kbytes" % (float(size) / 1024.0))
      else:
        print(outstr + "%u bytes" % (size))
    bss.add_line(assembler.format_equ("memory_end", "aligned_end + %i" % (offset)))
    self.sections += [bss]
    return size

  def remove_rodata(self):
    """Remove .rodata sections by merging them into the previous .text section."""
    text_section = None
    rodata_sections = []
    ii = 0
    while len(self.sections) > ii:
      section = self.sections[ii]
      if "text" == section.name:
        text_section = section
        ii += 1
      elif "rodata" == section.name:
        if text_section:
          text_section.content += section.content
        else:
          rodata_sections += [section]
        del(self.sections[ii])
      else:
        ii += 1
    # .rodata sections defined before any .text sections will be merged into
    # the last .text sextion.
    for ii in rodata_sections:
      text_section.content += ii.content

  def write(self, op, assembler):
    """Write an output assembler file or append to an existing file."""
    if isinstance(op, str):
      fd = open(op, "w")
      for ii in self.sections:
        ii.write(fd)
      fd.close()
      if verbose:
        print("Wrote assembler source file '%s'." % (op))
    else:
      prefix = assembler.format_block_comment("Program")
      op.write(prefix)
      for ii in self.sections:
        ii.write(op)

########################################
# AssemblerSection #####################
########################################

class AssemblerSection:
  """Section in an existing assembler source file."""

  def __init__(self, section_name, section_tag = None):
    """Constructor."""
    self.name = section_name
    self.tag = section_tag
    self.content = []

  def add_line(self, line):
    """Add one line."""
    self.content += [line]

  def crunch(self):
    """Remove all offending content."""
    while True:
      lst = self.want_line(r'\s*\.file\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.globl\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.ident\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.section\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.type\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.size\s+(.*)')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.(bss)\s+')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.(data)\s+')
      if lst:
        self.erase(lst[0])
        continue
      lst = self.want_line(r'\s*\.(text)\s+')
      if lst:
        self.erase(lst[0])
        continue
      break
    if "i386" == osarch or "i686" == osarch:
      self.crunch_i386()
    self.tag = None

  def crunch_i386(self):
    """Perform platform-dependent crunching."""
    lst = self.want_line(r'\s*(_start)\:.*')
    if lst:
      ii = lst[0] + 1
      jj = ii
      while True:
        if not re.match(r'\s*push.*', self.content[jj]):
          if verbose:
            print("Erasing function header from '%s': %i lines." % (lst[1], jj - ii))
          self.erase(ii, jj)
          break
        jj += 1
    lst = self.want_line(r'\s*int\s+\$?(\S+).*')
    if lst and ("0x80" == lst[1] or "128" == lst[1]):
      ii = lst[0] + 1
      jj = ii
      while True:
        if len(self.content) <= jj or re.match(r'\s*\S+\:\s*', self.content[jj]):
          if verbose:
            print("Erasing function footer after interrupt '%s': %i lines." % (lst[1], jj - ii))
          self.erase(ii, jj)
          break
        jj += 1

  def empty(self):
    """Tell if this section is empty."""
    if not self.content:
      return False
    return True

  def erase(self, first, last = None):
    """Erase lines."""
    if not last:
      last = first + 1
    self.content[first:last] = []

  def extract_bss(self):
    """Extract a variable that should go to .bss section."""
    # Test for relevant .globl element.
    found = self.extract_globl_object()
    if found:
      return found
    found = self.extract_comm_object()
    if found:
      return found
    self.minimal_align()
    self.crunch()
    return None

  def extract_comm_object(self):
    """.comm extract."""
    idx = 0
    while True:
      lst = self.want_line(r'\s*\.local\s+(\S+).*', idx)
      if lst:
        attempt = lst[0]
        name = lst[1]
        idx = attempt + 1
        lst = self.want_line(r'\s*\.comm\s+%s\s*,(.*)' % (name), idx)
        if not lst:
          continue
        size = lst[1]
        match = re.match(r'\s*(\d+)\s*,\s*(\d+).*', size)
        if match:
          size = int(match.group(1))
        else:
          size = int(size)
        self.erase(attempt, lst[0] + 1)
        return (name, size)
      return None

  def extract_globl_object(self):
    """.globl extract."""
    idx = 0
    while True:
      lst = self.want_line(r'\s*\.globl\s+(\S+).*', idx)
      if lst:
        attempt = lst[0]
        name = lst[1]
        idx = attempt + 1
        lst = self.want_line("\s*.type\s+(%s),\s+@object" % (name), idx)
        if not lst:
          continue
        lst = self.want_line("\s*(%s)\:" % (name), lst[0] + 1)
        if not lst:
          continue
        lst = self.want_line("\s*\.zero\s+(\d+)", lst[0] + 1)
        if not lst:
          continue
        self.erase(attempt, lst[0] + 1)
        return (name, int(lst[1]))
      return None

  def minimal_align(self):
    """Remove all .align declarations, replace with 32-bit alignment."""
    for ii in range(len(self.content)):
      line = self.content[ii]
      if re.match(r'.*\.align\s.*', line):
        self.content[ii] = "  .balign 4\n"

  def want_line(self, op, first = 0):
    """Want a line matching regex from object."""
    for ii in range(first, len(self.content)):
      line = self.content[ii]
      match = re.match(op, line)
      if match:
        return (ii, match.group(1))
    return None

  def write(self, fd):
    """Write this section into a file."""
    if self.tag:
      fd.write(self.tag)
    for ii in self.content:
      fd.write(ii)

########################################
# AssemblerVariable ####################
########################################

class AssemblerVariable:
  """One assembler variable."""

  def __init__(self, op):
    """Constructor."""
    if not is_listing(op):
      raise RuntimeError("only argument passed is not a list")
    self.desc = op[0]
    self.size = op[1]
    self.value = op[2]
    self.name = None
    if 3 < len(op):
      self.name = op[3]
    self.label_pre = []
    self.label_post = []

  def add_label_pre(self, op):
    """Add pre-label(s)."""
    if is_listing(op):
      self.label_pre += op
    else:
      self.label_pre += [op]

  def add_label_post(self, op):
    """Add post-label(s)."""
    if is_listing(op):
      self.label_post += op
    else:
      self.label_post += [op]

  def generate_source(self, op, indent, label = None):
    """Generate assembler source."""
    ret = ""
    indent = get_indent(indent)
    for ii in self.label_pre:
      ret += op.format_label(ii)
    if isinstance(self.value, str) and self.value.startswith("\"") and label and self.name:
      ret += op.format_label("%s_%s" % (label, self.name))
    formatted_comment = op.format_comment(self.desc, indent)
    formatted_data = op.format_data(self.size, self.value, indent)
    if formatted_comment:
      ret += formatted_comment
    ret += formatted_data
    for ii in self.label_post:
      ret += op.format_label(ii)
    return ret

  def mergable(self, op):
    """Tell if the two assembler variables are mergable."""
    if self.size != op.size:
      return False
    if self.value != op.value:
      return False
    return True

  def merge(self, op):
    """Merge two assembler variables into one."""
    self.desc = listify(self.desc, op.desc)
    self.name = listify(self.name, op.name)
    self.label_pre = listify(self.label_pre, op.label_pre)
    self.label_post = listify(self.label_post, op.label_post)

  def remove_label_pre(self, op):
    """Remove a pre-label."""
    if op in self.label_pre:
      self.label_pre.remove(op)

  def remove_label_post(self, op):
    """Remove a post-label."""
    if op in self.label_post:
      self.label_post.remove(op)

########################################
# AssemblerSegment #####################
########################################

class AssemblerSegment:
  """Segment is a collection of variables."""

  def __init__(self, op):
    """Constructor."""
    self.name = None
    self.desc = None
    self.data = []
    if isinstance(op, str):
      self.name = op
      self.desc = None
    elif is_listing(op):
      for ii in op:
        if is_listing(ii):
          self.add_data(ii)
        elif not self.name:
          self.name = ii
        elif not self.desc:
          self.desc = ii
        else:
          raise RuntimeError("too many string arguments for list constructor")
    if 0 >= len(self.data):
      raise RuntimeError("segment '%s' is empty" % self.name)
    self.add_name_label()
    self.add_name_end_label()

  def add_data(self, op):
    """Add data into this segment."""
    self.data += [AssemblerVariable(op)]

  def add_dt_needed(self, op):
    """Add requirement to given library."""
    friendly = get_friendly_library_name(op)
    d_tag = AssemblerVariable(("d_tag, DT_NEEDED = 1", 4, 1))
    d_un = AssemblerVariable(("d_un, library name offset in strtab", 4, "strtab_%s - strtab" % friendly))
    self.data[0:0] = [d_tag, d_un]
    self.add_name_label()

  def add_library_name(self, op):
    """Add a library name."""
    friendly = get_friendly_library_name(op)
    libname = AssemblerVariable(("library name string", 1, "\"%s\"" % op, friendly))
    terminator = AssemblerVariable(("string terminating zero", 1, 0))
    self.data += [libname, terminator]
    self.add_name_end_label()

  def add_name_label(self):
    """Add name label to first assembler variable."""
    for ii in self.data:
      ii.remove_label_pre(self.name)
    self.data[0].add_label_pre(self.name)

  def add_name_end_label(self):
    """Add a name end label to last assembler variable."""
    end_label = "%s_end" % (self.name)
    for ii in self.data:
      ii.remove_label_post(end_label)
    self.data[-1].add_label_post(end_label)

  def empty(self):
    """Tell if this segment is empty."""
    return 0 >= len(self.data)

  def generate_source(self, op):
    """Generate assembler source."""
    ret = op.format_block_comment(self.desc)
    for ii in self.data:
      ret += ii.generate_source(op, 1, self.name)
    return ret

  def merge(self, op):
    """Attempt to merge with given segment."""
    highest_mergable = 0
    for ii in range(min(len(self.data), len(op.data))):
      mergable = True
      for jj in range(ii + 1):
        if not self.data[-ii - 1 + jj].mergable(op.data[jj]):
          mergable = False
          break
      if mergable:
        highest_mergable = ii + 1
    if 0 >= highest_mergable:
      return False
    print("Merging headers %s and %s at point %i." % (self.name, op.name, highest_mergable))
    ii = highest_mergable
    while 0 < ii:
      self.data[-ii].merge(op.data[highest_mergable - ii])
      ii -= 1
    op.data[0:highest_mergable] = []
    return True

  def write(self, fd, assembler):
    """Write segment onto disk."""
    fd.write(self.generate_source(assembler))

assembler_ehdr = (
    "ehdr",
    "Elf32_Ehdr",
    ("e_ident[EI_MAG0], magic value 0x7F", 1, 0x7F),
    ("e_ident[EI_MAG1] to e_indent[EI_MAG3], magic value \"ELF\"", 1, "\"ELF\""),
    ("e_ident[EI_CLASS], ELFCLASS32 = 1", 1, 1),
    ("e_ident[EI_DATA], ELFDATA2LSB = 1", 1, 1),
    ("e_ident[EI_VERSION], EV_CURRENT = 1", 1, 1),
    ("e_ident[EI_OSABI], ELFOSABI_LINUX = 3, ELFOSABI_FREEBSD = 9", 1, PlatformVar("ei_osabi")),
    ("e_indent[EI_MAG9 to EI_MAG15], unused", 1, [0, 0, 0, 0, 0, 0, 0, 0]),
    ("e_type, ET_EXEC = 2", 2, 2),
    ("e_machine, EM_386 = 3", 2, PlatformVar("e_machine")),
    ("e_version, EV_CURRENT = 1", 4, 1),
    ("e_entry, execution starting point", 4, "_start"),
    ("e_phoff, offset from start to program headers", 4, "ehdr_end - ehdr"),
    ("e_shoff, start of section headers", 4, 0),
    ("e_flags, unused", 4, 0),
    ("e_ehsize, Elf32_Ehdr size", 2, "ehdr_end - ehdr"),
    ("e_phentsize, Elf32_Phdr size", 2, "phdr_load_end - phdr_load"),
    ("e_phnum, Elf32_Phdr count, PT_LOAD, [PT_LOAD (bss)], PT_INTERP, PT_DYNAMIC", 2, PlatformVar("phdr_count")),
    ("e_shentsize, Elf32_Shdr size", 2, 0),
    ("e_shnum, Elf32_Shdr count", 2, 0),
    ("e_shstrndx, index of section containing string table of section header names", 2, 0),
    )

assembler_phdr_load_single = (
    "phdr_load",
    "Elf32_Phdr, PT_LOAD",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of program start", 4, 0),
    ("p_vaddr, program virtual address", 4, 0x08048000),
    ("p_paddr, unused", 4, 0),
    ("p_filesz, program size on disk", 4, "end - ehdr"),
    ("p_memsz, program size in memory", 4, "memory_end - ehdr"),
    ("p_flags, rwx = 7", 4, 7),
    ("p_align, usually 0x1000", 4, 4096),
    )

assembler_phdr_load_double = (
    "phdr_load",
    "Elf32_Phdr, PT_LOAD",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of program start", 4, 0),
    ("p_vaddr, program virtual address", 4, 0x08048000),
    ("p_paddr, unused", 4, 0),
    ("p_filesz, program size on disk", 4, "end - ehdr"),
    ("p_memsz, program headers size in memory", 4, "end - ehdr"),
    ("p_flags, rwx = 7", 4, 7),
    ("p_align, usually 0x1000", 4, 4096),
    )

assembler_phdr_load_bss = (
    "phdr_load_bss",
    "Elf32_Phdr, PT_LOAD (.bss)",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of fake .bss segment", 4, "end - ehdr"),
    ("p_vaddr, program virtual address", 4, "end + 0x1000"),
    ("p_paddr, unused", 4, 0),
    ("p_filesz, .bss size on disk", 4, 0),
    ("p_memsz, .bss size in memory", 4, "memory_end - end"),
    ("p_flags, rw = 6", 4, 6),
    ("p_align, usually 0x1000", 4, 4096),
    )

assembler_phdr_dynamic = (
    "phdr_dynamic",
    "Elf32_Phdr, PT_DYNAMIC",
    ("p_type, PT_DYNAMIC = 2", 4, 2),
    ("p_offset, offset of block", 4, "dynamic - ehdr"),
    ("p_vaddr, address of block", 4, "dynamic"),
    ("p_paddr, unused", 4, 0),
    ("p_filesz, block size on disk", 4, "dynamic_end - dynamic"),
    ("p_memsz, block size in memory", 4, "dynamic_end - dynamic"),
    ("p_flags, ignored", 4, 0),
    ("p_align", 4, 4),
    )

assembler_phdr_interp = (
    "phdr_interp",
    "Elf32_Phdr, PT_INTERP",
    ("p_type, PT_INTERP = 3", 4, 3),
    ("p_offset, offset of block", 4, "interp - ehdr"),
    ("p_vaddr, address of block", 4, "interp"),
    ("p_paddr, unused", 4, 0),
    ("p_filesz, block size on disk", 4, "interp_end - interp"),
    ("p_memsz, block size in memory", 4, "interp_end - interp"),
    ("p_flags, ignored", 4, 0),
    ("p_align, 1 for strtab", 4, 1),
    )

assembler_hash = (
    "hash",
    "DT_HASH",
    ("", 4, 1),
    ("", 4, 3),
    ("", 4, 2),
    ("", 4, 0),
    ("", 4, 0),
    ("", 4, 1),
    )

assembler_dynamic = (
    "dynamic",
    "PT_DYNAMIC",
    ("d_tag, DT_HASH = 4", 4, 4),
    ("d_un", 4, "hash"),
    ("d_tag, DT_STRTAB = 5", 4, 5),
    ("d_un", 4, "strtab"),
    ("d_tag, DT_SYMTAB = 6", 4, 6),
    ("d_un", 4, "symtab"),
    ("d_tag, DT_DEBUG = 21", 4, 21),
    ("d_un", 4, 0),
    ("d_tag, DT_NULL = 0", 4, 0),
    ("d_un", 4, 0),
    )

assembler_symtab = (
    "symtab",
    "DT_SYMTAB",
    ("empty symbol", 4, 0),
    ("empty symbol", 4, 0),
    ("unmergable empty symbol", 4, (0, 0)),
    ("st_name", 4, "strtab_environ - strtab"),
    ("st_value", 4, "environ"),
    ("st_size", 4, 4),
    ("st_info", 1, 17),
    ("st_other", 1, 0),
    ("st_shndx", 2, 9),
    ("st_name", 4, "strtab_progname - strtab"),
    ("st_value", 4, "__progname"),
    ("st_size", 4, 4),
    ("st_info", 1, 17),
    ("st_other", 1, 0),
    ("st_shndx", 2, 9),
    )

assembler_interp = (
    "interp",
    "PT_INTERP",
    ("path to interpreter", 1, PlatformVar("interp")),
    ("interpreter terminating zero", 1, 0),
    )

assembler_strtab = (
    "strtab",
    "DT_STRTAB",
    ("initial zero", 1, 0),
    ("symbol name", 1, "\"__progname\"", "progname"),
    ("string terminating zero", 1, 0),
    ("symbol name", 1, "\"environ\"", "environ"),
    ("string terminating zero", 1, 0),
    )

########################################
# Linker ###############################
########################################

class Linker:
  """Linker used to link object files."""

  def __init__(self, op):
    """Constructor."""
    self.command = op
    self.command_basename = os.path.basename(self.command)
    self.library_directories = []
    self.libraries = []
    self.linker_flags = []
    self.linker_script = []

  def generate_library_directory_list(self):
    """Set link directory listing."""
    ret = []
    prefix = "-L"
    if self.command_basename.startswith("cl."):
      prefix = "/L"
    for ii in self.library_directories:
      ret += [prefix + ii]
    if self.command_basename.startswith("ld"):
      ret += ["-rpath-link", ":".join(self.library_directories)]
    return ret

  def generate_library_list(self):
    """Generate link library list libraries."""
    ret = []
    prefix = "-l"
    if self.command_basename.startswith("cl."):
      prefix = "/l"
    for ii in self.libraries:
      ret += [prefix + ii]
    return ret

  def generate_linker_flags(self):
    """Generate linker command for given mode."""
    self.linker_flags = []
    if self.command_basename.startswith("g++") or self.command_basename.startswith("gcc"):
      self.linker_flags += ["-nostartfiles", "-nostdlib", "-Xlinker", "--strip-all"]
    elif self.command_basename.startswith("clang"):
      self.linker_flags += ["-nostdlib", "-Xlinker", "--strip-all"]
    elif self.command_basename.startswith("ld"):
      dynamic_linker = str(PlatformVar("interp"))
      if dynamic_linker.startswith("\"") and dynamic_linker.endswith("\""):
        dynamic_linker = dynamic_linker[1:-1]
      elif dynamic_linker.startswith("0x"):
        dynamic_linker = ""
      self.linker_flags += ["-nostdlib", "--strip-all", "--dynamic-linker=%s" % (dynamic_linker)]
    else:
      raise RuntimeError("compilation not supported with compiler '%s'" % (op))

  def get_library_name(self, op):
    """Get actual name of library."""
    libname = "lib%s.so" % (op)
    # Shared object may be linker script, if so, it will tell actual shared object.
    for ii in self.library_directories:
      current_libname = os.path.join(ii, libname)
      if file_is_ascii_text(current_libname):
        fd = open(current_libname, "r")
        match = re.search(r'GROUP\s*\(\s*(\S+)\s+', fd.read(), re.MULTILINE)
        fd.close()
        if match:
          ret = os.path.basename(match.group(1))
          if verbose:
            print("Using shared library '%s' instead of '%s'." % (ret, libname))
          return ret
    return libname

  def get_linker_script(self, src, dst):
    """Try to link, generate linker script as side effect."""
    return self.link(src, dst, ["--verbose"])

  def link(self, src, dst, extra_args = []):
    """Link a file."""
    cmd = [self.command, src, "-o", dst] + self.linker_flags + self.generate_library_directory_list() + self.generate_library_list() + extra_args + self.linker_script
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)
    return so

  def link_binary(self, src, dst):
    """Link a binary file with no bells and whistles."""
    entry_param = "--entry=" + str(PlatformVar("entry"))
    cmd = [self.command, "--oformat=binary", entry_param, src, "-o", dst]
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)

  def set_libraries(self, lst):
    """Set libraries to link."""
    self.libraries = lst

  def set_library_directories(self, lst):
    self.library_directories = []
    for ii in lst:
      if os.path.isdir(ii):
        self.library_directories += [ii]

  def set_linker_script(self, op):
    """Use given linker script."""
    self.linker_script = ["-T", op]

########################################
# Compiler #############################
########################################

class Compiler(Linker):
  """Compiler used to process C source."""

  def __init__(self, op):
    """Constructor."""
    Linker.__init__(self, op)
    self.compiler_flags = []
    self.compiler_flags_extra = []
    self.definitions = []
    self.include_directories = []

  def add_extra_compiler_flags(self, op):
    """Add extra compiler flags."""
    if is_listing(op):
      for ii in op:
        self.add_extra_compiler_flags(ii)
    elif not op in self.include_directories and not op in self.definitions:
      self.compiler_flags_extra += [op]

  def compile_asm(self, src, dst):
    """Compile a file into assembler source."""
    cmd = [self.command, "-S", src, "-o", dst] + self.compiler_flags + self.compiler_flags_extra + self.definitions + self.include_directories
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)

  def compile_and_link(self, src, dst):
    """Compile and link a file directly."""
    cmd = [self.command, src, "-o", dst] + self.compiler_flags + self.compiler_flags_extra + self.definitions + self.include_directories + self.linker_flags + self.generate_library_directory_list() + self.generate_library_list()
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)

  def generate_compiler_flags(self):
    """Generate compiler flags."""
    self.compiler_flags = []
    if self.command_basename.startswith("g++") or self.command_basename.startswith("gcc"):
      self.compiler_flags += ["-Os", "-ffast-math", "-fno-asynchronous-unwind-tables", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fomit-frame-pointer", "-fsingle-precision-constant", "-fwhole-program", "-march=pentium4", "-mpreferred-stack-boundary=2"]
    elif self.command_basename.startswith("clang"):
      self.compiler_flags += ["-Os", "-ffast-math", "-fno-asynchronous-unwind-tables", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fomit-frame-pointer", "-march=pentium4"]
    else:
      raise RuntimeError("compilation not supported with compiler '%s'" % (self.command_basename))

  def preprocess(self, op):
    """Preprocess a file, return output."""
    args = [self.command, op] + self.compiler_flags_extra + self.definitions + self.include_directories
    if self.command_basename.startswith("cl."):
      args += ["/E"]
    else:
      args += ["-E"]
    (so, se) = run_command(args)
    if 0 < len(se) and verbose:
      print(se)
    return so

  def set_definitions(self, lst):
    """Set definitions."""
    prefix = "-D"
    self.definitions = []
    if self.command_basename.startswith("cl."):
      prefix = "/D"
      self.definitions += [prefix + "WIN32"]
    if isinstance(lst, (list, tuple)):
      for ii in lst:
        self.definitions += [prefix + ii]
    else:
      self.definitions += [prefix + lst]

  def set_include_dirs(self, lst):
    """Set include directory listing."""
    prefix = "-I"
    if os.path.basename(self.command).startswith("cl."):
      prefix = "/I"
    self.include_directories = []
    for ii in lst:
      if os.path.isdir(ii):
        new_include_directory = prefix + ii
        self.include_directories += [new_include_directory]
        self.compiler_flags_extra.remove(new_include_directory)

########################################
# Symbol ###############################
########################################

class Symbol:
  """Represents one (function) symbol."""

  def __init__(self, lst, lib):
    """Constructor."""
    self.returntype = lst[0]
    if isinstance(lst[1], (list, tuple)):
      self.name = lst[1][0]
      self.rename = lst[1][1]
    else:
      self.name = lst[1]
      self.rename = lst[1]
    self.parameters = None
    if 2 < len(lst):
      self.parameters = lst[2:]
    self.library = lib

  def generate_definition(self):
    """Get function definition for given symbol."""
    prefix = ""
    if self.name[:2] == "gl":
      prefix = "DNLOADAPIENTRY "
    params = "void"
    if self.parameters:
      params = ", ".join(self.parameters)
    return "%s (%s*%s)(%s)" % (self.returntype, prefix, self.name, params)

  def generate_prototype(self):
    """Get function prototype for given symbol."""
    prefix = ""
    if self.name[:2] == "gl":
      prefix = "DNLOADAPIENTRY "
    params = "void"
    if self.parameters:
      params = ", ".join(self.parameters)
    return "(%s (%s*)(%s))" % (self.returntype, prefix, params)

  def generate_rename_direct(self):
    """Generate definition to use without a symbol table."""
    return "#define %s%s %s" % (symbol_prefix, self.name, self.rename)

  def generate_rename_tabled(self):
    """Generate definition to use with a symbol table."""
    return "#define %s%s g_symbol_table.%s" % (symbol_prefix, self.name, self.name)

  def get_hash(self):
    """Get the hash of symbol name."""
    return sdbm_hash(self.name)

  def get_library_name(self, linker):
    """Get linkable library object name."""
    return linker.get_library_name(self.library.name)

  def __lt__(self, rhs):
    """Sorting operator."""
    if self.library.name < rhs.library.name:
      return True
    elif self.library.name > rhs.library.name:
      return False
    return self.name < rhs.name

  def __str__(self):
    """String representation."""
    return self.name

########################################
# Library ##############################
########################################

class LibraryDefinition:
  """Represents one library containing symbols."""

  def __init__(self, library_name):
    """Constructor."""
    self.name = library_name
    self.symbols = []

  def add_symbols(self, lst):
    """Add a symbol listing."""
    for ii in lst:
      self.symbols += [Symbol(ii, self)]

  def find_symbol(self, op):
    """Find a symbol by name."""
    for ii in self.symbols:
      if ii.name == op:
        return ii
    return None

library_definition_c = LibraryDefinition("c")
library_definition_c.add_symbols((
  ("void*", "malloc", "size_t"),
  ("int", "puts", "const char*"),
  ("int", ("rand", "bsd_rand")),
  ("void", ("srand", "bsd_srand"), "unsigned int"),
  ))
library_definition_gl = LibraryDefinition("GL")
library_definition_gl.add_symbols((
  ("void", "glActiveTexture", "GLenum"),
  ("void", "glAttachShader", "GLuint", "GLuint"),
  ("void", "glBindFramebuffer", "GLenum", "GLuint"),
  ("void", "glBindTexture", "GLenum", "GLuint"),
  ("void", "glClear", "GLbitfield"),
  ("void", "glClearColor", "GLclampf", "GLclampf", "GLclampf", "GLclampf"),
  ("void", "glCompileShader", "GLuint"),
  ("GLuint", "glCreateProgram"),
  ("GLuint", "glCreateShader", "GLenum"),
  ("void", "glDisable", "GLenum"),
  ("void", "glDisableVertexAttribArray", "GLuint"),
  ("void", "glDrawArrays", "GLenum", "GLint", "GLsizei"),
  ("void", "glEnable", "GLenum"),
  ("void", "glEnableVertexAttribArray", "GLuint"),
  ("void", "glFramebufferTexture2D", "GLenum", "GLenum", "GLenum", "GLuint", "GLint"),
  ("void", "glGenerateMipmap", "GLenum"),
  ("void", "glGenFramebuffers", "GLsizei", "GLuint*"),
  ("void", "glGenTextures", "GLsizei", "GLuint*"),
  ("GLint", "glGetAttribLocation", "GLuint", "const GLchar*"),
  ("GLint", "glGetUniformLocation", "GLuint", "const GLchar*"),
  ("void", "glLineWidth", "GLfloat"),
  ("void", "glLinkProgram", "GLuint"),
  ("void", "glRectf", "GLfloat", "GLfloat", "GLfloat", "GLfloat"),
  ("void", "glRects", "GLshort", "GLshort", "GLshort", "GLshort"),
  ("void", "glShaderSource", "GLuint", "GLsizei", "const GLchar**", "const GLint*"),
  ("void", "glTexImage2D", "GLenum", "GLint", "GLint", "GLsizei", "GLsizei", "GLint", "GLenum", "GLenum", "const GLvoid*"),
  ("void", "glTexImage2DMultisample", "GLenum", "GLsizei", "GLint", "GLsizei", "GLsizei", "GLboolean"),
  ("void", "glTexImage3D", "GLenum", "GLint", "GLint", "GLsizei", "GLsizei", "GLsizei", "GLint", "GLenum", "GLenum", "const GLvoid*"),
  ("void", "glTexParameteri", "GLenum", "GLenum", "GLint"),
  ("void", "glUseProgram", "GLuint"),
  ("void", "glUniform1i", "GLint", "GLint"),
  ("void", "glUniform1f", "GLint", "GLfloat"),
  ("void", "glUniform2i", "GLint", "GLint", "GLint"),
  ("void", "glUniform3f", "GLint", "GLfloat", "GLfloat", "GLfloat"),
  ("void", "glUniform3i", "GLint", "GLint", "GLint", "GLint"),
  ("void", "glUniform4i", "GLint", "GLint", "GLint", "GLint", "GLint"),
  ("void", "glUniform1fv", "GLint", "GLsizei", "const GLfloat*"),
  ("void", "glUniform2fv", "GLint", "GLsizei", "const GLfloat*"),
  ("void", "glUniform3fv", "GLint", "GLsizei", "const GLfloat*"),
  ("void", "glUniform4fv", "GLint", "GLsizei", "const GLfloat*"),
  ("void", "glUniformMatrix3fv", "GLint", "GLsizei", "GLboolean", "const GLfloat*"),
  ("void", "glVertexAttribPointer", "GLuint", "GLint", "GLenum", "GLboolean", "GLsizei", "const GLvoid*"),
  ("void", "glViewport", "GLint", "GLint", "GLsizei", "GLsizei"),
  ))
library_definition_glu = LibraryDefinition("GLU")
library_definition_glu.add_symbols((
  ("GLint", "gluBuild3DMipmaps", "GLenum", "GLint", "GLsizei", "GLsizei", "GLsizei", "GLenum", "GLenum", "const void*"),
  ))
library_definition_m = LibraryDefinition("m")
library_definition_m.add_symbols((
  ("double", "acos", "double"),
  ("float", "acosf", "float"),
  ("float", "powf", "float", "float"),
  ("float", "tanhf", "float")
  ))
library_definition_sdl = LibraryDefinition("SDL")
library_definition_sdl.add_symbols((
  ("void", "SDL_GL_SwapBuffers"),
  ("int", "SDL_Init", "Uint32"),
  ("int", "SDL_OpenAudio", "SDL_AudioSpec*", "SDL_AudioSpec*"),
  ("void", "SDL_PauseAudio", "int"),
  ("int", "SDL_PollEvent", "SDL_Event*"),
  ("void", "SDL_Quit"),
  ("SDL_Surface*", "SDL_SetVideoMode", "int", "int", "int", "Uint32"),
  ("int", "SDL_ShowCursor", "int"),
  ))

library_definitions = [
    library_definition_c,
    library_definition_gl,
    library_definition_glu,
    library_definition_m,
    library_definition_sdl,
    ]

########################################
# C header generation ##################
########################################

template_header_begin = """#ifndef DNLOAD_H
#define DNLOAD_H\n
/** \\file
 * \\brief Dynamic loader header stub.
 *
 * This file was automatically generated by '%s'.
 */\n
#if defined(%s)
#if defined(WIN32)
#include \"windows.h\"
#include \"GL/glew.h\"
#include \"GL/glu.h\"
#include \"SDL.h\"
#elif defined(__APPLE__)
#include \"GL/glew.h\"
#include \"GL/glu.h\"
#include \"SDL/SDL.h\"
#else
#include \"GL/glew.h\"
#include \"GL/glu.h\"
#include \"SDL.h\"
#endif
#include \"bsd_rand.h\"
#else
/** \cond */
#define GL_GLEXT_PROTOTYPES
/** \endcond */
#include \"GL/gl.h\"
#include \"GL/glext.h\"
#include \"GL/glu.h\"
#include \"SDL.h\"
#include \"asm_exit.h\"
#endif\n
#if defined(GLEWAPIENTRY)
/** \cond */
#define DNLOADAPIENTRY GLEWAPIENTRY
/** \endcond */
#else
/** \cond */
#define DNLOADAPIENTRY
/** \endcond */
#endif\n
#if defined(WIN32)
/** \cond */
#define _USE_MATH_DEFINES
/** \endcond */
#endif
#if defined(__cplusplus)
#include <cmath>
#else
#include <math.h>
#endif\n
#if defined(__cplusplus)
extern "C" {
#endif
"""

template_header_end = """
#if defined(__cplusplus)
}
#endif\n
#endif
"""

template_loader = """
#if defined(%s)
/** \cond */
#define dnload()
/** \endcond */
#else
%s
#endif
"""

template_loader_dlfcn = """#include <dlfcn.h>
static const char g_dynstr[] = \"\"
%s;
/** \\brief Perform init.
 *
 * dlopen/dlsym -style.
 */
static void dnload(void)
{
  char *src = (char*)g_dynstr;
  void **dst = (void**)&g_symbol_table;
  do {
    void *handle = dlopen(src, RTLD_LAZY);
    for(;;)
    {
      while(*(src++));
      if(!*(src))
      {
        break;
      }
      *dst++ = dlsym(handle, src);
    }
  } while(*(++src));
}"""

template_loader_hash = """#if defined(__FreeBSD__) || defined(__linux__)
#if defined(__i386)
#include \"dnload_elf32.h\"
#else
#error "no import by hash procedure defined for current architecture"
#endif
#else
#error "no import by hash procedure defined for current operating system"
#endif
/** \\brief Perform init.
 *
 * Import by hash - style.
 */
static void dnload(void)
{
  unsigned ii;
  for(ii = 0; (%i > ii); ++ii)
  {
    void **iter = ((void**)&g_symbol_table) + ii;
    *iter = dnload_find_symbol(*(uint32_t*)iter);
  }
}"""

template_loader_vanilla = """/** \cond */
#define dnload()
/** \endcond */"""

template_symbol_definitions = """
#if defined(%s)
/** \cond */
%s
/** \endcond */
#else
/** \cond */
%s
/** \endcond */
#endif
"""

template_symbol_table = """
#if !defined(%s)
/** \\brief Symbol table structure.
 *
 * Contains all the symbols required for dynamic linking.
 */
static struct SymbolTableStruct
{
%s
} g_symbol_table%s;
#endif
"""

def analyze_source(op):
  """Analyze given preprocessed C source for symbol names."""
  symbolre =  re.compile(r"[\s:;&\|\<\>\=\^\+\-\*/\(\)\?]" + symbol_prefix + "([a-zA-Z0-9_]+)")
  results = symbolre.findall(op, re.MULTILINE)
  ret = set()
  for ii in results:
    symbolset = set()
    symbolset.add(ii)
    ret = ret.union(symbolset)
  return ret

def generate_loader(symbols, linker):
  """Generate the loader code."""
  if "vanilla" == compilation_mode:
    loader_content = generate_loader_vanilla()
  elif "dlfcn" == compilation_mode:
    loader_content = generate_loader_dlfcn(symbols, linker)
  else:
    loader_content = generate_loader_hash(symbols)
  return template_loader % (definition_ld, loader_content)

def generate_loader_dlfcn(symbols, linker):
  """Generate dlopen/dlsym loader code."""
  dlfcn_string = ""
  current_lib = None
  for ii in symbols:
    symbol_lib = ii.library.name
    if current_lib != symbol_lib:
      if current_lib:
        dlfcn_string += "\"\\0%s\\0\"\n" % (ii.get_library_name(linker))
      else:
        dlfcn_string += "\"%s\\0\"\n" % (ii.get_library_name(linker))
      current_lib = symbol_lib
    dlfcn_string += "\"%s\\0\"\n" % (ii)
  dlfcn_string += "\"\\0\""
  return template_loader_dlfcn % (dlfcn_string)

def generate_loader_hash(symbols):
  """Generate import by hash loader code."""
  return template_loader_hash % (len(symbols))

def generate_loader_vanilla():
  """Generate loader that actually leaves the loading to the operating system."""
  return template_loader_vanilla

def generate_symbol_definitions(symbols):
  """Generate a listing of definitions from replacement symbols to real symbols."""
  direct = []
  tabled = []
  for ii in symbols:
    direct += [ii.generate_rename_direct()]
    tabled += [ii.generate_rename_tabled()]
  if "vanilla" == compilation_mode:
    tabled = direct
  return template_symbol_definitions % (definition_ld, "\n".join(direct), "\n".join(tabled))

def generate_symbol_struct(symbols):
  """Generate the symbol struct definition."""
  if "vanilla" == compilation_mode:
    return ""
  definitions = []
  hashes = []
  symbol_table_content = ""
  for ii in symbols:
    definitions += ["  %s;" % (ii.generate_definition())]
    hashes += ["  %s%s," % (ii.generate_prototype(), ii.get_hash())]
  if "dlfcn" != compilation_mode:
    symbol_table_content = " =\n{\n%s\n}" % ("\n".join(hashes))
  return template_symbol_table % (definition_ld, "\n".join(definitions), symbol_table_content)

########################################
# Functions ############################
########################################

def check_executable(op):
  """Check for existence of a single binary."""
  output_string = "Trying binary '%s'... " % (op)
  try:
    proc = subprocess.Popen([op], stdout = subprocess.PIPE, stderr = subprocess.PIPE)
    if proc.poll():
      proc.kill()
  except OSError:
    if verbose:
      print(output_string + "not found")
    return False
  if verbose:
    print(output_string + "found")
  return True

def compress_file(compression, src, dst):
  """Compress a file to be a self-extracting file-dumping executable."""
  if "lzma" == compression:
    command = ["xz", "--format=lzma", "--lzma1=preset=9e,lc=1,lp=0,pb=0", "--stdout"]
    unpack_header = "i=/tmp/i;tail -n+2 $0|lzcat>$i;chmod +x $i;$i;rm $i;exit"
  elif "raw" == compression:
    command = ["xz", "-9", "--extreme", "--format=raw", "--stdout"]
    unpack_header = "i=/tmp/i;tail -n+2 $0|xzcat -F raw>$i;chmod +x $i;$i;rm $i;exit"
  elif "xz" == compression:
    command = ["xz", "--format=xz", "--lzma2=preset=9e,lc=1,pb=0", "--stdout"]
    unpack_header = "i=/tmp/i;tail -n+2 $0|xzcat>$i;chmod +x $i;$i;rm $i;exit"
  else:
    raise 
  (compressed, se) = run_command(command + [src])
  wfd = open(dst, "w")
  wfd.write(unpack_header + "\n")
  wfd.write(compressed)
  wfd.close()
  make_executable(dst)
  print("Wrote '%s': %i bytes" % (dst, os.path.getsize(dst)))

def file_is_ascii_text(op):
  """Check if given file contains nothing but ASCII7 text."""
  if not os.path.isfile(op):
    return False
  fd = open(op)
  while True:
    line = fd.readline()
    if 0 >= len(line):
      fd.close()
      return True
    try:
      line.decode("ascii")
    except UnicodeDecodeError:
      fd.close()
      return False

def find_file(fn, path_list):
  """Search for given file from given paths downward."""
  for ii in path_list:
    ret = locate(ii, fn)
    if ret:
      return ret
  return None

def find_symbol(op):
  """Find single symbol."""
  for ii in library_definitions:
    ret = ii.find_symbol(op)
    if ret:
      return ret
  raise RuntimeError("symbol '%s' not known, please add it to the script" % (symbol))

def find_symbols(lst):
  """Find symbol object(s) corresponding to symbol string(s)."""
  ret = []
  for ii in lst:
    ret += [find_symbol(ii)]
  return ret

def listify(lhs, rhs):
  """Make a list of two elements if reasonable."""
  if not lhs:
    return rhs
  if not rhs:
    return lhs
  if is_listing(lhs) and is_listing(rhs):
    return lhs + rhs
  if is_listing(lhs):
    return lhs + [rhs]
  if is_listing(rhs):
    return [lhs] + rhs
  return [lhs, rhs]

def generate_linker_script(src, dst):
  """Get the linker script from given listing, write improved linker script to given file."""
  match = re.match(r'.*linker script\S+\s*\n=+\s+(.*)\s+=+\s*\n.*', src, re.DOTALL)
  if not match:
    raise RuntimeError("could not extract script from linker output")
  ld_script = re.sub(r'\n([^\n]+)(_end|_edata|__bss_start)(\s*=[^\n]+)\n', r'\n\1/*\2\3*/\n', match.group(1), re.MULTILINE)
  fd = open(dst, "w")
  fd.write(ld_script)
  fd.close()
  if verbose:
    print("Wrote linker script '%s'." % (dst))

def get_friendly_library_name(op):
  """Get library name suitable for labels."""
  return op.replace(".", "_")

def get_indent(op):
  """Get indentation for given level."""
  ret = ""
  for ii in range(op):
    # Would tab be better?
    ret += "  "
  return ret

def is_listing(op):
  """Tell if given parameter is a listing."""
  return isinstance(op, (list, tuple))

def locate(pth, fn):
  """Search for given file from given path downward."""
  pthfn = pth + "/" + fn
  if os.path.isfile(pthfn):
    return os.path.normpath(pthfn)
  for ii in os.listdir(pth):
    iifn = pth + "/" + ii
    if os.path.isdir(iifn):
      ret = locate(iifn, fn)
      if ret:
        return ret
  return None

def make_executable(op):
  """Make given file executable."""
  if not os.stat(op)[stat.ST_MODE] & stat.S_IXUSR:
    run_command(["chmod", "+x", output_file])

def merge_segments(lst):
  """Try to merge segments in a given list in-place."""
  ii = 0
  while True:
    jj = ii + 1
    if len(lst) <= jj:
      return lst
    seg1 = lst[ii]
    seg2 = lst[jj]
    if seg1.merge(seg2):
      if seg2.empty():
        del lst[jj]
      else:
        ii += 1
    else:
      ii += 1
  return lst

def run_command(lst):
  """Run program identified by list of command line parameters."""
  if verbose:
    print("Executing command: %s" % (" ".join(lst)))
  proc = subprocess.Popen(lst, stdout = subprocess.PIPE, stderr = subprocess.PIPE)
  ret = proc.communicate()
  returncode = proc.returncode
  if 0 != proc.returncode:
    raise RuntimeError("command failed: %i, stderr output:\n%s" % (proc.returncode, ret[1]))
  return ret

def sdbm_hash(name):
  """Calculate SDBM hash over a string."""
  ret = 0
  for ii in name:
    ret = (ret * 65599 + ord(ii)) & 0xFFFFFFFF
  return hex(ret)

def search_executable(op):
  """Check for existence of binary, everything within the list will be tried."""
  checked = []
  if isinstance(op, (list, tuple)):
    for ii in op:
      if not ii in checked:
        if check_executable(ii):
          return ii
        else:
          checked += [ii]
  elif isinstance(op, str):
    if not op in checked:
      if check_executable(op):
        return op
      checked += [op]
  else:
    raise RuntimeError("weird argument given to executable search: %s" % (str(op)))
  for ii in default_compiler_list:
    if not ii in checked:
      if check_executable(ii):
        return ii
      checked += [ii]
  return None

def touch(op):
  """Emulate *nix 'touch' command."""
  if not os.path.exists(op):
    if verbose:
      print("Creating nonexistent file '%s'." % (op))
    fd = open(op, "w")
    fd.close()
  elif not os.path.isfile(op):
    raise RuntimeError("'%s' exists but is not a normal file" % (op))

########################################
# Main #################################
########################################

if __name__ == "__main__":
  """Main function."""

  ii = 1
  while ii < len(sys.argv):
    arg = sys.argv[ii]
    if arg in ("-A", "--assembler"):
      ii += 1
      assembler = sys.argv[ii]
    elif arg in ("-C", "--compiler"):
      ii += 1
      compiler = sys.argv[ii]
    elif arg in ("-d", "--define"):
      ii += 1
      definition_ld = sys.argv[ii]
    elif arg in ("-h", "--help"):
      print(string_help)
      sys.exit(0)
    elif arg in ("-I", "--include"):
      ii += 1
      include_directories += [sys.argv[ii]]
    elif arg.startswith("-I"):
      include_directories += [arg[2:]]
    elif arg in ("-k", "--linker"):
      ii += 1
      linker += [sys.argv[ii]]
    elif arg in ("-l", "--library"):
      ii += 1
      libraries += [sys.argv[ii]]
    elif arg.startswith("-l"):
      libraries += [arg[2:]]
    elif arg in ("-L", "--library-directory"):
      ii += 1
      library_directories += [sys.argv[ii]]
    elif arg.startswith("-L"):
      library_directories += [arg[2:]]
    elif arg in ("-m", "--method"):
      ii += 1
      compilation_mode = sys.argv[ii]
    elif arg in ("-o", "--output-file"):
      ii += 1
      output_file = sys.argv[ii]
    elif arg in ("-P", "--call-prefix"):
      ii += 1
      symbol_prefix = sys.argv[ii]
    elif arg in ("-s", "--search-path"):
      ii += 1
      target_search_path += [sys.argv[ii]]
    elif arg in ("-t", "--target"):
      ii += 1
      target = sys.argv[ii]
    elif arg in ("-u", "--unpack-header"):
      ii += 1
      compression = sys.argv[ii]
    elif arg in ("-v", "--verbose"):
      verbose = True
    else:
      source_files += [sys.argv[ii]]
    ii += 1

  if not compilation_mode in ("vanilla", "dlfcn", "hash", "maximum"):
    raise RuntimeError("unknown method '%s'" % (compilation_mode))

  if 0 >= len(target_search_path):
    target_search_path = [ "." ]

  if target == None:
    target = header_file
  target_path, target_file = os.path.split(os.path.normpath(target))
  if target_path:
    if verbose:
      print("Using explicit target header file '%s'." % (target))
    touch(target)
  else:
    target_file = find_file(target, target_search_path)
    if target_file:
      target = os.path.normpath(target_file)
      target_path, target_file = os.path.split(target)
      if verbose:
        print("Header file '%s' found in path '%s/'." % (target_file, target_path))
    else:
      raise RuntimeError("no information where to put header file '%s' - not found in path(s) %s" % (target, str(target_search_path)))

  if 0 >= len(source_files):
    potential_source_files = os.listdir(target_path)
    sourcere = re.compile(r".*(c|cpp)$")
    for ii in potential_source_files:
      if sourcere.match(ii):
        source_files += [target_path + "/" + ii]
    if 0 >= len(source_files):
      raise RuntimeError("could not find any source files in '%s'" % (target_path))

  if compiler:
    if not check_executable(compiler):
      raise RuntimeError("could not use supplied compiler '%s'" % (compiler))
  else:
    if os.name == "nt":
      compiler = search_executable(["cl.exe"] + default_compiler_list)
    else:
      compiler = search_executable(default_compiler_list)
  if not compiler:
    raise RuntimeError("suitable compiler not found")
  compiler = Compiler(compiler)

  sdl_config = search_executable(["sdl-config"])
  if sdl_config:
    (sdl_stdout, sdl_stderr) = run_command([sdl_config, "--cflags"])
    compiler.add_extra_compiler_flags(sdl_stdout.split())
  compiler.set_include_dirs(include_directories)

  if output_file:
    if assembler:
      if not check_executable(assembler):
        raise RuntimeError("could not use supplied compiler '%s'" % (compiler))
    else:
      assembler = search_executable(default_assembler_list)
    if not assembler:
      raise RuntimeError("suitable assembler not found")
    assembler = Assembler(assembler)
    if linker:
      if not check_executable(linker):
        raise RuntimeError("could not use supplied linker '%s'" % (linker))
    else:
      linker = search_executable(default_linker_list)
    linker = Linker(linker)
    if strip:
      if not check_executable(strip):
        raise RuntimeError("could not use supplied strip executable '%s'" % (compiler))
    else:
      strip = search_executable(default_strip_list)
    if not strip:
      raise RuntimeError("suitable strip executable not found")

  compiler.set_definitions(["DNLOAD_H"])
  symbols = set()
  for ii in source_files:
    if verbose:
      print("Analyzing source file '%s'." % (ii))
    so = compiler.preprocess(ii)
    source_symbols = analyze_source(so)
    symbols = symbols.union(source_symbols)
  symbols = find_symbols(symbols)
  if "dlfcn" == compilation_mode:
    symbols = sorted(symbols)

  if verbose:
    symbol_strings = map(lambda x: str(x), symbols)
    print("Symbols found: ['%s']" % ("', '".join(symbol_strings)))

  file_contents = template_header_begin % (os.path.basename(sys.argv[0]), definition_ld)
  file_contents += generate_symbol_definitions(symbols)
  file_contents += generate_symbol_struct(symbols)
  file_contents += generate_loader(symbols, linker)
  file_contents += template_header_end

  fd = open(target, "w")
  fd.write(file_contents)
  fd.close()

  if verbose:
    print("Wrote header file '%s'." % (target))

  if output_file:
    if 1 < len(source_files):
      raise RuntimeError("only one source file supported when generating output file")
    source_file = source_files[0]
    output_file = os.path.normpath(output_file)
    output_path, output_basename = os.path.split(output_file)
    if output_basename == output_file:
      output_path = target_path
    output_file = os.path.normpath(os.path.join(output_path, output_basename))
    compiler.generate_compiler_flags()
    compiler.generate_linker_flags()
    compiler.set_definitions([])
    compiler.set_libraries(libraries)
    compiler.set_library_directories(library_directories)
    linker.generate_linker_flags()
    linker.set_libraries(libraries)
    linker.set_library_directories(library_directories)
    if "maximum" == compilation_mode:
      compiler.compile_asm(source_file, output_file + ".S")
      segment_ehdr = AssemblerSegment(assembler_ehdr)
      segment_phdr_dynamic = AssemblerSegment(assembler_phdr_dynamic)
      segment_phdr_interp = AssemblerSegment(assembler_phdr_interp)
      segment_hash = AssemblerSegment(assembler_hash)
      segment_dynamic = AssemblerSegment(assembler_dynamic)
      segment_symtab = AssemblerSegment(assembler_symtab)
      segment_interp = AssemblerSegment(assembler_interp)
      segment_strtab = AssemblerSegment(assembler_strtab)
      for ii in libraries:
        library_name = linker.get_library_name(ii)
        segment_dynamic.add_dt_needed(library_name)
        segment_strtab.add_library_name(library_name)
      asm = AssemblerFile(output_file + ".S")
      bss_size = asm.generate_fake_bss(assembler)
      # TODO: probably creates incorrect binaries at values very close but less than 128M due to code size
      if 128 * 1024 * 1024 < bss_size:
        replace_platform_variable("phdr_count", 4)
        segment_phdr_load_double = AssemblerSegment(assembler_phdr_load_double)
        segment_phdr_load_bss = AssemblerSegment(assembler_phdr_load_bss)
        load_segments = [segment_phdr_load_double, segment_phdr_load_bss]
        if verbose:
          print("More than 128M of memory used, second PT_LOAD required.")
      else:
        segment_phdr_load_single = AssemblerSegment(assembler_phdr_load_single)
        load_segments = [segment_phdr_load_single]
        if verbose:
          print("Less than 128M of memory used, going with one PT_LOAD.")
      segments = [segment_ehdr] + load_segments + [segment_phdr_dynamic, segment_phdr_interp, segment_hash, segment_dynamic, segment_symtab, segment_interp, segment_strtab]
      segments = merge_segments(segments)
      fd = open(output_file + ".final.S", "w")
      for ii in segments:
        ii.write(fd, assembler)
      asm.write(fd, assembler)
      fd.close()
      if verbose:
        print("Wrote assembler source '%s'." % (output_file + ".final.S"))
      assembler.assemble(output_file + ".final.S", output_file + ".o")
      linker.link_binary(output_file + ".o", output_file + ".stripped")
    elif "hash" == compilation_mode:
      compiler.compile_asm(source_file, output_file + ".S")
      asm = AssemblerFile(output_file + ".S")
      asm.remove_rodata()
      asm.write(output_file + ".final.S", assembler)
      assembler.assemble(output_file + ".final.S", output_file + ".o")
      linker_script = linker.get_linker_script(output_file + ".o", output_file + ".unprocessed")
      generate_linker_script(linker_script, output_file + ".ld")
      linker.set_linker_script(output_file + ".ld")
      linker.link(output_file + ".o", output_file + ".unprocessed")
    elif "dlfcn" == compilation_mode or "vanilla" == compilation_mode:
      compiler.compile_and_link(source_file, output_file + ".unprocessed")
    else:
      raise RuntimeError("unknown compilation mode: %s" % str(compilation_mode))
    if compilation_mode in ("vanilla", "dlfcn", "hash"):
      shutil.copy(output_file + ".unprocessed", output_file + ".stripped")
      run_command([strip, "-K", ".bss", "-K", ".text", "-K", ".data", "-R", ".comment", "-R", ".eh_frame", "-R", ".eh_frame_hdr", "-R", ".fini", "-R", ".gnu.hash", "-R", ".gnu.version", "-R", ".jcr", "-R", ".note", "-R", ".note.ABI-tag", "-R", ".note.tag", output_file + ".stripped"])
    compress_file(compression, output_file + ".stripped", output_file)

  sys.exit(0)
