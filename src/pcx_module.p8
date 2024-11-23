%import gfx_lores
%import palette


pcx_module {
    sub show_image(uword filenameptr, bool set_gfx_screenmode) -> bool {
        bool load_ok = false
        ubyte[128] header

        if diskio.f_open(filenameptr) and diskio.f_read(header, 128)==128 {
            if header[0] == $0a and header[2] <= 1 {
                ubyte bits_per_pixel = header[3]
                if bits_per_pixel in [1,4,8] {
                    uword width = mkword(header[$09], header[$08]) - mkword(header[$05], header[$04]) + 1
                    uword height = mkword(header[$0b], header[$0a]) - mkword(header[$07], header[$06]) + 1
                    ubyte number_of_planes = header[$41]
                    uword palette_format = mkword(header[$45], header[$44])
                    uword num_colors = $0001<<bits_per_pixel
                    if number_of_planes == 1 {
                        if (width & 7) == 0 {
                            if set_gfx_screenmode
                                gfx_lores.graphics_mode()    ; 320*240, 256c
                            else
                                gfx_lores.clear_screen(0)
                            if palette_format==2
                                custompalette.set_grayscale256()
                            else if num_colors == 16
                                palette.set_rgb8(&header + $10, 16, 0)
                            else if num_colors == 2 {
                                palette.set_all_white()
                                palette.set_color(0, $000)
                            }
                            if header[2]==0 {
                                ; uncompressed
                                when bits_per_pixel {
                                    8 -> load_ok = pcxbitmap.do8bpp(width, height)
                                    4 -> load_ok = pcxbitmap.do4bpp(width, height)
                                    1 -> load_ok = pcxbitmap.do1bpp(width, height)
                                }
                            } else {
                                ; RLE-compressed
                                when bits_per_pixel {
                                    8 -> load_ok = pcxbitmap.do8bpp_rle(width, height)
                                    4 -> load_ok = pcxbitmap.do4bpp_rle(width, height)
                                    1 -> load_ok = pcxbitmap.do1bpp_rle(width, height)
                                }
                            }
                            if load_ok {
                                diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
                                ubyte haspalette = cbm.CHRIN()
                                if haspalette == 12 {
                                    ; there is 256 colors of palette data at the end
                                    uword palette_mem = memory("palette", 256*4, 0)       ; only use 768 of these, but this allows re-use of the same block that the bmp module allocates
                                    load_ok = false
                                    if diskio.f_read(palette_mem, 3*256)==3*256 {
                                        load_ok = true
                                        palette.set_rgb8(palette_mem, num_colors, 0)
                                    } else
                                        loader.error_details = "invalid palette size"
                                } else
                                    loader.error_details = "no palette data"
                            } else
                                loader.error_details = "bitmap decode error"
                        } else
                            loader.error_details = "width not multiple of 8"
                    } else
                        loader.error_details = ">256 colors"
                } else
                    loader.error_details = "invalid bpp"
            } else
                loader.error_details = "no pcx"
        } else
            loader.error_details = "no header"
        diskio.f_close()
        return load_ok
    }
}

pcxbitmap {

    uword offsetx
    ubyte offsety
    uword @zp py
    uword @zp px
    uword scanline_buf = memory("scanline", 320, 0)

    sub start_plot(uword width, uword height) {
        offsetx = 0
        offsety = 0
        py = 0
        px = 0
        if width < gfx_lores.WIDTH
            offsetx = (gfx_lores.WIDTH - width) / 2
        if height < gfx_lores.HEIGHT
            offsety = (gfx_lores.HEIGHT - lsb(height)) / 2
    }

    sub next_scanline() -> bool {
        px = 0
        py++
        return py < gfx_lores.HEIGHT
    }

    sub do1bpp_rle(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
        while py < height {
            cx16.r4 = cbm.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = cbm.CHRIN()
                repeat cx16.r4L
                    gfx_lores.set_8_pixels_from_bits(cx16.r5L, 1, 0)
                px += cx16.r4 * 8
            } else {
                gfx_lores.set_8_pixels_from_bits(cx16.r4L, 1, 0)
                px += 8
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do4bpp_rle(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
        while py < height {
            cx16.r4L = cbm.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = cbm.CHRIN()
                cx16.r5H = cx16.r5L & 15
                cx16.r5L >>= 4
                repeat cx16.r4L {
                    gfx_lores.next_pixel(cx16.r5L)
                    gfx_lores.next_pixel(cx16.r5H)
                }
                px += cx16.r4L*2
            } else {
                gfx_lores.next_pixel(cx16.r4L >> 4)
                gfx_lores.next_pixel(cx16.r4L & 15)
                px += 2
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do8bpp_rle(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
        while py < height {
            cx16.r4L = cbm.CHRIN()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = cbm.CHRIN()
                repeat cx16.r4L
                    gfx_lores.next_pixel(cx16.r5L)
                px += cx16.r4L
            } else {
                gfx_lores.next_pixel(cx16.r4L)
                px++
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do1bpp(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
        repeat height {
            repeat width/8 {
                cx16.r0L = cbm.CHRIN()
                gfx_lores.set_8_pixels_from_bits(cx16.r0L, 1, 0)
            }
        }

        return true
    }

    sub do4bpp(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        diskio.reset_read_channel()     ; so we can use cbm.CHRIN()
        repeat height {
            repeat width/4 {
                cx16.r4L = cbm.CHRIN()
                gfx_lores.next_pixel(cx16.r4L >> 4)
                gfx_lores.next_pixel(cx16.r4L & 15)
            }
        }

        return true
    }

    sub do8bpp(uword width, uword height) -> bool {
        start_plot(width, height)
        gfx_lores.position(offsetx, offsety)
        repeat height {
            void diskio.f_read(scanline_buf, width)
            gfx_lores.next_pixels(scanline_buf, width)
        }

        return true
    }
}
