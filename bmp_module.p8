%import gfx2
%import diskio

bmp_module {
    sub show_image(uword filenameptr) -> bool {
        bool load_ok = false
        ubyte[$36] header
        uword size
        uword @zp width
        uword height
        ubyte @zp bpp
        uword offsetx
        uword offsety
        uword palette = memory("palette", 256*4, 0)
        uword scanline_buf = memory("scanline", 320, 0)
        uword total_read = 0

        if diskio.f_open(filenameptr) {
            size = diskio.f_read(&header, $36)
            if size==$36 {
                total_read = $36
                if header[0]=='b' and header[1]=='m' {
                    diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
                    uword bm_data_offset = mkword(header[11], header[10])
                    uword header_size = mkword(header[$f], header[$e])
                    width = mkword(header[$13], header[$12])
                    height = mkword(header[$17], header[$16])
                    bpp = header[$1c]
                    uword num_colors = header[$2e]
                    if num_colors == 0
                        num_colors = $0001<<bpp
                    uword skip_hdr = header_size - 40
                    repeat skip_hdr
                        void cbm.CHRIN()
                    total_read += skip_hdr
                    size = diskio.f_read(palette, num_colors*4)
                    if size==num_colors*4 {
                        total_read += size
                        repeat bm_data_offset - total_read
                            void cbm.CHRIN()
                        gfx2.clear_screen(0)
                        custompalette.set_bgra(palette, num_colors)
                        decode_bitmap()
                        load_ok = true
                    }
                    else
                        main.load_error_details = "invalid palette size"
                }
                else
                    main.load_error_details = "not bmp"
            }
            else
                main.load_error_details = "no header"

            diskio.f_close()
        }

        return load_ok

        sub start_plot() {
            offsetx = 0
            offsety = 0
            if width < gfx2.width
                offsetx = (gfx2.width - width - 1) / 2
            if height < gfx2.height
                offsety = (gfx2.height - height - 1) / 2
            if width > gfx2.width
                width = gfx2.width
            if height > gfx2.height
                height = gfx2.height
        }

        sub decode_bitmap() {
            start_plot()
            uword bits_width = width * bpp
            ubyte pad_bytes = (((bits_width + 31) >> 5) << 2) - ((bits_width + 7) >> 3) as ubyte
            uword num_pixels

            uword y
            for y in height-1 downto 0 {
                gfx2.position(offsetx, offsety+y)
                when bpp {
                    8 -> {
                        void diskio.f_read(scanline_buf, width)
                        gfx2.next_pixels(scanline_buf, width)
                    }
                    4 -> {
                        num_pixels = (width+1)/2
                        void diskio.f_read(scanline_buf, num_pixels)
                        cx16.r6 = scanline_buf
                        repeat num_pixels {
                            cx16.r5L = @(cx16.r6)
                            cx16.r6++
                            gfx2.next_pixel(cx16.r5L>>4)
                            gfx2.next_pixel(cx16.r5L&15)
                        }
                    }
                    2 -> {
                        num_pixels = (width+3)/4
                        void diskio.f_read(scanline_buf, num_pixels)
                        cx16.r6 = scanline_buf
                        repeat num_pixels {
                            cx16.r5L = @(cx16.r6)
                            cx16.r6++
                            gfx2.next_pixel(cx16.r5L>>6)
                            gfx2.next_pixel(cx16.r5L>>4 & 3)
                            gfx2.next_pixel(cx16.r5L>>2 & 3)
                            gfx2.next_pixel(cx16.r5L & 3)
                        }
                    }
                    1 -> {
                        num_pixels = (width+7)/8
                        void diskio.f_read(scanline_buf, num_pixels)
                        cx16.r6 = scanline_buf
                        repeat num_pixels {
                            gfx2.set_8_pixels_from_bits(@(cx16.r6), 1, 0)
                            cx16.r6++
                        }
                    }
                }

                repeat pad_bytes
                    void cbm.CHRIN()
            }
        }
    }
}
