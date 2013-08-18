		;; 4k-intron tekniikkatestausta (‰‰ni l‰hinn‰)
BITS 32	
	
	org     0x08048000
		
ehdr:						                ; Elf32_Ehdr
	db      0x7F, "ELF", 1, 1, 1	;   e_ident (ELF)
devdsp:
	db "/dev/dsp",0

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
	dd      $$		;   p_paddr
	dd      filesize	;   p_filesz  
	dd	filesize+100663296; p_memsz (96 megaa muistia lis‰‰ vaikkapa)
	dd      0x07		;   p_flags (r, w ja exec)
	dd      0x1000		;   p_align
	
 phdrsize      equ     $ - phdr



	;; t‰st‰ homma alkaa
				
_start:
 startoff equ $-$$

	;; tekaistaan sample
	mov ecx,10000000
looppi:
	mov edx,ecx
	shl edx, 8
	mov [ecx+uninit_data], dx
	dec ecx
	jnz looppi

	;; avataan /dev/dsp kirjoitusta varten
	mov eax, 5
	mov ebx, devdsp         ; 
	mov ecx, 0x01		; write only
	xor edx, edx
	int 0x80
	
	push eax		; filedescriptori talteen (mihink‰h‰n pino muuten menee?)
	push eax
	
	;; 44.1KHz, 16bit mono
	mov eax, 54		; ioctl
	pop ebx			; file descriptor
	mov ecx, 0xc0045005	; ioctl command
	mov edx, dsp_fmt	; pointer to arguments
	int 0x80

	;; kama ulos
	mov eax, 4
	pop ebx
	mov ecx, uninit_data
	mov edx, 10000
	int 0x80

	xor eax,eax
	inc eax
	int 0x80		; return valuella ei v‰lii

dsp_fmt:
	dd 0x00000010

filesize equ $ - $$
uninit_data:
