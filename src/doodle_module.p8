%import gfx2
%import diskio
%import palette

doodle_module {
    uword color_data = memory("palette", 256*4, 0)      ; reuse
    uword scanline_buf = memory("scanline", 320, 0)     ; reuse

    sub show_image(uword filenameptr, bool set_gfx_screenmode) -> bool {
        ; first 2 bytes header
        ; then 1000 bytes for the screen ram (=colors)
        ; then 24 bytes padding
        ; then 8000 bytes bitmap data
        if diskio.f_open(filenameptr) and diskio.f_read(color_data, 1002)==1002 {
            if diskio.f_read(scanline_buf, 24)==24 {
                ; set a better C64 color palette, the X16's default is too saturated
                palette.set_c64pepto()
                if set_gfx_screenmode
                    gfx2.screen_mode(1)    ; 320*240, 256c
                else
                    gfx2.clear_screen(0)
                bool success = convert_doodlepic()
                diskio.f_close()
                return success
            }
        }
        diskio.f_close()
        return false
    }

    sub convert_doodlepic() -> bool {
        uword @zp color_ptr = color_data+2   ; skip the prg load header
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
                    plot_8_pixels()
                    bitmap_ptr++
                }
                color_ptr++
            }
        }
        return true

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
