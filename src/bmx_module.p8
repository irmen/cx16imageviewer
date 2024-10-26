bmx_module {
    sub show_image(uword filenameptr, bool set_gfx_screenmode) -> bool {
        if bmx.open(diskio.drivenumber, filenameptr) {
            if set_gfx_screenmode
                gfx2.screen_mode(1)
            if bmx.width<=gfx2.width {
                ; adjust the actual color depth for the bitmap: (screen mode 1 assumes 8bpp)
                cx16.VERA_L1_CONFIG = cx16.VERA_L1_CONFIG & %11111100 | bmx.vera_colordepth
                if bmx.width==gfx2.width {
                    ; can use the fast, full-screen load routine
                    if bmx.continue_load(0, 0) {
                        if bmx.height<gfx2.height {
                            ; fill the remaining bottom part of the screen
                            gfx2.fillrect(0, bmx.height, gfx2.width, gfx2.height-bmx.height, bmx.border)
                        }
                        return true
                    } else
                        main.load_error(bmx.error_message, filenameptr)
                } else {
                    ; clear the screen with the border color
                    gfx2.clear_screen(bmx.border)
                    ; need to use the slower load routine that does padding
                    ; center the image on the screen nicely
                    uword offset = (gfx2.width-bmx.width)/2 + (gfx2.height-bmx.height)/2*gfx2.width
                    when(bmx.bitsperpixel) {
                        1 -> offset /= 8
                        2 -> offset /= 4
                        4 -> offset /= 2
                        else -> {}
                    }
                    if bmx.continue_load_stamp(0, offset, gfx2.width)
                        return true
                    else
                        main.load_error(bmx.error_message, filenameptr)
                }
            } else
                main.load_error("image too large", filenameptr)
        } else
            main.load_error(bmx.error_message, filenameptr)
        return false
    }
}