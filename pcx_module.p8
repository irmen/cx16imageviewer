%import gfx2
%import diskio
%import palette


pcx_module {
    uword load_error_details

    sub show_image(uword filenameptr) -> ubyte {
        ubyte load_ok = false
        load_error_details = "file"

        if diskio.f_open(8, filenameptr) {
            ubyte[128] header
            uword size = diskio.f_read(header, 128)
            if size==128 {
                if header[0] == $0a and header[2] == 1 {
                    ubyte bits_per_pixel = header[3]
                    if bits_per_pixel in [1,4,8] {
                        uword width = mkword(header[$09], header[$08]) - mkword(header[$05], header[$04]) + 1
                        uword height = mkword(header[$0b], header[$0a]) - mkword(header[$07], header[$06]) + 1
                        ubyte number_of_planes = header[$41]
                        uword palette_format = mkword(header[$45], header[$44])
                        uword num_colors = 2**bits_per_pixel
                        if number_of_planes == 1 {
                            if (width & 7) == 0 {
                                gfx2.clear_screen()
                                if palette_format==2
                                    custompalette.set_grayscale256()
                                else if num_colors == 16
                                    palette.set_rgb8(&header + $10, 16)
                                else if num_colors == 2
                                    palette.set_monochrome($000, $fff)
                                when bits_per_pixel {
                                    8 -> load_ok = bitmap.do8bpp(width, height)
                                    4 -> load_ok = bitmap.do4bpp(width, height)
                                    1 -> load_ok = bitmap.do1bpp(width, height)
                                }
                                if load_ok {
                                    load_ok = c64.CHRIN()
                                    if load_ok == 12 {
                                        ; there is 256 colors of palette data at the end
                                        uword palette_mem = sys.progend()
                                        load_ok = false
                                        size = diskio.f_read(palette_mem, 3*256)
                                        if size==3*256 {
                                            load_ok = true
                                            palette.set_rgb8(palette_mem, num_colors)
                                        } else
                                            load_error_details = "invalid palette size"
                                    } else
                                        load_error_details = "no palette data"
                                } else
                                    load_error_details = "bitmap decode error"
                            } else
                                load_error_details = "width not multiple of 8"
                        } else
                            load_error_details = ">256 colors"
                    } else
                        load_error_details = "invalid bpp"
                } else
                    load_error_details = "no pcx"
            } else
                load_error_details = "no header"

            diskio.f_close()
        }

        return load_ok
    }
}

bitmap {

    uword offsetx
    uword offsety
    uword py
    uword px
    ubyte y_ok
    ubyte status

    sub start_plot(uword width, uword height) {
        offsetx = 0
        offsety = 0
        y_ok = true
        py = 0
        px = 0
        if width < gfx2.width
            offsetx = (gfx2.width - width) / 2
        if height < gfx2.height
            offsety = (gfx2.height - height) / 2
        status = (not c64.READST()) or (c64.READST()&64==64)
    }

    sub next_scanline() {
        px = 0
        py++
        y_ok = py < gfx2.height
        gfx2.position(offsetx, offsety+py)
        status = (not c64.READST()) or (c64.READST()&64==64)
    }

    sub do1bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height and status {
            cx16.r4 = c64.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = c64.CHRIN()
                if y_ok
                    repeat cx16.r4L {
                        gfx2.set_8_pixels_from_bits(cx16.r5L, 1, 0)
                    }
                px += cx16.r4 * 8
            } else {
                if y_ok
                    gfx2.set_8_pixels_from_bits(cx16.r4L, 1, 0)
                px += 8
            }
            if px==width
                next_scanline()
        }

        return status
    }

    sub do4bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height and status {
            cx16.r4L = c64.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = c64.CHRIN()
                if y_ok
                    repeat cx16.r4L {
                        gfx2.next_pixel(cx16.r5L >> 4)
                        gfx2.next_pixel(cx16.r5L & 15)
                    }
                px += cx16.r4L*2
            } else {
                if y_ok {
                    gfx2.next_pixel(cx16.r4L >> 4)
                    gfx2.next_pixel(cx16.r4L & 15)
                }
                px += 2
            }
            if px==width
                next_scanline()
        }

        return status
    }

    sub do8bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height and status {
            cx16.r4L = c64.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = c64.CHRIN()
                if y_ok
                    repeat cx16.r4L
                        gfx2.next_pixel(cx16.r5L)
                px += cx16.r4L
            } else {
                if y_ok
                    gfx2.next_pixel(cx16.r4L)
                px++
            }
            if px==width
                next_scanline()
        }

        return status
    }
}
