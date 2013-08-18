BITS 32	
section .text code align=1
		
	org     0x08000000
		
ehdr:						                ; Elf32_Ehdr
	db      0x7F, "ELF", 1, 1, 1	;   e_ident (ELF)
	db	"/dev/dsp",0
	dw      2		;   e_type    (executable)
	dw      3		;   e_machine (i386)
	dd      1		;   e_version (current)	 
	dd      _start		;   e_entry 
	dd      phdr - $$	;   e_phoff	
	dd      0               ;   e_shoff
	dd      0		;   e_flags 
	dw      ehdrsize	;   e_ehsize
	dw      phdrsize	;   e_phentsize
	;; seuraavat 8 byte‰ sama kuin phdr:n alku!
	;dw      1		;   e_phnum
	;dw	 0		;   e_shentsize
	;dw      0		;   e_shnum
	;dw      0		;   e_shstrndx

 ehdrsize      equ     $ - ehdr

	;; koodisegmentin phdr
phdr:				; Elf32_Phdr	
	dd      1		;   p_type (PT_LOAD)	
	dd      0		;   p_offset
	dd      $$		;   p_vaddr 
	dd      0		;   p_paddr
	dd      filesize	;   p_filesz  
	dd	filesize+100663296; p_memsz (96 megaa muistia lis‰‰ vaikkapa)
	dd      0x07		;   p_flags (r, w ja exec)
	dd      0x1000		;   p_align
	
 phdrsize      equ     $ - phdr


_start:
 startoff equ $-$$
	pusha			; rekisterit talteen, jottei itse ohjelma h‰iriinny

;;; pura kama
	mov esi, compressed_data
	mov edi, decomp
decompress_loop:	
	mov al, [esi] 		; lue kompressoitu
	inc esi	
	cmp al, MAGIC_BYTE2	; kolmen nollan sarja enkoodattu t‰ll‰
	jne .ei3nollaa
	xor eax, eax
	stosw
	jmp short asdff
.ei3nollaa:		
	cmp al, MAGIC_BYTE
	jne .eirepeat
		
	;; repeattia tuleepi
	xor ecx, ecx
	xor edx, edx
	mov dx, [esi]
	mov cl, dl
	and cl, 0x0f		; repeatcount
	add cl, 4
	shr edx, 4		; hyppy
	mov ebx, edi
	sub ebx, edx 		; ebx = repeatin alku
	;; kopioi kama
.repeat_loop:			
	mov al,[ebx]
	stosb
	inc ebx
	loop .repeat_loop

	inc esi
	inc esi

	jmp short decompress_loop
	
.eirepeat:
asdff:	
	stosb

	cmp esi, end_of_compressed_data
	jc decompress_loop
	
;;; hypp‰‰ puretun koodin alkuun
;jump_to_code:	
;	
	popa
	jmp decomp

;;; DEBUG

;	mov eax, 4
;	mov ebx, 1		; stdout
;	mov ecx, esp
;	mov edx, 16
;	int 0x80

;	mov eax, 1
;	int 0x80

;;; DEBUG

;; kolme nollaa ulos
	
foo:	
	
decomp_codesize equ $ - $$
		
filesize equ decomp_codesize + COMPSIZE

compressed_data equ foo
end_of_compressed_data equ foo + COMPSIZE ; t‰‰ ei v‰ltt‰m‰tt‰ oikein k‰y, tulee sellanen hassu looppi (kompressoidun datan pituus riippuu kompressoidun datan pituudesta, wheeh)

;;; t‰nne se puretaan ja sit hyp‰t‰‰n
decomp equ ehdr + 0x4000