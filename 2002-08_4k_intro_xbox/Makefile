KAIKKI = joo ioctl audio 256 256_stdout text comptest

all: $(KAIKKI)

clean:
	-rm $(KAIKKI)

4k_compress : 4k_compress.c
#	nasm -f bin -dCOMPSIZE=0 -dMAGIC_BYTE=0 -o cdh decomp.asm
	gcc -Wall -O2 -march=athlon -o 4k_compress 4k_compress.c

comptest_decomp_hdr : decomp.asm comptest_uncomp comptest_comp
	nasm -f bin -dCOMPSIZE=$(shell filesize comptest_comp) \
	-dMAGIC_BYTE=$(shell 4k_compress 1 -m1 <comptest_uncomp) \
	-dMAGIC_BYTE2=$(shell 4k_compress 1 -m2 <comptest_uncomp) \
	-o comptest_decomp_hdr decomp.asm

comptest_uncomp : comptest.asm
	nasm -f bin -o comptest_uncomp comptest.asm

comptest_comp : comptest.asm comptest_uncomp 4k_compress
	4k_compress 1 <comptest_uncomp >comptest_comp

comptest : comptest_decomp_hdr comptest_comp
	cat comptest_decomp_hdr comptest_comp >comptest
#	-rm comptest_decomp_hdr comptest_comp
	chmod 700 comptest

% : %.asm
	nasm -f bin -o $@ $<
	chmod 700 $@
