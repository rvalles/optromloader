;optromloader, by Roc Valles Domenech.
;MIT license, see LICENSE for details.
;https://www.rvalles.net
format binary as "raw"
use16
org 7C00h
jmp 0x0000:start
start:
	mov sp,$7C00
	mov ax,0
	mov bx,ss
	mov ss,ax
	mov ds,ax
	mov si,banner_str
	call printstr
	mov ax,1
	mov bx,bootblock_end
	call readblock
	mov bx,[bootblock_end]
	cmp bx,$AA55
	jnz bad_header_magic
	mov si,romsize_str
	call printstr
	mov ax,0
	mov al,[bootblock_end+2]
	mov bx,ax
	call printhex8
	mov si,romsizebytes_str
	call printstr
	mov ax,bx
	mov cl,9
	shl ax,cl
	call printhex16
	mov si,ramsize_str
	call printstr
	int 12h
	call printhex16
	mov dx,bx
	test dx,1
	jz .blocks_even
	add dx,1
.blocks_even:
	shr dx,1
	sub ax,dx
	mov [1043],ax
	mov si,ramsizeafter_str
	call printstr
	int 12h
	call printhex16
	mov cl,6
	shl ax,cl ;target segment
	mov es,ax
	mov dx,0
	mov si,readblocks_str
	call printstr
	mov cx,bx
	mov bx,0 ;target address
.readrom:
	;hlt
	add dl,1
	mov ax,dx
	call printhex8
	call readblock
	add bx,512
	mov si,readblocksbs_str
	call printstr
	cmp cx,dx
	jne .readrom
	;mov si,cksum_str
	;call printstr
	mov ax,es
	mov [.calloptrom+3], ax
	mov ah,0eh
	mov al,'#'
	int 10h
	;sti ;some bad BIOSs disable on int13 and forget to restore.
.calloptrom:
	call 0xA000:3
	mov ah,0eh
	mov al,'@'
	int 10h
	int 19h
;*****************************************************************************
bad_header_magic:
	mov si,bad_header_magic_str
	call printstr
	mov ax,bx
	call printhex16
	jmp $
printstr: ;SI *str
	push ax
	mov ah,0eh ;print character
.printstr_loop:
	lodsb ;SI++ -> al
	test al,al
	jz .printstr_end
	int 10h ;print
	jmp .printstr_loop
.printstr_end:
	pop ax
	ret
;FIXME: these value dumpers could be shorter.
printhex8: ;AL (preserved) value to print
	push ax
	push bx
	push cx
	mov ah,0eh
	mov bl,al
	mov cl,4
	rol bl,cl ;in 8086, 1 or cl. 186+ for higher imm.
	call printhexdigit
	rol bl,cl
	call printhexdigit
	pop cx
	pop bx
	pop ax
	ret
printhex16: ;AX (preserved) value to print
	push ax
	push bx
	push cx
	mov bx,ax
	mov ah,0eh
	mov cl,4
	rol bx,cl
	call printhexdigit
	rol bx,cl
	call printhexdigit
	rol bx,cl
	call printhexdigit
	rol bx,cl
	call printhexdigit
	pop cx
	pop bx
	pop ax
	ret
printhexdigit: ;FIXME: Make shorter. possibly use daa/adc inst.
	mov al,bl
	and al,$F
	add al,$30
	cmp al,$3A
	jb .printhexlow
	add al,7
.printhexlow:
	int 10h
	ret
resetfloppy:
	mov ah,0
	mov dl,0
	int 13h
	ret
readblock: ;AX blocknumber, ES:BX (preserved) addr.
	;call printhex16
	;xchg ax,bx
	;call printhex16
	;xchg ax,bx
	push cx
	push dx
	;CHS magic: get number of tracks, heads>>1 is cyl
	mov dl,sectorspertrack
	div dl ;ax/dl -> /al, %ah
	mov dh,0 ;head 0..15
	test al,1
	jz .heads_even
	add dh,1
.heads_even:
	shr al,1
	;CX 0-5 sector, 6-7 track MSB, 8-15 track LSB
	mov ch,al ;cyl
	add ah,1 ;CHS sectors start at 1
	mov cl,ah ;sector
	mov ah,02h ;BIOS 13h read CHS block
	mov al,1 ;sectors to read 1..128
	mov dl,0 ;drive 0=A 80h=hdd0
	;xchg ax,cx
	;call printhex16
	;xchg ax,cx
	;xchg ax,dx
	;call printhex16
	;xchg ax,dx
	push ax
.retry:
	;hlt
	;push ax
	;mov ah,0eh
	;mov al,'%'
	;int 10h
	;pop ax
	int 13h
	;push ax
	;mov ah,0eh
	;mov al,'?'
	;int 10h
	;pop ax
	cmp ah,0
	jne .error
	;mov dx,es
	;mov ds,dx
	;mov ax,[bx]
	;call printhex16
	mov dx,0
	mov ds,dx
	pop ax
	pop dx
	pop cx
	ret
.error:
	push ax
	mov ah,0eh
	mov al,'E'
	int 10h
	pop ax
	mov al,ah
	mov ah,0
	call printhex8
	call resetfloppy
	mov si,readblocks_str
	call printstr
	pop ax
	push ax
	jmp .retry
banner_str: db "optromloader, by Roc Valles Domenech <rvalles.net>, built ",date,'.',13,10,0
bad_header_magic_str: db "Ehdrmagic:",0
romsize_str: db "ROM blks:",0
romsizebytes_str: db "->",0
ramsize_str: db 13,10,"RAM:",0
ramsizeafter_str: db "/",0
readblocks_str: db 13,10,"Rd:",0
readblocksbs_str: db 8,8,0
;readblocksbs_str: db 13,10,"Rd+",0
;cksum_str: db 13,10,"Ck+",0
.finalize_bootblock:
	times 510-($-$$) db $cc
	dw $AA55
bootblock_end:
