%import gfx2
%import textio
%import diskio
%import string
%import bmx
%import koala_module
%import doodle_module
%import iff_module
%import pcx_module
%import bmp_module
%zeropage basicsafe
%option no_sysinit

main {
    uword load_error_details
    ubyte system_screen_mode

    sub start() {
        system_screen_mode = cx16.screen_mode(0, true)
        cx16.rombank(0)        ; switch to kernal rom (for faster file i/o)

        ; trick to check if we're running on sdcard or host system shared folder
        txt.print("\x93\nimage viewer for commander x16\nformats supported: ")
        uword ext
        for ext in main.recognised_extension.extensions {
            txt.print(ext)
            txt.spc()
        }
        txt.nl()
        txt.nl()
        if list_image_files_on_disk() {
            txt.print("\nenter file name or just enter to view all: ")
            ubyte i = txt.input_chars(diskio.list_filename)
            if i!=0 {
                gfx2.screen_mode(1)
                if not attempt_load(diskio.list_filename)
                    load_error("invalid file", diskio.list_filename)
            }
            else
                show_pics_sdcard()
        }
        else
            txt.print("files are read with sequential file loading.\nin the emulator this currently only works with files on an sd-card image.\nsorry :(\n")

        gfx2.screen_mode(0)      ; back to default text mode
        palette.set_c64pepto()
        txt.print("that was all folks!\n")

        cx16.rombank(4)        ; switch back to basic rom
    }

    sub list_image_files_on_disk() -> bool {
        if diskio.lf_start_list(0) {
            txt.print(" blocks   filename\n-------- -------------\n")
            while diskio.lf_next_entry() {
                uword extension = &diskio.list_filename + rfind(&diskio.list_filename, '.')
                if recognised_extension(extension) {
                    txt.spc()
                    print_uw_right(diskio.list_blocks)
                    txt.print("    ")
                    txt.print(diskio.list_filename)
                    txt.nl()
                }
            }
            diskio.lf_end_list()
            return true
        }
        return false
    }

    sub print_uw_right(uword value) {
        if value < 10
            txt.spc()
        if value < 100
            txt.spc()
        if value < 1000
            txt.spc()
        if value < 10000
            txt.spc()
        txt.print_uw(value)
    }

    sub recognised_extension(str extension) -> bool {
        str[] extensions = [".koa", ".iff", ".lbm", ".pcx", ".bmp", ".bmx", ".dd", ".ddl"]
        uword ext
        for ext in extensions {
            if string.compare(extension, ext)==0
                return true
        }
        return false
    }

    sub show_pics_sdcard() {

        ; load and show the images on the disk with the given extensions.
        ; this only works in the emulator V38 with an sd-card image with the files on it.

        uword filenames = memory("filenames", 20*200, 0)
        uword @zp names_ptr = filenames
        ubyte num_files = diskio.list_filenames(0, filenames, sizeof(filenames))
        if num_files!=0 {
            gfx2.screen_mode(1)    ; 320*240, 256c
            while @(names_ptr)!=0 {
                void attempt_load(names_ptr)
                names_ptr += string.length(names_ptr) + 1
            }
        } else
            txt.print("no files in directory!\n")
    }

    sub attempt_load(uword filenameptr) -> bool {
        main.load_error_details = 0
        uword extension = filenameptr + rfind(filenameptr, '.')
        if ".iff"==extension or ".lbm"==extension {
            if iff_module.show_image(filenameptr) {
                if iff_module.num_cycles!=0 {
                    repeat 500 {
                        sys.wait(1)
                        iff_module.cycle_colors_each_jiffy()
                    }
                }
                else
                    sys.wait(180)
                return true
            } else {
                load_error(main.load_error_details, filenameptr)
            }
        }
        else if ".pcx"==extension {
            if pcx_module.show_image(filenameptr) {
                sys.wait(180)
                return true
            } else {
                load_error(main.load_error_details, filenameptr)
            }
        }
        else if ".koa"==extension {
            if koala_module.show_image(filenameptr) {
                sys.wait(180)
                return true
            } else {
                load_error(main.load_error_details, filenameptr)
            }
        }
        else if ".dd"==extension or ".ddl"==extension {
            if doodle_module.show_image(filenameptr) {
                sys.wait(180)
                return true
            } else {
                load_error(main.load_error_details, filenameptr)
            }
        }
        else if ".bmp"==extension {
            if bmp_module.show_image(filenameptr) {
                sys.wait(180)
                return true
            } else {
                load_error(main.load_error_details, filenameptr)
            }
        }
        else if ".bmx"==extension {
            if bmx.open(diskio.drivenumber, filenameptr) {
                if bmx.width<=gfx2.width {
                    ; set the color depth for the bitmap:
                    cx16.VERA_L1_CONFIG = cx16.VERA_L1_CONFIG & %11111100 | bmx.vera_colordepth
                    if bmx.width==gfx2.width {
                        ; can use the fast, full-screen load routine
                        if bmx.continue_load(0, 0) {
                            if bmx.height<gfx2.height {
                                ; fill the remaining bottom part of the screen
                                gfx2.fillrect(0, bmx.height, gfx2.width, gfx2.height-bmx.height, bmx.border)
                            }
                            sys.wait(180)
                            return true
                        } else
                            load_error(bmx.error_message, filenameptr)
                    } else {
                        ; clear the screen with the border color
                        gfx2.clear_screen(bmx.border)
                        ; need to use the slower load routine that does padding
                        ; center the image on the screen nicely
                        uword offset = (gfx2.width-bmx.width)/2 + (gfx2.height-bmx.height)/2*gfx2.width
                        if bmx.continue_load_stamp(0, offset, gfx2.width) {
                            sys.wait(180)
                            return true
                        } else
                            load_error(bmx.error_message, filenameptr)
                    }
                } else
                    load_error("image too large", filenameptr)
            } else
                load_error(bmx.error_message, filenameptr)
            return false
        }
;        else if ".rle"==extension  {   ; or maybe .rlx
;            if rle_module.show_image(filenameptr) {
;                sys.wait(180)
;                return true
;            } else {
;                load_error(main.load_error_details, filenameptr)
;            }
;        }
        return false
    }

    sub load_error(uword what, uword filenameptr) {
        ; back to default text mode and palette
        gfx2.screen_mode(0)
        cbm.CINT()
        void cx16.screen_mode(system_screen_mode, false)
        txt.print("load error: ")
        if what!=0
            txt.print(what)
        txt.print("\nfile: ")
        txt.print(filenameptr)
        txt.nl()
        cx16.rombank(4)        ; switch back to basic rom
        sys.exit(1)
    }

    sub rfind(uword stringptr, ubyte char) -> ubyte {
        ubyte i
        for i in string.length(stringptr)-1 downto 0 {
            if @(stringptr+i)==char
                return i
        }
        return 0
    }

}

custompalette {

    sub set_bgra(uword palletteptr, uword num_colors) {
        uword vera_palette_ptr = $fa00
        ubyte red
        ubyte greenblue

        ; 4 bytes per color entry (BGRA), adjust color depth from 8 to 4 bits per channel.
        repeat num_colors {
            red = @(palletteptr+2) >> 4
            greenblue = @(palletteptr+1) & %11110000
            greenblue |= @(palletteptr+0) >> 4    ; add Blue
            palletteptr+=4
            cx16.vpoke(1, vera_palette_ptr, greenblue)
            vera_palette_ptr++
            cx16.vpoke(1, vera_palette_ptr, red)
            vera_palette_ptr++
        }
    }

    sub set_grayscale256() {
        ; grays $000- $fff stretched out over all the 256 colors
        ubyte c = 0
        uword vera_palette_ptr = $fa00
        repeat 16 {
            repeat 16 {
                cx16.vpoke(1, vera_palette_ptr, c)
                vera_palette_ptr++
                cx16.vpoke(1, vera_palette_ptr, c)
                vera_palette_ptr++
            }
            c += $11
        }
    }
}
