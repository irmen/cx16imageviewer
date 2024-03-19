%import gfx2
%import diskio
%import palette

koala_module {
    ; c64 koala file structure: 8000 bytes bitmap data, 1000 bytes color data, 1000 bytes bg color data, 1 byte screen background color.
    ; c64 koala files are about 10Kb each and fit easily in a contiguous main memory block.
    uword color_data = memory("palette", 256*4, 0)      ; reuse
    uword bg_color_data = memory("koala_bg_colors", 1000, 0)
    uword scanline_buf = memory("scanline", 320, 0)     ; reuse
    ubyte screen_color

    sub show_image(uword filenameptr, bool set_gfx_screenmode) -> bool {
        if diskio.f_open(filenameptr) {
            diskio.f_seek(0, 8002)      ; initially skip the header and bitmap data
            if diskio.f_read(color_data, 1000)==1000 {
                if diskio.f_read(bg_color_data, 1000)==1000 {
                    if diskio.f_read(&screen_color, 1)==1 {
                        screen_color &= 15
                        diskio.f_seek(0, 2)      ; seek back to the bitmap data
                        if set_gfx_screenmode
                            gfx2.screen_mode(1)    ; 320*240, 256c
                        else
                            gfx2.clear_screen(0)
                        palette.set_c64pepto()   ; set a better C64 color palette, the X16's default is too saturated
                        bool success = convert_koalapic()
                        diskio.f_close()
                        return success
                    }
                }
            }
            diskio.f_close()
        }
        return false
    }

    sub convert_koalapic() -> bool {
        cx16.r14 = color_data
        cx16.r15 = bg_color_data
        uword offsety = (gfx2.height - 200) / 2
        ubyte cy
        for cy in 0 to 24*8 step 8 {
            uword posy = cy + offsety
            ; read and decode next "scanline" (1 character in height=8 pixels)
            uword @zp bitmap_ptr = scanline_buf
            if diskio.f_read(bitmap_ptr, 320)!=320
                return false
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
        return true

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
_bgcolor            lda  p8v_screen_color  ; screen background color
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
