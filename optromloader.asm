;optromloader, by Roc Valles Domenech.
;MIT license, see LICENSE for details.
;https://www.rvalles.net
format binary as "raw"
use16
;8086 conditional branches must be rel8
macro jcc8086 opcode,dest {
	assert dest-$-2 >= -128
	assert dest-$-2 <= 127
	opcode dest
}
if defined readblock_retries
readblock_tries=readblock_retries+1
else
readblock_tries=5 ;use FDD with care
end if
if ~ definite bios_drive
bios_drive=0
end if
org 7C00h ;fixed bootloader load address
	jmp 0x0000:start ;ensure CS is zero
start:
	xor ax,ax
	mov ss,ax ;handed-over SS could be anything, like CS
	mov sp,$7C00 ;set a stack right under the bootloader
	mov ds,ax ;DS can't be trusted either
	mov es,ax ;ES isn't any more trustworthy
	mov si,banner_str
	call printstr
	;*** Load first block of ROM image (containing ROM header)
	mov al,1 ;block number (0 bootloader, 1+ ROM image)
	mov bx,bootblock_end ;target addr
	call readblock
	;*** Check ROM magic value
	mov ax,[bootblock_end] ;load magic value from ROM header
	cmp ax,$AA55 ;expected value
	jcc8086 jz,.good_header_magic
	mov si,bad_header_magic_str
	call printstr
	call printhex16 ;magic value found in ROM header
	jmp badend
.good_header_magic:
	;*** Obtain ROM size
	mov si,romsize_str
	call printstr
	mov ah,0
	mov al,[bootblock_end+2] ;load length from ROM header
	mov di,ax ;save length (blocks) into DI
	call printhex8 ;length in blocks
	cmp al,0 ;length shouldn't be zero
	jcc8086 jz,badend
	;*** Adjust conventional/low memory size
if ~ defined target_segment
	mov dx,di ;recover ROM length (blocks) from DI
	inc dx ;round up to even
	shr dx,1 ;512 blocks becomes 1KB blocks
	int 12h ;get mem size
	sub ax,dx ;calculate remaining conventional memory
	jcc8086 jnc,.mem_ok ;no underflow
	xor ax,ax ;conventional memory left at 0 is code for "no ram left"
.mem_ok:
	mov [1043],ax ;store new low mem size into BIOS variable 40:0013
	mov cl,6 ;segments are 2^4 bytes, low ram size in 2^10 bytes, thus <<6
	shl ax,cl ;in 8086, 1 or CL. 186+ for higher imm
else
	mov ax,target_segment
end if
	;*** Set up target segment
	mov si,segment_str
	call printstr
	call printhex16 ;target segment
	mov bp,ax ;saved for later
	mov es,bp ;target segment
	cmp ax,$0800 ;bootloader entrypoint + 2 blocks, >>4 because segment
	jcc8086 jae,segment_ok ;not clobbering this bootloader (A20 wrap not considered)
badend:
	mov si,bad_str
	call printstr
	jmp $ ;infinite loop deadend
segment_ok:
	;*** Read ROM image
	mov si,readblocks_str
	call printstr
	xor dx,dx ;block to read; will become 1 before reading
	mov cx,di ;recover ROM length (blocks) from DI
	cmp cl,255 ;set CF if CL under 255
	sbb cx,-1 ;add 1 if CF is set. Thus the 255 case becomes 256
	xor bx,bx ;target address
.readrom:
	;hlt ;delay for debugging
	inc dx ;increase target block. Needs to be 16bit, as image starts at 1
	mov ax,dx ;block to seek to and read
	call printhex16 ;block
	call readblock
	add bx,512 ;next target address += 1 blocksize
	jcc8086 jnc,.same_segment
	mov ax,es ;get segment
	add ax,$1000 ;64KB forward, in segment terms
	mov es,ax ;set new segment
.same_segment:
	mov si,readblocksbs_str
	call printstr
	loop .readrom ;loop if there's still blocks left to read
	;*** Verify checksum
	mov si,checksum_str
	call printstr
	mov bx,di ;recover ROM length (blocks) from DI
	mov di,bp ;recover target segment from BP
	mov dl,0 ;checksum initialized with value 0
.checksum_nextblock:
	mov ds,di ;DS now points to the block we're about to checksum
	mov cx,512 ;size of a block, as we deal with one block at a time
	xor si,si ;at start of segment
.checksum_loop: ;DS:SI addr, CX size (single segment!), AX/Zflag if bad
	lodsb ;load [SI++] into AL
	sub dl,al ;checksum -= AL
	loop .checksum_loop
	add di,$20 ;advance 512 bytes via segment.
	dec bl ;blocksleft-=1
	jcc8086 jnz,.checksum_nextblock
	cmp dl,0 ;checksum - storedchecksum (last byte) should be zero
	jcc8086 jnz,badend
	mov si,ok_str
	call printstr
	;*** Call ROM image entrypoint
	mov [.calloptrom+3],bp ;replace target segment in long call
	mov si,rominit_str
	call printstr
	sti ;some bad BIOSs disable interrupts on int 13h
.calloptrom:
	call $CAFE:3 ;long call. Segment placeholder gets replaced by mov above
	;*** Tell BIOS to try booting elsewhere
	mov si,int19h_str
	call printstr ;also does zero DS. Option ROM could have changed it.
	int 19h ;try next boot device (some BIOSs will reboot if none left)
	;int 19h shouldn't return, so this shouldn't be reached
	jmp badend
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
printstr: ;0:SI *str, ***zeroes DS***
	push ax ;preserve AX
	xor ax,ax
	mov ds,ax ;zero DS.
	cld ;direction flag could have been set
.printstr_loop:
	lodsb ;load [SI++] into AL
	test al,al ;are we done? (is character a NUL?)
	jcc8086 jz,.printstr_end
	call printchar
	jmp .printstr_loop
.printstr_end:
	pop ax ;restore AX
	ret
printhex8: ;character in AX
	push cx ;preserve CX
	mov cl,4 ;how much to shift right to get first nibble
	jmp _printhexdigits
printhex16:
	push cx ;preserve CX
	mov cl,12 ;how much to shift right to get first nibble
_printhexdigits: ;intentional fallthrough
	push ax ;preserve AX
	push dx ;preserve DX
	mov dx,ax ;save whole 16bit
.hexdigit:
	mov ax,dx ;recover whole 16bit
	shr ax,cl ;get relevant nibble into place
	and al,$F ;get rid of anything but relevant nibble
	daa ;if (AL>9) AL+=6
	add al,-16 ;CF if AL>=16, or AL>9 before the DAA
	adc al,'0'+16 ;adc using prepared CF. We compensate 16 for last opcode
	call printchar
	sub cl,4 ;next digit will need less shifting to prepare
	jcc8086 jns,.hexdigit
	pop dx ;restore DX
	pop ax ;restore AX
	pop cx ;restore CX
	ret
readblock: ;AX blockno, [ES:BX] dest, trashes AX (reserved, retval)
	push cx ;preserve CX
	push dx ;preserve DX
	push di ;preserve DI
	;*** CHS magic
	;tracks>>1 is cyl, tracks&1 is head
	mov dl,sectors_per_track ;get number of tracks
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
	mov dl,bios_drive ;drive 0=A 80h=hdd0
	mov di,readblock_tries ;how many read attempts before giving up
.retry:
	push ax ;preserve AX for potential retries
	int 13h ;call BIOS function for disk operations
	cmp ah,0 ;returned status, where 0 means OK
	jcc8086 jne,.error
	pop ax ;free AX used for retries
	pop di ;restore DI
	pop dx ;restore DX
	pop cx ;restore CX
	ret
.error:
	mov al,'E'
	call printchar
	mov al,ah ;status was returned in AH
	call printhex8 ;status value
	mov ah,0 ;reset command
	mov dl,bios_drive ;drive 0=A 80h=hdd0
	int 13h ;call BIOS function for disk operations
	mov si,readblocks_str
	call printstr ;reprint header in next line to preserve read error on screen
	mov ax,'_' ;pad character
	call printchar ;pad output for block number
	call printchar
	call printchar
	call printchar ;4 nibbles
	dec di ;decrement tries left
	jcc8086 jnz,.canretry
	jmp badend ;enough attempts
.canretry:
	pop ax ;restore AX containing parameters for retry
	jmp .retry ;retry reading sector
banner_str: db "optromloader, by Roc Valles Domenech, built ",build_date,'.',13,10,0
bad_header_magic_str: db "Mgk:",0
romsize_str: db "ROM blks:",0
segment_str: db " Seg:",0
readblocks_str: db 13,10,"Rd:",0
readblocksbs_str: db 8,8,8,8,0
;readblocksbs_str: db 13,10,"Rd+",0
rominit_str: db "Init.",0
int19h_str: db "int19h.",0
checksum_str: db 13,10,"Ck+",0
bad_str: db "!BAD",0
ok_str: db "OK.",0
;pad rest of bootblock and add $AA55 magic value at the right location
	times 510-($-$$) db $cc ;int3, a breakpoint. Better results should IP end up pointing here
	dw $AA55 ;bootblock magic value
bootblock_end:
if defined include_optrom
	file include_optrom
end if
if defined pad_to_bytes
	times pad_to_bytes-($-$$) db $cc ;int3, a breakpoint. Better results should IP end up pointing here
end if
