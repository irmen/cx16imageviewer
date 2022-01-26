%import gfx2
%import fileloader
%import palette

koala_module {
    ; c64 koala files are about 10Kb each and fit easily in a contiguous main memory block.
    uword load_location = memory("koala_file_buffer", 8000+1000+1000+1+2, 0)
    str load_error_details = "file load"

    sub show_image(uword filenameptr) -> ubyte {
        if fileloader.load(filenameptr, load_location) - load_location == 10003 {
            ; set a better C64 color palette, the X16's default is too saturated
            palette.set_c64pepto()
            convert_koalapic()
            return true
        }
        return false
    }

    sub convert_koalapic() {
        cx16.r14 = load_location + 2 + 8000     ; colors_data_location
        cx16.r15 = cx16.r14 + 1000          ; bg_colors_data_location
        cx16.r13L = @(load_location + 2 + 8000 + 1000 + 1000) & 15     ; background_color
        uword bitmap_ptr = load_location+2

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
                    plot_4x2_pixels()
                }
                cx16.r14 ++
                cx16.r15 ++
            }
        }

        sub plot_4x2_pixels() {
            cx16.r0L = @(bitmap_ptr)
            pixel()
            cx16.r0L <<= 2
            pixel()
            cx16.r0L <<= 2
            pixel()
            cx16.r0L <<= 2
            pixel()
            bitmap_ptr++

            asmsub pixel() {
                %asm {{
                    lda  cx16.r0L
                    and  #%11000000
                    beq  _bgcolor
                    cmp  #%01000000
                    beq  _col1
                    cmp  #%10000000
                    beq  _col2
                    ; col3
                    lda  (cx16.r15)        ; bg_colors_data_location
                    and  #15
                    bra  +
_bgcolor            lda  cx16.r13L         ; background color
                    bra  +
_col1               lda  (cx16.r14)        ; colors_data_location
                    lsr  a
                    lsr  a
                    lsr  a
                    lsr  a
                    bra  +
_col2               lda  (cx16.r14)         ; colors_data_location
                    and  #15
+                   ; now plot two pixels because C64 multicolor mode is double wide pixels
                    sta  cx16.VERA_DATA0
                    sta  cx16.VERA_DATA0
                    rts
                }}
            }
        }
    }
}
