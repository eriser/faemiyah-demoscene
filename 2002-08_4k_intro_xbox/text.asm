;;;  testataan v‰h‰n terminaalikontrollihˆmpp‰‰ (jos vaikka tekis textmode-4k:)

BITS 32	
	
	org     0x08001000
		
	;; tee v‰h‰ audioo	
	mov ecx, 8000*16
audioloop:
	mov eax, ecx
	shl eax, 1
	mov [ecx+audio_mix], al
	loop audioloop
	
	;; avaa /dev/dsp
	mov eax, 5		; open
	mov ebx, str_devdsp	; pointteri nimistringiin
	mov ecx, 0x01		; write only
	xor edx, edx
	int 0x80
	
	mov [desc_devdsp], eax	; descriptori talteen

	
	call writeaudio		; etuk‰teen v‰h‰n pohjalle
looppi:			
	call clear
	call drawpic1
	call writeaudio 	;  kirjoita sekka audioo
	call delay	    
	call clear
	call drawpic2
	call writeaudio
	call delay
	jmp looppi
	
	;; poistu
	xor eax, eax 		
	inc eax 		; eax==1 (exit)
	int 0x80


;;; - - - - - -
;;; piirr‰ kuva
drawpic1:	
	mov eax, 4
	mov ebx, 1		; stdout
	mov ecx, pic1
	mov edx, pic1len
	int 0x80
	ret

drawpic2:	
	mov eax, 4
	mov ebx, 1		; stdout
	mov ecx, pic2
	mov edx, pic2len
	int 0x80
	ret

;;; - - - - - -
;;; kirjoita audioo v‰h‰n
writeaudio:	

	mov eax, 4		; write
	mov ebx, [desc_devdsp]	; descriptori
	mov ecx, [audio_bytes_written]
	add ecx, audio_mix	
;	mov ecx, ehdr
	mov edx, 8000		
	int 0x80

	add [audio_bytes_written], dword 8000	
	ret
	
;;; - - - - - -
;;; odota, kunnes jonkin verran ‰‰nt‰ on ulostettu
delay:				
	mov edi, [audio_bytes_played]
	add edi, 8000 		;

.delay_loop:
	;; sleeppaa hetki
	mov eax, 162 
	mov ebx, timespec
	mov ecx, ebx
	int 0x80
	;; lue soitetut bytet
	mov eax, 54		; ioctl
	mov ebx, [desc_devdsp]	; file desc.
	mov ecx, 0x800c5012 	; SNDCTL_DSP_GETOPTR
	mov edx, count_info	; pointer to arguments
	int 0x80
	;; vertaa
	cmp [count_info],edi	
	jc .delay_loop

	mov [audio_bytes_played], edi
	
	ret

audio_bytes_written:
	dd 0
audio_bytes_played:			
	dd 0
	
timespec:	
	dd 0 		; seconds
	dd 1000		; nanoseconds
	
;;; - - - - - -
;;; tyhj‰‰ termis
clear:	
	;; escapesekvenssi stdouttiin (tyhj‰‰ termis)
	mov eax, 4		; write
	mov ebx, 1		; stdout?
	mov ecx, escseq_cleardisplay	; pos
	mov edx, escseq_cleardisplay_len	; les
	int 0x80
	ret		

;;; - - - - - -

escseq_cleardisplay:			
	db 0x1b, "[1J"		; erase display
escseq_cleardisplay_len equ $ - escseq_cleardisplay
	
escseq_cursorpos:
	db 0x1b, "[H"         ; kursori yl‰nurkkaan
escreq_cursorpos_len equ $ - escseq_cursorpos

pic1:
	db "000010000", 0x0a
	db "000010000", 0x0a
	db "000010000", 0x0a
	db "000010000", 0x0a
	db "000010000", 0x0a
	db "000010000", 0x0a
	db "000010000", 0x0a
pic1len equ $ - pic1

pic2:
	db "000000000", 0x0a
	db "000000000", 0x0a
	db "000000000", 0x0a
	db "111111111", 0x0a
	db "000000000", 0x0a
	db "000000000", 0x0a
	db "000000000", 0x0a
pic2len equ $ - pic2


;;; graffan esitt‰mieen k‰ytett‰v‰t merkit
graph_chars:	
	;; 00
	;; 00
	db " "
	;; 10
	;; 00
	db "'"
	;; 01
	;; 00
	db "'"
	;; 11
	;; 00
	db "^"
	;; 00
	;; 10
	db "."
	;; 10
	;; 10
	db "I"
	;; 01
	;; 10
	db "/"
	;; 11
	;; 10
	db "F"
	;; 00
	;; 01
	db ","
	;; 10
	;; 01
	db 0x57 		; kenoviiva
	;; 01
	;; 01
	db "I"
	;; 11
	;; 01
	db "7"
	;; 00
	;; 11
	db "_"
	;; 10
	;; 11
	db "L"
	;; 01
	;; 11
	db "J"
	;; 11
	;; 11
	db "O"
	
str_devdsp:	
	db "/dev/dsp",0

desc_devdsp:	
	dd 0			; /dev/dsp:n filedescriptori		
		
filesize equ $ - $$
section .bss
count_info:	
	resb 256

audio_mix:	