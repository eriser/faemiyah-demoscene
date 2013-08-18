;;;  tehään sit textmodegraffaaa kun ei fb:ta tueta, kele ;)
	
BITS 32	

	org     0x08004000
	
section .text code align=1	

;;;  jos argumentteja annettu, niin nosoundmodee
;;; (tee simppeli paska sleeppiajastus ja skippaa auduohommat)

;;; hoitele argumentit
	call generate_julia

	mov eax, [esp]		; argc
	dec eax

	test al, 0x02
	jz ei_25_lines
	inc dword [lines_modpoint+2]
ei_25_lines:	
	
	test al, 0x01
	jz soundit_paalla
	;; nosound-mode (säännöt vaatii)
	add byte [nosound_modpoint+1], nosound_viive-asdfioxxx
	
	jmp short nosaund
soundit_paalla:
	
	;; avaa /dev/dsp
	mov eax, 5		; open
	mov ebx, str_devdsp	; pointteri nimistringiin
	xor ecx, ecx
	inc ecx			; 
	xor edx, edx
	int 0x80

	mov [desc_devdsp], eax	; descriptori talteen
	push eax
	
	;; 16bit LE mono
	mov ebx, eax		; fdesc
	mov eax, 54		; ioctl
	push eax
 	mov edx, dsp_fmt	; pointer to arguments
	mov ecx, 0xc0045005	; ioctl command
	int 0x80	

	;; 44100KHz
	pop eax			; 54 (ioctl)
	pop ebx			; filedesc
;	mov eax, 54		; ioctl
	mov ecx, 0xc0045002	; ioctl command
	mov edx, dsp_rate	; pointer to arguments
	int 0x80	

	;; resofilsu init
;	pxor mm6, mm6		; d0
;	pxor mm7, mm7		; d1
	;; näyttäis mmx-rekisterit(kin) olevan nollaa aluksi, kivaa

nosaund:	

	;; avaa stdin
	mov eax, 5
	mov ebx, str_devstdin
	mov ecx, 04000
	mov edx, 0
	int 0x80
	mov [stdin_desc], eax
		
;	jmp eipiisi
	ASDF equ 1024*0
		
		
	;; bass
	mov esi, bass
	mov edx, sawnote
	call makesong
	mov edx, resommx
	call makesong
	call mix_audio_bufs

	;; dikidii
	mov edx, sawnote
	call makesong
	mov edx, resommx
	call makesong
	call mix_audio_bufs

	;; dikidii2
;	mov edx, sawnote
;	call makesong
;	mov edx, resommx
;	call makesong
;	call mix_audio_bufs
	
	;; melodia
	mov edx, pianonote
	call makesong
	mov edx, resommx
	call makesong
	call mix_audio_bufs

	;; melodian kakkosääni
	mov edx, pianonote
	call makesong
	mov edx, resommx
	call makesong
	call mix_audio_bufs

	;; padi
	mov edx, padchord
	call makesong
	mov edx, resommx
	call makesong
	call mix_audio_bufs
		
	;; filtteristä reso pois nyt
 	mov [mod_point + 3], byte 16

	mov edx, basari
	call makebiit
	mov edx, resommx
	call makesong
	call mix_audio_bufs

	mov edx, hihat
	call makebiit
	call mix_audio_bufs

	;; hihat pidemmäks
	mov [mod_point2+1], word 3500
	
	mov edx, hihat
	call makebiit
	call mix_audio_bufs

	mov edx, snare
	call makebiit
	mov edx, resommx
	call makesong
	call mix_audio_bufs

eipiisi:	

;;; dumppaa piisi stderriin ja poistu
;	mov eax, 4
;	mov ebx, 2
;	mov ecx, audio_mix
;	mov edx, 44100*280
;	int 0x80
;	jmp helevettiin
	
	;; tyhjää ruutu ja tee muuta escapeilla aluks
	mov eax, 4
	mov ebx, 1
	mov ecx, alku_escseq
	mov edx, 8
	int 0x80
		
	call tunneli_precalc
	call bumpmap_precalc
	call generate_tunnel_texture
			
;	jmp helevettiin
	
	call writeaudio

	;; audio vaan heti virtaamaan
	mov ebx, [desc_devdsp]	; fdesc
	mov eax, 54		; ioctl
	mov edx, dsp_fmt	; pointer to arguments
	mov ecx, 0x00005008	; ioctl command
	int 0x80	

	mov ebp, script	
looppi:
	
	cmp [ebp], dword 0
	je helevettiin
	
	call writeaudio		; nosound-modessa kutsutaan tässä sleeppiajastinta

	;; tyhjää vscreenit
	mov edi, vscreen1
	mov ecx, 80*50*2
	xor eax,eax
	rep stosd
	
	call [ebp]		; paletti tms.
	mov edi, vscreen1
	call [ebp+4]
	mov edi, vscreen2
	call [ebp+8]
	
	mov eax, [sync]
	sub eax, [ebp+12]

	jc einext_script
	add ebp, 16
einext_script:	
		
	call flipmmx

	cmp byte [quit_flag], 0
	jne helevettiin
	
;	cmp dword [sync], 1024*10+768
;	jnc looppi
	jmp short looppi
	
helevettiin:		
	;; poistu
	mov eax, 4
	mov ebx, 1
	mov ecx, lopputeksti
	mov edx, lpt-lopputeksti
	int 0x80
	
	xor eax, eax 		
	inc eax 		; eax==1 (exit)
	int 0x80

	quit_flag:
	dd 0

;;; ruutu tyhjäks, kursori päälle ja jotai muutakin?
lopputeksti:
	db 0x1b, "]R"		; reset palette
	db 0x1b, "c"		;
	db 0x1b, "[?25h"
;	db "asdf"
lpt:	



	;; yht. pituus 1024 * 10 + 768!
script:
	;; funktio (vscreen1), funktio (vscreen2), syncraja

;	dd setpalette6
;	dd blank
;	dd process_bumpmap
;	dd 100000
	
	dd setpalette4
	dd blank
	dd blank
	dd 1024*1	

	dd setpalette4
	dd tunneliefu
	dd tunneliefu2
	dd 1024*3
	
	dd setpalette2
	dd rotator
	dd tunneliefu
	dd 1024*6

	dd setpalette6
	dd blank
	dd process_bumpmap
	dd 1024*8

	dd setpalette6
	dd tunneliefu2
	dd process_bumpmap
	dd 1024*10 + 768 
	
	dd 0	;loppu 
	

	
;;; ------------------------------------------------------------------------------------	

;;; Graffa

;;; ------------------------------------------------------------------------------------	

blank:
	pusha

	mov ecx, 160*80
	xor eax,eax
	rep stosb

	popa
	ret

;; precalcit	
tunneli_precalc:
	pusha
	emms

	mov edi, tunnel_table
	
	mov edx, 100
.yloop

	mov ecx, 160
.xloop
	;; ensin pisteen kulma radiaaneina

	;; kordinaatit
	mov [fputemp], edx
	fild dword [fputemp]
	fisub word [cons_240]

;	fist dword [edi] ; y-etäisyys	
;	add edi, 4
	
	mov [fputemp], ecx
	fild dword [fputemp]
	fisub word [cons_320] 	

;	fist dword [edi] ; x-etäisyys	
;	add edi, 4

	;; ja niiden neliöt kans
	fld st1
	fmul st0
	fld st1
	fmul st0
	
	;; sitten etäisyys

	faddp st1
	fsqrt			; st0=sqrt(x^2+y^2)

	fist dword [edi]	; etäisyys
	add edi, 8
	
	fild word [tunnel_n]
	fsubp st1
	fidiv word [tunnel_kerr]

	fsincos			; miks helvetissä fptan ei tässä toimi,
	fdivp st1		; onko nasmin dokuissa virhe? (toim. huom.: on.)
	
	fimul word [asdff]
					
	;; oikea kohta tekstuurista olis jotain tyyliin
	;; tan(N-etäisyys), kokeillaan

	fistp dword [edi]	; y-koordinaatti
	add edi, 4
	
	fpatan			; kulma
	fimul word [kulma_kerroin] ; vähän pitää skaalata

	fistp dword [edi]	; x-koordinaatti
	add edi, 4
	
	loop .xloop

	dec edx
	jnz .yloop


;;; tekstuuri tehdään vaik samalla

	
	popa
	ret

ttexttable:	
	db 0xff,0x88,0x99,0x77
	db 0xff,0x00,0x00,0x00
	db 0xff,0x55,0xaa,0xee
	db 0xff,0x00,0xff,0x00
	

generate_tunnel_texture:
	pusha

	mov ecx, 255*255
	mov edi, tunnel_texture1
.tunnel_texture_loop:

	xor eax, eax
	mov esi, ecx
	and esi, 0xe000
	shr esi, 11
	mov edx, ecx
	and edx, 0x00ff
	shr edx, 6
	add esi, edx

	mov al, [esi+ttexttable]
	stosb

	loop .tunnel_texture_loop

	;; toinen tekstuuri
	mov al, 255
	mov ecx, 255*128
	mov edi, tunnel_texture2
	rep stosb
	
	popa
	ret

	
	
kulma_kerroin:	
	dw 500
asdff:
	dw 100
tunnel_n:	
	dw 600
tunnel_kerr:
	dw 130*3
	
cons_320:
	dw 80
cons_240:
	dw 50

;;; bumpma
bumpmap_precalc:
	pusha
	emms
	
	mov [light_x], dword 80
	mov [light_y], dword 20
	mov [temp], dword 200
	fild dword [temp]
	fstp dword [light_z]
	
	mov edi, height_map
	mov ecx, 160*10

.bloop:
	mov [temp], dword 100
	fild dword [temp]
	fstp dword [edi]
	add edi, 4
	
	loop .bloop

	popa
	ret
		
	;; vanhan intron kamaa, säädä!
;  rotozoomaa 160*100-palasen vscreen1:een isommasta vscreenist„
;   kulma @ [temp] (wordina 0-65535)

rotator:
	pusha

	mov eax, [sync]
	shl eax, 6
	mov [temp], eax
	
	fild word [temp]
	fmul dword [kulmakerr]
	fld st0
	fld st0
	fsin
	fimul dword [satakasiysikertaakuusviisviiskolmekuus]
	fistp dword [temp+4] ; y
	fcos
	fimul dword [satakasiysikertaakuusviisviiskolmekuus]
	fistp dword [temp+8] ; x    vasen yl„kulma t„st„


	add [temp+4],dword 160*65536
	add [temp+8],dword 150*65536

	fsub dword [kaanto]
	fld st0              
	fsin
	fimul dword [_0x10000]
	fistp dword [temp+12] ; ysuunta
	fcos
	fimul dword [_0x10000]
	fistp dword [temp+16] ; xsuunta


	xor ebp, ebp

	mov ecx,100
rotatoryloop:
	push ecx

	mov edx,[temp+4] ; y
	mov esi,[temp+8] ; x    seuraava rivi

	mov ecx,160
rotatorxloop:
	push ecx

	push esi
	push edx

	shr edx,16
	imul edx,200
	shr esi,16
	add esi,edx

	mov al, [esi+reitreis_vscreen] ; iisosta vscreenist„

	stosb ; siihen vaan
	pop edx
	pop esi

	add edx,[temp+12] ; y
	add esi,[temp+16] ; x

	pop ecx
	loop rotatorxloop

	mov eax,[temp+12] ;yaddi
	add [temp+8],eax  ; x

	mov eax,[temp+16] ;xaddi
	sub [temp+4],eax  ; y      ; menee vähän eri suuntaan 
                          
	pop ecx
	loop rotatoryloop

	;; tyhjää iso vscreen

	mov edi, reitreis_vscreen
	mov ecx, 400*400/4
	xor eax, eax
	rep stosd
	
	popa	
	ret



satakasiysikertaakuusviisviiskolmekuus: ; ~sqrt(100^2+160^2)*65536
 dd 180*65536
kaanto:
 dd 2.583087 ; tämä vähennetään niin päästään vaakasuuntaan

_0x10000:
 dd 2*65536    ; kerroin (fixed käytössä katsos)

	
;;; tunnelin tekis, heightmappiseinillä ni vähän hienompi

tunneliefu3:
	pusha
	mov [tunnel_using_texture], dword tunnel_texture1	
	jmp short tunnel1foo
	
tunneliefu2:	
	pusha
	mov [tunnel_using_texture], dword tunnel_texture2
	mov eax, [sync]
	neg eax
	shr eax,1	
	mov [tsync], eax
	jmp short tunnel_foo
	
tunneliefu:
	pusha
	mov [tunnel_using_texture], dword tunnel_texture1

tunnel1foo:	
	mov eax, [sync]
	mov [tsync], eax

tunnel_foo:	

;	mov edi, vscreen1
	mov esi, tunnel_table
	
	mov ebp, 100
.yloop

	mov ecx, 160
.xloop
	push ecx
	
	mov edx, [esi]		; etäisyys
	add esi, 8
	;; ota tekstuurista pikseli
	
	mov eax, [esi]

	mov ebx, [tsync]
	shl ebx, 2
	sub eax, ebx
	
	
	and eax, 255
	imul eax, 255
	add esi, 4
	mov ebx, [esi]
	add ebx, [tsync]
	shl ebx, 1
	and ebx, 255
	add eax, ebx

	xor ecx, ecx
;	mov cl, [eax+tunnel_texture]	; pikseli 1
	add eax, [tunnel_using_texture]
	mov cl, [eax]

	
	imul ecx, edx
	shr ecx, 7
	mov al, cl

	stosb

	add esi, 4
	
	pop ecx	
	loop .xloop

	dec ebp
	jnz .yloop

	popa
	ret

tunnelcounter:
	dd 0

	

	
;;; joo-o, katotaans jos tän sais toimii
		
reitreis:
	pusha

	mov eax, [sync]
	shl eax, 4
	mov [kulma], ax

	add [camx], dword 100000
	add [camy], dword 100000
	
	mov ecx,200
raytracexloop:
	push ecx
; ensin kerroin mutkakorjaukselle

	fld1

	mov ebx,ecx
	sub ebx,160
	mov [temp],ebx
	fild dword [temp]
	fabs
	fmul dword [angadd]
	fcos

	fdivp st1 ; st0=1/cos(abs(x-320))
	fstp dword [temp+8] ; da kerroin
  

;

	fild word [kulma]
	fmul dword [kulmakerr] ; kameran kulma sopivasti skaalattuna

	mov [temp],ecx      ; s„teen kulma
	fild dword [temp]   
	fmul dword [angadd] ; skaalataan sopivaksi

	faddp st1 ; lisätään yhteen

; nyt on säteen kulma, siitä x- ja y-addit

	fld st0 ; tarvitaan kulma toisen kerran pinoon

	fsin
	fmul dword [sadekerr]
	fmul dword [temp+8]
	fistp dword [temp]           ; y-add

	fcos
	fmul dword [sadekerr]  
	fmul dword [temp+8]
	fistp dword [temp+4]          ; x-add


	mov ebx,[camx] ; kameran sijainti 
	mov edx,[camy]  



	mov ecx,180 ; näin pitkälle säde lennähtää
rayloop:
	push ecx

	add ebx,[temp+4]
	add edx,[temp]    ; s„de se lent„„ vaan

	push edx
	push ebx

	shr ebx,20 ; jaa 65536*16:lla
	shr edx,20 ; jaa 65536*16:lla

	and edx,3
	and ebx,3

	xor eax,eax
	mov al,[raytracescene+ebx+edx*4] ; kartasta

	pop ebx
	pop edx
	pop ecx

	cmp al,0
	jne seinatulijo

 
	loop rayloop
	jmp eiseinaa

	;; piirretään nyt
seinatulijo:


	push ecx ;  ja talteen viivanpiirron ajaksi
; pit„„ korjata ecx niin ettei pullistele

;jmp eiskuareroot
	neg ecx
	add ecx,180

	mov [temp+12],ecx
	fild dword [temp+12]
	fsqrt
	fimul word [kymmenen]
	fistp dword [temp+12]
	mov ecx,[temp+12]

	neg ecx
	add ecx,180
eiskuareroot:	

	inc ecx ; varmuuden vuoksi 

	mov ebp, 300
	sub ebp, ecx
	shr ebp, 1

modpoint_rei:			; tähän 400 joskus
	imul ebp, 200 ; iso vscreen on 400*400
	add ebp,[esp+4] ; x
; ecx on korkeus k„tev„sti (testii vaan)

reitreisviivaloop:

	cmp [edi+ebp], byte 0
	jne qwer
	mov [edi+ebp], byte 100
	jmp short eirtof
qwer:	

	
	add [edi+ebp],byte 1
	jnc eirtof
	mov [edi+ebp], byte 255
eirtof:	
	
	add ebp ,200
loop reitreisviivaloop

	pop ecx ; ecx selvisi tästä, voidaan jatkaa sädettä

	dec ecx
	jz eiseinaa
	jmp rayloop

eiseinaa:
	pop ecx
	dec ecx
	jz raytracexloopohi
	jmp raytracexloop
raytracexloopohi:



	popa
	ret
	
; - - - -
; raytracelle

angadd: ; lis„ys kulmaan /rivi
 dd 0.0049087
kulmakerr: ; t„ll„ kertomalla skaalataan kulma v„lille 0-2PI
 dd 0.00009587
sadekerr:
 dd 35000.0   ; kuinka pitkin hypp„yksin s„de etenee (*65536 fixedin takia)
camx:
 dd 65536*4*16
camy:
 dd 65536*4*16
kymmenen:
 dw 13


raytracescene: ; 8*8 - sCeNe    bit0-3 color 1 4-7 color 2

 db 0,1,0,0
 db 0,1,0,0
 db 0,1,1,1
 db 1,0,0,0
	
		
;;; plasmahdustakin tarvitsemme

;;; edi=kohde, esi hassu vakio


fcons1:
	dd 100

;;; tekaise paletti

sync_const:
	dw 73

sync_const2:
	dw 117

sync_const3
	dw 235
	
light_move_kerr:
	dw 40

;light_move_kerr2:
;	dw 30

light_move_kerr3:
	dd -150.0

;morph_kerr:
;	dd 0.0001
	
setpalette6:
	pusha

;	mov [light_x], dword 100
;	mov [light_y], dword 50

;	fild dword [light_move_kerr3]
;	fstp dword [light_z]
	
	
;	fld dword [julia_const_n]
;	fadd dword [morph_kerr]
;	fstp dword [julia_const_n]

;	call generate_julia
	
	mov [pal1], dword 0xff00ff00
	mov [pal2+1], word 0xffff

	fild dword [sync]
	fidiv word [sync_const]
	fsin
	fmul dword [julia_add_x]
	fistp dword  [light_x]


	fild dword [sync]
	fidiv word [sync_const2]
	fcos
	fimul word [light_move_kerr]
	fistp dword  [light_y]
	
	add dword [light_y], 50	
	add dword [light_x], 80	

	;; z-akseli
	fild dword [sync]
	fidiv word [sync_const3]
	fcos
	fmul dword [light_move_kerr3]
	fstp dword  [light_z]
	
	jmp palette_foo
	
;setpalette5:
;	pusha
	
;	mov [pal1], dword 0xff00ff
;	mov [pal2+1], word 0x0000

;	mov eax, [sync]
;	shl eax, 3
;	mov bl, 255
;	sub bl, al
;	mov [pal2+2], bl
;	shr eax, 5
;	mov [pal1+1], al
;	mov [pal1+3], al

;	jmp palette_foo	

setpalette4:
	pusha

	mov [pal1], dword 0xff00ffff
	mov [pal2+1], word 0x0000
	
	mov eax, [sync]
	mov [pal1+2], al

	jmp palette_foo
	
;setpalette3:
;	pusha

;	mov [pal1], dword 0xffffffff
;	mov [pal2+1], word 0x0000

jmp short .asd
	
	fild dword [sync]
	fidiv word [const_512]
	fst st0
	fcos
	fimul word [const_50]
	fiadd word [const_80]
	fist dword [light_x]
	fsin
	fimul word [const_50]
	fiadd word [const_50]
	fist dword [light_y]

.asd:	
	;; test
	
	jmp short palette_foo

const_80:
	dw 80
const_50:
	dw 50
const_512:
	dw 512
		
setpalette2:
	pusha

	call reitreis
	
	mov [pal1], dword 0xffffff00
	mov [pal2+1], word 0xff00

	mov eax, [sync]
	neg eax
	push eax
	shl eax, 3
	mov [pal1], al

	mov [pal1+1], al

	pop eax
	add eax, 64
	shl eax, 2
	mov [pal2+1], al
	
;	jmp short palette_foo

;setpalette1:
;	pusha	

;	mov [pal1], dword 0xff0000
;	mov [pal2+1], word 0x0000

;	mov eax, [sync]
;	shl eax, 3
;	mov bl, 255
;	sub bl, al
;	mov [pal2+1], bl
;	shr eax, 5
;	mov [pal1+3], al
	
palette_foo:	
	
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
	
	xor eax, eax
	xor edx, edx
	mov al, [pal1-1+esi]

	imul eax, ecx
	shr eax, 3	

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
	ret

pal1:
	db 255			; b
	db 0			; g
	db 255			; r
pal2:	
	db 255			; r
	db 200			; g
	db 128			; b

	db 0
	
palette_chars:	
	db "0123456789abcdef"
	
;;;  merkkejä:	 32 240 206  (240 ruls)
	
ttesst:	
	db 0x1b, ']', "P0000000"
	
;;; mmx-flippi
		
		
flipmmx:
	pusha

	;; kursori ylänurkkaan
	mov eax, 4
	mov ebx, 1
	mov ecx, escseq_cursorpos
	mov edx, 3
	int 0x80

;	xor [fls], dword 0x40
	
	mov ebp, 49
flipyloop:	

	mov esi, 80
flipxloop:	
	;; virtualscreenistä kummankin osavärin kirkkaudet
	mov edi, ebp
	imul edi, 320
	add edi, esi
	add edi, esi
	add edi, vscreen1

	xor ebx, ebx
	xor eax, eax
	mov bl, [edi]
	add eax, ebx
	mov bl, [edi+1]
	add eax, ebx
	mov bl, [edi+160]
	add eax, ebx
	mov bl, [edi+167]
	add eax, ebx

	add eax, [fls]
	jnc sdfg1
	mov eax, 0x00ff
sdfg1:	
	
	shr eax, 7		; skaalaa välille 0-7
	add al, '0'
	mov [flip_col+3], al

	add edi, vscreen2-vscreen1
	xor ebx, ebx
	xor eax, eax
	mov bl, [edi]
	add eax, ebx
	mov bl, [edi+1]
	add eax, ebx
	mov bl, [edi+160]
	add eax, ebx
	mov bl, [edi+161]
	add eax, ebx

	add eax, [fls]
	jnc sdfg2
	mov eax, 0x00ff
sdfg2:	

	shr eax, 7		; skaalaa välille 0-7
	add al, '0'
	mov [flip_col+6], al
	
	;; väri ja merkki ulos
	mov eax, 4
	mov ebx, 1
	mov ecx, flip_col
	mov edx, 9
	int 0x80

	dec esi
	jz eiflxloop
	jmp flipxloop
eiflxloop:	
	
	cmp [temp+2], byte '0'

lines_modpoint:	
	sub ebp, 1
	jna flipyloopohi
	jmp flipyloop
flipyloopohi:	

	mov eax, 3		; read
	mov ebx, [stdin_desc]	; stdin
	mov ecx, temp
	mov edx, 1
	int 0x80

	cmp byte [temp], 0x1b
	jne eiq
	mov [quit_flag], byte 1
eiq:	
			
	popa
	ret

fls:
	dd 0

;vscreen_suhde:
;	dd 0	 		; 0-32767, isommalla enemmän kakkosta, pienemmällä ykköstä

escseq_cursorpos:
	db 0x1b, "[H1;1"         ; kursori ylänurkkaan

flip_col:			; merkki 206
	db 0x1b, '[', "30;40", 'm', '0'	; bold
cposreport:	
	
;	db 0x1b, "[6n"

;;; --------------------------------------
;;; --------------------------------------
;;; --------------------------------------

%define	VIRTUAL_SCREEN_W	160
%define	VIRTUAL_SCREEN_H	100
%define	LIUKU_MAX		15
%define	LIUKU_SHL		4
%define	STACK_START		28
%define	STACK_START_SMALL	4
%define	ITERATE_MAX		255

; Julia additions and multiplications
%define	JULIA_ADD_X		(1.0-VIRTUAL_SCREEN_W/2.0)
%define	JULIA_ADD_Y		(1.0-VIRTUAL_SCREEN_H/2.0)
%define	JULIA_MUL_X		((1.0/(VIRTUAL_SCREEN_W/2.0))*2.0)
%define	JULIA_MUL_Y		((1.0/(VIRTUAL_SCREEN_H/2.0))*2.0*3.0/4.0)

%macro abs 1
	cmp	%1, 0
	jge	%%absb_pos
	not	%1
	inc	%1
%%absb_pos:
%endmacro

; Multiply register with scanline lenght
%macro mulscan 2
 %if %2 = 160
	lea	%1, [%1*4+%1]
	sal	%1, 5
 %elif %2 = 320
	lea	%1, [%1*4+%1]
	sal	%1, 6
 %elif %2 = 512
	sal	%1, 9
 %elif %2 = 640
	lea	%1, [%1*4+%1]
	sal	%1, 7
 %elif %2 = 1024
	sal	%1, 10
 %elif %2 = 1280
	lea	%1, [%1*4+%1]
	sal	%1, 8
 %elif %2 = 2048
	sal	%1, 11
 %else
	imul	%1, %2
 %endif
%endmacro

;GLOBAL vscreen
;GLOBAL iterate
;GLOBAL process_bumpmap
;GLOBAL calculate_collisions
;GLOBAL height_map
;GLOBAL light_x
;GLOBAL light_y
;GLOBAL light_z
;GLOBAL ivar
;GLOBAL fvar
;GLOBAL generate_julia

;SECTION .text

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Laskee kollisiot, pisteen x ja y parametreinä stackiin ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

calculate_collisions:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	esi

	mov	eax, [esp+STACK_START]
	mov	ebx, [esp+STACK_START+4]
	mov	edi, [light_x]
	mov	esi, [light_y]


	mov	ecx, edi
	mov	edx, esi
	sub	edi, eax
	sub	esi, ebx

	abs	edi
	abs	esi
	mov	[distance_x], edi
	mov	[distance_y], esi
	mov	dword [block_counter], dword LIUKU_MAX

	cmp	edi, esi
	jge	.interpolate_via_x
	jmp	.interpolate_via_y

; X:n kautta
.interpolate_via_x:
	mov	[cord1], ebx
	mov	[cord2], edx

	fild	dword [cord2]
	fisub	dword [cord1]
	cmp	edi, 0
	je	.load_zero_y
	fidiv	dword [distance_x]
	fild	dword [cord1]
	jmp	.load_over_y
.load_zero_y:
	fstp	st0
	fldz
	fldz
.load_over_y:

	fld	dword [light_z]
	mov	esi, ebx
	mulscan	esi, VIRTUAL_SCREEN_W*4
	fsub	dword [height_map+eax*4+esi]
	cmp	edi, 0
	je	.load_zero_z
	fidiv	dword [distance_x]
	fld	dword [height_map+eax*4+esi]
	fst	dword [start_z]
	jmp	.load_over_z
.load_zero_z:
	fstp	st0
	fldz
.load_over_z:

	mov	edi, eax	; fpu flags == ah

.x_loop:
	fld	st2
	fist	dword [cord2]
	fadd	st4
	fstp	st3
	mov	esi, [cord2]

	cmp	esi, 0
	jl	near .loop_loppu
	cmp	esi, VIRTUAL_SCREEN_H
	jge	near .loop_loppu

	mulscan	esi, VIRTUAL_SCREEN_W*4
	fcom	dword [height_map+esi+edi*4]
	fadd	st1
	fstsw	ax
	sahf
	jae	.no_block_x
	dec	dword [block_counter]
	jz	near .loop_loppu
.no_block_x:
	cmp	edi, ecx
	jg	.decrease_edi
	je	near .loop_loppu
	inc	edi
	cmp	edi, VIRTUAL_SCREEN_W
	jge	near .loop_loppu
	jmp	.x_loop
.decrease_edi:
	dec	edi
	cmp	edi, 0
	jl	near .loop_loppu
	jmp	near .x_loop

; Y:n kautta
.interpolate_via_y:
	mov	[cord1], eax
	mov	[cord2], ecx

	fild	dword [cord2]
	fisub	dword [cord1]
	fidiv	dword [distance_y]
	fild	dword [cord1]

	fld	dword [light_z]
	mov	edi, ebx
	mulscan	edi, VIRTUAL_SCREEN_W*4
	fsub	dword [height_map+eax*4+edi]
	fidiv	dword [distance_y]
	fld	dword [height_map+eax*4+edi]
	fst	dword [start_z]

	mov	edi, eax	; fpu flags == ah

.y_loop:
	fld	st2
	fist	dword [cord2]
	fadd	st4
	fstp	st3
	mov	eax, [cord2]

	cmp	eax, 0
	jl	.loop_loppu
	cmp	eax, VIRTUAL_SCREEN_W
	jge	.loop_loppu

	mov	esi, ebx
	mulscan	esi, VIRTUAL_SCREEN_W*4
	fcom	dword [height_map+esi+eax*4]
	fadd	st1
	fstsw	ax
	sahf
	jae	.no_block_y
	dec	dword [block_counter]
	jz	.loop_loppu
.no_block_y:
	cmp	ebx, edx
	jg	.decrease_ebx
	je	.loop_loppu
	inc	ebx
	cmp	ebx, VIRTUAL_SCREEN_H
	jge	.loop_loppu
	jmp	.y_loop
.decrease_ebx:
	dec	ebx
	cmp	ebx, 0
	jl	.loop_loppu
	jmp	.y_loop

.loop_loppu:
	mov	eax, [esp+STACK_START]
	mov	ebx, [esp+STACK_START+4]
	mov	ecx, [block_counter]
	shl	ecx, 4
	mulscan	ebx, VIRTUAL_SCREEN_W
	mov	[vscreen+eax+ebx], byte cl
	
	fstp	st0
	fstp	st0
	fstp	st0
	fstp	st0
	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Ajaa kollisionetsinnän pomppukartan joka pikselille ;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

process_bumpmap:
	push	eax
	push	ebx
	push	ecx
	push	edx

	mov	ecx, VIRTUAL_SCREEN_W
	mov	edx, VIRTUAL_SCREEN_H
	mov	ebx, 0

.loop_y:
	mov	eax, 0
.loop_x:
	push	ebx
	push	eax
	call	calculate_collisions
	pop	eax
	pop	ebx
	inc	eax
	cmp	eax, ecx
	jl	.loop_x

	inc	ebx
	cmp	ebx, edx
	jl	.loop_y

	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Generoi Julian, ei parametreja ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

complex_add:
	fld	dword [esp+STACK_START_SMALL]
	fadd	dword [esp+STACK_START_SMALL+8]
	fstp	dword [esp+STACK_START_SMALL+16]
	fld	dword [esp+STACK_START_SMALL+4]
	fadd	dword [esp+STACK_START_SMALL+12]
	fstp	dword [esp+STACK_START_SMALL+20]
	ret

complex_mul:
	fld	dword [esp+STACK_START_SMALL]
	fmul	dword [esp+STACK_START_SMALL+8]
	fld	dword [esp+STACK_START_SMALL+4]
	fmul	dword [esp+STACK_START_SMALL+12]
	fsubp	st1
	fstp	dword [esp+STACK_START_SMALL+16]

	fld	dword [esp+STACK_START_SMALL]
	fmul	dword [esp+STACK_START_SMALL+12]
	fld	dword [esp+STACK_START_SMALL+8]
	fmul	dword [esp+STACK_START_SMALL+4]
	faddp	st1
	fstp	dword [esp+STACK_START_SMALL+20]
	ret

complex_abs:
	fld	dword [esp+STACK_START_SMALL]
	fmul	st0
	fld	dword [esp+STACK_START_SMALL+4]
	fmul	st0
	faddp	st1
	fsqrt
	fstp	dword [cabs_return]
	ret


iterate:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	esi

	xor	ecx, ecx
	mov	ebx, [esp+STACK_START]
	mov	edx, [esp+STACK_START+4]
	mov	[z1_n], ebx
	mov	[z1_i], edx
	mov	ebx, [julia_const_n]
	mov	edx, [julia_const_i]

.loop:
	push	dword [z1_i]
	push	dword [z1_n]
	call	complex_abs
	pop	esi
	pop	esi
	fld	dword [cabs_return]

fst	dword [fvar+ecx*4]

	fcomp	dword [bailout]
	fstsw	ax
	sahf
	ja	.loppu
	cmp	ecx, ITERATE_MAX
	jge	.loppu
	push	esi
	push	esi
	push	dword [z1_i]
	push	dword [z1_n]
	push	dword [z1_i]
	push	dword [z1_n]
	call	complex_mul
	pop	esi
	pop	esi
	pop	esi
	pop	esi
	pop	dword [z2_n]
	pop	dword [z2_i]
	push	esi
	push	esi
	push	edx
	push	ebx
	push	dword [z2_i]
	push	dword [z2_n]
	call	complex_add
	pop	esi
	pop	esi
	pop	esi
	pop	esi
	pop	dword [z1_n]
	pop	dword [z1_i]
	inc	ecx
	jmp	.loop

.loppu:
	mov	[iteration], ecx

	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

	
generate_julia:
	push	eax
	push	ebx
	push	ecx
	push	edx
	push	edi
	push	esi

	xor	edx, edx

.loop_y:
	xor	ecx, ecx
	mov	ebx, edx
	mulscan	ebx, VIRTUAL_SCREEN_W*4

.loop_x:
	mov	dword [diff], ecx
	fild	dword [diff]
	fadd	dword [julia_add_x]
	fmul	dword [julia_mul_x]
	fstp	dword [iter_n]
	mov	dword [diff], edx
	fild	dword [diff]
	fadd	dword [julia_add_y]
	fmul	dword [julia_mul_y]
	fstp	dword [iter_i]
	push	dword [iter_i]
	push	dword [iter_n]
	call	iterate
	pop	esi
	pop	esi
	fild	dword [iteration]
	fstp	dword [height_map+ebx+ecx*4]
	inc	ecx
	cmp	ecx, VIRTUAL_SCREEN_W
	jl	.loop_x
	inc	edx
	cmp	edx, VIRTUAL_SCREEN_H
	jl	.loop_y

	pop	esi
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	eax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Data ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;SECTION .data


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Taulukot ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;SECTION .bss


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Käytä (ehkä) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;fstp	dword [fvar+4]
;fstp	dword [fvar+0]
;mov	[ivar+0], eax
;mov	[ivar+4], ebx
;mov	[ivar+8], ecx
;mov	[ivar+12], edx
;mov	[ivar+16], edi
;mov	[ivar+20], esi
;mov	eax, [start_z]
;mov	[fvar+8], eax








	

	
		
;;; ------------------------------------------------------------------------------------	

;;; Audio

;;; ------------------------------------------------------------------------------------	

TEMPO equ 1100	
		
;;; käy yhden songin läpi

;;; edx = funktio, esi = songptr
			
makesong:		

	mov edi, audio_temp
	mov ebp, foobar-bass
.songloop:	
	xor eax, eax
	mov al, [esi]
	inc esi
	cmp al, 0
	je .songdone	

	cmp al, 0x81
	jc .eilooppia

	sub al,0x80

	cmp [esi + ebp], byte 0 ; onko vanhaa looppia käynnissä?
	je .eivanhaa
	dec byte [esi + ebp]
	jnz .eilooploppu
	;; looppi loppui, joten jatketaan normaalisti
	inc esi
	jmp short .songloop
.eilooploppu:	
	;; looppaa, eli esi-=hyppy
	xor ebx, ebx
	mov bl, [esi]
	sub esi, ebx
	jmp short .songloop
	
.eivanhaa:	
	;; aloita uusi looppi
	mov [esi + ebp], al
	jmp short .eilooploppu

.eilooppia:	
	
	mov ecx, eax
	imul ecx, TEMPO
	
	xor ebx, ebx
	mov bl, [esi]
	cmp bl,0
	je .eicall
	
	call edx
	jmp short .ffoo
.eicall:	
	xor eax, eax
	rep stosw
.ffoo:		
	add edi, ecx
	add edi, ecx
	
	inc esi
	jmp short .songloop

.songdone	
;;; kursori pois päältä

	mov eax, 4
	mov ebx, 1
	mov ecx, cursor_off
	mov edx, 7
	int 0x80
	
	ret

;;; - - - - - -

makebiit:

;;; edx = rumpufunkkari, esi = songptr

	mov edi, audio_temp
.biit_loop:	
	
	mov al,[esi]
	inc esi
	cmp al,0
	je .biitdone	

	xor ecx,ecx
	mov cl,al 		; kuinka monta kertaa pattern loopataan?
	xor ebx,ebx
	mov bl,[esi]
	inc esi
.loop_loop
	
	mov ebp, 15
.patternloop

	bt [drum_patterns+ebx], ebp
	jnc .eirump
	call edx
.eirump
	
	add edi, TEMPO*8

	dec ebp
	jns .patternloop


	loop .loop_loop


	jmp short .biit_loop

	.biitdone:
	ret
	
	
;;; - - - - - -
;;; sahaa pätkä

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde
	
sawnote:
	pusha

	push ecx
		
	mov ecx, ebx

	and bl, 0x0f
	mov edx, [ebx*2 + notetable-2] ; addi

	shr ecx, 4		
	shr edx, cl		; shifti
	
	pop ecx	
	;; nyt edx:ssä addi
		
.noteloop:
	add ebx, edx
	mov eax, ebx
	sar eax, 18
	stosw
	loop .noteloop

	popa
	ret

;;; - - - - - -
;;;  foo-o

pianonote:
	pusha

	push ecx
		
	mov ecx, ebx

	and bl, 0x0f
	mov edx, [ebx*2 + notetable-2] ; addi

	shr ecx, 4		
	shr edx, cl		; shifti
	
	pop ecx	
	;; nyt edx:ssä addi

	mov esi, 55000	; vola
	
.pnoteloop:
	add ebx, edx
	mov eax, ebx
	sar eax, 16

	and ax, 0xefff
	
	imul eax, esi
	sar eax, 18
	dec esi
	jnz .foo
	inc esi
.foo:	

	
	mov bx, [edi-60000]
	sar bx, 1
	add eax,ebx
	
	stosw
	loop .pnoteloop

	popa
	ret

	
;;; - - - - - -
;;; pätkä padia

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde
	
padchord:	
	pusha

.padloop:	
	push ecx

	xor eax,eax
	xor ebp,ebp
	
	mov ecx, 12*4
.phatloop:
	;; nouda edx:ään addi tablesta
	test cl,11b
	jnz .eiseur

	;; seuraava nuotti
	mov edx,[ebp*2+notetable-2]	; addi tablesta
	shr edx, 6			; ja oktaavi sopivaksi

	bt [ebx+padchords-2], ebp	
	jc .notee
	xor edx,edx
	sub cl, 3
.notee:	
	
	inc ebp
.eiseur:	
	;; 
	add [ecx*4+pad_note_buf], edx
	mov esi, [ecx*4+pad_note_buf]
	sar esi, 21		; ei saa klipata

	add eax,esi 		; miksaa sekaan
	
	add edx, 20000	; detunee

	loop .phatloop

	stosw
	pop ecx
	loop .padloop	
	
	popa
	ret
		
;;; - - - - - -
;;; basso runpu kiitos

;;; edi kohde

basari:
	pusha

	mov ecx, 4000
.basariloop:
	add ebx, ecx
	mov eax, ebx
	shr eax, 3
	xor ax, cx
	stosw
	
	loop .basariloop	

	popa
	ret


hihat:
	pusha

mod_point2:	
	mov ecx, 500
.basariloop:
	push ecx

	and cx, 0x03ff
	
	mov eax, [$$ + ecx]
	and eax, 0x08f0
	stosw

	pop ecx
	loop .basariloop	

	popa
	ret

snare:
	pusha

	mov ecx, 2000
.snareloop:
	add ebx, ecx
	add edx, ebx
	mov eax,edx
	sar ax, 1
	stosw
	
	loop .snareloop

	popa
	ret
		
			
;;; - - - - - -
;;; resofiltteri mmx:llä

;;; k1 = ((float)1/44100) / (((float)1/44100) + 1.732/(2*3.14157*cutoff));
;;;  k2 = ((float)1/44100) / (((float)1/44100) + 1.732/(2*3.14157*(cutoff*.85)));	

;;; ecx = kesto sampleinta, ebx = byte 2, edi kohde
	
resommx:	
	pusha

	cmp bl, 0x80
	jc .value

	;; slaidii!! whee!
	sub ebx, 0xc0
;	shl ebx, 4		; TODO: säädä tää sopivaksi
	movd mm3, ebx		; slaidi
	
	jmp short resofilterloop	
.value:		
	shl ebx, 8+8
	movd mm4, ebx		; cutoff
	pxor mm3, mm3		; ei slaidii
			
resofilterloop:	

	xor eax, eax
	mov ax, [edi]
	movd mm1, eax		; inputti

	paddd mm4, mm3		; slaidia tässä
	movq mm0, mm4		
	psrlq mm0, 8		; shift right ennen kertolaskentoa
	;; nyt mm0:ssa cutoffkerroin
		
; feedback eli fb*(d0-d1)
	
	movq mm5, mm6
	
	psubsw mm5, mm7		; mm5 = d0 - d1
			
	paddsw mm1, mm5		; lisää feedbackki kakkosfilsun inputtiin	
mod_point:			; reso poistetaan täält
	psraw mm5, 2
	paddsw mm1, mm5
	
	;; vähennä d0		
	psubsw mm1, mm6
	
	;; kerro delta cutoffkertoimella
	pmaddwd mm1, mm0
	psrld mm1, 16		
	
	paddsw mm6, mm1	

	;; kakkosfilsu 
	movq mm1, mm6		; inputti kakkoseen (khöhöhö, kakkoseen, öhöh)
	
	psubsw mm1, mm7
		
	pmaddwd mm1, mm0	; kerro cutoffkertoimella
	psrld mm1, 16
	pmaddwd mm1, [mmx_cutoff_ero] ; pienempi cutoff kakkosfilsulla
	psrld mm1, 16

	paddsw mm7, mm1

	movd eax, mm7		; kakkosfilsun outputti ulos
	
	stosw

	loop resofilterloop

	popa
	ret	
	
mmx_cutoff_ero:	
	dw 0x7500
	dw 0

;;; - - - - - -
;;; Miksaa audiobufferit (saturaation kans, ämmämmäks 0wnZ j00)
	
mix_audio_bufs:
 	mov ecx,44100*300
.mmx_mix_loop:
	movq mm0, [ecx+audio_temp]
	pxor mm1, mm1			; tää ja suraava rivi ehkä tarpeettomia?
	movq [ecx+audio_temp], mm1	;	
	psraw mm0, 1		; arithmetic shr (word)
	paddsw mm0, [ecx+audio_mix] ; add with saturation (word)
	movq [ecx+audio_mix], mm0
	sub ecx, 8 		; quadwordi kerrallaan
	jnz .mmx_mix_loop
	emms
	ret


;;; FIXME: miks pätkii?? säädä 
	
;;; - - - - - -
;;; kirjoita audioo vähän
	ACSIZE equ 4196
	AC_BUFFER_LOW equ 4196*4
	
writeaudio:	
	pusha

nosound_modpoint:	
	jmp short asdfioxxx
asdfioxxx:	
	
	;; lue soitetut bytet
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; file desc.
	mov ecx, 0x800c5012 	; SNDCTL_DSP_GETOPTR
	mov edx, count_info	; pointer to arguments
	int 0x80

writeloop:	
	mov ebp, [audio_bytes_written]
	sub ebp, [count_info]
	cmp ebp, AC_BUFFER_LOW	; tän verran pidettävä aina bufferissa
	jnc buffer_ok		; FOO
	
	mov eax, 4		; write
	mov ebx, [desc_devdsp]	; descriptori
	mov ecx, [audio_bytes_written]
	add ecx, audio_mix	
	mov edx, ACSIZE
	int 0x80

	add [audio_bytes_written], dword ACSIZE
	jmp short writeloop
	
buffer_ok:	

	;; päivitä synccicountteri
	xor edx, edx
	mov eax, [count_info]
	add eax, TEMPO/2
	mov ebx, TEMPO
	div ebx
	mov [sync], eax
	
	popa	
	ret


nosound_viive:	
	;; nosound-ajastus (sleepataan vaan framejen välillä vakioaika, huono
	;; mutta evk

;	mov eax, 162		; nanosleep
;	mov ebx, timespec
;	mov ecx, ebx
;	int 0x80

;	add [audio_bytes_played], dword 4410

	inc dword  [sync]	; FIXME:säädä sopivaks joskus
	
	jmp short buffer_ok
	
;timespec:	
;	dd 0
;	dd 50*1000
	
str_devdsp equ 0x08000007 ; headeriin mahtuu just sopivasti	
;str_devdsp:	
;	db "/dev/dsp",0

str_devstdin
	db "/dev/stdin",0
	
cursor_off:
	db 0x1b,"[?25l."
	
alku_escseq:	
;	db 0x1b, "[2J"		; erase display
	db 0x0c
	db 0x1b, "[", "1", "m"	; bold
alku_escseq_len equ $ - alku_escseq
	
;; täältäkin voi siirrellä osan kamasta uninit. dataan	
		
dsp_fmt:
	dd 0x00000010

dsp_rate:
	dd 44100

	
	
;;; piisi

;;; syntsat

;;; byte1:	0x00 end, 0x01-0x7f kesto, 0x80-0xff loop (counter = byte-0x80)
;;; byte2:	nuotti:	0x00 - b0-3 nro 4-7 shift  looppi: matka
	
bass:	
	db 0x40, 0x95 		; alkuviive
	db 0x7f+8, 3
	
	
	db 0x04, 0x85
	db 0x02, 0x95
	db 0x02, 0x00
	db 0x08, 0x95
	db 0x7f + 32, 4*2 +1

	db 0x04, 0x71
	db 0x02, 0x81
	db 0x02, 0x00
	db 0x08, 0x81
	db 0x7f + 32, 4*2 +1

	db 0x81, 10*2 +1

	db 0x04, 0x88
	db 0x02, 0x98
	db 0x02, 0x00
	db 0x08, 0x98
	db 0x7f + 3, 4*2 +1

	db 0x04, 0x88
	db 0x02, 0x98
	db 0x02, 0x00
	db 0x04, 0x98
	db 0x04, 0x80
	
	db 0x04, 0x71
	db 0x02, 0x81
	db 0x02, 0x00
	db 0x08, 0x81
	db 0x7f + 4, 4*2 +1

	db 0x04, 0x85
	db 0x02, 0x95
	db 0x02, 0x00
	db 0x08, 0x95
	db 0x7f + 4, 4*2 +1

	db 0x04, 0x8a
	db 0x02, 0x9a
	db 0x02, 0x00
	db 0x08, 0x9a
	db 0x7f + 4, 4*2 +1

	db 0x83, 25*2 +1

	db 0x40, 0x00
	db 0x83, 3

	
	db 0x10, 0x85		
	db 0x08, 0x00	
	db 0x02, 0x85
	db 0x02, 0x00
	db 0x06, 0x85

	db 0x02, 0x00
	db 0x02, 0x85
	db 0x02, 0x00
	db 0x10, 0x85
	db 0x10, 0x00

	db 0x08, 0x85		
	db 0x08, 0x00	
	db 0x02, 0x85
	db 0x02, 0x00
	db 0x06, 0x85

	db 0x02, 0x00
	db 0x02, 0x85
	db 0x02, 0x00
	db 0x10, 0x85
	db 0x08, 0x00

	db 0x7f+10, 2*20 +1

	db 0x22, 0x85		
					
	db 0x00

bassfilter:
	db 0x10, 0x02

	db 0x3f, 0xc3 		; alkuviive
	db 0x7f+8, 3

	db 0x40, 0x10
	db 0x7f+52, 1*2 +1

	db 0x40, 0xc3
	db 0x7f+50, 1*2 +1

	db 0x00

rez:
	db 0x40, 0x00 		; alkuviive
	db 0x7f+8, 3

	db 0x08, 0x00
	db 0x02, 0x60
	db 0x02, 0x00
	db 0x83, 2*2 +1
	db 0x04, 0x7a
	db 0x08, 0x60
	db 0x04, 0x63
	db 0x04, 0x60
	db 0x04, 0x7a
	db 0x04, 0x60
	db 0x02, 0x75
	db 0x02, 0x00
	db 0x08, 0x75

	db 0x7f +32, 13*2 +1

	db 0x08, 0x00
	db 0x02, 0x60
	db 0x02, 0x00
	db 0x83, 2*2 +1
	db 0x04, 0x7a
	db 0x08, 0x60
	db 0x04, 0x65
	db 0x04, 0x60
	db 0x04, 0x7a
	db 0x04, 0x60
	db 0x02, 0x78
	db 0x02, 0x00
	db 0x08, 0x78

	db 0x7f +20, 13*2 +1


	db 0x81, 28*2 +1
	
	db 0x00


rezfilter:
	db 0x40, 0x00 		; alkuviive
	db 0x7f+8, 3

	db 0x10, 0x04
	db 0x3f, 0xc4
	db 0x80 +14, 1*2 +1

	db 0x40, 0x81
	db 0x80 +1, 4*2 +1

	db 0x10, 0x6f
	db 0x3f, 0xba
	db 0x7f +16, 1*2 +1

	db 0x40, 0xc8
	db 0x7f + 6, 3

	db 0x40, 0xbd
	db 0x7f+24, 3

	db 0x40, 0x00
	db 0x8f, 3
	
	db 0x00

rez2:

;	db 0x40, 0x00
;	db 0x7f+32+16+24+8, 3

;	db 0x60, 0x95
;	db 0x81, 3
	
;	db 0x00

rezfilter2:
;	db 0x40, 0x20
;	db 0x7f+8+32+16+24, 3

;	db 0x5f, 0xb6
;	db 0x81, 3

;	db 0x60, 0x00
	
;	db 0x00

pianosong:	
	db 0x40, 0x00 		; alkuviive
	db 0x7f+8, 3
		
	db 0x40, 0x00
	db 0x18, 0x68
	db 0x18, 0x67
	db 0x10, 0x63
	db 0x80, 0x60

	db 0x40, 0x00
	db 0x18, 0x68
	db 0x18, 0x67
	db 0x10, 0x63
	db 0x80, 0x50

	db 0x40, 0x00
	db 0x18, 0x51
	db 0x18, 0x50
	db 0x10, 0x68
	db 0x80, 0x65

	db 0x40, 0x00
	db 0x18, 0x68
	db 0x18, 0x67
	db 0x10, 0x63
	db 0x80, 0x6a

	db 0x81, 20*2 +1

	db 0x20, 0x00
	db 0x0c, 0x51
	db 0x0c, 0x50
	db 0x08, 0x68
	db 0x60, 0x65

	db 0x0c, 0x68
	db 0x0c, 0x67
	db 0x08, 0x63
	db 0x40, 0x65

	db 0x83, 9*2 +1	

	db 0x60, 0x65

	db 0x50, 0x00
	db 0x50, 0x00
		
	db 0x78, 0x68
	db 0x18, 0x6a
	db 0x6e, 0x67
	db 0x02, 0x00

	db 0x10, 0x7a
	db 0x08, 0x60

	db 0x68, 0x65

	db 0x10, 0x65
	db 0x08, 0x63

	db 0x68, 0x78
	
	db 0x82, 21	

	db 0x7f, 0x0d 		; että delayt jatkuu pidempään
			
	db 0x00	

pianofilter:
	db 0x40, 0x00 		; alkuviive
	db 0x7f+8, 3

	db 0x01, 0x58
	db 0x15, 0xc8
	db 0x15, 0xb9
	db 0xc8, 2*2 +1

	db 0x40, 0x38
	db 0x7f+27, 3	

	db 0x58, 0x9b
	db 0x70, 0x01

	db 0x00
	
pianosong2:

	db 0x40, 0x00
	db 0x7f +32+8, 3

	db 0x20, 0x00
	db 0x0c, 0x68
	db 0x0c, 0x68
	db 0x08, 0x63
	db 0x60, 0x61

	db 0x0c, 0x65
	db 0x0c, 0x60
	db 0x08, 0x60
	db 0x40, 0x62

	db 0x83, 9*2 +1	

	db 0x60, 0x61

	db 0x50, 0x00 		;  optaa!
	db 0x50, 0x00

	db 0x40, 0x00
	db 0x7f+8, 3
	
	db 0x6c, 0x40
	db 0x0c, 0x5a	
	db 0x0c, 0x58	
	db 0x75, 0x57

	db 0x07, 0x55
	db 0x06, 0x57
	
	db 0x6a, 0x5a	

	db 0x0c, 0x58	
	db 0x0c, 0x57	
	db 0x0c, 0x53	
	db 0x0c, 0x50	
	db 0x02, 0x54
	db 0x7f, 0x55	
		
	db 0x00
	
pianofilter2:
	db 0x40, 0x00 		; alkuviive
	db 0x7f+8, 3

	db 0x01, 0x48
	db 0x15, 0xc8
	db 0x15, 0xb9
	db 0xc8, 2*2 +1

	db 0x40, 0x20
	db 0x7f+64, 3	

	db 0x00
				
padsong:
	db 0x40, 0x02 		; alkuviive
	db 0x7f+8, 3

	db 0x02, 0x02
	db 0x02, 0x00
	db 0x02, 0x02
	db 0x02, 0x00
	db 0x08, 0x02
	db 0x7f + 32, 5*2 +1

	db 0x02, 0x04
	db 0x02, 0x00
	db 0x02, 0x04
	db 0x02, 0x00
	db 0x08, 0x04
	db 0x7f + 32, 5*2 +1

	db 0x81, 12*2 +1

	db 0x02, 0x06
	db 0x02, 0x00
	db 0x02, 0x06
	db 0x02, 0x00
	db 0x08, 0x06
	db 0x7f + 4, 5*2 +1

	db 0x02, 0x04
	db 0x02, 0x00
	db 0x02, 0x04
	db 0x02, 0x00
	db 0x08, 0x04
	db 0x7f + 4, 5*2 +1

	db 0x02, 0x02
	db 0x02, 0x00
	db 0x02, 0x02
	db 0x02, 0x00
	db 0x08, 0x02
	db 0x7f + 4, 5*2 +1

	db 0x02, 0x08
	db 0x02, 0x00
	db 0x02, 0x08
	db 0x02, 0x00
	db 0x08, 0x08
	db 0x7f + 4, 5*2 +1

	db 0x83, 24*2 +1

	db 0x40, 0x04
	db 0x7f+4, 3

	db 0x7f, 0x02
	db 0x7f, 0x0a
	db 0x03, 0x0a
	db 0x7f, 0x0c
	db 0x7f, 0x0e
	db 0x82, 11

	
	db 0x00	

padfilter:
	db 0x8, 0x02
	
	db 0x3f, 0xc7 		; alkuviive
	db 0x7f+8, 3

	db 0x02, 0x20
	db 0x7f, 0xea
	db 0x7f, 0x96
	db 0x7f + 8, 3*2+1

	db 0x02, 0x70
	db 0x7f, 0xb0
	db 0x7f, 0xd0
	db 0x7f + 5, 3*2+1

	db 0x01, 0x0f
	
	db 0x40, 0xc2
	db 0x7f+19, 3

	db 0x4d, 0xb3
	db 0x7f+3, 3

	db 0x7e, 0x01
	
	db 0x00



;;; rummutteluu

basarisong:			; ok
	db 0x08, 0x08
	
	db 0x1f, 0x00
	db 0x01, 0x02
	db 0x11, 0x00
	db 0x01, 0x02

	db 0x02, 0x10
		
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x0c
	db 0x01, 0x0e
	db 0x01, 0x10
	db 0x00

basarifilter:	

	db 0x7f, 0x10
	db 0xb0, 3
	db 0x00	

hihatsong:	
	db 0x08, 0x08

	db 0x30, 0x04
	db 0x08, 0x08
	db 0x10, 0x12
	
	db 0x00

ohisong:			; ok
	db 0x08, 0x08

	db 0x20, 0x08
	db 0x10, 0x0a

	db 0x08, 0x08
	db 0x10, 0x0a
	
	db 0x00
	
snaresong:			; ok
	db 0x08, 0x08

	db 0x20, 0x08
	db 0x10, 0x06	

	db 0x0c, 0x08
	db 0x0c, 0x06
	
	db 0x00

snarefilter:
	db 0x7f, 0x60
	db 0x7f+92, 3
	db 0x00


;;; filsut	

;;; byte1:	0x00 end, 0x01-0x7f kesto, 0x80-0xff loop (counter = byte-0x80)	
;;; byte2:	0x00-0x7f arvo, 0x80-0xff slide		
	
padchords:
	dw 0000000100101001b
	dw 0000000100100011b
	dw 0000010100001001b
	dw 0000010000100101b
	dw 0000010010101000b
	dw 0000010100001001b
	dw 0000000100101010b
x
			
	
drum_patterns:	
	dw 1000100010001000b	
	dw 1000100010001011b	
	dw 1111111111111111b
	dw 0000100000001000b
	dw 0000000000000000b
	dw 0010001000100010b
	dw 1000001100100000b
	dw 0010001101100000b
	dw 1000000000000000b
	dw 1000100001001000b

;;; nää voi siirtää toiseen sectioniin kun valmista
audio_bytes_written:
;	dd 44100*220
	dd 0
	
audio_bytes_played:
	dd 0

	
	;; synkkikountteri, oleellinen
sync:	
	dd 0	

stdin_desc:	
	dd 0	
		
;;; - - - - - -
;;; nuottitable

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

	
bailout		dd	2.0 ;constant, for now

; Julia stuffxx
julia_add_x	dd	-79.0 ;JULIA_ADD_X
julia_add_y	dd	-49.0 ;JULIA_ADD_Y
julia_mul_x	dd	0.025 ;JULIA_MUL_X
julia_mul_y	dd	0.025 ;JULIA_MUL_Y

;julia_const_n	dd	-0.709 ;JULIA_ADD_X
julia_const_n	dd	-0.709 ;JULIA_ADD_X
julia_const_i	dd	-0.278 ;JULIA_ADD_Y

	
tsync:
	dd 0
	
;;; ------------------------------------------------------------------------------------	
	
foobar:		
filesize equ $ - $$

section .bss data align=1

	resb 100		; hmh
	
fputemp:	
	resd 1

temp:	
	resd 16	
			
loopcounters:
	resb 4000

	
pad_note_buf:
	resd 16*16

;; bumpin kama	
height_map	resd	VIRTUAL_SCREEN_W*VIRTUAL_SCREEN_H*2 ; Float!
;vscreen		resb	VIRTUAL_SCREEN_W*VIRTUAL_SCREEN_H
ivar		resd	10
fvar		resd	10

light_x		resd	1
light_y		resd	1
light_z		resd	1
diff		resd	1
cord1		resd	1
cord2		resd	1
block_counter	resd	1
start_z		resd	1
start_cord	resd	1
distance_x	resd	1
distance_y	resd	1
z1_n		resd	1
z1_i		resd	1
z2_n		resd	1
z2_i		resd	1
iter_n		resd	1
iter_i		resd	1
cabs_return	resd	1
iteration	resd	1 	

mm_size:
	resd 1			; file size
fbdev_desc:
	resd 1 			; fdesc

desc_devdsp:	
	resd 1			; /dev/dsp:n filedescriptori		

kulma:	
	resd 1	

		
;;; 

tunnel_using_texture:	
	resd 1
		
count_info:	
	resb 256

tunnel_table:
	resb 640*480*16

tunnel_texture1:	
	resb 256*256
tunnel_texture2:	
	resb 256*256

vscreen1:
	resb 80*50*4

vscreen2:	
	resb 80*50*4
vscreen equ vscreen2
			

reitreis_vscreen:	
	resb 400*400
	
audio_mix:
	resb 44100*280

audio_temp:		
	resb 44100*280
