%import gfx2
%import fileloader
%import palette

; NOTE: This image format is not added by default as it is a very niche format and there are no available encoders yet.

rlex_module_XXX {
    sub show_image(uword filenameptr) -> bool {
        bool load_ok = false
        uword filesize = fileloader.load(filenameptr, 0) - $a000   ; load into hiram
        filesize += 8192 * (cx16.r1L - cx16.r0L)
        if filesize {
            ; TODO : implement extended format that includes some sort of header with RLX magic number + width/height/bitdepth
            ; first 2 bytes are a dummy prg header
            void fileloader.nextbyte()
            void fileloader.nextbyte()
            filesize -= 2
            ; first 16 words are the vera color palette data
            ubyte[32] verapalette
            uword size = fileloader.nextbytes(&verapalette, 32)
            if size {
                filesize -= size
                palette.set_rgb(&verapalette, 16)
                ; for now, fixed size 320*240 pixels of RLE compressed image data follows.
                gfx2.position(0,0)
                while filesize {
                    cx16.r0L = fileloader.nextbyte()
                    filesize--
                    ubyte @zp color = cx16.r0L & %00001111
                    uword @zp span = cx16.r0L >> 4
                    if span == 15 {
                        span += fileloader.nextbyte()
                        filesize--
                    }
                    repeat span+1   ; repeats is actually off by one
                        gfx2.next_pixel(color)
                }
                load_ok = true
            } else
                fileloader.load_error_details = "no palette"

            fileloader.close()
        }

        return load_ok
    }
}
