%import gfx2
%import diskio
%import palette

koala_module {
    const uword load_location = $6000
    uword load_error_details = "file load"

    sub show_image(uword filenameptr) -> ubyte {
        if diskio.load(8, filenameptr, load_location)==10001 {
            ; set a better C64 color palette, the Cx16's default is too saturated
            palette.set_c64pepto()
            convert_koalapic()
            return true
        }
        return false
    }

    sub convert_koalapic() {
        ubyte cy
        ubyte @zp cx
        uword @zp cy_times_forty = 0
        ubyte @zp d
        uword bitmap_ptr = load_location

        ; theoretically you could put the 8-pixel array in zeropage to squeeze out another tiny bit of performance
        ubyte[8] pixels

        gfx2.clear_screen()
        uword offsety = (gfx2.height - 200) / 2

        for cy in 0 to 24*8 step 8 {
            uword posy = cy + offsety
            for cx in 0 to 39 {
                uword posx = cx as uword * 8
                for d in 0 to 7 {
                    gfx2.position(posx, posy + d)
                    get_8_pixels()
                    gfx2.next_pixels(pixels, 8)
                }
            }
            cy_times_forty += 40
        }

        sub get_8_pixels() {
            ubyte  bm = @(bitmap_ptr)
            ubyte  @zp  m = pixcolor()
            pixels[7] = m
            pixels[6] = m
            bm >>= 2
            m = pixcolor()
            pixels[5] = m
            pixels[4] = m
            bm >>= 2
            m = pixcolor()
            pixels[3] = m
            pixels[2] = m
            bm >>= 2
            m = pixcolor()
            pixels[1] = m
            pixels[0] = m
            bitmap_ptr++

            sub pixcolor() -> ubyte {
                when bm & 3 {
                    0 -> return @(load_location + 8000 + 1000 + 1000) & 15
                    1 -> return @(load_location + 8000 + cy_times_forty + cx) >>4
                    2 -> return @(load_location + 8000 + cy_times_forty + cx) & 15
                    else -> return @(load_location + 8000 + 1000 + cy_times_forty + cx) & 15
                }
            }
        }
    }
}
