format binary as "raw"
use16
delayticks=19 ;at least a second
rom_length=128 ;length in 512 byte blocks
org 0
dw $AA55 ;rom magic
db rom_length
start: ;assume sane stack, which means sane SS and SP
	mov bx,ds ;save entry DS
	mov ax,cs
	mov ds,ax ;set DS to be the same as CS
	mov si,hello_str
	call printstr
	sti ;as we'll rely on timer tick interrupt (int8)
	mov cx,delayticks ;timer tick interrupt fires at 18.2065Hz
	call delayloopnaive
	mov al,'.'
	call printchar
	mov cx,delayticks ;timer tick interrupt fires at 18.2065Hz
	call delayloop
	mov si,bye_str
	call printstr
	mov ds,bx ;restore entry DS
	retf ;return from far call
	;*****************************************************************************
printchar: ;AL character to print
	push bx ;preserve BX
	push ax ;preserve AX
	mov ah,0fh ;get current video state
	int 10h ;BH is set to current page
	mov bl,$7 ;light grey
	pop ax ;restore AX
	push ax ;preserve AX again
	mov ah,0eh ;print character (teletype)
	int 10h ;character finally printed
	pop ax ;restore AX
	pop bx ;restore BX
	ret
printstr: ;0:SI *str
	push ax ;preserve AX
	xor ax,ax
	cld ;direction flag could have been set
.printstr_loop:
	lodsb ;load [SI++] into AL
	test al,al ;are we done? (is character a NUL?)
	jz .printstr_end
	call printchar
	jmp .printstr_loop
.printstr_end:
	pop ax ;restore AX
	ret
delayloopnaive: ;CX interrupts to wait (not preserved)
	hlt ;wait until int8 (timer) fires or some other interrupt does
	loop delayloopnaive
	ret
delayloop: ;CX ticks to wait (not preserved)
	push ax ;preserve AX
	push bx ;preserve BX
	mov bx,ds ;save DS
	mov ax,$40 ;bios variables segment
	mov ds,ax
	mov ax,[$6C] ;get current timeofday lower 16bit
	add cx,ax ;get target time
.delayloop:
	mov ax,[$6C] ;get current timeofday lower 16bit
	sub ax,cx ;is it lower than the target time?
	jc .delayloop ;wait further if so.
	mov ds,bx ;restore ds to what it was
	pop bx ;restore BX
	pop ax ;restore AX
	ret
hello_str:
	db "TestROM.",0
bye_str:
	db "EndTest.",0
.finalize_optrom:
	times 512*rom_length-($-$$)-1 db $cc ;int3, a breakpoint. Better results should IP end up pointing here.
	db $00 ;signature
