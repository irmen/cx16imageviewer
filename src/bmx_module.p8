bmx_module {
    sub show_image(uword filenameptr, bool set_gfx_screenmode) -> bool {
        if bmx.open(diskio.drivenumber, filenameptr) {
            if set_gfx_screenmode
                gfx_lores.graphics_mode()
            if bmx.width<=gfx_lores.WIDTH {
                ; adjust the actual color depth for the bitmap: (screen mode 1 assumes 8bpp)
                cx16.VERA_L1_CONFIG = cx16.VERA_L1_CONFIG & %11111100 | bmx.vera_colordepth
                if bmx.width==gfx_lores.WIDTH {
                    ; can use the fast, full-screen load routine
                    if bmx.continue_load(0, 0) {
                        if bmx.height<gfx_lores.HEIGHT {
                            ; fill the remaining bottom part of the screen
                            gfx_lores.fillrect(0, lsb(bmx.height), gfx_lores.WIDTH, lsb(gfx_lores.HEIGHT-bmx.height), bmx.border)
                        }
                        return true
                    } else
                        main.load_error(bmx.error_message, filenameptr)
                } else {
                    ; clear the screen with the border color
                    gfx_lores.clear_screen(bmx.border)
                    ; need to use the slower load routine that does padding
                    ; center the image on the screen nicely
                    uword offset = (gfx_lores.WIDTH-bmx.width)/2 + (gfx_lores.HEIGHT-bmx.height)/2*gfx_lores.WIDTH
                    when(bmx.bitsperpixel) {
                        1 -> offset /= 8
                        2 -> offset /= 4
                        4 -> offset /= 2
                        else -> {}
                    }
                    if bmx.continue_load_stamp(0, offset, gfx_lores.WIDTH)
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