SUFFIXES = .nsm
.nsm.o:
	nasm -f elf -D AUTOMAKE -o $@ $<

ftoi_SOURCES = ftoi.cpp
pinp_SOURCES = pinp.nsm \
	       dummy.c

noinst_PROGRAMS = ftoi pinp
