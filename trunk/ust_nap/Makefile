ALL=musatest musatest.gz i m m.gz

all: i i.rel

clean:
	-rm -f $(ALL)

m.gz: m
	cat m|gzip -c -9 -n >m.gz

i: m.gz
	cp -f unpackhdr i
	cat m.gz >>i
	chmod 700 i
	ls -l i

i.rel: m.gz
	cp -f unpackhdr.rel i.rel
	cat m.gz >>i.rel
	chmod 700 i.rel
	ls -l i.rel

m: musatest.asm
	nasm -f bin -o $@ $<
	chmod 700 $@