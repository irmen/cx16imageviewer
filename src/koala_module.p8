%import gfx2
%import diskio
%import palette

koala_module {
    ; c64 koala file structure: 8000 bytes bitmap data, 1000 bytes color data, 1000 bytes bg color data, 1 byte screen background color.
    ; c64 koala files are about 10Kb each and fit easily in a contiguous main memory block.
    const uword KOALA_FILESIZE = 8000+1000+1000+1+2
    uword load_location = memory("koala_file_buffer", KOALA_FILESIZE, 0)

    sub show_image(uword filenameptr) -> bool {
        if diskio.load_raw(filenameptr, load_location) - load_location == KOALA_FILESIZE {
            ; set a better C64 color palette, the X16's default is too saturated
            palette.set_c64pepto()
            convert_koalapic()
            return true
        }
        return false
    }

    sub convert_koalapic() {
        cx16.r14 = load_location + 2 + 8000     ; colors_data_location
        cx16.r15 = cx16.r14 + 1000              ; bg_colors_data_location
        cx16.r13L = @(load_location + 2 + 8000 + 1000 + 1000) & 15     ; background_color
        uword @zp bitmap_ptr = load_location+2

        gfx2.clear_screen(0)
        uword offsety = (gfx2.height - 200) / 2

        ubyte cy
        for cy in 0 to 24*8 step 8 {
            uword posy = cy + offsety
            ubyte @zp cx
            for cx in 0 to 39 {
                cx16.r5 = cx as uword * 8   ; xpos
                ubyte @zp d
                for d in 0 to 7 {
                    gfx2.position(cx16.r5, posy + d)
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
            return

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
                    ; we could also have used 2x horizontal scaling mode in the VERA, but I didn't want to mess with the screen mode too much. And its only a single STA.
                    sta  cx16.VERA_DATA0
                    sta  cx16.VERA_DATA0
                    rts
                }}
            }
        }
    }
}