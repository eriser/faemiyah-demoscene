	;; 4k-intron tekniikkatestausta (ääni lähinnä)
align 1
BITS 32	
	
	org     0x35850000
		
ehdr:						                ; Elf32_Ehdr
	db      0x7F, "ELF", 1, 1, 1	;   e_ident (ELF)

write:	; just sopivasti 9 tavua	
	xor ebx, ebx
	inc ebx			; stdout
	mov ecx, edi
	int 0x80
foo:	
	jmp short foo

	dw      2		;   e_type    (executable)
	dw      3		;   e_machine (i386)
	dd      1		;   e_version (current)	 
	dd      _start		;   e_entry 
	dd      phdr - $$	;   e_phoff	
	dd      0               ;   e_shoff
	dd      0		;   e_flags 
	dw      56      	;   e_ehsize
	dw      32 		;   e_phentsize
	;; seuraavat 8 byteä sama kuin phdr:n alku!
	;dw      1		;   e_phnum
	;dw	 0		;   e_shentsize
	;dw      0		;   e_shnum
	;dw      0		;   e_shstrndx

 ehdrsize      equ     $ - ehdr

	;; koodisegmentin phdr
phdr:				; Elf32_Phdr	
	dd      1		;   p_type (PT_LOAD)	
	dd      0		;   p_offset
;	dd      $$		;   p_vaddr
;	dd      0		;   p_paddr TÄTÄ EI TARTTE, TÄSSON VAPAATA

	db 0x00			; tätä tavua ei taida saada hyötykäyttöön kun p_vaddr mod pagesizen ilmeisesti oltava 0
	
notetable:	
	db 0x00			; 0 tyhjä

	db 0x85			; 1 c
	db 0x35			; 2 basso-g#
	db 0x9f			; 3 d#
	db 0xb2			; 4 f
	db 0xc8			; 5 g
	db 0xd4			; 6 g#
	
	dd      filesize	;   p_filesz  

	db 0x42			; b basso-c
	db 0x59			; c basso-f
	db 0x6a			; d basso-g# 2
	
	db 0x00		

	dd      0x07		;   p_flags (r, w ja exec)
;	dd      0x1000		;   p_align
	
 phdrsize      equ     $ - phdr



_start:
 startoff equ $-$$
;;; Alussa kaikki rekisterit nollia ilmeisesti?

	mov ebp, 256
	
	mov esi, song
voiceloop:
	mov edi, audio_mix

songloop:
	mov ebx, notetable
nextnote:		
	mov al, [esi]

	cmp al, 0xef
	jz snare
		
	jc eiloop		; loopataan, jos byte =>0xf0

	and al, 0x0f		; nyt eax=looppicounter
	jz ohi			; 0xf0 lopettaa äänen
	inc esi
	cmp [esi+ebp], byte 0	; onko laskuri nolla?
	jne ei_uusiloop

	;; ei käynnissä oleva luuppi ->
	;; aseta counter
	mov [esi+ebp], al

ei_uusiloop:

	dec byte [esi+ebp]	; dec. counter
	jz loop_loppui
	
	mov al, [esi]
	sub esi, eax
	jmp short nextnote	; seuraavaan nuottiin vaan
eiloop:	
		
	mov ecx, eax
	and cl, 0xf0
	jz write		; nollakestoinen nuotti lopettaa songin
;	jnz eiwrite
;	jmp write
eiwrite:		
	
	shl ecx, 5
	and al,0x0f
	xlatb
noteloop:
	add edx, eax
	push edx
	shr edx, 6
mod:	and dl, 01000000b
	add [edi], dl
	inc edi
	pop edx
	loop noteloop

loop_loppui:		
	inc esi

	jmp short songloop
ohi:
	inc esi			
	sub [mod+2], byte 00010100b	; self-modifying kode!! l337!!
	jmp short voiceloop
	

	;; kuul kohinarumpu
snare:	
	mov ch, 1000b
.snareloop:	
	mov al, [ebx]
	and al, 01010101b
	stosb	
	inc ebx
	loop .snareloop
	jmp short loop_loppui	
	
	;; (65536/8000)*440*e^((n/12)*ln 2)
song:
	;; nuotti:	 0x[len][note]
	;; loopit:	 0xf[matka+2], counter

	;; Ääni 1
	db 0x4b		
	db 0x21
	db 0x2b
	db 0xef
	db 0x41

	db 0xf8
	db 0x06

	db 0x4c		
	db 0x21
	db 0x2c
	db 0xef
	db 0x43

	db 0xf4
	db 0x06
	
	db 0x42
	db 0x21
	db 0x22
	db 0xef
	db 0x4d

	db 0xf4
	db 0x06	

	db 0xf5
	db 22

	db 0x8b
		
	db 0xf0


	;; Ääni 2

	db 0x80

	db 0xf8
	db 2

	db 0xf4
	db 4
	
	db 0xc1
	db 0xc6
	db 0xc4 
	db 0xe5
        db 0xe0

	db 0xf3
	db 0x06
	
	db 0x21
	db 0x24
	db 0x25
	db 0xe1

	db 0x40

	db 0xfa
	db 2
	
	db 0xf2
	db 19

	db 0xf0

	;; Ääni 3
	db 0x26
	db 0x25
	db 0x23
	db 0x21
	
	db 0xfb	
	db 0x05

	db 0x21
	db 0x23
	db 0x24
	db 0x25
	
	db 0xfd	
	db 0x05

	db 0x24
	db 0x25
	db 0x26
	db 0x21
	
	db 0xf8	
	db 0x05

	db 0xf5
	db 19
	
	db 0xf0 		; jotta edi osottaisi lopussa bufferin alkuun
	db 0x04

filesize equ $ - $$	
	
align 1
section .bss

notes:	
	resd 1024		; pientä hajurakoa
			
audio_mix:	

