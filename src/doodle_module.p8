%import gfx2
%import diskio
%import palette

doodle_module {
    sub show_image(uword filenameptr) -> bool {
        if diskio.load_raw(filenameptr, koala_module.load_location) - koala_module.load_location == 9218 {
            ; set a better C64 color palette, the X16's default is too saturated
            palette.set_c64pepto()
            convert_doodlepic()
            return true
        }
        return false
    }

    sub convert_doodlepic() {
        ; first 2 bytes header
        ; then 1000 bytes for the screen ram (=colors)
        ; then 24 bytes padding
        ; then 8000 bytes bitmap data
        uword @zp bitmap_ptr = koala_module.load_location+2+1024
        uword @zp color_ptr = koala_module.load_location+2

        gfx2.clear_screen(0)
        uword offsety = (gfx2.height - 200) / 2

        ubyte cy
        for cy in 0 to 24*8 step 8 {
            uword posy = cy + offsety
            ubyte cx
            for cx in 0 to 39 {
                cx16.r5 = cx as uword * 8   ; xpos
                ubyte @zp d
                for d in 0 to 7 {
                    gfx2.position(cx16.r5, posy + d)
                    plot_8_pixels()
                    bitmap_ptr++
                }
                color_ptr++
            }
        }

        sub plot_8_pixels() {
;            cx16.r0L = @(bitmap_ptr)
;            cx16.r1L = @(color_ptr) & 15
;            cx16.r2L = @(color_ptr) >> 4
;            repeat 8 {
;                rol(cx16.r0L)
;                if_cc
;                    cx16.VERA_DATA0 = cx16.r1L  ; background
;                else
;                    cx16.VERA_DATA0 = cx16.r2L  ; foreground
;            }
            %asm {{
                lda  (p8v_bitmap_ptr)
                sta  P8ZP_SCRATCH_B1
                lda  (p8v_color_ptr)
                and  #15
                tax
                lda  (p8v_color_ptr)
                lsr  a
                lsr  a
                lsr  a
                lsr  a
                ldy  #8
_loop           rol  P8ZP_SCRATCH_B1
                bcs  +
                stx  cx16.VERA_DATA0
                bcc  ++
+               sta  cx16.VERA_DATA0
+               dey
                bne  _loop
                rts
            }}
        }
    }
}
