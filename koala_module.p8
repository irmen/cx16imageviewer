%import gfx2
%import diskio
%import palette

koala_module {
    const uword load_location = $6000
    uword load_error_details = "file load"

    sub show_image(uword filenameptr) -> ubyte {
        if diskio.load(8, filenameptr, load_location)==10001 {
            ; set a better C64 color palette, the X16's default is too saturated
            palette.set_c64pepto()
            convert_koalapic()
            return true
        }
        return false
    }

    sub convert_koalapic() {
        cx16.r14 = load_location + 8000     ; colors_data_location
        cx16.r15 = cx16.r14 + 1000          ; bg_colors_data_location
        cx16.r13L = @(load_location + 8000 + 1000 + 1000) & 15     ; background_color
        uword bitmap_ptr = load_location

        gfx2.clear_screen()
        uword offsety = (gfx2.height - 200) / 2

        ubyte cy
        for cy in 0 to 24*8 step 8 {
            uword posy = cy + offsety
            ubyte @zp cx
            for cx in 0 to 39 {
                uword posx = cx as uword * 8
                ubyte @zp d
                for d in 0 to 7 {
                    gfx2.position(posx, posy + d)
                    get_8_pixels()
                    gfx2.next_pixels(&cx16.r8, 8)
                }
                cx16.r14 ++
                cx16.r15 ++
            }
        }

        sub get_8_pixels() {
            ubyte  bm = @(bitmap_ptr)
            ubyte  @zp  m = pixcolor()
            cx16.r11H = m
            cx16.r11L = m
            bm >>= 2
            m = pixcolor()
            cx16.r10H = m
            cx16.r10L = m
            bm >>= 2
            m = pixcolor()
            cx16.r9H = m
            cx16.r9L = m
            bm >>= 2
            m = pixcolor()
            cx16.r8H = m
            cx16.r8L = m
            bitmap_ptr++

            sub pixcolor() -> ubyte {
                ubyte @zp coloridx
                when bm & 3 {
                    0 -> coloridx = cx16.r13L            ; background color
                    1 -> coloridx = @(cx16.r14) >>4      ; colors_data_location
                    2 -> coloridx = @(cx16.r14) & 15     ; colors_data_location
                    else -> coloridx = @(cx16.r15) & 15  ; bg_colors_data_location
                }
                return coloridx
            }
        }
    }
}
