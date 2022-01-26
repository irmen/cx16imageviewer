%import textio
%import diskio

fileloader {

    uword @shared @requirezp data_ptr

    sub load(str filename, uword address) -> uword {
        if not address {
            address = $a000
            cx16.rambank(1)
        }
        data_ptr = address
        txt.print("loading ")
        txt.print(filename)
        ;c64.SETMSG(%10000000)       ; enable kernal status messages for load
        uword end = diskio.load_raw(8, filename, address)
        ;c64.SETMSG(0)
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
        ; we should probably return only bytes that are actually available, but that slows down the routine
        ; it doesn't hurt to just fill the full buffer requested.
        return count
    }

    asmsub nextbyte() -> ubyte @A {
        %asm {{
            lda  (data_ptr)
            pha
            inc  data_ptr
            bne  +
            inc  data_ptr+1
+           lda  data_ptr+1
            cmp  #$c0
            bne  +
            stz  data_ptr
            lda  #$a0
            sta  data_ptr+1
            inc  $00            ; next ram bank
+           pla
            rts
        }}
    }
}
