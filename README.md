# optromloader: IBM PC/Clone 8086+ floppy-loading of option roms.

Booted from a floppy, it will load an Option ROM image into the end of conventional memory.

![PCem IBM PC screenshot](https://b.rvalles.net/unsorted/pcem_ibmpc_optromboot_xtide.png)

## Use cases (non-exhaustive)
* Test boot ROMs before burning them.
* Netboot with etherboot/gpxe/ipxe.
* IDE support (including LBA!) with XTIDE Universal BIOS.

## Highlights
* Flat assembler syntax.
* Pure 8086 code.
* Fits in a floppy bootblock.
* Verifies ROM image checksum after loading.
* Works on PC/XT/AT and clones.
  * Also works on newer hardware, such as the 486 with AMI BIOS I wrote it for.
* Trivial to use. Concatenate loader and the ROM image, write into floppy.
* Makefile will prepare 5.25" 360K/1.2M and 3.5" 720K/1.44M floppy images.
* MIT License. See LICENSE file.

## Usage
* Ensure fasm (flat assembler) is installed.
* Copy your ROM image as the `optrom.bin` file.
  * Ensure the ROM image is signed (has correct checksum).
    * optromloader will loudly refuse to run the ROM image if not signed.
    * Test with `make emulaterom`. Qemu's BIOS won't see the ROM if it's not signed.
    * Qemu provides a python tool to sign ROMs:
        * https://github.com/qemu/qemu/blob/master/scripts/signrom.py
    * For XTIDE Universal BIOS ROMs, use its XTIDECFG tool to configure and sign ROM images.
* Run `make`.
* Floppy images will be created (fd*.img).
* Optionally test 1.44M image with qemu: `make emulate`.
* Alternatively, use a binary release. Concatenate:
  * optromloader9/15/18, according to sectors per track in your floppy format:
    * `9` for 5.25" 360K and 3.5" 720K.
    * `15` for 5.25" 1.2M.
    * `18` for 3.5" 1.44M.
  * the ROM image.
  * pad to floppy size.

## Caveats
* ROM size cannot be over 64KB (one 8086 segment).
* Hardcoded to use the first floppy drive.

## Author
Roc Vallès Domènech
