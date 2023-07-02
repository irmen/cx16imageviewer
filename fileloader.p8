%import diskio

fileloader {

    uword @shared @requirezp data_ptr
    uword load_error_details                ; pointer to string containing error message

    sub load(str filename, uword address) -> uword {
        ; returns end address, and also start ram bank in cx16.r0L and end ram bank in cx16.r1L.
        if not address {
            address = $a000
            cx16.rambank(1)
        }
        ubyte startbank = cx16.getrambank()
        data_ptr = address
        ;c64.SETMSG(%10000000)       ; enable kernal status messages for load
        uword end = diskio.load_raw(filename, address)
        ;c64.SETMSG(0)
        if end==0
            return 0
        @(end) = 0
        cx16.r0L = startbank
        cx16.r1L = cx16.getrambank()
        cx16.rambank(1)
        return end
    }

    sub close() {
        ; do nothing as everything is handled from memory
        ; but could be used to close a file stream
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

    asmsub nextbyte() clobbers(A) -> ubyte @Y {
        %asm {{
            lda  (p8_data_ptr)
            tay
            inc  p8_data_ptr
            bne  +
            inc  p8_data_ptr+1
+           lda  p8_data_ptr+1
            cmp  #$c0
            bne  +
            stz  p8_data_ptr
            lda  #$a0
            sta  p8_data_ptr+1
            inc  $00            ; next ram bank
+           rts
        }}
    }
}
