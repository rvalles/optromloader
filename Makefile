fasm = fasm
hexdumpcmd = hexdump -C
#hexdumpcmd = xxd -a
qemu = qemu-system-i386
date = \"`date -u +%Y%m%d%H%MZ`\"
.PHONY: all
all: optromloader18 optromloader15 optromloader9 fd1440.img fd720.img fd1200.img fd360.img hexdump
optromloader18: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) -d date=$(date) -d sectorspertrack=18 optromloader.asm $@
optromloader15: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) -d date=$(date) -d sectorspertrack=15 optromloader.asm $@
optromloader9: optromloader.asm
	@echo "*** assembling $@..."
	$(fasm) -d date=$(date) -d sectorspertrack=9 optromloader.asm $@
fd1440.img: optromloader18 optrom.bin
	@echo "*** building $@..."
	cat optromloader18 optrom.bin >pad.bin && dd bs=1474560 conv=sync if=pad.bin of=$@
	rm -f pad.bin
fd720.img: optromloader9 optrom.bin
	@echo "*** building $@..."
	cat optromloader9 optrom.bin >pad.bin && dd bs=737280 conv=sync if=pad.bin of=$@
	rm -f pad.bin
fd1200.img: optromloader15 optrom.bin
	@echo "*** building $@..."
	cat optromloader15 optrom.bin >pad.bin && dd bs=1228800 conv=sync if=pad.bin of=$@
	rm -f pad.bin
fd360.img: optromloader9 optrom.bin
	@echo "*** building $@..."
	cat optromloader9 optrom.bin >pad.bin && dd bs=368640 conv=sync if=pad.bin of=$@
	rm -f pad.bin
testrom.bin: testrom.asm
	@echo "*** building $@ (not signed)..."
	$(fasm) testrom.asm $@
	$(hexdumpcmd) $@
.PHONY: clean
clean:
	@echo "*** Removing build artifacts..."
	rm -f optromloader9 optromloader15 optromloader18 fd1440.img fd720.img fd1200.img fd360.img pad.bin testrom.bin
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
