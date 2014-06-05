#!/usr/bin/env python
"""Script to read C/C++ source input and generate a minimal program."""

import argparse
import os
import re
import shutil
import subprocess
import stat
import struct
import sys
import textwrap

########################################
# Globals ##############################
########################################

compilation_mode = "maximum"
definition_ld = "USE_LD"
symbol_prefix = "dnload_"
verbose = False

########################################
# PlatformVar ##########################
########################################

(osname, osignore1, osignore2, osignore3, osarch) = os.uname()

class PlatformVar:
  """Platform-dependent variable."""

  def __init__(self, name):
    """Initialize platform variable."""
    self.name = name

  def get(self):
    """Get value associated with the name."""
    if not self.name in platform_variables:
      raise RuntimeError("unknown platform variable '%s'" % (self.name))
    var = platform_variables[self.name]
    platform = (osname, osarch, platform_map(osname) + "-" + platform_map(osarch))
    for ii in platform:
      if ii in var:
        return var[ii]
      while ii in platform_mapping:
        ii = platform_mapping[ii]
        if ii in var:
          return var[ii]
    if "default" in var:
      return var["default"]
    raise RuntimeError("current platform %s not supported for variable '%s'" % (str(platform), self.name))

  def __int__(self):
    """Convert to integer."""
    ret = self.get()
    if not isinstance(ret, int):
      raise ValueError("not an integer platform variable")
    return ret

  def __str__(self):
    """Convert to string."""
    ret = self.get()
    if isinstance(ret, int):
      return hex(ret)
    return ret

platform_mapping = {
  "amd64" : "64-bit",
  "freebsd" : "FreeBSD",
  "i386" : "ia32",
  "i686" : "ia32",
  "ia32" : "32-bit",
  "linux" : "Linux",
  "x86_64" : "amd64",
  }

platform_variables = {
  "addr" : { "32-bit" : 4, "64-bit" : 8 },
  "align" : { "32-bit" : 4, "64-bit" : 8, "amd64" : 1, "ia32" : 1 },
  "bom" : { "amd64" : "<", "ia32" : "<" },
  "e_machine" : { "amd64" : 62, "ia32" : 3 },
  "ei_class" : { "32-bit" : 1, "64-bit" : 2 },
  "ei_osabi" : { "FreeBSD" : 9, "Linux" : 3 },
  "entry" : { "32-bit" : 0x2000000, "64-bit" : 0x400000 },
  #"entry" : { "32-bit" : 0x8048000, "64-bit" : 0x400000 },
  "interp" : { "FreeBSD" : "\"/libexec/ld-elf.so.1\"", "Linux-32-bit" : "\"/lib/ld-linux.so.2\"", "Linux-64-bit" : "\"/lib64/ld-linux-x86-64.so.2\"" },
  "march" : { "amd64" : "core2", "ia32" : "pentium4" },
  "memory_page" : { "32-bit" : 0x1000, "64-bit" : 0x200000 },
  "mpreferred-stack-boundary" : { "32-bit" : 2, "64-bit" : 4 },
  "phdr_count" : { "default" : 3 },
  }

def platform_map(op):
  """Follow platform mapping chain as long as possible."""
  while op in platform_mapping:
    op = platform_mapping[op]
  return op

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
    self.quad = ".quad"
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
    size = int(size)
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
    elif 8 == size:
      return indent + self.quad + " " + value + "\n"
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
    offset = 0
    size = 0
    bss_elements = []
    for ii in self.sections:
      while True:
        entry = ii.extract_bss()
        if not entry:
          break
        name, size = entry
        bss_elements += [(name, offset)]
        offset += size
        size = offset
        if 0 < offset % 4:
          offset += 4 - (offset % 4)
    # TODO: Probably creates incorrect binaries at values very close but less than 128M due to code size.
    if 128 * 1048576 < size:
      pt_load_string = ", second PT_LOAD required"
      bss_offset = PlatformVar("memory_page")
    else:
      pt_load_string = ", one PT_LOAD sufficient"
      bss_offset = 0
    if verbose:
      outstr = "Constructed fake .bss segement: "
      if 1073741824 < size:
        print("%s%1.1f Gbytes%s" % (outstr, float(size) / 1073741824.0, pt_load_string))
      elif 1048576 < size:
        print("%s%1.1f Mbytes%s" % (outstr, float(size) / 1048576.0, pt_load_string))
      elif 1024 < size:
        print("%s%1.1f kbytes%s" % (outstr, float(size) / 1024.0, pt_load_string))
      else:
        print("%s%u bytes%s" % (outstr, size, pt_load_string))
    bss = AssemblerSection(".bss")
    bss.add_line("end:\n")
    bss.add_line(".balign %i\n" % (int(PlatformVar("addr"))))
    bss.add_line("aligned_end:\n")
    bss.add_line(assembler.format_equ("bss_start", "aligned_end + " + str(bss_offset)))
    for ii in bss_elements:
      bss.add_line(assembler.format_equ(ii[0], "bss_start + %i" % (ii[1])))
    bss.add_line(assembler.format_equ("bss_end", "bss_start + %i" % (size)))
    self.sections += [bss]
    return (0 != bss_offset)

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
    if osarch_is_amd64():
      self.crunch_amd64(lst)
    elif osarch_is_ia32():
      self.crunch_ia32(lst)
    self.tag = None

  def crunch_amd64(self, lst):
    """Perform platform-dependent crunching."""
    self.crunch_entry_push()
    lst = self.want_line(r'\s*(syscall).*')
    if lst:
      ii = lst[0] + 1
      jj = ii
      while True:
        if len(self.content) <= jj or re.match(r'\s*\S+\:\s*', self.content[jj]):
          if verbose:
            print("Erasing function footer after system call: %i lines." % (jj - ii))
          self.erase(ii, jj)
          break
        jj += 1

  def crunch_entry_push(self):
    """Crunch amd64/ia32 push directives from given line listing."""
    lst = self.want_entry_point()
    if not lst:
      return
    ii = lst[0] + 1
    jj = ii
    reinstated_lines = []
    stack_offset = 0
    while True:
      match = re.match(r'\s*(push\S).*', self.content[jj], re.IGNORECASE)
      if match:
        stack_offset += asm_get_push_width(match.group(1))
        jj += 1
        continue;
      # xor (zeroing) seems to be only stuff inserted in the 'middle' of pushing.
      match = re.match(r'\s*xor.*', self.content[jj], re.IGNORECASE)
      if match:
        reinstated_lines += [self.content[jj]]
        jj += 1
        continue
      match = re.match(r'(\s*sub\S*\s+)(\$?\S+)(\s*,\s*\S*[er]sp.*)', self.content[jj], re.IGNORECASE)
      if match:
        addition = match.group(2)
        if "$" == addition[:1]:
          addition = "$" + str(int(addition[1:]) + stack_offset)
        else:
          addition = str(int(addition) + stack_offset)
        self.content[jj] = match.group(1) + addition + match.group(3) + "\n"
      if verbose:
        print("Erasing function header from '%s': %i lines." % (lst[1], jj - ii - len(reinstated_lines)))
      self.erase(ii, jj)
      self.content[ii:ii] = reinstated_lines
      break

  def crunch_ia32(self, lst):
    """Perform platform-dependent crunching."""
    self.crunch_entry_push()
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
    """Remove all .align declarations, replace with desired alignment."""
    desired = int(PlatformVar("align"))
    for ii in range(len(self.content)):
      line = self.content[ii]
      match = re.match(r'.*\.align\s+(\d+).*', line)
      if match:
        align = int(match.group(1))
        # Due to GNU AS compatibility modes, .align may mean different things.
        if osarch_is_amd64 or osarch_is_ia32():
          if desired != align:
            if verbose:
              print("Replacing %i-byte alignment with %i-byte alignment." % (align, desired))
            self.content[ii] = "  .balign %i\n" % (desired)
        else:
          print("Replacing low-order bit alignment %i with %i-byte alignment." % (align, desired))
          self.content[ii] = "  .balign %i\n" % (desired)

  def want_entry_point(self):
    """Want a line matching the entry point function."""
    return self.want_line(r'\s*(_start)\:.*')

  def want_line(self, op, first = 0):
    """Want a line matching regex from object."""
    for ii in range(first, len(self.content)):
      line = self.content[ii]
      match = re.match(op, line, re.IGNORECASE)
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
    self.original_size = -1
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

  def deconstruct(self):
    """Deconstruct into byte stream."""
    try:
      if is_listing(self.value):
        lst = []
        for ii in self.value:
          lst += self.deconstruct_single(int(ii))
      else:
        lst = self.deconstruct_single(int(self.value))
    except ValueError:
      return False
    if 1 >= len(lst):
      return [self]
    ret = []
    for ii in range(len(lst)):
      var = AssemblerVariable(("", 1, ord(lst[ii]), None))
      if 0 == ii:
        var.desc = self.desc
        var.name = self.name
        var.original_size = self.size
        var.label_pre = self.label_pre
      elif len(lst) - 1 == ii:
        var.label_post = self.label_post
      ret += [var]
    return ret

  def deconstruct_single(self, op):
    """Desconstruct a single value."""
    bom = str(PlatformVar("bom"))
    int_size = int(self.size)
    if 1 == int_size:
      return struct.pack(bom + "B", op)
    if 2 == int_size:
      if 0 > op:
        return struct.pack(bom + "h", op)
      else:
        return struct.pack(bom + "H", op)
    elif 4 == int_size:
      if 0 > op:
        return struct.pack(bom + "i", op)
      else:
        return struct.pack(bom + "I", op)
    elif 8 == int_size:
      if 0 > op:
        return struct.pack(bom + "q", op)
      else:
        return struct.pack(bom + "Q", op)
    raise RuntimeError("cannot pack value of size %i" % (int_size))

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
    if int(self.size) != int(op.size):
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

  def reconstruct(self, lst):
    """Reconstruct variable from a listing."""
    original_size = int(self.original_size)
    self.original_size = -1
    if 1 >= original_size:
      return False
    if len(lst) < original_size - 1:
      return False
    ret = chr(self.value)
    for ii in range(original_size - 1):
      op = lst[ii]
      if op.name:
        return False
      if op.label_pre:
        return False
      if op.label_post:
        if (original_size - 2) != ii:
          return False
        self.label_post = listify(self.label_post, op.label_post)
      if "" != op.desc:
        return False
      if -1 != op.original_size:
        return False
      ret += chr(op.value)
    bom = str(PlatformVar("bom"))
    if 2 == original_size:
      self.value = struct.unpack(bom + "H", ret)[0]
    elif 4 == original_size:
      self.value = struct.unpack(bom + "I", ret)[0]
    elif 8 == original_size:
      self.value = struct.unpack(bom + "Q", ret)[0]
    self.size = original_size
    return original_size - 1

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
    self.refresh_name_label()
    self.refresh_name_end_label()

  def add_data(self, op):
    """Add data into this segment."""
    self.data += [AssemblerVariable(op)]
    self.refresh_name_label()
    self.refresh_name_end_label()

  def add_dt_hash(self, op):
    """Add hash dynamic structure."""
    d_tag = AssemblerVariable(("d_tag, DT_HASH = 4", PlatformVar("addr"), 4))
    d_un = AssemblerVariable(("d_un", PlatformVar("addr"), op))
    self.data[0:0] = [d_tag, d_un]
    self.refresh_name_label()

  def add_dt_needed(self, op):
    """Add requirement to given library."""
    d_tag = AssemblerVariable(("d_tag, DT_NEEDED = 1", PlatformVar("addr"), 1))
    d_un = AssemblerVariable(("d_un, library name offset in strtab", PlatformVar("addr"), "strtab_%s - strtab" % labelify(op)))
    self.data[0:0] = [d_tag, d_un]
    self.refresh_name_label()

  def add_dt_symtab(self, op):
    """Add symtab dynamic structure."""
    d_tag = AssemblerVariable(("d_tag, DT_SYMTAB = 6", PlatformVar("addr"), 6))
    d_un = AssemblerVariable(("d_un", PlatformVar("addr"), op))
    self.data[0:0] = [d_tag, d_un]
    self.refresh_name_label()

  def add_hash(self, lst):
    """Generate a minimal DT_HASH based on symbol listing."""
    self.data = []
    num = len(lst) + 1
    self.add_data(("", 4, 1))
    self.add_data(("", 4, num))
    self.add_data(("", 4, num - 1))
    self.add_data(("", 4, 0))
    if 1 < num:
      for ii in range(num - 1):
        self.add_data(("", 4, ii))

  def add_strtab(self, op):
    """Add a library name."""
    libname = AssemblerVariable(("symbol name string", 1, "\"%s\"" % op, labelify(op)))
    terminator = AssemblerVariable(("string terminating zero", 1, 0))
    self.data[1:1] = [libname, terminator]
    self.refresh_name_end_label()

  def add_symbol_empty(self):
    """Add an empty symbol."""
    if osarch_is_32_bit():
      self.add_data(("empty symbol", 4, (0, 0, 0, 0)))
    elif osarch_is_64_bit():
      self.add_data(("empty symbol", 4, (0, 0)))
      self.add_data(("empty symbol", PlatformVar("addr"), (0, 0)))
    else:
      raise_unknown_address_size()

  def add_symbol_und(self, name):
    """Add a symbol to satisfy UND from external source."""
    if osarch_is_32_bit():
      self.add_data(("st_name", 4, "strtab_%s - strtab" % (name)))
      self.add_data(("st_value", PlatformVar("addr"), name))
      self.add_data(("st_size", PlatformVar("addr"), PlatformVar("addr")))
      self.add_data(("st_info", 1, 17))
      self.add_data(("st_other", 1, 0))
      self.add_data(("st_shndx", 2, 1))
    elif osarch_is_64_bit():
      self.add_data(("st_name", 4, "strtab_%s - strtab" % (name)))
      self.add_data(("st_info", 1, 17))
      self.add_data(("st_other", 1, 0))
      self.add_data(("st_shndx", 2, 1))
      self.add_data(("st_value", PlatformVar("addr"), name))
      self.add_data(("st_size", PlatformVar("addr"), PlatformVar("addr")))
    else:
      raise_unknown_address_size()

  def deconstruct_head(self):
    """Deconstruct this segment (starting from head) into a byte stream."""
    ret = []
    for ii in range(len(self.data)):
      op = self.data[ii].deconstruct()
      if not op:
        return (ret, self.data[ii:])
      ret += op
    return (ret, [])

  def deconstruct_tail(self):
    """Deconstruct this segment (starting from tail) into a byte stream."""
    ret = []
    for ii in range(len(self.data)):
      op = self.data[-ii - 1].deconstruct()
      if not op:
        return (self.data[:len(self.data) - ii], ret)
      ret = op + ret
    return ([], ret)

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
    (head_src, bytestream_src) = self.deconstruct_tail()
    (bytestream_dst, tail_dst) = op.deconstruct_head()
    print("me(%s): %i, other: %i" % (self.name, len(bytestream_src), len(bytestream_dst)))
    for ii in range(min(len(bytestream_src), len(bytestream_dst))):
      mergable = True
      for jj in range(ii + 1):
        if not bytestream_src[-ii - 1 + jj].mergable(bytestream_dst[jj]):
          mergable = False
          break
      if mergable:
        highest_mergable = ii + 1
    if 0 >= highest_mergable:
      return False
    if verbose:
      print("Merging headers %s and %s at %i bytes." % (self.name, op.name, highest_mergable))
    for ii in range(highest_mergable):
      bytestream_src[-highest_mergable + ii].merge(bytestream_dst[ii])
    bytestream_dst[0:highest_mergable] = []
    self.reconstruct(head_src + bytestream_src)
    op.reconstruct(bytestream_dst + tail_dst)
    return True

  def reconstruct(self, bytestream):
    """Reconstruct data from bytestream."""
    self.data = []
    while 0 < len(bytestream):
      front = bytestream[0]
      if self.name == "phdr_interp":
        print("%s: %s (%s)" % (front.desc, str(front.value), str(front.original_size)))
      bytestream = bytestream[1:]
      constructed = front.reconstruct(bytestream)
      if constructed:
        bytestream[:constructed] = []
      self.data += [front]

  def refresh_name_label(self):
    """Add name label to first assembler variable."""
    for ii in self.data:
      ii.remove_label_pre(self.name)
    if 0 < len(self.data):
      self.data[0].add_label_pre(self.name)

  def refresh_name_end_label(self):
    """Add a name end label to last assembler variable."""
    end_label = "%s_end" % (self.name)
    for ii in self.data:
      ii.remove_label_post(end_label)
    if 0 < len(self.data):
      self.data[-1].add_label_post(end_label)

  def write(self, fd, assembler):
    """Write segment onto disk."""
    if 0 >= len(self.data):
      raise RuntimeError("segment '%s' is empty" % self.name)
    fd.write(self.generate_source(assembler))

assembler_ehdr = (
    "ehdr",
    "Elf32_Ehdr or Elf64_Ehdr",
    ("e_ident[EI_MAG0], magic value 0x7F", 1, 0x7F),
    ("e_ident[EI_MAG1] to e_indent[EI_MAG3], magic value \"ELF\"", 1, "\"ELF\""),
    ("e_ident[EI_CLASS], ELFCLASS32 = 1, ELFCLASS64 = 2", 1, PlatformVar("ei_class")),
    ("e_ident[EI_DATA], ELFDATA2LSB = 1, ELFDATA2MSB = 2", 1, 1),
    ("e_ident[EI_VERSION], EV_CURRENT = 1", 1, 1),
    ("e_ident[EI_OSABI], ELFOSABI_LINUX = 3, ELFOSABI_FREEBSD = 9", 1, PlatformVar("ei_osabi")),
    ("e_ident[EI_ABIVERSION], always 0", 1, 0),
    ("e_indent[EI_MAG10 to EI_MAG15], unused", 1, (0, 0, 0, 0, 0, 0, 0)),
    ("e_type, ET_EXEC = 2", 2, 2),
    ("e_machine, EM_386 = 3, EM_X86_64 = 62", 2, PlatformVar("e_machine")),
    ("e_version, EV_CURRENT = 1", 4, 1),
    ("e_entry, execution starting point", PlatformVar("addr"), "_start"),
    ("e_phoff, offset from start to program headers", PlatformVar("addr"), "ehdr_end - ehdr"),
    ("e_shoff, start of section headers", PlatformVar("addr"), 0),
    ("e_flags, unused", 4, 0),
    ("e_ehsize, Elf32_Ehdr size", 2, "ehdr_end - ehdr"),
    ("e_phentsize, Elf32_Phdr size", 2, "phdr_load_end - phdr_load"),
    ("e_phnum, Elf32_Phdr count, PT_LOAD, [PT_LOAD (bss)], PT_INTERP, PT_DYNAMIC", 2, PlatformVar("phdr_count")),
    ("e_shentsize, Elf32_Shdr size", 2, 0),
    ("e_shnum, Elf32_Shdr count", 2, 0),
    ("e_shstrndx, index of section containing string table of section header names", 2, 0),
    )

assembler_phdr32_load_single = (
    "phdr_load",
    "Elf32_Phdr, PT_LOAD",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of program start", PlatformVar("addr"), 0),
    ("p_vaddr, program virtual address", PlatformVar("addr"), PlatformVar("entry")),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, program size on disk", PlatformVar("addr"), "end - ehdr"),
    ("p_memsz, program size in memory", PlatformVar("addr"), "bss_end - ehdr"),
    ("p_flags, rwx = 7", 4, 7),
    ("p_align, usually 0x1000", PlatformVar("addr"), PlatformVar("memory_page")),
    )

assembler_phdr32_load_double = (
    "phdr_load",
    "Elf32_Phdr, PT_LOAD",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of program start", PlatformVar("addr"), 0),
    ("p_vaddr, program virtual address", PlatformVar("addr"), PlatformVar("entry")),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, program size on disk", PlatformVar("addr"), "end - ehdr"),
    ("p_memsz, program headers size in memory", PlatformVar("addr"), "end - ehdr"),
    ("p_flags, rwx = 7", 4, 7),
    ("p_align, usually " + str(PlatformVar("memory_page")), PlatformVar("addr"), PlatformVar("memory_page")),
    )

assembler_phdr32_load_bss = (
    "phdr_load_bss",
    "Elf32_Phdr, PT_LOAD (.bss)",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_offset, offset of fake .bss segment", PlatformVar("addr"), "end - ehdr"),
    ("p_vaddr, program virtual address", PlatformVar("addr"), "bss_start"),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, .bss size on disk", PlatformVar("addr"), 0),
    ("p_memsz, .bss size in memory", PlatformVar("addr"), "bss_end - end"),
    ("p_flags, rw = 6", 4, 6),
    ("p_align, usually " + str(PlatformVar("memory_page")), PlatformVar("addr"), PlatformVar("memory_page")),
    )

assembler_phdr32_dynamic = (
    "phdr_dynamic",
    "Elf32_Phdr, PT_DYNAMIC",
    ("p_type, PT_DYNAMIC = 2", 4, 2),
    ("p_offset, offset of block", PlatformVar("addr"), "dynamic - ehdr"),
    ("p_vaddr, address of block", PlatformVar("addr"), "dynamic"),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, block size on disk", PlatformVar("addr"), "dynamic_end - dynamic"),
    ("p_memsz, block size in memory", PlatformVar("addr"), "dynamic_end - dynamic"),
    ("p_flags, ignored", 4, 0),
    ("p_align", PlatformVar("addr"), 1),
    )

assembler_phdr32_interp = (
    "phdr_interp",
    "Elf32_Phdr, PT_INTERP",
    ("p_type, PT_INTERP = 3", 4, 3),
    ("p_offset, offset of block", PlatformVar("addr"), "interp - ehdr"),
    ("p_vaddr, address of block", PlatformVar("addr"), "interp"),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, block size on disk", PlatformVar("addr"), "interp_end - interp"),
    ("p_memsz, block size in memory", PlatformVar("addr"), "interp_end - interp"),
    ("p_flags, ignored", 4, 0),
    ("p_align, 1 for strtab", PlatformVar("addr"), 1),
    )

assembler_phdr64_load_single = (
    "phdr_load",
    "Elf64_Phdr, PT_LOAD",
    ("p_type, PT_LOAD = 1", 4, 1),
    ("p_flags, rwx = 7", 4, 7),
    ("p_offset, offset of program start", PlatformVar("addr"), 0),
    ("p_vaddr, program virtual address", PlatformVar("addr"), PlatformVar("entry")),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, program size on disk", PlatformVar("addr"), "end - ehdr"),
    ("p_memsz, program size in memory", PlatformVar("addr"), "bss_end - ehdr"),
    ("p_align, usually " + str(PlatformVar("memory_page")), PlatformVar("addr"), PlatformVar("memory_page")),
    )

assembler_phdr64_dynamic = (
    "phdr_dynamic",
    "Elf64_Phdr, PT_DYNAMIC",
    ("p_type, PT_DYNAMIC = 2", 4, 2),
    ("p_flags, ignored", 4, 0),
    ("p_offset, offset of block", PlatformVar("addr"), "dynamic - ehdr"),
    ("p_vaddr, address of block", PlatformVar("addr"), "dynamic"),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, block size on disk", PlatformVar("addr"), "dynamic_end - dynamic"),
    ("p_memsz, block size in memory", PlatformVar("addr"), "dynamic_end - dynamic"),
    ("p_align", PlatformVar("addr"), 1),
    )

assembler_phdr64_interp = (
    "phdr_interp",
    "Elf64_Phdr, PT_INTERP",
    ("p_type, PT_INTERP = 3", 4, 3),
    ("p_flags, ignored", 4, 0),
    ("p_offset, offset of block", PlatformVar("addr"), "interp - ehdr"),
    ("p_vaddr, address of block", PlatformVar("addr"), "interp"),
    ("p_paddr, unused", PlatformVar("addr"), 0),
    ("p_filesz, block size on disk", PlatformVar("addr"), "interp_end - interp"),
    ("p_memsz, block size in memory", PlatformVar("addr"), "interp_end - interp"),
    ("p_align, 1 for strtab", PlatformVar("addr"), 1),
    )

assembler_hash = (
    "hash",
    "DT_HASH",
    )

assembler_dynamic = (
    "dynamic",
    "PT_DYNAMIC",
    ("d_tag, DT_STRTAB = 5", PlatformVar("addr"), 5),
    ("d_un", PlatformVar("addr"), "strtab"),
    ("d_tag, DT_DEBUG = 21", PlatformVar("addr"), 21),
    ("d_un", PlatformVar("addr"), 0),
    ("d_tag, DT_NULL = 0", PlatformVar("addr"), 0),
    ("d_un", PlatformVar("addr"), 0),
    )

assembler_symtab = (
    "symtab",
    "DT_SYMTAB",
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
    if op.startswith("/"):
      return op
    # Check if the library is specified verbatim. If yes, no need to expand.
    if re.match(r'lib.+\.so(\..*)?', op):
      return op
    libname = "lib%s.so" % (op)
    # Shared object may be linker script, if so, it will tell actual shared object.
    for ii in self.library_directories:
      current_libname = locate(ii, libname)
      if current_libname and file_is_ascii_text(current_libname):
        fd = open(current_libname, "r")
        match = re.search(r'GROUP\s*\(\s*(\S+)\s+', fd.read(), re.MULTILINE)
        fd.close()
        if match:
          ret = os.path.basename(match.group(1))
          if verbose:
            print("Using shared library '%s' instead of '%s'." % (ret, libname))
          return ret
    return libname

  def generate_linker_script(self, dst):
    """Get linker script from linker, improve it, write improved linker script to given file."""
    (so, se) = run_command([self.command, "--verbose"])
    if 0 < len(se) and verbose:
      print(se)
    match = re.match(r'.*linker script\S+\s*\n=+\s+(.*)\s+=+\s*\n.*', so, re.DOTALL)
    if not match:
      raise RuntimeError("could not extract script from linker output")
    ld_script = match.group(1)
    ld_script = re.sub(r'\n([^\n]+)(_end|_edata|__bss_start)(\s*=[^\n]+)\n', r'\n\1/*\2\3*/\n', ld_script, re.MULTILINE)
    ld_script = re.sub(r'SEGMENT_START\s*\(\s*(\S+)\s*,\s*\d*x?\d+\s*\)', r'SEGMENT_START(\1, %s)' % (str(PlatformVar("entry"))), ld_script, re.MULTILINE)
    fd = open(dst, "w")
    fd.write(ld_script)
    fd.close()
    if verbose:
      print("Wrote linker script '%s'." % (dst))
    return ld_script

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
    cmd = [self.command, "--oformat=binary", entry_param, src, "-o", dst] + self.linker_script
    (so, se) = run_command(cmd)
    if 0 < len(se) and verbose:
      print(se)
    return so

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
      self.compiler_flags += ["-Os", "-ffast-math", "-fno-asynchronous-unwind-tables", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fomit-frame-pointer", "-fsingle-precision-constant", "-fwhole-program", "-march=%s" % (str(PlatformVar("march"))), "-mpreferred-stack-boundary=%i" % (int(PlatformVar("mpreferred-stack-boundary"))), "-Wall"]
    elif self.command_basename.startswith("clang"):
      self.compiler_flags += ["-Os", "-ffast-math", "-fno-asynchronous-unwind-tables", "-fno-exceptions", "-fno-rtti", "-fno-threadsafe-statics", "-fomit-frame-pointer", "-march=%s" % (str(PlatformVar("march"))), "-Wall"]
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
        if new_include_directory in self.compiler_flags_extra:
          self.compiler_flags_extra.remove(new_include_directory)
        self.include_directories += [new_include_directory]

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
#if (defined(_LP64) && _LP64) || (defined(__LP64__) && __LP64__)
/** Size of pointer in bytes (64-bit). */
#define DNLOAD_POINTER_SIZE 8
#else
/** Size of pointer in bytes (32-bit). */
#define DNLOAD_POINTER_SIZE 4
#endif\n
#if !defined(%s)
#if defined(__x86_64)
#if defined(__FreeBSD__)
/** Assembler exit syscall macro. */
#define asm_exit() asm volatile("movq $1,%%rax\\nsyscall")
#elif defined(__linux__)
/** Assembler exit syscall macro. */
#define asm_exit() asm volatile("movq $60,%%rax\\nsyscall")
#endif
#elif defined(__i386)
#if defined(__FreeBSD__) || defined(__linux__)
/** Assembler exit syscall macro. */
#define asm_exit() asm volatile("movl $1,%%eax\\nint $128")
#endif
#endif
#if !defined(asm_exit)
#error "no assembler exit procedure defined for current operating system or architecture"
#endif
#endif\n
#if defined(__cplusplus)
extern "C" {
#endif\n
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

template_loader_hash = """#include <stdint.h>
/** \\brief SDBM hash function.
 *
 * \\param op String to hash.
 * \\return Full hash.
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
typedef Elf_Sword dnload_elf_tag_t;
#endif
/** \\brief ELF base address. */
#define ELF_BASE_ADDRESS %s
/** \\brief Get the address associated with given tag in a dynamic section.
 *
 * \\param dyn Dynamic section.
 * \\param tag Tag to look for.
 * \\return Address matching given tag.
 */
static const void* elf_get_dynamic_address_by_tag(const void *dyn, dnload_elf_tag_t tag)
{
  const dnload_elf_dyn_t *dynamic = (const dnload_elf_dyn_t*)dyn;
  for(;;)
  {
    if(dynamic->d_tag == tag)
    {
      return (const void*)dynamic->d_un.d_ptr;
    }
    ++dynamic;
  }
}
/** \\brief Get the program link map.
 *
 * \\return Link map struct.
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
/** \\brief Get address of one dynamic section corresponding to given library.
 *
 * \param lmap Link map.
 * \param tag Tag to look for.
 */
static const void* elf_get_library_dynamic_section(const struct link_map *lmap, dnload_elf_tag_t tag)
{
  const void *ret = elf_get_dynamic_address_by_tag(lmap->l_ld, tag);
  // Sometimes the value is an offset instead of a naked pointer.
  if(ret < (const void*)lmap->l_addr)
  {
    return (uint8_t*)ret + (size_t)lmap->l_addr;
  }
  return ret;
}
/** \\brief Find a symbol in any of the link maps.
 *
 * Should a symbol with name matching the given hash not be present, this function will happily continue until
 * we crash. Size-minimal code has no room for error checking.
 *
 * \\param hash Hash of the function name string.
 * \\return Symbol found.
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
    unsigned numchains = hashtable[1]; /* Number of symbols. */
    unsigned ii;
    for(ii = 0; (ii < numchains); ++ii)
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
  return template_loader_hash % (str(PlatformVar("entry")), len(symbols))

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

def asm_get_push_width(op):
  """Get width of push instruction."""
  op = op.lower()
  if "pushq" == op:
    return 8
  elif "pushl" == op:
    return 4
  raise RuntimeError("width of push instruction '%s' not known" % (op))

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

def labelify(op):
  """Take string as input. Convert into string that passes as label."""
  return re.sub(r'[\/\.]', '_', op)

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
  if is_listing(pth):
    for ii in pth:
      ret = locate(ii, fn)
      if ret:
        return ret
    return None
  pthfn = pth + "/" + fn
  if os.path.isfile(pthfn):
    return os.path.normpath(pthfn)
  try:
    for ii in os.listdir(pth):
      iifn = pth + "/" + ii
      if os.path.isdir(iifn):
        ret = locate(iifn, fn)
        if ret:
          return ret
  except OSError as ee: # Permission denied or the like.
    if 13 == ee.errno:
      return None
    raise ee
  return None

def make_executable(op):
  """Make given file executable."""
  if not os.stat(op)[stat.ST_MODE] & stat.S_IXUSR:
    run_command(["chmod", "+x", op])

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

def osarch_is_32_bit():
  """Check if the architecture is 32-bit."""
  return osarch_match("32-bit")

def osarch_is_64_bit():
  """Check if the architecture is 32-bit."""
  return osarch_match("64-bit")

def osarch_is_amd64():
  """Check if the architecture maps to amd64."""
  return osarch_match("amd64")

def osarch_is_ia32():
  """Check if the architecture maps to ia32."""
  return osarch_match("ia32")

def osarch_match(op):
  """Check if osarch matches some chain resulting in given value."""
  if op == osarch:
    return True
  ii = osarch
  while ii in platform_mapping:
    ii = platform_mapping[ii]
    if op == ii:
      return True
  return False

def osname_is_freebsd():
  """Check if the operating system name maps to FreeBSD."""
  return ("FreeBSD" == osname)

def osname_is_linux():
  """Check if the operating system name maps to Linux."""
  return ("Linux" == osname)

def raise_unknown_address_size():
  """Common function to raise an error if os architecture address size is unknown."""
  raise RuntimeError("platform '%s' addressing size unknown" % (osarch))

def readelf_truncate(src, dst):
  """Truncate file to size reported by readelf first PT_LOAD file size."""
  (so, se) = run_command(["readelf", "--program-headers", src])
  match = re.search(r'LOAD\s+\S+\s+\S+\s+\S+\s+(\S+)\s+', so, re.MULTILINE)
  if match:
    truncate_size = int(match.group(1), 0)
  else:
    raise RuntimeError("could not read file size from executable '%s'" % (src))
  size = os.path.getsize(src)
  if size == truncate_size:
    if verbose:
      print("Executable size equals PT_LOAD size (%u bytes), no truncation necessary." % (size))
    shutil.copy(src, dst)
  else:
    print("Truncating file size to PT_LOAD size: %u bytes" % (truncate_size))
    rfd = open(src, "r")
    wfd = open(dst, "w")
    wfd.write(rfd.read(truncate_size))
    rfd.close()
    wfd.close()

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
# CustomHelpFormatter ##################
########################################

class CustomHelpFormatter(argparse.HelpFormatter):
  """Help formatter with necessary changes."""

  def _fill_text(self, text, width, indent):
    """Method override."""
    ret = []
    for ii in text.splitlines():
      ret += [textwrap.fill(ii, width, initial_indent=indent, subsequent_indent=indent)]
    return "\n\n".join(ret)

  def _split_lines(self, text, width):
    """Method override."""
    indent_len = len(get_indent(1))
    ret = []
    for ii in text.splitlines():
      indent = 0
      for jj in range(len(ii)):
        if not ii[jj].isspace():
          indent = jj
          break
      lines = textwrap.wrap(ii[indent:], width - jj * indent_len)
      for ii in range(len(lines)):
        lines[ii] = get_indent(indent) + lines[ii]
      ret += lines
    return ret

########################################
# Main #################################
########################################

def main():
  """Main function."""
  global compilation_mode
  global definition_ld
  global osname
  global symbol_prefix
  global verbose

  assembler = None
  cross_compile = False
  compiler = None
  compression = "lzma"
  default_assembler_list = ["/usr/local/bin/as", "as"]
  default_compiler_list = ["g++49", "g++-4.9", "g++", "clang++"]
  default_linker_list = ["/usr/local/bin/ld", "ld"]
  default_strip_list = ["/usr/local/bin/strip", "strip"]
  include_directories = ["/usr/include/SDL", "/usr/local/include", "/usr/local/include/SDL"]
  libraries = []
  library_directories = ["/lib", "/lib/x86_64-linux-gnu", "/usr/lib", "/usr/lib/x86_64-linux-gnu", "/usr/local/lib"]
  linker = None
  output_file = None
  source_files = []
  strip = None
  target_search_path = []
  version = "r106"

  parser = argparse.ArgumentParser(usage = "%s [args] <source file(s)> [-o output]" % (sys.argv[0]), description = "Size-optimized executable generator for *nix platforms.\nPreprocesses given source file(s) looking for specifically marked function calls, then generates a dynamic loader header file that can be used within these same source files to decrease executable size.\nOptionally also perform the actual compilation of a size-optimized binary after generating the header.", formatter_class = CustomHelpFormatter, add_help = False)
  parser.add_argument("-A", "--assembler", help = "Try to use given assembler executable as opposed to autodetect.")
  parser.add_argument("-c", "--create-binary", action = "store_true", help = "Create output file, determine output file name from input file name.")
  parser.add_argument("-C", "--compiler", help = "Try to use given compiler executable as opposed to autodetect.")
  parser.add_argument("-d", "--define", default = "USE_LD", help = "Definition to use for checking whether to use 'safe' mechanism instead of dynamic loading.\n(default: %(default)s)")
  parser.add_argument("-h", "--help", action = "store_true", help = "Print this help string and exit.")
  parser.add_argument("-I", "--include-directory", action = "append", help = "Add an include directory to be searched for header files.")
  parser.add_argument("-k", "--linker", help = "Try to use given linker executable as opposed to autodetect.")
  parser.add_argument("-l", "--library", action = "append", help = "Add a library to be linked against.")
  parser.add_argument("-L", "--library-directory", action = "append", help = "Add a library directory to be searched for libraries when linking.")
  parser.add_argument("-m", "--method", default = compilation_mode, choices = ("vanilla", "dlfcn", "hash", "maximum"), help = "Method to use for decreasing output file size:\n\tvanilla:\n\t\tProduce binary normally, use no tricks except unpack header.\n\tdlfcn:\n\t\tUse dlopen/dlsym to decrease size without dependencies to any specific object format.\n\thash:\n\t\tUse knowledge of object file format to perform 'import by hash' loading, but do not break any specifications.\n\tmaximum:\n\t\tUse all available techniques to decrease output file size. Resulting file may violate object file specification.\n(default: %(default)s)")
  parser.add_argument("-o", "--output-file", help = "Compile a named binary, do not only create a header. If the name specified features a path, it will be used verbatim. Otherwise the binary will be created in the same path as source file(s) compiled.")
  parser.add_argument("-O", "--operating-system", help = "Try to target given operating system insofar cross-compilation is possible.")
  parser.add_argument("-P", "--call-prefix", default = symbol_prefix, help = "Call prefix to identify desired calls.\n(default: %(default)s)")
  parser.add_argument("-s", "--search-path", action = "append", help = "Directory to search for the header file to generate. May be specified multiple times. If not given, searches paths of source files to compile. If not given and no source files to compile, current path will be used.")
  parser.add_argument("-S", "--strip-binary", help = "Try to use given strip executable as opposed to autodetect.")
  parser.add_argument("-t", "--target", default = "dnload.h", help = "Target header file to look for.\n(default: %(default)s)")
  parser.add_argument("-u", "--unpack-header", choices = ("lzma", "xz"), default = "lzma", help = "Unpack header to use.\n(default: %(default)s)")
  parser.add_argument("-v", "--verbose", action = "store_true", help = "Print more about what is being done.")
  parser.add_argument("-V", "--version", action = "store_true", help = "Print version and exit.")
  parser.add_argument("source", nargs = "*", help = "Source file(s) to preprocess and/or compile.")
 
  args = parser.parse_args()
  if args.assembler:
    assembler = args.assembler
  if args.create_binary:
    output_file = True
  if args.compiler:
    compiler = args.compiler
  if args.help:
    print(parser.format_help().strip())
    return 0
  if args.include_directory:
    include_directories += args.include_directory
  if args.linker:
    linker = args.linker
  if args.library:
    libraries += args.library
  if args.library_directory:
    library_directories += args.library_directory
  if args.operating_system:
    new_osname = platform_map(args.operating_system.lower())
    if new_osname != osname:
      cross_compile = True
      osname = new_osname
  if args.output_file:
    output_file = args.output_file
  if args.search_path:
    target_search_path += args.search_path
  if args.strip_binary:
    strip = args.strip_binary
  if args.verbose:
    verbose = True
  if args.version:
    print(version)
    return 0
  if args.source:
    source_files += args.source

  definition_ld = args.define
  compilation_mode = args.method
  compression = args.unpack_header
  symbol_prefix = args.call_prefix
  target = args.target

  if not compilation_mode in ("vanilla", "dlfcn", "hash", "maximum"):
    raise RuntimeError("unknown method '%s'" % (compilation_mode))

  if 0 >= len(target_search_path):
    for ii in source_files:
      source_path, source_file = os.path.split(os.path.normpath(ii))
      if source_path and not source_path in target_search_path:
        target_search_path += [source_path]
  if 0 >= len(target_search_path):
    target_search_path = ["."]

  target_path, target_file = os.path.split(os.path.normpath(target))
  if target_path:
    if verbose:
      print("Using explicit target header file '%s'." % (target))
    touch(target)
  else:
    target_file = locate(target_search_path, target)
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

  file_contents = template_header_begin % (os.path.basename(sys.argv[0]), definition_ld, definition_ld)
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
    if not isinstance(output_file, str):
      output_path, output_basename = os.path.split(source_file)
      output_basename, source_extension = os.path.splitext(output_basename)
      output_file = os.path.normpath(os.path.join(output_path, output_basename))
      if verbose:
        print("Using output file '%s' after source file '%s'." % (output_file, source_file))
    else:
      output_file = os.path.normpath(output_file)
      output_path, output_basename = os.path.split(output_file)
      if output_basename == output_file:
        output_path = target_path
      output_file = os.path.normpath(os.path.join(output_path, output_basename))
    libraries = sorted(libraries)
    if verbose:
      print("Linking against libraries: %s" % (str(libraries)))
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
      if osarch_is_32_bit():
        segment_phdr_dynamic = AssemblerSegment(assembler_phdr32_dynamic)
        segment_phdr_interp = AssemblerSegment(assembler_phdr32_interp)
      elif osarch_is_64_bit():
        segment_phdr_dynamic = AssemblerSegment(assembler_phdr64_dynamic)
        segment_phdr_interp = AssemblerSegment(assembler_phdr64_interp)
      else:
        raise_unknown_address_size()
      segment_dynamic = AssemblerSegment(assembler_dynamic)
      segment_hash = AssemblerSegment(assembler_hash)
      segment_interp = AssemblerSegment(assembler_interp)
      segment_strtab = AssemblerSegment(assembler_strtab)
      segment_symtab = AssemblerSegment(assembler_symtab)
      und_symbol_string = "Checking for required UND symbols... "
      if osname_is_freebsd():
        und_symbols = sorted(["environ", "__progname"])
      else:
        und_symbols = None
      if verbose:
        print(und_symbol_string + str(und_symbols))
      if is_listing(und_symbols):
        segment_symtab.add_symbol_empty()
        for ii in und_symbols:
          segment_symtab.add_symbol_und(ii)
        for ii in reversed(und_symbols):
          segment_strtab.add_strtab(ii)
        segment_dynamic.add_dt_symtab("symtab")
        segment_dynamic.add_dt_hash("hash")
        segment_hash.add_hash(und_symbols)
      else:
        segment_dynamic.add_dt_symtab(0)
      for ii in reversed(libraries):
        library_name = linker.get_library_name(ii)
        segment_dynamic.add_dt_needed(library_name)
        segment_strtab.add_strtab(library_name)
      asm = AssemblerFile(output_file + ".S")
      # generate_fake_bss() returns true if second PT_LOAD was needed.
      if asm.generate_fake_bss(assembler):
        replace_platform_variable("phdr_count", 4)
        if osarch_is_32_bit():
          segment_phdr_load_double = AssemblerSegment(assembler_phdr32_load_double)
          segment_phdr_load_bss = AssemblerSegment(assembler_phdr32_load_bss)
        elif osarch_is_64_bit():
          segment_phdr_load_double = AssemblerSegment(assembler_phdr64_load_double)
          segment_phdr_load_bss = AssemblerSegment(assembler_phdr64_load_bss)
        else:
          raise_unknown_address_size()
        load_segments = [segment_phdr_load_double, segment_phdr_load_bss]
      else:
        if osarch_is_32_bit():
          segment_phdr_load_single = AssemblerSegment(assembler_phdr32_load_single)
        elif osarch_is_64_bit():
          segment_phdr_load_single = AssemblerSegment(assembler_phdr64_load_single)
        else:
          raise_unknown_address_size()
        load_segments = [segment_phdr_load_single]
      segments = [segment_ehdr] + load_segments + [segment_phdr_dynamic, segment_phdr_interp]
      if is_listing(und_symbols):
        segments += [segment_hash]
      segments += [segment_dynamic]
      if is_listing(und_symbols):
        segments += [segment_symtab]
      segments += [segment_interp, segment_strtab]
      segments = merge_segments(segments)
      fd = open(output_file + ".final.S", "w")
      for ii in segments:
        ii.write(fd, assembler)
      asm.write(fd, assembler)
      fd.close()
      if verbose:
        print("Wrote assembler source '%s'." % (output_file + ".final.S"))
      assembler.assemble(output_file + ".final.S", output_file + ".o")
      linker.generate_linker_script(output_file + ".ld")
      linker.set_linker_script(output_file + ".ld")
      linker.link_binary(output_file + ".o", output_file + ".unprocessed")
      readelf_truncate(output_file + ".unprocessed", output_file + ".stripped")
    elif "hash" == compilation_mode:
      compiler.compile_asm(source_file, output_file + ".S")
      asm = AssemblerFile(output_file + ".S")
      asm.remove_rodata()
      asm.write(output_file + ".final.S", assembler)
      assembler.assemble(output_file + ".final.S", output_file + ".o")
      linker.generate_linker_script(output_file + ".ld")
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

  return 0

if __name__ == "__main__":
  sys.exit(main())
