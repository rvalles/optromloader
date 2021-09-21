fasm = fasm
fasm_extraopts = -p 2
#fasm_extraopts += -d target_segment=0xE000
readblock_retries = 7
hexdumpcmd = hexdump -C
#hexdumpcmd = xxd -a
qemu = qemu-system-i386
date = \"`date -u +%Y%m%d%H%MZ`\"
fasm_extraopts += -d build_date=$(date)
fasm_extraopts += -d readblock_retries=$(readblock_retries)
.PHONY: all
all: optromloader18 optromloader15 optromloader9 fd1440.img fd720.img fd1200.img fd360.img hexdump
optromloader18: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=18 optromloader.asm $@
optromloader15: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=15 optromloader.asm $@
optromloader9: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=9 optromloader.asm $@
fd1440.img: optromloader.asm optrom.bin
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=18 -d pad_to_bytes=1474560 -d include_optrom="'optrom.bin'" optromloader.asm $@
fd720.img: optromloader.asm optrom.bin
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=9 -d pad_to_bytes=737280 -d include_optrom="'optrom.bin'" optromloader.asm $@
fd1200.img: optromloader.asm optrom.bin
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=15 -d pad_to_bytes=1228800 -d include_optrom="'optrom.bin'" optromloader.asm $@
fd360.img: optromloader.asm optrom.bin
	@echo "*** assembling $@..."
	$(fasm) $(fasm_extraopts) -d sectors_per_track=9 -d pad_to_bytes=368640 -d include_optrom="'optrom.bin'" optromloader.asm $@
testrom.bin: testrom.asm
	@echo "*** assembling $@ (not signed)..."
	$(fasm) testrom.asm $@
	$(hexdumpcmd) $@
.PHONY: clean
clean:
	@echo "*** Removing build artifacts..."
	rm -f optromloader9 optromloader15 optromloader18 fd1440.img fd720.img fd1200.img fd360.img testrom.bin
.PHONY: hexdump
hexdump: optromloader18
	@echo "*** hexdump optromloader18..."
	$(hexdumpcmd) optromloader18
.PHONY: emulate
emulate: fd1440.img
	@echo "*** Emulating with qemu..."
	$(qemu) -drive if=floppy,format=raw,index=0,file=fd1440.img
.PHONY: emulaterom
emulaterom: optrom.bin
	@echo "*** Emulating with qemu..."
	$(qemu) -net none -option-rom optrom.bin
