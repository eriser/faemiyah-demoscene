	;; 4k-intron tekniikkatestausta (‰‰ni l‰hinn‰)
BITS 32	
	
	org     0x08048000
		
ehdr:						                ; Elf32_Ehdr
	db      0x7F, "ELF", 1, 1, 1	;   e_ident (ELF)
devdsp:
	db "/dev/dsp",0
	;; t‰‰ll‰ headerissa on nollia ja vaikka mit‰, k‰yt‰ n‰it‰ hyv‰ksi!
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

;;; Ensin teh‰‰n saundii

;	xor eax, eax
;	mov ax, [notetable]
;	mov ebp, eax
;	call phatsaw
;	call mix_audio_bufs

;	xor eax, eax
;	mov ax, [notetable+4*2]
;	mov ebp, eax
;	call phatsaw
;	call mix_audio_bufs
	
	
	call basari
	call mix_audio_bufs

	call reso_better

;;; Sitten soitetaan
	
	;; avataan /dev/dsp kirjoitusta varten
	mov eax, 5
	mov ebx, devdsp         
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
	mov ecx, audio_mix
	mov edx, 44100
	int 0x80

	xor eax,eax
	inc eax
	int 0x80		; return valuella ei v‰lii

dsp_fmt:
	dd 0x00000010




;;;
;;; Audiorutiinit (mix, filsut jne.)
;;;

notetable_iso:
;	dd 2678268  		; C
;;	dd 2837526		; C#
;	dd 3006254		; D
;	dd 3185015		; D#
;;	dd 3374406		; E
;	dd 3575058		; F
;;	dd 3787642		; F#
;	dd 4012867		; G
;	dd 4251485		; G#
;	dd 4504291		; A
;	dd 4772130		; A#
;;	dd 5055896		; H

	;; (65536/44100)*440*e^((n/12)*ln 2)

notetable:			; vain 8 nuottia k‰ytˆss‰, t‰‰ s‰‰st‰‰!

	dw 654			; C
;	dw 693			; C#
	dw 734			; D
	dw 778			; D#
;	dw 824			; E
	dw 873			; F
;	dw 925			; F#
	dw 980			; G
	dw 1038			; G#
	dw 1100			; A
	dw 1165			; A#
;	dw 1234			; B

	
	;; padsoinnut (oikealta vasemmalle)
chord1:
	db 0x00010111		; basso c
chord2:		
	db 0x01011001		; basso f
chord3:	
	db 0x01001010		; basso a#
chord4:		
	db 0x10010110		; bassi d#

;;; t‰h‰n sellanen kellojuttu sointujen taustalle:
;;; e#2 d2 g, a a# c2, d2 a# a f g
;;;                 tai a# a f, g
;;; e#2 d2 g, a a# c2, d2 a# a f d d#2 d2 g 	
	
			
;;; Miksaa audiobufferit (saturaation kans, ‰mm‰mm‰ks 0wnZ j00)
mix_audio_bufs:
 	mov ecx,44100*16
.mmx_mix_loop:
	movq mm0, [ecx+audio_temp]
	psraw mm0, 1		; arithmetic shr (word)
	paddsw mm0, [ecx+audio_mix] ; add with saturation (word)
	movq [ecx+audio_mix], mm0
	sub ecx, 8 		; quadwordi kerrallaan
	jnz .mmx_mix_loop
	emms
	ret

;;; Parenpi ja nopeenpi (?) resofilsu
		
reso_better:

	mov edi, audio_mix 	; t‰‰ll‰ filtterˆid‰‰n
	mov esi, 0x01		; cutoffin muutos /sample
	
	mov ecx, 44100*5
.resofilterloop:	

	add [cutoff], esi
	
	fild word [cutoff]
	fmul dword [cutoffkerroin]

	fild word [edi]
	
	fsub dword [d0] ; erotus st0=st0-d0

; feedback eli fb*(d0-d1)
	fld dword [d0]
	fsub dword [d1] ; st0=d0-d1
	fmul dword [feedback]
	faddp st1 

	fmul st1
	fadd dword [d0] ; ja lis‰‰ erotus*k1 vanhaan arvoon

	fst dword [d0] ; d0 talteen

	fsub dword [d1] ; erotus st0=d0-d1
	fmulp st1
	fmul dword [peakwidth] 	; kakkosfiltteriss‰ v‰h‰n alempi cutoff
	fadd dword [d1] ; ja lis‰‰ erotus*k1 vanhaan arvoon


	fst dword [d1]
	fistp word [edi] ; konvertoi intiksi
	inc edi
	inc edi

	loop .resofilterloop

	ret
	

		
;;; sahaa! (ebp freq.addi)
	
phatsaw:
	mov ebx, audio_temp
.phatloop:	
	mov [ebx], word 0
	mov edx, ebp		; freq.addi
	mov ecx, 8
.phat_inner:
	add [phatsaws+ecx*2], dx
	mov ax,[phatsaws+ecx*2]
	sar ax, 3		; ettei klippaa (t‰ssei jaksais mmx:‰‰ k‰ytell‰)
	add [ebx], ax
	add dx,2		; detune
	loop .phat_inner	
		
	add ebx, 2
	cmp ebx, 44100*16+audio_temp
	jna .phatloop
	
	ret

	
;;; basari
	
basari:	
	mov ecx, 1620
	mov edi, audio_temp
.basariloop:
	add ebx, ecx
	mov eax, ebx
	and ah, 0x80
	stosw
	loop .basariloop
	ret
	
		
cutoffkerroin: ; t‰ll‰ kerrotaan cutoff niin saadaan k1 ja k2
	dd 0.000038
	
cutoff:
	dw 0x1000
peakwidth:
	dd 0.85
d0:	
	dd 0
d1:			
	dd 0
feedback:
	dd 1.6

filesize equ $ - $$
align 1
section .bss
	
phatsaws:	
	resw 16
						
;;; Temppi‰, buffereita, kaikkee 

audio_temp:	
	resw 44100*120		; t‰h‰n yks sample aina

audio_mix:	
	resw 44100*120		; t‰h‰n finalmix
