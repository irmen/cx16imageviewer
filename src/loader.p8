%import gfx2
%import diskio
%import textio
%import string
%import bmx
%import palette
%import koala_module
%import doodle_module
%import iff_module
%import pcx_module
%import bmp_module
%import bmx_module

loader {

    str[] known_extensions = [".koa", ".iff", ".lbm", ".pcx", ".bmp", ".bmx", ".dd", ".ddl"]

    sub is_known_extension(str extension) -> bool {
        if string.length(extension) > 4     ; max extension length
            return false
        str extension_copy = "?" * 4
        extension_copy = extension
        void string.lower(extension_copy)
        for cx16.r4 in known_extensions {
            if string.compare(extension_copy, cx16.r4)==0
                return true
        }
        return false
    }

    uword error_details
    ubyte @shared orig_screenmode = 255

    sub attempt_load(uword filenameptr, bool set_gfx_screenmode) -> bool {
        void string.lower(filenameptr)
        if set_gfx_screenmode {
            void cx16.get_screen_mode()
            %asm {{
                sta  p8v_orig_screenmode
            }}
        }

        loader.error_details = 0
        uword extension = filenameptr + rfind(filenameptr, '.')
        if ".iff"==extension or ".lbm"==extension {
            if iff_module.show_image(filenameptr, set_gfx_screenmode) {
                if iff_module.num_cycles!=0 {
                    repeat 500 {
                        sys.waitvsync()
                        iff_module.cycle_colors_each_jiffy()
                        if cbm.STOP2()
                            break
                    }
                }
                return true
            } else
                main.load_error(loader.error_details, filenameptr)
        }
        else if ".pcx"==extension {
            if pcx_module.show_image(filenameptr, set_gfx_screenmode)
                return true
            else
                main.load_error(loader.error_details, filenameptr)
        }
        else if ".koa"==extension {
            if koala_module.show_image(filenameptr, set_gfx_screenmode)
                return true
            else
                main.load_error(loader.error_details, filenameptr)
        }
        else if ".dd"==extension or ".ddl"==extension {
            if doodle_module.show_image(filenameptr, set_gfx_screenmode)
                return true
            else
                main.load_error(loader.error_details, filenameptr)
        }
        else if ".bmp"==extension {
            if bmp_module.show_image(filenameptr, set_gfx_screenmode)
                return true
            else
                main.load_error(loader.error_details, filenameptr)
        }
        else if ".bmx"==extension {
            if bmx_module.show_image(filenameptr, set_gfx_screenmode)
                return true
            else
                main.load_error(loader.error_details, filenameptr)
        }
;        else if ".rle"==extension  {   ; or maybe .rlx
;            if rle_module.show_image(filenameptr, set_gfx_screenmode) {
;                sys.wait(180)
;                return true
;            } else {
;                main.load_error(loader.error_details, filenameptr)
;            }
;        }
        return false
    }

    sub restore_screen_mode() {
        gfx2.screen_mode(0)
        if orig_screenmode!=255 {
            void cx16.screen_mode(orig_screenmode, false)
        }
    }

    sub rfind(uword stringptr, ubyte char) -> ubyte {
        ubyte i
        for i in string.length(stringptr)-1 downto 0 {
            if @(stringptr+i)==char
                return i
        }
        return 0
    }

    sub save_as_bmx(uword filenameptr) {
        sub textmode() {
            restore_screen_mode()
            palette.set_default16()
        }

        uword extension = filenameptr + rfind(filenameptr, '.')
        if ".bmx" == extension {
            textmode()
            txt.print(filenameptr)
            txt.print(": file is already in bmx format")
            sys.wait(120)
            return
        }
        if extension==filenameptr {
            void string.append(filenameptr, ".bmx")
        } else {
            extension[1] = 'b'
            extension[2] = 'm'
            extension[3] = 'x'
            extension[4] = 0
        }

        bmx.set_bpp(gfx2.bpp)
        bmx.width = gfx2.width
        bmx.height = gfx2.height
        bmx.border = 0
        bmx.compression = 0
        bmx.palette_entries = $0001 << gfx2.bpp
        bmx.palette_start = 0

        ubyte[50] bmxfilename
        void string.copy(filenameptr, bmxfilename)
        bool success = bmx.save(diskio.drivenumber, bmxfilename, 0, 0, gfx2.width)
        textmode()
        if success {
            txt.print("converted to: ")
            txt.print(bmxfilename)
            txt.nl()
        } else {
            txt.print("failed to save as ")
            txt.print(bmxfilename)
            txt.print(": ")
            txt.print(bmx.error_message)
        }
        sys.wait(200)
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
