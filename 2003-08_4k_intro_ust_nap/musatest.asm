BITS 32	

;#############################################################################
; Definet ####################################################################
;#############################################################################

; Efektit
%define	EFFECT_TUNNEL_DNACOUNT	6

; Peruskama
%define SCREEN_W	80
%define SCREEN_H	50
%define SCREEN_B	32
%define BUFSIZE_C	(SCREEN_W * (SCREEN_H + 1))
%define BUFSIZE_Z	(SCREEN_W * SCREEN_H)
%define MSH_COMPLEXITY	65535
%define MSH_NUM		2
%define OBJ_NUM		EFFECT_TUNNEL_DNACOUNT
%define BUFFER_DETAIL	2

; Julkisia arvoja jotka aina sama
%define BACKFLOAT	-1000.0
%define BACKINT		-32768
%define VOXEL_SIZE	0.5

; Obut
%define MESH_DNA	0
%define MESH_METABALL	1

; DNA-rihma
%define DNA_HEIGHT	475.0
%define DNA_HEIGHT_INT	475
%define DNA_RADIUS	6.0
%define DNA_DOTRADIUS	0.5
%define DNA_ROTATION	768
%define DNA_DELAY	10
%define DNA_SPIRAL	1000
%define DNA_SECTION	20
%define DNA_SECTIONNUM	(DNA_SPIRAL / DNA_DELAY)
%define DNA_COMPLEXITY	(DNA_SPIRAL * 2 + DNA_SECTIONNUM * DNA_SECTION * 2)

; Metapallukat
%define METABALL_TAHKO		50
%define METABALL_MAX		4
%define METABALL_ATFIELD_COUNT	4
%define METABALL_MELD_COUNT	3

; Liput, kommentoi päälle / pois
;%define FLAG_SAVEREGS
%define FLAG_INCLUDE_TEXTOUT
%define FLAG_ONE_COLOR_FIRE

;#############################################################################
; Makrot #####################################################################
;#############################################################################

; Pushan korvike
%macro __pusha 0
%ifdef FLAG_SAVEREGS
	pusha
%endif
%endmacro

; Popan korvike
%macro __popa 0
%ifdef FLAG_SAVEREGS
	popa
%endif
%endmacro

%macro movbpp 4
%if %4 == 4
	mov	dword %1, %3
%elif %4 == 2
	mov	word %1, %2
%endif
%endmacro

%macro cmpbpp 4
%if %4 == 4
	cmp	dword %1, %3
%elif %4 == 2
	cmp	word %1, %2
%endif
%endmacro

%macro __null 1	
	xor	%1, %1
%endmacro

;#############################################################################
; Struktuurit ################################################################
;#############################################################################

; 32
STRUC voxel_t
.col1		resd	1
.col2		resd	1
.pos		resd	3
.dir		resd	3
ENDSTRUC

; 32
STRUC light_t
.rot		resw	4
.ambient	resd	1
.specular	resd	1
.dir		resd	3
.parity		resb	4
ENDSTRUC

; Yksinkertaistuksen takia aakkosjärjestyksestä on luovuttu!
; vähän siistii! VITTU!
; 4194304 = 65536 * 32 = 2^16 * 2^6 = 2^21
STRUC mesh_t
.dots		resb	voxel_t_size * MSH_COMPLEXITY
.dotc		resd	1
.parity		resb	28
ENDSTRUC

; 32
STRUC object_t
.rot		resw	4
.ref		resd	1
.pos		resd	3
.parity		resb	8
ENDSTRUC

;#############################################################################
; Koodi ######################################################################
;#############################################################################

section .text code align=1

TEMPO equ 2600
SONGLEN equ 180
				
	org     0x06000000
		
ehdr:						                ; Elf32_Ehdr
	db      0x7F, "ELF", 1, 1, 1	;   e_ident (ELF)
str_devdsp:	
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
	dd      $$		;   p_vaddr 
	dd      0		;   p_paddr
	dd      filesize	;   p_filesz  
	dd	filesize+100663296; p_memsz (96 megaa muistia lisää vaikkapa)
	dd      0x07		;   p_flags (r, w ja exec)
	dd      0x1000		;   p_align
	
 phdrsize      equ     $ - phdr


_start:
 startoff equ $-$$

;;; -----------------------------------------------------------------------------
;;; audioinit
audio_thread:
	
	;; avaa stdin
	mov eax, 5		; open
	mov ebx, str_devstdin	; pointteri nimistringiin
	mov ecx, 04000
	__null	edx
	int 0x80

	mov [desc_stdin], eax	; descriptori talteen
	
	;; avaa /dev/dsp
	mov eax, 5		; open
	mov ebx, str_devdsp	; pointteri nimistringiin
	mov ecx, 1
	__null	edx
	int 0x80

	mov [desc_devdsp], eax	; descriptori talteen

	;; stereo
	mov ecx, 0xc0045006	; command
	mov edx, dsp_channels	; args
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; filedesc
	int 0x80		; 

	;; 16bit LE
	mov ecx, 0xc0045005	; ioctl cmd
 	mov edx, dsp_fmt	; pointer to args
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; fdesc
	int 0x80	
		
	;; 44100KHz
	mov ecx, 0xc0045002	; ioctl command
	mov edx, dsp_rate	; pointer to arguments
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; filedesc
	int 0x80	

;;; -----------------------------------------------------------------------------
;;; humppaa saatana


	;; jumps
	mov esi, bd1
	mov edx, basari
	call do_voice
	call mix_audio_bufs	
	; 	
	;;
	mov esi, pad1
	mov edx, padchord
	call do_voice
	call mix_audio_bufs


	;; tsih
	mov esi, hh1
	mov edx, hihat
	call do_voice
	call mix_audio_bufs	

	;; poks
	mov esi, sd1
	mov edx, snare
	call do_voice
	call mix_audio_bufs	

	;; boing
	mov esi, bass1
	mov edx, sawnote
	call do_voice
	call mix_audio_bufs

	;; tiluli
	mov esi, voice1
	mov edx, sawnote
	call do_voice		
	call mix_audio_bufs
	;; diu	
	mov [mmx_cutoff_ero+1], byte 0x40 ; filtteriä vähän säädetään

	mov esi, rez1
	mov edx, sawnote
	call do_voice
	call mix_audio_bufs

	mov esi, rez2
	mov edx, sawnote
	call do_voice
	call mix_audio_bufs

	mov [distort+1], byte 0	; särö päälle tana

	mov esi, rez3
	mov edx, sawnote
	call do_voice
	call mix_audio_bufs

.runk:	

	
	
	;; clone tässä
	mov eax, 120
	mov ebx, 0x00000700
	mov ecx, esp
	sub esp, 0x1000
	__null	edx
	int 0x80

	cmp eax, 0
	jne visual_thread	; ELITEE VITTU NII

;;; äänilooppi
;;; - - - - - -
;;; kirjoita audioo vähän
ACSIZE equ 1024
AC_BUFFER_LOW equ 32768
	
writeaudio:	

	;; lue soitetut bytet
	mov ecx, 0x800c5012 	; SNDCTL_DSP_GETOPTR
	mov edx, count_info	; pointer to arguments
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; file desc.
	int 0x80

	mov eax, 4		; write
mov ebx, [desc_devdsp]	; descriptori
	mov ecx, [audio_bytes_written]
	add ecx, audio_mix	
	mov edx, ACSIZE
	int 0x80

	add [audio_bytes_written], dword ACSIZE	
	
	;; päivitetään syncci
	__null	edx
	mov eax, [count_info]
	add eax, TEMPO/2
	mov ebx, TEMPO
	div ebx
	mov [glob_timer], eax

	jmp short writeaudio

visual_thread:	
	mov [audio_thread_pid], eax ; tää talteen että voidaan tappaa exitissä
	
	finit			; 	
	call func_init
	
mainloop:			; 	
	call func_control

;;; -----------------------------------------------------------------------------
;;; flippi

flip:

	;; kursori ylänurkkaan
	mov eax, 4
	mov ebx, 1
	mov ecx, escseq_cursorpos
	mov edx, 3
	int 0x80

	;; sit foox
	mov esi, buffer_c	; täällä paskaa

	mov ecx, 80*50-1
.fliploop:
	push ecx
	mov eax, [esi]

	shr al, 5
	add al,'0'
	mov [flip_col+3], al
	shr ah, 5
	add ah, '0'
	
	mov [flip_col+6], ah	

	;; väri ja merkki ulos
	mov eax, 4
	mov ebx, 1
	mov ecx, flip_col
	mov edx, 9
	int 0x80

	inc esi
	inc esi
	pop ecx
	loop .fliploop

	mov eax, 3		; read
	mov ebx, [desc_stdin]
	mov ecx, temp
	mov edx, 1
	int 0x80

	cmp byte [temp], 0x1b
	jne .eiq
	mov [quit_flag], byte 1
.eiq:	
	

	cmp byte [quit_flag], 0
	je near mainloop	
	
;;; -----------------------------------------------------------------------------
;;; pois
poies:	
	
	;; äänille killii
	mov eax, 37		; kill
	mov ebx, [audio_thread_pid]
	mov ecx, 9		; kill -9 perskele
	int 0x80

	;; ja pihalle
	mov eax, 1
	int 0x80
		
sync:	
	dd 0

audio_bytes_written:
	dd 0 + TEMPO*256*0
	

escseq_cursorpos:
	db 0x1b, "[H1;1"         ; kursori ylänurkkaan

alku_escseq:	
	db 0x1b, "[", "1", "m"	; bold

cursor_off:
	db 0x1b,"[?25l."	

str_devstdin:
	dd "/dev/stdin", 0
	
flip_col:		
	db 0x1b, '[', "30;40", 'm', '#'



pal_top:
	db 255

pal_bottom:
	db 0
	
pal1:
	db 255			; b
	db 0			; g
	db 255			; r
pal2:	
	db 0			; b
	db 255			; g
	db 255 			; r

	db 0
	
palette_chars:	
	db "0123456789abcdef"
	
ttesst:	
	db 0x1b, ']', "P0000000"

;;; -----------------------------------------------------------------------------
;;; duunaa yhden äänen annetuilla parametreilla
;;; esi = äänen alku, edx = kutsuttava nuottifunkkari
	
do_voice:	
	mov ebp, esi		; talteen, että voidaan hakea asetuksia sit

	mov edi, audio_temp_l	; ensin vasen kanava

	mov ecx, 2
channelloop:
	push ecx
	add esi, 24		; tässä itse nuottidatan alku
	push edi		; kohde talteen, että voidaan tehdä delay sitten
	
	;; ensin sahat
voiceloop:
	__null	eax
	mov al,[esi]
	inc esi
	cmp al,0x00		
	je voicedone		; nolla merkkaa äänen lopun

	cmp al,0xff
	jne eicutoffs
	
	;; cutoffslide
	__null	eax
	mov al, [esi]
	sub eax, 0x80
	movd mm3, eax
	
	inc esi
	jmp short voiceloop
eicutoffs:	

	cmp al,0xfe
	jne eicutoffa

	;; cutoff abs

	__null	eax
	mov al, [esi]
	shl eax, 7+8
	movd mm4, eax
	pxor mm3, mm3		; liuku pois
	
	inc esi
	jmp short voiceloop
eicutoffa:	
	
	cmp al,0x81		; >0x80 -> looppi
	jc eilooppia

	sub al,0x80

	cmp [esi+5000], byte 0x00
	je eivanhaa
	dec byte [esi+5000]
	jnz eilooploppu	; looppi ei lopussa, siis pompataan songissa takas

	inc esi
	jmp short voiceloop	; loop ohi, täältä löytyy seuraava nuotti

eilooploppu:	
	__null	ebx
	mov bl, [esi]
	dec esi
	sub esi, ebx
	sub esi, ebx
	jmp short voiceloop

eivanhaa:	
	mov [esi+5000], al
	jmp short eilooploppu

eilooppia:		; ei ollut looppihyppy, vaan ihan peräti nuotti

	mov ecx, eax		; lasketaan nuotin pituus
	imul ecx, TEMPO

	__null	ebx
	mov bl, [esi]
	cmp bl, 0
	jmp short calli		; rutiini handlaa nollan itse?
	jne calli		; nolla on silencee

	__null	eax		; tehdään hiljaisuutta
	rep stosw
	inc esi
	jmp short voiceloop

calli:	
	call edx		; edi target, ecx pituus
	inc esi
	jmp short voiceloop

voicedone:	

	;; tehdään delay
	pop edi			; bufferin alku pinosta
	mov ebx, [ebp]
	mov ecx, 44100*SONGLEN
delayloop:	
	push ecx

	;;
	mov ax, [edi+ebx]	
	cwde
	mov ecx, eax
	mov ax, [edi]
distort:			; 	jmp short eidist
	jmp short eidist
	add ax, 0x0200
	and ax, 0x8000
eidist:
	cwde
	
	imul eax, [ebp+2*4]	; vol
	imul ecx, [ebp+1*4]	; delay feedback
	add eax, ecx
	sar eax, 9
	stosw
	pop ecx
	loop delayloop

	;; sit kanavanvaihdos!
	pop ecx
	mov esi, ebp
	add ebp, 12
	mov edi, audio_temp_r
	dec ecx
	jnz channelloop
	
	;; sitten filsut ja delayt kumpaankin kanavaan
	;; 	

	ret

mmx_cutoff_ero:	
	dw 0x6000
	dw 0

;;; - - - - - -
;;; basorunpu

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde

basari:
	pusha
	cmp bl,0
	je .asdq
	mov ecx, 5000
.basariloop:	
	add ebx, ecx
	mov eax, ebx
	sar eax, 4
	and ax, 0x8000
	stosw

	loop .basariloop
.asdq:	
	popa
	add edi, ecx
	add edi, ecx
	ret

;;; - - - - - -
;;; snare

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde

snare:
	pusha
	cmp bl,0
	je .eisnare
	mov ecx, 1500
.snareloop:	
	add ebx, ecx
	add edx, ebx
	mov eax, edx
	sar ax, 3
	stosw
	stosw

	loop .snareloop
	
.eisnare:	
	popa
	add edi, ecx
	add edi, ecx
	ret

;;; 
	
hihat:
	pusha

	cmp bl, 0x00
	je .hihat_s
	
	mov ecx, ebx	
	shl ecx, 8
	mov edx, phdr
.hihatloop:
	mov eax, [edx]
	inc edx
	cmp bl,0x01
	jne .pasd
	sar ax, 1
.pasd:	
	stosw
	loop .hihatloop

.hihat_s	
	popa
	add edi, ecx
	add edi, ecx
	ret
	
;;; - - - - - -
;;; pätkä padia

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde
	
padchord:
	pusha
.padloop:	
	push ecx

	__null	eax
	__null	ebp
	
	mov ecx, 12*5
.phatloop:
	;; nouda edx:ään addi tablesta
	test cl,11b
	jnz .eiseur

	;; seuraava nuotti
	mov edx,[ebp*2+notetable-2]	; addi tablesta
	shr edx, 6			; ja oktaavi sopivaksi

	bt [ebx*2+padchords], ebp	
	jc .notee
	__null	edx
	sub cl, 3
.notee:	
	
	inc ebp
.eiseur:	
	;; 
	add [ecx*4+pad_note_buf], edx
	mov esi, [ecx*4+pad_note_buf]
	sar esi, 21		; ei saa klipata

	add eax,esi 		; miksaa sekaan
	
	add edx, 60000	; detunee

	loop .phatloop

	call resommx
	
	stosw
	pop ecx
	loop .padloop	

	popa
	add edi, ecx
	add edi, ecx
	ret
	
;;; - - - - - -
;;; sahaa pätkä

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde
	
sawnote:
	push edx
	push ecx
		
	mov ecx, ebx

	and bl, 0x0f
	__null	edx
	mov dx, [ebx*2 + notetable] ; addi
	shl edx, 16
	
	shr ecx, 4		
	shr edx, cl		; shifti
	
	pop ecx	
	;; nyt edx:ssä addi
.noteloop:
	
	add ebx, edx
	mov eax, ebx
	sar eax, 18

.pin:	
	
.eisawzero:	
 	call resommx		; eax filtterin kautta jee
	
	stosw
	loop .noteloop
	pop edx
	ret

	
;;; fildaah -------------------9o4öor394uröo349uröco3nrou3
	
resommx:	
		;; --------------
		;; nyt pitäis eax käyttää filsussa
	;; ---
		
	movd mm1, eax		; inputti
	
	;; filtteriliuku
	paddd mm4, mm3
	movq mm0, mm4
	psrlq mm0, 8
	;; mm0 == kerroin
	
; feedback eli fb*(d0-d1)
	
	movq mm5, mm6
	
	psubsw mm5, mm7		; mm5 = d0 - d1
			
	paddsw mm1, mm5		; lisää feedbackki kakkosfilsun inputtiin	

	psraw mm5, 2
	paddsw mm1, mm5
	
	;; vähennä d0		
	psubsw mm1, mm6
	
	;; kerro delta cutoffkertoimella
	pmaddwd mm1, mm0
	psrad mm1, 16

	;; hmm
	paddsw mm6, mm1		; tällä näköjään saadaan cutoffii ylös	
	paddsw mm6, mm1	

	;; kakkosfilsu 
	movq mm1, mm6		; inputti kakkoseen
	
	psubsw mm1, mm7
		
	pmaddwd mm1, mm0	; kerro cutoffkertoimella
	psrld mm1, 16
	pmaddwd mm1, [mmx_cutoff_ero] ; pienempi cutoff kakkosfilsulla
	psrld mm1, 16

	paddsw mm7, mm1
	paddsw mm7, mm1
	
	movd eax, mm7		; kakkosfilsun outputti ulos
	;; -------------------- filsu
	cwde
	ret	
		
;;; -----------------------------------------------------------------------------
;;; miksaa finaalioutputtiin träkit sopivasti interleavaten

mix_audio_bufs:
 	mov ecx,44100*300
	pxor mm2, mm2	
.mmx_mix_loop:
	movd mm0, [ecx+audio_temp_l]
	movd [ecx+audio_temp_l], mm2 ; nollataan samalla
	movd mm1, [ecx+audio_temp_r]
	movd [ecx+audio_temp_r], mm2
	;; interleaave low-order-words
	punpcklwd mm0, mm1
	
	paddsw mm0, [ecx*2+audio_mix] ; add with saturation (word)
	movq [ecx*2+audio_mix], mm0 ; sinne vaan

	sub ecx, 4 		; 4 + 4 tavua kerrallaan
	jnz .mmx_mix_loop
	emms

	;; tyhjää ruutu ja tee muuta escapeilla aluks
	mov eax, 4
	mov ebx, 1
	mov ecx, alku_escseq
	mov edx, 11
	int 0x80

	ret

	
;;; musadata:
;;; joka kanava rendataan 2 kertaa, eri efektiasetuksilla
;;; (cutoff, delay, muuta?)
;;; mix_audio_bufs interleavaa ja miksaa

;;; sahasyniin tarvitaan slidet
;;; rummuista paremmat
;;; padi?
;;; delayhin jonkinlainen all-pass -filsu vielä?

;#############################################################################
; func_drawworld() ###########################################################
;#############################################################################

func_drawworld:
	__pusha
; Tyhjennetään bufferit
.clrbuf_z:
; Tyhjennetään viimeinen rivi väribufferia
	mov	edi, buffer_c + SCREEN_W * SCREEN_H * BUFFER_DETAIL
	__null	eax
	mov	ecx, SCREEN_W * BUFFER_DETAIL / 4
	rep	stosd
; buffer_z alkaa buffer_c:n lopusta
%if BUFFER_DETAIL == 4
	mov	eax, BACKINT
%elif BUFFER_DETAIL == 2
	mov	eax, 10000000000000001000000000000000b
%endif
	mov	ecx, BUFSIZE_Z * BUFFER_DETAIL / 4
	rep	stosd
; Tulieffu hoitaa samalla ruudun tyhjennyksen
.fire:
	mov	ecx, SCREEN_W * SCREEN_H
	__null	edi
	mov	ebp, [glob_fire]
	cmp ebp, 0
	je .eifire	
	mov	esi, buffer_c + BUFFER_DETAIL * SCREEN_W
.fire_loop:
	__null	ebx
	movzx	eax, byte [esi + edi * BUFFER_DETAIL - BUFFER_DETAIL]
	;movzx	eax, bl
	mov	bl, [esi + edi * BUFFER_DETAIL]
	add	eax, ebx
	mov	bl, [esi + edi * BUFFER_DETAIL + BUFFER_DETAIL]
	add	eax, ebx
	__null	edx
	div	ebp
%ifdef FLAG_ONE_COLOR_FIRE
	__null	ah
	mov	[esi + edi * BUFFER_DETAIL - BUFFER_DETAIL * SCREEN_W], ax
%else
	mov	[esi + edi * BUFFER_DETAIL - BUFFER_DETAIL * SCREEN_W], al
	__null	ebx
	mov	bl, [esi + edi * BUFFER_DETAIL - BUFFER_DETAIL + 1]
	movzx	eax, bl
	mov	bl, [esi + edi * BUFFER_DETAIL + 1]
	add	eax, ebx
	mov	bl, [esi + edi * BUFFER_DETAIL + BUFFER_DETAIL + 1]
	add	eax, ebx
	__null	edx
	div	ebp
	mov	[esi + edi * BUFFER_DETAIL + 1 - BUFFER_DETAIL * SCREEN_W], al
%endif
	inc	edi
	loop	.fire_loop
.eifire:	
; Aletaan piirtää
.do_precalc:
	mov	eax, glob_lit + light_t.rot
	mov	edi, tempmatrix
	call	func_matrix_rot
	mov	ecx, glob_dir
	mov	edx, tempmatrix
	mov	eax, glob_lit + light_t.dir
	call	func_matrix_mul_vector
	mov	ebx, [glob_objc]
.check_effect:
; Tsekataan halutaanko?
	cmp	ebx, 0
	jg	near .prepare_drawobject_loop

;--------------------------------------
; Julia
;--------------------------------------
.julia:
	mov	esi, juliadata
	fld	dword [esi + juliadata_t.mandely]
	fld	dword [esi + juliadata_t.mandelx]

.prepareloop:
	mov	edx, SCREEN_H
	mov	eax, buffer_c + SCREEN_W * (SCREEN_H - 1) * BUFFER_DETAIL
.yloop:
	mov	ecx, SCREEN_W
.xloop:
	push	edx
	push	ecx
	fild	dword [esp + 4]
	fmul	dword [esi + juliadata_t.hdiv]
	fadd	dword [esi + juliadata_t.hbase]
	fild	dword [esp + 0]
	fmul	dword [esi + juliadata_t.wdiv]
	fadd	dword [esi + juliadata_t.wbase]
	pop	ecx
	pop	edx
	mov	ebx, -1

.iterate:
	inc	ebx
	cmp	ebx, 255
	jge	.iterate_over
	fld	st1
	fmul	st0
	fld	st1
	fmul	st0
	fsubrp	st1
; st0 = ^2real st1 = real, st2 = imag, st3 = juliareal, st4 = juliaimag
	fld	st1
	fmul	st3
	fadd	st0
; st0 = ^2imag, st1 = ^2real, st2 = real, st3 = imag, st4 = juliareal,
; st5 = juliaimag
	fadd	st5
	fstp	st3
	fadd	st3
	fst	st1
; Sitten pituus
	fmul	st0
	fld	st2
	fmul	st0
	faddp	st1
	fsqrt
	fld	dword [esi + juliadata_t.bailout]
	fcomip	st1
	fstp	st0
	ja	.iterate
.iterate_over:
	fstp	st0
	fstp	st0
	shl	ebx, 2
	cmp	ebx, 70
	jle	.skip
	mov	bh, bl		; hmm
	movbpp	[eax + ecx * BUFFER_DETAIL - BUFFER_DETAIL], bx, ebx, BUFFER_DETAIL
.skip:
	loop	.xloop
.xloop_loppu:
	sub	eax, SCREEN_W * BUFFER_DETAIL
	dec	edx
	jnz	.yloop
.loppu:
	fstp	st0
	fstp	st0
	__popa
	ret
;--------------------------------------
; Ei juuliaa vaan jotakin muuta
;--------------------------------------
.prepare_drawobject_loop:
	mov	ecx, ebx
	shl	ebx, 5
	add	ebx, glob_objs - object_t_size
.drawobject_loop:
	push	ecx
	mov	eax, [ebx + object_t.ref]
; Kerrotaan mesh_t_size:llä
	shl	eax, 21
	lea	ebp, [glob_mshs + eax] ; f
	lea	eax, [ebx + object_t.rot] ; f
	mov	edi, tempmatrix
	call	func_matrix_rot
	mov	ecx, tempmatrix
	mov	edx, tempmatrix_t
; Matriisin transpoosi
.transpose:
	mov	eax, [ecx + 0 + 0]
	mov	[edx + 0 + 0], eax
	mov	eax, [ecx + 12 + 0]
	mov	[edx + 0 + 4], eax
	mov	eax, [ecx + 24 + 0]
	mov	[edx + 0 + 8], eax
	mov	eax, [ecx + 0 + 4]
	mov	[edx + 12 + 0], eax
	mov	eax, [ecx + 12 + 4]
	mov	[edx + 12 + 4], eax
	mov	eax, [ecx + 24 + 4]
	mov	[edx + 12 + 8], eax
	mov	eax, [ecx + 0 + 8]
	mov	[edx + 24 + 0], eax
	mov	eax, [ecx + 12 + 8]
	mov	[edx + 24 + 4], eax
	mov	eax, [ecx + 24 + 8]
	mov	[edx + 24 + 8], eax
.transpose_loppu:
	mov	ecx, glob_lit + light_t.dir
	mov	edx, tempmatrix_t
	mov	eax, tempvector_l
	call	func_matrix_mul_vector
; ebp = mesh offset, ebx = obu offset
.prepare_drawvoxel_loop:
	mov	esi, [ebp + mesh_t.dotc] 
	lea	edi, [esi*8]
	lea	edi, [ebp + mesh_t.dots + edi*4 - voxel_t_size]
; edi = voxelpos, esi = counter, ebx = obu offset
.drawvoxel_loop:
	lea	ecx, [edi + voxel_t.pos]
	mov	edx, tempmatrix
	mov	eax, tempvector_t
	call	func_matrix_mul_vector
	mov	ecx, 3
.addpos_loop:
	fld	dword [eax + ecx*4 - 4]
	fadd	dword [ebx + object_t.pos + ecx*4 - 4]
	fstp	dword [eax + ecx*4 - 4]
	loop	.addpos_loop
; Testataan onko laillisella alueella
.cxcy_cmp:
	fld	dword [eax + 8]
	fld	st0
	fmul	dword [glob_backintperfloat]
	fistp	dword [temp3]
; HUOM! backclip on disabloitu tilan nimissä, pidettäköön huolta ettei siihen
; mennä
;	mov	eax, [temp3]
;	cmp	eax, BACKINT
;	jl	near .cancel_cxcy
	cmp	[temp3], dword -1
	jg	near .cancel_cxcy
.cxcy_ok:
; Otamme kamaa talteen jo nyt
	pusha
; Pienennämme laittamalla nämä rekistereihin
	mov	ebx, temp1
	mov	edx, temp2
	mov	ecx, glob_screenw
	fild	dword [ecx]
	fdiv	st1
; st0 = screen_w / 2 / rpos[2], st1 = rpos[2]
	fld	dword [glob_voxel_size]
	fmul	st1
; st0 = radisudiv, st1 = screen_w / 2 / rpos[2], st2 = rpos[2]
	fld	dword [eax + 0]
	fmul	st2
	fisubr	dword [ecx]
	fld	st0
	fadd	st2
	fistp	dword [ebx]
	fsub	st1
	fistp	dword [edx]
	fld	dword [eax + 4]
; HUOM! eax:ssa ollut tempvector_t on säilynyt siellä tänne asti!
	mov	eax, dword [ebx]
	mov	ecx, dword [edx]
	fmul	st2
	fiadd	dword [glob_screenh]
	fld	st0
	fadd	st2
	fistp	dword [ebx]
	fsub	st1
	fistp	dword [edx]
	mov	ebx, dword [ebx]
	mov	edx, dword [edx]
; Homma selvä
	fstp	st0
	fstp	st0
	fstp	st0
.lightdotproduct:
; Tilan säästämiseksi ebp saa toimia pointterina
	mov	ebp, tempvector_l
	fld	dword [glob_lightbase]
	fld	dword [ebp + 0]
	fmul	dword [edi + voxel_t.dir + 0]
	fld	dword [ebp + 4]
	fmul	dword [edi + voxel_t.dir + 4]
	faddp	st1
	fld	dword [ebp + 8]
	fmul	dword [edi + voxel_t.dir + 8]
	faddp	st1
	fmul	dword [glob_lightmul]
	faddp	st1
; st0 == cosine
	mov	ebp, temp1
	fild	dword [edi + voxel_t.col1]
	fmul	st1
	fistp	dword [ebp]
	mov	esi, [ebp]
	shl	esi, 8
	fild	dword [edi + voxel_t.col2]
	fmulp	st1
	fistp	dword [ebp]
	add	esi, [ebp]
.zbufrect_sijoita:
	mov	edi, [temp3]
; Z-buffered rectangle -osuus, EI SÄILYTÄ ARVOJA!
; eax = x1, ebx = y1, ecx = x2, edx = y2, edi = z, esi = väri
.zbufrect:
; Ei saa parametreja joissa x1 < x2, jos saa, unkommentoi
;	cmp	eax, ecx
;	jle	short .zbr_nochangex
;	xchg	eax, ecx
;.no_change_x:
;	cmp	ebx, edx
;	jle	short .zbr_nochangey
;	xchg	ebx, edx
;.no_change_y:
.zbr_check_xleft:
	cmp	eax, 0
	jge	short .zbr_check_xright
	cmp	ecx, 0
	jl	near .zbr_loppu
	__null	eax
.zbr_check_xright:
	mov	ebp, SCREEN_W - 1
	cmp	ecx, ebp
	jle	short .zbr_check_ytop
	cmp	eax, ebp
	jg	short .zbr_loppu
	mov	ecx, ebp
.zbr_check_ytop:
	cmp	ebx, 0
	jge	short .zbr_check_ybottom
	cmp	edx, 0
	jl	short .zbr_loppu
	__null	ebx
.zbr_check_ybottom:
	mov	ebp, SCREEN_H - 1
	cmp	edx, ebp
	jle	short .zbr_prepareloop
	cmp	ebx, ebp
	jg	short .zbr_loppu
	mov	edx, ebp
.zbr_prepareloop:
	sub	ecx, eax
	inc	ecx
	sub	edx, ebx
	inc	edx
	mov	[temp1], ecx
	imul	ebx, SCREEN_W
	add	ebx, eax
.zbr_bigloop:
	mov	ecx, [temp1]
	mov	eax, ebx
.zbr_smallloop:
	cmpbpp	[buffer_z + eax * BUFFER_DETAIL], di, edi, BUFFER_DETAIL
	jge	short .zbr_nodraw
	movbpp	[buffer_z + eax * BUFFER_DETAIL], di, edi, BUFFER_DETAIL

	;; HÄHÄHÄÄ RAISKAAN KILAPAN KOODIN
	mov ebp, [buffer_c + eax*BUFFER_DETAIL]
	and esi, [voxel_draw_mask]
	and ebp, [voxel_bg_mask]
	or esi, ebp
	movbpp	[buffer_c + eax * BUFFER_DETAIL], si, esi, BUFFER_DETAIL
	;; HÄHÄ, raiskasin sitä takaisin -Trilkk
	
.zbr_nodraw:
	inc	eax
	loop	.zbr_smallloop
	add	ebx, SCREEN_W
	dec	edx
	jnz	short .zbr_bigloop
.zbr_loppu:
	popa
	jmp	short .drawvoxel_loppu

; zbufrect on loppunu
.cancel_cxcy:
	fstp	st0
.drawvoxel_loppu:
	sub	edi, voxel_t_size
	dec	esi
	jnz	near .drawvoxel_loop
.drawobject_loppu:
	pop	ecx
	sub	ebx, object_t_size
	dec	ecx
	jnz	near .drawobject_loop
.drawworld_loppu:
	__popa
	ret
; evvk
STRUC juliadata_t
.bailout	resd	1
.hdiv		resd	1
.wdiv		resd	1
.hbase		resd	1
.wbase		resd	1
.xmul		resd	1
.ymul		resd	1
.xbase		resd	1
.ybase		resd	1
.mandelx	resd	1
.mandely	resd	1
ENDSTRUC

; Struktuurit
juliadata:
istruc juliadata_t
at juliadata_t.bailout,	dd	2.0
at juliadata_t.hdiv,	dd	0.02 ; 1 / (SCREEN_H / 2)
at juliadata_t.wdiv,	dd	0.0125 ; 1 / (SCREEN_H / 2)
at juliadata_t.hbase,	dd	-1.14
at juliadata_t.wbase,	dd	-0.36
at juliadata_t.xmul,	dd	0.032
at juliadata_t.ymul,	dd	0.015
at juliadata_t.xbase,	dd	0.139
at juliadata_t.ybase,	dd	0.680
at juliadata_t.mandelx,	dd	0
at juliadata_t.mandely,	dd	0
iend

	
;#############################################################################
; func_init() ################################################################
;#############################################################################

; Apudefinet
%define DNAADD		(mesh_t_size * MESH_DNA)
%define SPIRALADD	(voxel_t_size * DNA_SPIRAL)
%define SECTIONADD	(voxel_t_size * DNA_SECTION)

func_init:
	__pusha

.sc_prepare:
	mov	ecx, 65536
; Huomaa, että kaikki siniarvot ovat 1 / 0xFFFF vinossa myötäpäivään
; paska nakki
.sc_loop:
	push	ecx
	fild	dword [esp + 0]
	fmul	dword [piipershort]
	fld	st0
	fsin
	fstp	dword [array_sin + ecx*4 - 4]
	fcos
	fstp	dword [array_cos + ecx*4 - 4]
.sc_loop_check:
	pop	ecx
	loop	.sc_loop

; Alustaa 2 metapalloa samanaikaisesti
.metaball:
	mov	ecx, 65536 * 2
	mov	eax, glob_mshs + mesh_t.dots
	mov	edx, 255
.metaball_loop:
	mov	dword [eax + voxel_t.col1], edx
	mov	dword [eax + voxel_t.col2], edx
	add	eax, voxel_t_size
	loop	.metaball_loop

; DNA-genu
.dna_prepare:	
	mov	ecx, DNA_SPIRAL
	__null	ebx
	mov	ebp, glob_mshs + mesh_t.dots + DNAADD
	mov	dword [ebp - mesh_t.dots + mesh_t.dotc], DNA_COMPLEXITY
	__null	edi
	mov	esi, glob_mshs + mesh_t.dots + DNAADD + SPIRALADD * 2
	fld	dword [glob_dna_spiral_div]
	fld	dword [glob_dna_height]
	fmul	st1, st0
; st0 = currheight, st1 = height/spiral*2
.dna_loop:
; ecx talteen tilan säästämiseksi
	push	ecx
	fld	dword [glob_dna_radius]
	fld	dword [array_cos + ebx*4]
	fld	dword [array_sin + ebx*4]
; st0 = x, st1 = z, st2 = radius, st3 = currh, st4 = h/s*2
	fst	dword [ebp + voxel_t.dir + 0]
	fchs	
	fst	dword [ebp + voxel_t.dir + 0 + SPIRALADD]
	fmul	st2
	fst	dword [ebp + voxel_t.pos + 0 + SPIRALADD]
	fchs
	fstp	dword [ebp + voxel_t.pos + 0]
	fst	dword [ebp + voxel_t.dir + 4]
	fchs	
	fst	dword [ebp + voxel_t.dir + 4 + SPIRALADD]
	fmul	st1
	fst	dword [ebp + voxel_t.pos + 4 + SPIRALADD]
	fchs
	fstp	dword [ebp + voxel_t.pos + 4]
	fstp	st0
; Sitten y-arvot
	fst	dword [ebp + voxel_t.pos + 8]
	fst	dword [ebp + voxel_t.pos + 8 + SPIRALADD]
	fldz
	fst	dword [ebp + voxel_t.dir + 8]
	fstp	dword [ebp + voxel_t.dir + 8 + SPIRALADD]
	fsub	st0, st1
; Nyt testataan jos tuo mokoma tarvii puolan!
	cmp	edi, DNA_DELAY
	jl	short .dna_loop_loppu
	mov	edi, SECTIONADD
	fld	dword [glob_dna_section_div]
	fldz
; st0 = kerroin, st1 = interval
; Loopataan kun luodaan puola	
.dna_section_loop:
	fld	dword [ebp + voxel_t.pos + 0]
	fmul	st1
	fst	dword [esi + edi - voxel_t_size + voxel_t.pos + 0]
	fchs
	fstp	dword [esi + edi - voxel_t_size + voxel_t.pos + 0 + SECTIONADD]
	fld	dword [ebp + voxel_t.pos + 4]
	fmul	st1
	fst	dword [esi + edi - voxel_t_size + voxel_t.pos + 4]
	fchs
	fstp	dword [esi + edi - voxel_t_size + voxel_t.pos + 4 + SECTIONADD]
; Y-kordinaatti
	fld	st2
	fst	dword [esi + edi - voxel_t_size + voxel_t.pos + 8]
	fstp	dword [esi + edi - voxel_t_size + voxel_t.pos + 8 + SECTIONADD]
	lea	ecx, [ebp + voxel_t.dir]
	lea	eax, [esi + edi - voxel_t_size + voxel_t.dir]
	call	func_vector_copy
	add	ecx, SPIRALADD
	add	eax, SECTIONADD
	call	func_vector_copy
; Loopin loppu
.dna_section_loop_loppu:
	fadd	st1
	sub	edi, voxel_t_size
	jnz	short .dna_section_loop
; Puolan luonti loppuu	
.dna_section_loop_over:
	fstp	st0
	fstp	st0
	__null	edi
	add	esi, SECTIONADD * 2
; Ja dna:n luonti loppuu
.dna_loop_loppu:
	add	bx, DNA_ROTATION
	inc	edi
	add	ebp, voxel_t_size
	pop	ecx
	dec	ecx
	jnz	near .dna_loop
	fstp	st0
	fstp	st0

; Ihan loppu
.loppu:
	__popa
	ret

;#############################################################################
; func_matrix_mul_vector(dst, srcm, srcv) ####################################
;#############################################################################

; eax = dstvector, edx = matrix, ecx = srcvector

%define STACK_START_MMV		4

func_matrix_mul_vector:
	fld	dword [ecx + 8]
	fld	dword [ecx + 4]
	fld	dword [ecx + 0]
; st0 = v[0], st1 = v[1], st2 = v[2]
	add	eax, 12
	mov	ecx, 36
.loop:
	fld	dword [edx + ecx - 12 + 0]
	fmul	st1
	fld	dword [edx + ecx - 12 + 4]
	fmul	st3
	faddp	st1
	fld	dword [edx + ecx - 12 + 8]
	fmul	st4
	faddp	st1
	fstp	dword [eax - 4]
	sub	eax, 4
	sub	ecx, 12
	jnz	short .loop
	fstp	st0
	fstp	st0
	fstp	st0
	ret

;#############################################################################
; func_matrix_rot(matrix_t dst, rx, ry, rz) ##################################
;#############################################################################

; eax = rotaatioiden sijainti, edi = matrix

func_matrix_rot:
	movzx	edx, word [eax + 4]
	movzx	ecx, word [eax + 2]
	movzx	eax, word [eax + 0]
; eax = rx, ecx = ry, edx = rz
	mov	esi, array_cos
	fld	dword [esi + edx * 4]
	fld	dword [esi + ecx * 4]
	fld	dword [esi + eax * 4]
	mov	esi, array_sin
	fld	dword [esi + edx * 4]
	fld	dword [esi + ecx * 4]
	fld	dword [esi + eax * 4]
; st0 = sx, st1 = sy, st2 = sz, st3 = cx, st4 = cy, st5 = cz
.begincalc:
	fld	st4
	fmul	st6
	fld	st1
	fmul	st3
	fmul	st4
	faddp	st1
	fstp	dword [edi + 0 + 0]
	fld	st0
	fmul	st2
	fmul	st6
	fld	st3
	fmul	st6
	fsubp	st1
	fstp	dword [edi + 0 + 4]
	fld	st1
	fmul	st4
	fstp	dword [edi + 0 + 8]
	fld	st2
	fmul	st4
	fstp	dword [edi + 12 + 0]
	fld	st3
	fmul	st6
	fstp	dword [edi + 12 + 4]
	fld	st0
	fchs
	fstp	dword [edi + 12 + 8]
	fld	st0
	fmul	st3
	fmul	st5
	fld	st2
	fmul	st7
	fsubp	st1
	fstp	dword [edi + 24 + 0]
	fld	st0
	fmul	st5
	fmul	st6
	fld	st2
	fmul	st4
	faddp	st1
	fstp	dword [edi + 24 + 4]
	fld	st3
	fmul	st5
	fstp	dword [edi + 24 + 8]
.loppu:
	fstp	st0
	fstp	st0
	fstp	st0
	fstp	st0
	fstp	st0
	fstp	st0
	ret

;#############################################################################
; func_metaballs() ###########################################################
;#############################################################################

; Ei ota parametreja, kohdemesh tulee aina samaan paikkaan

; Sovimme:
%define METABALL_DIS	tempmatrix
%define METABALL_CIR	tempmatrix_t
; esi on seuraavan vokselin paikka
%define METABALL_SUM	esi + voxel_t.dir
%define METABALL_POS	esi + voxel_t.pos
%define METABALL_ADDR	glob_mshs + MESH_METABALL * mesh_t_size

func_metaballs:
	__pusha
prepare:
	mov	ebp, METABALL_TAHKO + 1
	mov	esi, METABALL_ADDR + mesh_t.dots
	mov	dword [esi - mesh_t.dots + mesh_t.dotc], 0
	mov	ecx, glob_metaball_tahko
	fild	dword [ecx]
	fild	dword [ecx]
	fild	dword [ecx]
	mov	ebx, ebp
xloop:
	fild	dword [glob_metaball_tahko]
	fstp	st2
	mov	edx, ebp
yloop:
	fild	dword [glob_metaball_tahko]
	fstp	st3
	mov	edi, ebp
zloop:
	__null	ecx
	mov	dword [METABALL_SUM + 0], ecx
	mov	dword [METABALL_SUM + 4], ecx
	mov	dword [METABALL_SUM + 8], ecx 
	call	dword [glob_metaballfunc]
	add	[METABALL_ADDR + mesh_t.dotc], ecx
	dec	ecx
	jnz	short skipadd
	add	esi, voxel_t_size
skipadd:
	fld1	
	fsubp	st3
	dec	edi
	jnz	short zloop
yloop_loppu:
	fld1	
	fsubp	st2, st0
	dec	edx
	jnz	short yloop
xloop_loppu:
	fld1	
	fsubp	st1, st0
	dec	ebx
	jnz	short xloop

loppu:
	fstp	st0
	fstp	st0
	fstp	st0
	__popa
	ret

; Kutsuttaville funktioille:
; st0 = x, st1 = y, st2 = z
; eax/ecx = temp, ebx/edx/edi = x/y/z, ebp = reset counter, esi = voxel addr

func_meld:
	mov	ecx, 4 * METABALL_MELD_COUNT
.loop:
	call	func_mb_calcdirdis
	sub	ecx, 4
	jnz	short .loop
; Tylsästi käydään eri vaihtoehdot läpi. Säälittävän tilaa- ja aikaavievää.
	;; sitä kun oot tollanen runkkari, nii
.check_radius_all:
	mov	ecx, METABALL_DIS
	fld	dword [ecx + 8]
	fld	dword [ecx + 4]
	fld	dword [ecx + 0]
	fld	dword [glob_metaball_size + 8]
	fld	st1
	fadd	st3
	fadd	st4
	fcomip	st1
	fstp	st0
	jae	short .check_radius_01
	jmp	short .func_mb_add_all
.check_radius_01:
	fld	dword [glob_metaball_size + 4]
	fld	st1
	fadd	st3
	fcomip	st1
	jae	short .check_radius_02
	fstp	st0
	__null	ecx
	jmp	short .func_mb_add_2
.check_radius_02:
	fld	st1
	fadd	st4
	fcomip	st1
	jae	short .check_radius_12
	fstp	st0
	__null	ecx
	call	func_mb_addtosum
	mov	ecx, 24
	jmp	short .func_mb_add_1
.check_radius_12:
	fld	st2
	fadd	st4
	fcomip	st1
	fstp	st0
	jae	short .check_radius_singles
	mov	ecx, 12
	jmp	short .func_mb_add_2
.check_radius_singles:
	fld	dword [glob_metaball_size + 0]
	fcomi	st1
	jbe	short .check_radius_1
	fstp	st0
	__null	ecx
	jmp	short .func_mb_add_1
.check_radius_1:
	fcomi	st2
	jbe	short .check_radius_2
	fstp	st0
	mov	ecx, 12
	jmp	short .func_mb_add_1
.check_radius_2:
	fcomip	st3
	jbe	short .loppu
	mov	ecx, 24
	jmp	short .func_mb_add_1
.loppu:
	__null	ecx
	fstp	st0
	fstp	st0
	fstp	st0
	ret
.func_mb_add_all:
	__null	ecx
	call	func_mb_addtosum
	add	ecx, 12
.func_mb_add_2:
	call	func_mb_addtosum
	add	ecx, 12
.func_mb_add_1:
	call	func_mb_addtosum
	jmp	short func_meld.ok
.ok:
; Setvoxel poistaa yhden
	fstp	st0
	fstp	st0
	call	func_mb_setvoxel
	mov	ecx, 1
	ret

; Hieno at-kenttäefu, oikeastaan tyylikkäämpi kuin nortsi metaball

func_atfield:
	mov	ecx, METABALL_ATFIELD_COUNT
.clearcircles_loop:
	mov	dword [METABALL_CIR + ecx*4 - 4], 0
	loop	.clearcircles_loop
	mov	ecx, 4 * METABALL_ATFIELD_COUNT
.calcdisloop:
	call	func_mb_calcdirdis
	fld	dword [METABALL_DIS + ecx - 4]
	push	ecx
	mov	ecx, METABALL_ATFIELD_COUNT
.calccircles_loop:
	fld	dword [glob_metaball_size + ecx * 4 - 4]
	fcomip	st1
	jbe	.no_incloop
	mov	eax, ecx
.inccircles_loop:
	inc	dword [METABALL_CIR + eax * 4 - 4]
	inc	eax
	cmp	eax, METABALL_ATFIELD_COUNT
	jle	.inccircles_loop
.no_incloop:
	loop	.calccircles_loop
.calcdisloop_loppu:
	pop	ecx
	fstp	st0
	sub	ecx, 4
	jnz	.calcdisloop
; Nyt kaikkialla on merkinnät joten kelataan uusiksi läpi ja katsotaan
; kasaumat
.prepare_checkdisloop:
	mov	ecx, METABALL_ATFIELD_COUNT
.checkdisloop:
	cmp	dword [METABALL_CIR + ecx * 4 - 4], ecx
	jl	.checkdisloop_loppu
	fld	dword [glob_metaball_size + ecx*4 - 4]
	push	ecx
	mov	eax, METABALL_ATFIELD_COUNT * 4
.sett_loop:
	fld	dword [METABALL_DIS + eax - 4]
	fcomip	st1
	ja	.no_addtosum
	lea	ecx, [eax*2 + eax - 12]
	call	func_mb_addtosum
.no_addtosum:
	sub	eax, 4
	jnz	.sett_loop
.sett_loop_loppu:
	pop	ecx
; Stäckissä 1, mutta poistuu setvoxelissa
	call	func_mb_setvoxel
.true:
	mov	ecx, 1
	ret
.checkdisloop_loppu:
	loop	.checkdisloop
.false:
	__null	ecx
	ret

; Apufunktiot

func_mb_addtosum:
	fld	dword [METABALL_SUM + 0]
	fadd	dword [glob_metaball_dir + ecx + 0]
	fstp	dword [METABALL_SUM + 0]
	fld	dword [METABALL_SUM + 4]
	fadd	dword [glob_metaball_dir + ecx + 4]
	fstp	dword [METABALL_SUM + 4]
	fld	dword [METABALL_SUM + 8]
	fadd	dword [glob_metaball_dir + ecx + 8]
	fstp	dword [METABALL_SUM + 8]
	ret

func_mb_calcdirdis:
	fld	st2
	fsub	dword [glob_metaball_pos + ecx*2 + ecx - 12 + 8]
	fld	st2
	fsub	dword [glob_metaball_pos + ecx*2 + ecx - 12 + 4]
	fld	st2
	fsub	dword [glob_metaball_pos + ecx*2 + ecx - 12 + 0]
	call	func_vector_len
	fstp	dword [METABALL_DIS + ecx - 4]
	fstp	dword [glob_metaball_dir + ecx*2 + ecx - 12 + 0]
	fstp	dword [glob_metaball_dir + ecx*2 + ecx - 12 + 4]
	fstp	dword [glob_metaball_dir + ecx*2 + ecx - 12 + 8]
	ret

func_mb_setvoxel:
	fstp	st0
	fld	st2
	fld	st2
	fld	st2
	fstp	dword [METABALL_POS + 0]
	fstp	dword [METABALL_POS + 4]
	fstp	dword [METABALL_POS + 8]
.vector_unit:
	fld	dword [METABALL_SUM + 8]
	fld	dword [METABALL_SUM + 4]
	fld	dword [METABALL_SUM + 0]
	call	func_vector_len
	fldz
	fcomip	st1
	jne	short .jatkuu
; Jos kyseessä on tapaus, jossa summa on 0, sanomme evvk (ei kaadu!)
	fstp	st0
	jmp	short .loppu
.jatkuu:
	fdiv	st1, st0
	fdiv	st2, st0
	fdivp	st3, st0
.loppu:
	fstp	dword [METABALL_SUM + 0]
	fstp	dword [METABALL_SUM + 4]
	fstp	dword [METABALL_SUM + 8]
	ret

;#############################################################################
; func_textout() #############################################################
;#############################################################################

; Normaalit konventiot, textout(x, y, väri, string)

%define CHARACTER_COUNT		13
%define STACK_START_TEXTOUT	36

func_textout:
%ifdef FLAG_INCLUDE_TEXTOUT
	__pusha

	imul	edx, SCREEN_W * BUFFER_DETAIL
	mov ecx, 10
.loop:
	push ecx
	push ebp		
	push	ebx
	push	eax
	push	edx
	movzx ebx, byte [string1 + ebp]
; eax = x, edx = y, ebx = character index
.drawchar_yloop_prepare:
	mov	ebx, [glob_font + ebx * 4]
	mov	ebp, 6
.drawchar_yloop:
	mov	ecx, 5
	mov	esi, eax
.drawchar_xloop:
	shl	ebx, 1
	jnc	short .drawchar_xloop_loppu
	movbpp	[buffer_c + edx + esi * BUFFER_DETAIL], di, edi, BUFFER_DETAIL
.drawchar_xloop_loppu:
	inc	esi
	loop	.drawchar_xloop
.drawchar_yloop_loppu:
	add	edx, SCREEN_W * BUFFER_DETAIL
	dec	ebp
	jnz	short .drawchar_yloop
.drawchar_loppu:
	pop	edx
	pop	eax
	add	eax, 6
.drawchar_return:		
	pop	ebx
	pop ebp
	inc ebp
	pop ecx
	loop .loop
; Lopetamme textouttaamisen	
.end:

.loppu:
	__popa
%endif
	ret

;#############################################################################
; func_vector_copy(dst, src) #################################################
;#############################################################################

; eax = dst, ecx = src, edx = temp

func_vector_copy:
	mov	edx, [ecx + 0]
	mov	[eax + 0], edx
	mov	edx, [ecx + 4]
	mov	[eax + 4], edx
	mov	edx, [ecx + 8]
	mov	[eax + 8], edx
	ret

;#############################################################################
; func_vector_len() ##########################################################
;#############################################################################

; Ottaa parametrit st0-st2, palauttaa st0
; Käyttää vain 2 fld:tä
; Ei tuhoa dataa

func_vector_len:
	fld	st0
	fmul	st0
	fld	st2
	fmul	st0
	faddp	st1
	fld	st3
	fmul	st0
	faddp	st1
	fsqrt
	ret

;#############################################################################
; Kontrolli ##################################################################
;#############################################################################

; Ajastus
%define DURATION_DNA		1024
%define DURATION_MELD		1024
%define DURATION_JULIA          1536
%define DURATION_ATFIELD1	1024
%define DURATION_ATFIELD2	1024
%define DURATION_MULTIDNA	2048
%define DURATION_HEART		2048


%ifdef PERSKELE
%define DURATION_DNA		10
%define DURATION_MELD		10
%define DURATION_JULIA          15
%define DURATION_ATFIELD1	10
%define DURATION_ATFIELD2	1024
%define DURATION_MULTIDNA	1024 + 512 + 128
%define DURATION_HEART		2048
%endif
	
%define END_DNA			DURATION_DNA
%define END_MELD		(END_DNA + DURATION_MELD)
%define END_JULIA		(END_MELD + DURATION_JULIA)
%define END_ATFIELD1		(END_JULIA + DURATION_ATFIELD1)
%define END_ATFIELD2		(END_ATFIELD1 + DURATION_ATFIELD2)
%define END_MULTIDNA		(END_ATFIELD2 + DURATION_MULTIDNA)
%define END_HEART		(END_MULTIDNA + DURATION_HEART)
%define START_DNA		END_DNA-DURATION_DNA
%define START_MELD		END_MELD-DURATION_MELD
%define START_JULIA		END_JULIA-DURATION_JULIA
%define START_ATFIELD1		END_ATFIELD1-DURATION_ATFIELD1
%define START_ATFIELD2		END_ATFIELD2-DURATION_ATFIELD2
%define START_MULTIDNA		END_MULTIDNA-DURATION_MULTIDNA
	
; Johdannaiset
%define START_FIRE		512
%define END_FIRE		(END_ATFIELD1)
%define START_MULTIDNA		END_ATFIELD2
%define END_INTRO		END_HEART

; Apufunktiot
; eax = timer

; edi = objpos, bx = rx, cx = ry, dx = rz
func_ctrl_set_rotref:
	mov	word [edi + object_t.rot + 0], bx
	mov	word [edi + object_t.rot + 2], cx
	mov	word [edi + object_t.rot + 4], dx
	mov	dword [edi + object_t.ref], esi
	ret

; Ottaa parametrit seuraavasti:
; bx/cx/dx = rx/ry/rz
; edi = destination (x, y, z)
; stackissa: x, y, z, xmul, ymul, zmul
func_ctrl_set_sines:
	mov	esi, ebx
	and 	esi, 0xFFFF
	fld	dword [array_sin + esi*4]
	fimul	dword [esp + 4 + 12 + 0]
	fiadd	dword [esp + 4 + 0]
	fstp	dword [edi + object_t.pos + 0]
	mov	esi, ecx
	and 	esi, 0xFFFF
	fld	dword [array_sin + esi*4]
	fimul	dword [esp + 4 + 12 + 4]
	fiadd	dword [esp + 4 + 4]
	fstp	dword [edi + object_t.pos + 4]
	mov	esi, edx
	and 	esi, 0xFFFF
	fld	dword [array_sin + esi*4]
	fimul	dword [esp + 4 + 12 + 8]
	fiadd	dword [esp + 4 + 8]
	fstp	dword [edi + object_t.pos + 8]
	ret	

; Pääfunktio
func_control:
	__pusha
	mov	eax, [glob_timer]
	lea	edx, [eax * 8]
	shl	edx, 2
	mov	word [glob_lit + light_t.rot + 0], dx
	shl	edx, 1
	mov	word [glob_lit + light_t.rot + 2], dx
	shl	edx, 1
	mov	word [glob_lit + light_t.rot + 4], dx

.check_dna:
	cmp	eax, END_DNA
	jg .check_meld
	cmp eax, START_FIRE
	jl .nof	
	;; basarivilkkupaletti!
	mov	byte [glob_fire], 3
.nof
	call .efu_dna
	call	func_drawworld

	jmp .loppu	
	; 	jmp	short .efu_dna

.check_meld:
	cmp eax, END_MELD
	jg .check_julia
	;; basarivilkkupaletti!
	mov	byte [glob_fire], 3
	push eax
	mov [pal_bottom], byte 0
	and eax, 0x1f
	cmp al,0x8
	jg .proror
	mov [pal_bottom], byte 0x80
.proror:	
	pop eax	
	call .efu_metaballefux
	call	func_drawworld
	jmp .loppu	

.check_julia:
	cmp	eax, END_JULIA
	jg .check_metaballefux1
	;; julian paletti
	mov [pal_bottom], byte 0
	mov [pal1], dword 0x8800aaff
	mov [pal2+1], word 0x0000

	
	call .efu_julia
	call	func_drawworld
	jmp .loppu	

.check_metaballefux1:
	cmp	eax, END_ATFIELD1
	jg .check_metaballefux2

	mov [pal1], dword 0x00aaaaff
	mov [pal2+1], word 0x8800

	
	call .efu_metaballefux
	call	func_drawworld
	jmp .loppu

	;; ilman lieskaa jälkikuvalla
.check_metaballefux2:
	cmp	eax, END_ATFIELD2
	jg near .check_multidna

	mov [pal1], dword 0x000000ff
	mov [pal2+1], word 0xff00


	push eax
	push eax
	mov [voxel_draw_mask], word 0xff00
	call .efu_metaballefux
	mov [glob_fire], byte 0xff
	call	func_drawworld
	pop eax
	sub eax, 30
	mov [voxel_draw_mask], word 0x00ff ;	
	mov [voxel_bg_mask], word 0xff00
	call .efu_metaballefux	
	mov [glob_fire], byte 0
	call	func_drawworld

	pop eax
	sub eax, START_ATFIELD2
	shr eax, 7		; Griitsien määrä
	imul ebp, eax, byte 10
	
	;; greetziih huarat vittu
	mov eax, 3
	mov edx, 40
	mov edi, 0x00ff		; 	mov ebx, string1
	call func_textout
		
	jmp .loppu

.check_multidna:
	cmp	eax, END_MULTIDNA
	jg .check_heart
	;; palettivilahdus
	push eax
	sub eax, START_MULTIDNA
	cmp eax, 255
	jnc .multidna_nopal
	mov bl, 255
	sub bl, al
	mov [pal_bottom], bl
	mov [pal1], dword 0x000000ff
	mov [pal2+1], word 0xffff

.multidna_nopal:
	pop eax		

	push eax
	mov [voxel_draw_mask], word 0xff00
	call .efu_multidna	
	mov [glob_fire], byte 0xff
	call	func_drawworld
	pop eax
	mov [voxel_draw_mask], word 0x00ff ;	
	mov [voxel_bg_mask], word 0x0000
	call .efu_metaballefux	
	mov [glob_fire], byte 0x00
	call	func_drawworld
	jmp short .loppu
	; 	jmp	near .efu_multidna

.check_heart:
	cmp	eax, END_MULTIDNA
	jl	.loppu
	mov [quit_flag], byte 1
.loppu:

;;; palettirunkku
.makepalette:	
	pusha		

	mov ecx, 16
	.pal_loop
	push ecx

	dec ecx
	
	mov edi, ttesst+3
	
	mov al, [palette_chars+ecx]
	stosb			; värin numero

	;; osavärit
	mov esi, 3
.ovloop:
	push ecx
	push esi

	test cl, 8
	jz .fapiti
	add esi, 3	
.fapiti:	
	
	and cl, 7	
	
	__null	eax
	__null	ebx
	__null	edx
	mov al, [pal1-1+esi]

	;; range
	mov bl, [pal_top]
	mov dl, [pal_bottom]
	sub ebx, edx

	imul eax, ebx
	imul eax, ecx
	shr eax, 3+8		; nyt välillä 0-255 taas
	add eax, edx

	__null	edx
	
	mov ebp, 16
	div ebp
	mov al, [palette_chars+eax]
	stosb			; 
	mov al, [palette_chars+edx]
	stosb			; 

	pop esi
	pop ecx
	dec esi
	jnz .ovloop

	mov eax, 4		; säädä väri
	mov ebx, 1
	mov ecx, ttesst	
	mov edx, 10
	int 0x80

	pop ecx
	loop .pal_loop
	
	popa		
	
	__popa
	ret
; DNA
.efu_dna:	
	mov	dword [glob_objc], 1 
	lea	edx, [eax * 8]
	;; 	lea	edx, [edx * 4]	lea	ecx, [edx * 4]
	shl edx, 2
	mov ecx, edx
	shl ecx, 2
	lea	ebx, [edx + 16384]
	mov	edi, glob_objs
	__null	esi
	push	esi
	push	esi
	push	esi
	push	dword -50
	push	esi
	push	esi
	call	func_ctrl_set_sines
	add	esp, 24
	mov	esi, MESH_DNA
	call	func_ctrl_set_rotref
	ret			
	; 	jmp	short .loppu
; MELD ja ATFIELD
.efu_metaballefux:
	mov	dword [glob_objc], 1
	mov	ebx, -6000
	__null	ecx
	mov	edx, eax
	shl	edx, 4
	push	ecx
	push	ecx
	push	ecx
	push	dword -45
	push	dword 4
	push	ecx
	cmp	eax, END_MELD
; Jos atfield meldin sijaan teemme pari muutosta
	jl	.efu_meld_noatfield
	mov	dword [esp + 4], 0
	__null	ebx
	mov	edi, glob_metaball_size
	mov	esi, glob_metaball_size2
	mov	ecx, METABALL_MAX
	mov	dword [glob_metaballfunc], func_atfield
	rep	movsd
.efu_meld_noatfield
	mov	edi, glob_objs
	mov	esi, MESH_METABALL
	call	func_ctrl_set_rotref
	call	func_ctrl_set_sines
	add	esp, 24
	lea	ebx, [eax*8 + eax]
	__null	edx
	lea	ecx, [ebx*2]
	lea	ebx, [ebx*8 + ebx]
	mov	edi, glob_metaball_pos - object_t.pos + 0
	__null	esi
	push	esi
	push	10
	push	20
	push	esi
	push	-5
	push	esi
	call	func_ctrl_set_sines
	add	edi, 12
	add	ebx, 16384
	mov	dword [esp + 4], 5
	call	func_ctrl_set_sines
	add	edi, 12
	xchg	ebx, ecx
	add	esp, 24
	__null	esi
	push	esi
	push	20
	push	10
	push	esi
	push	esi
	push	-5
	call	func_ctrl_set_sines
	add	edi, 12
	add	ecx, 16385
	mov	dword [esp + 0], 5
	call	func_ctrl_set_sines
	add	esp, 24
	call	func_metaballs
	ret			
	; 	jmp	near .loppu
; MULTIDNA
.efu_multidna:
	mov	ebp, EFFECT_TUNNEL_DNACOUNT
	mov	dword [glob_objc], ebp
	mov	edi, glob_objs
	lea	ebx, [eax * 8 + eax]
	lea	ebx, [ebx * 8 + ebx]
	__null	edx
.multidna_loop:
	push	ebx
	__null	ebx
	__null	ecx
	mov	esi, MESH_DNA
	call	func_ctrl_set_rotref
	pop	ebx
	lea	ecx, [ebx + 16384]
	lea	esi, [eax - START_MULTIDNA]
	shr	esi, 1
	sub	esi, DNA_HEIGHT_INT
	push	dword edx
	push	dword 15
	push	dword 15
	push	dword esi
	push	dword edx
	push	dword edx
	call	func_ctrl_set_sines
	add	esp, 24
	add	ebx, 65536 / EFFECT_TUNNEL_DNACOUNT
	add	edi, object_t_size
	dec	ebp
	jnz	.multidna_loop
	ret			
	; 	jmp	near .loppu 
; JULIA
.efu_julia:
	mov	dword [glob_objc], 0
	mov	esi, juliadata
	lea	ebx, [eax + eax*8]
	lea	ebx, [ebx + ebx*8]
	lea	ecx, [ebx*2]
	mov	edx, array_sin
	and	ebx, 0xFFFF
	fld	dword [edx + ebx * 4]
	fmul	dword [esi + juliadata_t.xmul]
	fadd	dword [esi + juliadata_t.xbase]
	fstp	dword [esi + juliadata_t.mandelx]
	and	ecx, 0xFFFF
	fld	dword [edx + ecx * 4]
	fmul	dword [esi + juliadata_t.ymul]
	fadd	dword [esi + juliadata_t.ybase]
	fstp	dword [esi + juliadata_t.mandely]
	ret

;#############################################################################
; Muuttujat ##################################################################
;#############################################################################


piipershort		dd	0.0000958737992429 ; PI / 32768.0
glob_backintperfloat	dd	32.768 ; BACKINT / BACKFLOAT
glob_dir		dd	0, -1.0, 0
glob_dna_height		dd	DNA_HEIGHT
glob_dna_radius		dd	DNA_RADIUS
glob_dna_section_div	dd	0.05	; 1 / DNA_SECTION
glob_dna_spiral_div	dd	0.002	; 2 / DNA_SPIRAL
glob_lightbase		dd	0.55
glob_lightmul		dd	-0.45 
glob_metaballfunc	dd	func_meld
glob_metaball_size	dd	5.0, 15.0, 25.0, 30.0
glob_metaball_size2	dd	4.0, 8.0, 12.0, 16.0
glob_metaball_tahko	dd	(METABALL_TAHKO / 2)
glob_screenh		dd	(SCREEN_H / 2)
glob_screenw		dd	(SCREEN_W / 2)
glob_voxel_size		dd	VOXEL_SIZE


; Valinnaisuus
%ifdef FLAG_INCLUDE_TEXTOUT
glob_font
	dd 0
	dd 11111101000010000100001000010000b ; 1 t	
	dd 11111010000100001110010000111100b ; 2 e
	dd 11110010010100101110010100100100b ; 3 r
	dd 11110010010111001001010011111000b ; 4 b
	dd 01110100011000111111100011000100b ; 5 a
	dd 01110100011000010111100010111000b ; 6 g
	dd 01110100011000110001100010111000b ; 7 o
	dd 01110100011000110101100110111100b ; 8 q
	dd 01110100000100000110000010111000b ; 9 s
	dd 01100010000100001000010011111100b ; 10 l
	dd 01110001000010000100001000111000b ; 11 i
	dd 01110000100001000010010100011000b ; 12 j
	dd 10001100011000111111100011000100b ; 13 h
	dd 10001100011000110001100010111000b ; 14 u
	dd 10001100010101001010010100010000b ; 15 v
	dd 10001110111111110101100011000100b ; 16 m
	dd 10001110011110110111100111000100b ; 17 n
%endif

;#############################################################################
; Loppu ######################################################################
;#############################################################################

	
;;; -----------------------------------------------------------------------------
;;; itse piisi, formaatti muistuttanee viimevuotista
;;; -----------------------------------------------------------------------------

;;; rakenne:
;;;  
;;;  db delay_len, delay_fb, vol, filter_offset (left)
;;;  db delay_len, delay_fb, vol, filter_offset (right)
;;;
;;;  db b1, b2  (*n)
;;; byte1:	0x00 end, 0x01-0x7f kesto, 0x80-0xfd loop (counter = byte-0x80), 
;;;		0xfe filsuctl abs (& spd=0), 0xff filsuctl spd
;;; byte2:	nuotti:	0x00 - b0-3 nro 4-7 shift  looppi: matka
;;;		filsu: abs val / sped
;;; 0x00 lopettaa äänen
	
;;; vähän testisahakuvioo täs ensiksi

voice1:
	dd -TEMPO*12, -320, 180 ; left
	dd -TEMPO*16,  360, 165 ; right

 	db 0xfe, 0x08		; filsu

	db 0x40, 0x0c
	db 0x87, 1

	;; tilu tulee

	db 0xff, 0x81
	;; 	db 0x40, 0x00		; 	db 0x85, 1
	db 0x01, 0x50
	db 0x01, 0x0c
	db 0x01, 0x55
	db 0x01, 0x0c
	db 0x01, 0x57	
	db 0x1f, 0x0c
	db 0x87, 6

	db 0x20, 0x0c

 	db 0xfe, 0x0a		; filsu
	db 0xff, 0x86
	;; diuuuu
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	db 0x01, 0x0c
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	
	db 0x05, 0x0c

	db 0x01, 0x50

	db 0x0b, 0x0c

	db 0x01, 0x6a
	db 0x01, 0x0c
	db 0x01, 0x50
	db 0x01, 0x0c
	db 0x01, 0x57
	db 0x03, 0x0c
	db 0x81, 16

	
 	db 0xfe, 0x30		; filsu
	db 0xff, 0x89
		
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	db 0x01, 0x0c
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	
	db 0x05, 0x0c

	db 0x01, 0x50

	db 0x0b, 0x0c

	db 0x01, 0x6a
	db 0x01, 0x0c
	db 0x01, 0x50
	db 0x01, 0x0c
	db 0x01, 0x57

	db 0x03, 0x0c

	db 0x86, 16

	;; duuriin
	db 0xff, 0x90
	db 0x01, 0x55
	db 0x01, 0x0c
	db 0x01, 0x54
	db 0x01, 0x0c
	db 0x01, 0x55
	db 0x01, 0x0c
	db 0x01, 0x54
	
	db 0x05, 0x0c

	db 0x01, 0x50

	db 0x0b, 0x0c

	db 0x01, 0x67
	db 0x01, 0x0c
	db 0x01, 0x50
	db 0x01, 0x0c
	db 0x01, 0x57

	db 0x03, 0x0c

	db 0xfe, 0x50
	db 0xff, 0x7e

	db 0x81, 36

	db 0xfe, 0x10

	db 0x40, 0x0c
	db 0x83, 1
	
	;; melodian jälkeen
	db 0xff, 0x93
		
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	db 0x01, 0x0c
	db 0x01, 0x53
	db 0x01, 0x0c
	db 0x01, 0x52
	
	db 0x05, 0x0c

	db 0x01, 0x50

	db 0x0b, 0x0c

	db 0x01, 0x6a
	db 0x01, 0x0c
	db 0x01, 0x50
	db 0x01, 0x0c
	db 0x01, 0x57

	db 0x03, 0x0c

	db 0x83, 16
	
		
	db 0x00
			; end voice 1

bass1:	
	dd -TEMPO*2, -150, 172 ; left
	dd -TEMPO*3, 150, 172 ; right

	db 0xfe, 0x15
	
	db 0x04, 0x0c
	db 0x04, 0x80
	db 0xbf, 2

	db 0xfe, 0x15

	;; tilu tulee
	db 0x40, 0x0c
	db 0x85, 1

	db 0x04, 0x0c
	db 0x04, 0x98
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x9a
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x95
	db 0x86, 2

	db 0x04, 0x0c
	db 0x04, 0x97

	;; duuriin
	db 0x04, 0x0c
	db 0x04, 0x98
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x9a
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x97
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x80
	db 0x83, 2

	db 0x81, 23

	;; melodiaosa
	db 0x04, 0x0c
	db 0x04, 0x98
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x9a
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x97
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x80
	db 0x83, 2
	;; 
	db 0x04, 0x0c
	db 0x04, 0x98
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x9a
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x83
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x95
	db 0x83, 2
	;; 
	db 0x04, 0x0c
	db 0x04, 0x98
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x9a
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x97
	db 0x83, 2

	db 0x04, 0x0c
	db 0x04, 0x80
	db 0x83, 2
			
	db 0x00
	
pad1:	
	dd -24000, 330, 140 ; left
	dd -33200, -320, 140 ; right

	db 0x40, 0x00
	db 0x87, 1

	;; tilu tulee

	db 0xfe, 0x03
	db 0xff, 0x82	
	db 0x40, 0x07
	db 0x40, 0x01
	db 0x40, 0x09
	db 0x40, 0x02

	db 0xff, 0x7c
	db 0x40, 0x07
	db 0x40, 0x07
	
 	db 0xfe, 0x40		; filsu	
	db 0xff, 0x81
	
	db 0x20, 0x02
	db 0x20, 0x03
	db 0x40, 0x04

	;; duuriin
	db 0x20, 0x02
	db 0x20, 0x03
	db 0x20, 0x05
	db 0x20, 0x06

	db 0x81, 7

	db 0x20, 0x02
	db 0x20, 0x03
	db 0x20, 0x05
	db 0x20, 0x07

	db 0x20, 0x02
	db 0x20, 0x03
	db 0x20, 0x01
	db 0x20, 0x08

	db 0x20, 0x02
	db 0x20, 0x03
	db 0x20, 0x05
	db 0x20, 0x07

	db 0xff, 0x72
	db 0x60, 0x02

	db 0xfe, 0x10
	db 0x40, 0x00
				
	db 0x00
	
hh1:	
	dd -1800, -350, 30 ; left
	dd -1800, -350, 25 ; right

	db 0x40, 0x00
	db 0x81, 1

	db 0x04, 0x00
	db 0x04, 0x0c
	db 0xaf, 2
	
	;; tilu tulee
	db 0x40, 0x00
	db 0x85, 1
	
	db 0x02, 0x01
	db 0x02, 0x01
	db 0x02, 0x0c
	db 0x02, 0x01

	db 0xef, 4

	db 0x00
	
bd1:	
	dd -1800, 50, 70 ; left
	dd -1800, 50, 70 ; right

	db 0x08, 0x08
	db 0xbf, 1

	db 0x40, 0x08
	
	;; tilu tulee
	db 0x40, 0x00
	db 0x83, 1

	db 0x38, 0x08
	db 0x02, 0x08
	db 0x02, 0x08
	db 0x02, 0x08
	db 0x02, 0x08
		
	db 0x08, 0x08
	db 0x9e, 1

	db 0x04, 0x08
	db 0x02, 0x08
	db 0x02, 0x08

	db 0x82, 5

	db 0x08, 0x08
	db 0x90, 1

	db 0x00

sd1:
	dd -1000, 200, 200 ; left
	dd -1000, 200, 200 ; right

	db 0x08, 0x00
	db 0xbf, 1

	;; tilu tulee
	db 0x40, 0x00
	db 0x85, 1

	db 0x08, 0x00
	db 0x08, 0x08
	db 0x8e, 2

	db 0x08, 0x00
	db 0x06, 0x08
	db 0x02, 0x08

	db 0x82, 6

	db 0x08, 0x00
	db 0x08, 0x08
	db 0x87, 2

	db 0x00

rez1:
	dd -TEMPO*7, 180, 100 ; left
	dd -TEMPO*5, 200, 120 ; right

	db 0xfe, 0x10

	db 0x40, 0x0c
	db 0x8c, 1

	;; diuuuu
	db 0xfe, 0x90
	db 0xff, 0x68
	db 0x40, 0x80	

	db 0xfe, 0x10
	db 0x40, 0x0c
	db 0x8b, 1
	
	db 0xfe, 0x58
	db 0xff, 0x7b
	db 0x20, 0x98
	db 0x20, 0x9a
	db 0x20, 0x97
	db 0x20, 0x80

	;; loppudiu
	db 0xfe, 0x90
	db 0xff, 0x72
	db 0x70, 0x98

	db 0xfe, 0x10
	db 0x40, 0x0c

	db 0x00
	
rez2:	
	dd -TEMPO*3, 340, 70 ; left
	dd -TEMPO*5, -300, 60 ; right

	db 0xfe, 0x40

	db 0x40, 0x0c
	db 0x8f, 1

	;; tilu tulee
	db 0x40, 0x0c
	db 0x85, 1

	db 0xff, 0x98		;	 
	db 0x36, 0x60
	db 0x06, 0x62	
	db 0x04, 0x63	

	db 0x1f, 0x67

	db 0xff, 0x78		; 
	db 0x01, 0x69
	db 0x10, 0x6a
	db 0x10, 0x67

	db 0x20, 0x65

	db 0x10, 0x63
	db 0x10, 0x65
	db 0x20, 0x67

	db 0x0c, 0x69
	db 0x0c, 0x6a
	db 0x08, 0x69

	db 0x0c, 0x67
	db 0x0c, 0x65
	db 0x08, 0x60

	db 0x1c, 0x62	
	db 0x02, 0x63
	db 0x02, 0x62

	db 0x40, 0x7a

	db 0xfe, 0x70
	db 0xff, 0x78
	db 0x70, 0x88

	db 0xfe, 0x10
	db 0x40, 0x0c
	
	db 0x00

rez3:				; tässä on delay ja särö!
	dd -TEMPO*2, 260, 16 ; left
	dd -TEMPO*3, -290, 16 ; right

	db 0xfe, 0x40

	db 0x40, 0x0c
	db 0x83, 1

	db 0xfe, 0x18
	db 0xff, 0x82

	db 0x01, 0x80
	db 0x01, 0x0c
	db 0x01, 0x80
	db 0x01, 0x0c
	db 0x02, 0x80
	db 0x02, 0x0c
	db 0x02, 0x80
	db 0x02, 0x0c
	db 0x01, 0x80
	db 0x01, 0x0c
	db 0x01, 0x80
	db 0x01, 0x0c
		
	db 0x8f, 12

	db 0xff, 0x79
	db 0x70, 0x90		; 	
	
	db 0xfe, 0x20
	db 0x00	
		
				
;;; -----------------------------------------------------------------------------
;;; dataa
;;; -----------------------------------------------------------------------------

notetable:
	dw 20924 		; C
	dw 22168		; C#
	dw 23486		; D
	dw 24883		; D#
	dw 26362		; E
	dw 27930		; F
	dw 29591		; F#
	dw 31351		; G
	dw 33215		; G#
	dw 35190		; A
	dw 37282		; A#
	dw 39499		; B
	
padchords:

	dw 0			; hiljaa
	dw 0000010010001000b	; C 1
	dw 0000000100001001b	; F 2
	dw 0000010000100100b	; G 3
	dw 0000000100100001b	; d 4
	dw 0000010010000100b	; e 5
	dw 0000000010010001b	; A 6
	dw 0000000010001001b	; a 7
	dw 0000001000100001b	; D 8
	dw 0000001000100100b    ; h 9
	
dsp_fmt:
	dd 0x00000010
dsp_rate:
	dd 44100
dsp_channels:
	dd 2

voxel_draw_mask:	
	dw 0xffff
		
voxel_bg_mask:	
	dw 0x0000	
		
quit_flag:
	dd 0

glob_fire:
	dd 255

	;; rmm ninive vv blamstrain valquis juhovh
string1:	
	db 6, 3, 2, 2, 1, 9, 0, 0, 0, 0
string2:	
 	db 4, 10, 5, 16, 9, 1, 3, 5, 11, 17 
string3:	
	db 12, 14, 13, 7, 15, 13, 0, 0, 0, 0
string4:			; 	db 17, 11, 17, 11, 15, 2,  0, 0, 0, 0
string5:	
	db 3, 16, 16, 0, 0, 0, 0, 0, 0, 0
string6:			; 	
	db 15, 5, 10, 8, 14, 11, 9, 0, 0, 0
string7:	
	db 15, 15

filesize equ $ - $$


;;; -----------------------------------------------------------------------------
;;; uninit. paska
;;; -----------------------------------------------------------------------------
	
section .bss data align=1

resd 30
	
vscreen1:
vscreen2:
	
desc_devdsp:
	resd 1

desc_stdin:
	resd 1

audio_thread_pid:
	resd 1
	
loops:
	resb 40000

pad_note_buf:
	resd 16*16

;;; reilusti tilaa audiolle

	resb 100000 		; delaylle nollaa
	
audio_temp_l:
	resw 44100*SONGLEN

audio_temp_r:
	resw 44100*SONGLEN

audio_mix:
	resd 44100*SONGLEN*2

looptemp:	
count_info:	
	resb 998
array_cos		resd	65536
array_sin		resd	65536
buffer_c		resb	BUFSIZE_C * BUFFER_DETAIL
buffer_z		resb	BUFSIZE_Z * BUFFER_DETAIL
glob_lit		resb	light_t_size
glob_mshs		resb	MSH_NUM * mesh_t_size
glob_objc		resd	1
glob_objs		resb	OBJ_NUM * object_t_size
glob_metaball_pos	resd	METABALL_MAX * 3
glob_metaball_dir	resd	METABALL_MAX * 3
glob_timer		resd	1
temp1			resd	1
temp2			resd	1
temp3			resd	1
tempmatrix		resd	9
tempmatrix_t		resd	9
tempvector_l		resd	3
tempvector_t		resd	3

temp:
	resd 100

pt_regs:	
	.ebx:           resd 1
	.ecx:           resd 1 
	.edx:           resd 1
	.esi:           resd 1
        .edi:           resd 1
	.ebp:           resd 1
	.eax:           resd 1
	.xds:           resd 1
	.xes:           resd 1
	.orig_eax:      resd 1
	.eip:           resd 1
	.xcs:           resd 1
	.eflags:        resd 1
	.esp:           resd 1
	.xss:           resd 1
	
