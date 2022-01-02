%import textio
%import diskio

fileloader {

    uword @shared data_ptr

    sub load(str filename, uword address) -> uword {
        if not address {
            address = $a000
            cx16.rambank(1)
        }
        data_ptr = address
        txt.print("loading ")
        txt.print(filename)
        txt.print(" from ")
        txt.print_uwhex(address, true)
        uword end = diskio.load_raw(8, filename, address)
        txt.print(" to ")
        txt.print_uwhex(end, true)
        txt.nl()
        @(end) = 0
        cx16.rambank(1)
        return end
    }

    sub nextbytes(uword buffer, uword count) -> uword {
        repeat count {
            @(buffer) = nextbyte()
            buffer++
        }
        ; TODO return only bytes that are actually available
        return count
    }

    asmsub nextbyte() -> ubyte @A {
        %asm {{
            lda  data_ptr
            ldy  data_ptr+1
            sta  P8ZP_SCRATCH_W1
            sty  P8ZP_SCRATCH_W1+1
            lda  (P8ZP_SCRATCH_W1)
            pha
            inc  data_ptr
            bne  +
            inc  data_ptr+1
+           lda  data_ptr+1
            cmp  #$c0
            bne  +
            lda  #$a0
            stz  data_ptr
            sta  data_ptr+1
            inc  $00            ; next ram bank
+           pla
            rts
        }}
    }

;    sub nextbyte22() -> ubyte {
;        cx16.r2L = @(data_ptr)
;        data_ptr++
;        if(msb(data_ptr)==$c0) {
;            data_ptr=$a000
;            cx16.rambank(cx16.getrambank()+1)
;        }
;        return cx16.r2L
;    }
}
