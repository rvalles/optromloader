;optromloader, by Roc Valles Domenech.
;MIT license, see LICENSE for details.
;https://www.rvalles.net
format binary as "raw"
use16
org 7C00h ;fixed bootloader load address
jmp 0x0000:start ;ensure CS is zero
start:
	mov sp,$7C00 ;set a stack right under the bootloader
	xor ax,ax
	mov ss,ax ;handed-over SS could be anything, like CS
	mov ds,ax ;DS can't be trusted either
	mov si,banner_str
	call printstr
	;*** Load first block of ROM image (containing ROM header)
	mov al,1 ;block number
	mov bx,bootblock_end ;target addr
	call readblock
	;*** Check ROM magic value
	mov ax,[bootblock_end] ;load magic value from ROM header
	cmp ax,$AA55 ;expected value
	jz .good_header_magic
	mov si,bad_header_magic_str
	call printstr
	call printhex16
	jmp $ ;deadend infinite loop
.good_header_magic:
	;*** Obtain ROM size
	mov si,romsize_str
	call printstr
	mov ah,0
	mov al,[bootblock_end+2] ;load length from ROM header
	mov bx,ax ;save length (blocks) into BX
	call printhex8
	mov si,romsizebytes_str
	call printstr
	mov cl,9 ;calculate ROM size in bytes: blocks*512
	shl ax,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhex16
	;*** Adjust conventional/low memory size
	mov si,ramsize_str
	call printstr
	int 12h ;get low mem size
	call printhex16
	mov dx,bx ;recover rom length (blocks) from bx
	test dx,1
	jz .blocks_even
	inc dx ;round required storage up to 1KB
.blocks_even:
	shr dx,1 ;512 blocks becomes 1KB blocks
	sub ax,dx ;decrease low mem size by rounded size of ROM image
	mov [1043],ax ;store new low mem size into BIOS variable 40:0013
	mov si,ramsizeafter_str
	call printstr
	int 12h ;get low mem size
	call printhex16
	;*** Setup ROM reading parameters
	mov cl,6 ;segments are 2^4 bytes, low ram size in 2^10 bytes, thus <<6.
	shl ax,cl ;in 8086, 1 or cl. 186+ for higher imm
	mov es,ax ;target segment
	xor dx,dx ;block to read; will become 1 before reading
	mov si,readblocks_str
	call printstr
	mov cx,bx ;recover rom length (blocks) from bx
	xor bx,bx ;target address
.readrom:
	;hlt ;delay for debugging
	inc dx ;increase target block. Needs to be 16bit, as image starts at 1
	mov ax,dx ;block to seek to and read
	call printhex8
	call readblock
	add bx,512 ;next target address += 1 blocksize
	mov si,readblocksbs_str
	call printstr
	cmp cx,dx ;are we done
	jne .readrom ;loop if not
	;mov si,cksum_str
	;call printstr
	;*** Call ROM image entrypoint
	mov [.calloptrom+3],es ;replace target segment in long call
	mov si,rominit_str
	call printstr
	;sti ;some bad BIOSs disable on int13 and forget to restore
.calloptrom:
	call 0xA000:3 ;long jump. Segment placeholder gets replaced by mov above
	;*** Tell BIOS to try booting elsewhere
	mov si,int19h_str
	call printstr
	int 19h ;try next boot device (some BIOSs will reboot if none left)
	;int 19h shouldn't return, so this shouldn't be reached
;*****************************************************************************
printstr: ;SI *str
	push ax ;preserve AX
	cld ;direction flag could have been set
	mov ah,0eh ;print character
.printstr_loop:
	lodsb ;SI++ -> al
	test al,al ;are we done? (is character a NUL?)
	jz .printstr_end
	int 10h ;print
	jmp .printstr_loop
.printstr_end:
	pop ax ;restore AX
	ret
;FIXME: these value dumpers could be shorter
printhex8: ;AL value to print
	push ax ;preserve AX
	push bx ;preserve BX
	push cx ;preserve CX
	mov ah,0eh
	mov bl,al
	mov cl,4
	rol bl,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	rol bl,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	pop cx ;restore CX
	pop bx ;restore BX
	pop ax ;restore AX
	ret
printhex16: ;AX value to print
	push ax ;preserve AX
	push bx ;preserve BX
	push cx ;preserve CX
	mov bx,ax ;we will make multiple BIOS calls using AX
	mov ah,0eh
	mov cl,4
	rol bx,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	rol bx,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	rol bx,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	rol bx,cl ;in 8086, 1 or cl. 186+ for higher imm
	call printhexdigit
	pop cx ;restore CX
	pop bx ;restore BX
	pop ax ;restore AX
	ret
printhexdigit: ;FIXME: Make shorter. possibly use daa/adc inst
	mov al,bl ;two nibbles copied
	and al,$F ;we only need the least significant nibble
	add al,$30 ;'0'
	cmp al,$3A ;'9'+1
	jb .printhexlow
	add al,7 ;'9'+1+7 = 'A'
.printhexlow:
	int 10h
	ret
readblock: ;AX blocknumber, ES:BX addr, trashes AX (future return value)
	;call printhex16
	;xchg ax,bx
	;call printhex16
	;xchg ax,bx
	push cx ;preserve CX
	push dx ;preserve DX
	;*** CHS magic
	;tracks>>1 is cyl, tracks&1 is head
	mov dl,sectorspertrack ;get number of tracks
	div dl ;ax/dl -> /al, %ah
	mov dh,1 ;tracks&1 is head
	and dh,al ;CHS head 0..15 (0 or 1 for floppy)
	shr al,1 ;tracks>>1 is cyl
	;CX 0-5 sector, 6-7 cyl MSB, 8-15 cyl LSB
	mov ch,al ;CHS cyl LSB.
	inc ah ;CHS sectors start at 1
	mov cl,ah ;CHS sector in LSB, cyl MSB (zero) in MSB
	mov ah,02h ;BIOS 13h read CHS block
	mov al,1 ;sectors to read 1..128
	mov dl,0 ;drive 0=A 80h=hdd0
	;xchg ax,cx
	;call printhex16
	;xchg ax,cx
	;xchg ax,dx
	;call printhex16
	;xchg ax,dx
.retry:
	push ax ;preserve AX for potential retries
	;hlt
	;push ax
	;mov ah,0eh
	;mov al,'%'
	;int 10h
	;pop ax
	int 13h ;call BIOS function for disk operations
	;push ax
	;mov ah,0eh
	;mov al,'?'
	;int 10h
	;pop ax
	cmp ah,0 ;returned status, where 0 means OK
	jne .error
	;mov dx,es
	;mov ds,dx
	;mov ax,[bx]
	;call printhex16
	;mov dx,0
	;mov ds,dx
	pop ax ;free AX used for retries
	pop dx ;restore DX
	pop cx ;restore CX
	ret
.error:
	push ax ;preserve AX
	mov ah,0eh
	mov al,'E'
	int 10h
	pop ax ;restore AX
	mov al,ah ;status was returned in AH
	mov ah,0
	call printhex8 ;print status value
	call .resetfloppy
	mov si,readblocks_str
	call printstr ;reprint header in next line to preserve read error on screen
	pop ax ;restore AX containing parameters for retry
	jmp .retry ;retry reading sector
.resetfloppy:
	mov ah,0 ;reset command
	mov dl,0 ;drive 0=A 80h=hdd0
	int 13h ;call BIOS function for disk operations
	ret
banner_str: db "optromloader, by Roc Valles Domenech <rvalles.net>, built ",date,'.',13,10,0
bad_header_magic_str: db "Ehdrmagic:",0
romsize_str: db "ROM blks:",0
romsizebytes_str: db "->",0
ramsize_str: db 13,10,"RAM:",0
ramsizeafter_str: db "/",0
readblocks_str: db 13,10,"Rd:",0
readblocksbs_str: db 8,8,0
rominit_str: db 13,10,"ROM Init.",0
int19h_str: db " INT 19h.",0
;readblocksbs_str: db 13,10,"Rd+",0
;cksum_str: db 13,10,"Ck+",0
.finalize_bootblock:
	times 510-($-$$) db $cc
	dw $AA55
bootblock_end:
