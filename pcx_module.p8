%import gfx2
%import fileloader
%import palette


pcx_module {
    sub show_image(uword filenameptr) -> ubyte {
        ubyte load_ok = false

        if fileloader.load(filenameptr, 0) {
            ubyte[128] header
            uword size = fileloader.nextbytes(header, 128)
            if size==128 {
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
                                gfx2.clear_screen(0)
                                if palette_format==2
                                    custompalette.set_grayscale256()
                                else if num_colors == 16
                                    palette.set_rgb8(&header + $10, 16)
                                else if num_colors == 2
                                    palette.set_monochrome($000, $fff)
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
                                    ubyte haspalette = fileloader.nextbyte()
                                    if haspalette == 12 {
                                        ; there is 256 colors of palette data at the end
                                        uword palette_mem = memory("palette", 256*4, 0)       ; only use 768 of these, but this allows re-use of the same block that the bmp module allocates
                                        load_ok = false
                                        size = fileloader.nextbytes(palette_mem, 3*256)
                                        if size==3*256 {
                                            load_ok = true
                                            palette.set_rgb8(palette_mem, num_colors)
                                        } else
                                            fileloader.load_error_details = "invalid palette size"
                                    } else
                                        fileloader.load_error_details = "no palette data"
                                } else
                                    fileloader.load_error_details = "bitmap decode error"
                            } else
                                fileloader.load_error_details = "width not multiple of 8"
                        } else
                            fileloader.load_error_details = ">256 colors"
                    } else
                        fileloader.load_error_details = "invalid bpp"
                } else
                    fileloader.load_error_details = "no pcx"
            } else
                fileloader.load_error_details = "no header"

            fileloader.close()
        }

        return load_ok
    }
}

pcxbitmap {

    uword offsetx
    uword offsety
    uword @zp py
    uword @zp px

    sub start_plot(uword width, uword height) {
        offsetx = 0
        offsety = 0
        py = 0
        px = 0
        if width < gfx2.width
            offsetx = (gfx2.width - width) / 2
        if height < gfx2.height
            offsety = (gfx2.height - height) / 2
    }

    sub next_scanline() -> bool {
        px = 0
        py++
        return py < gfx2.height
    }

    sub do1bpp_rle(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height {
            cx16.r4 = fileloader.nextbyte()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = fileloader.nextbyte()
                repeat cx16.r4L
                    gfx2.set_8_pixels_from_bits(cx16.r5L, 1, 0)
                px += cx16.r4 * 8
            } else {
                gfx2.set_8_pixels_from_bits(cx16.r4L, 1, 0)
                px += 8
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do4bpp_rle(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height {
            cx16.r4L = fileloader.nextbyte()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = fileloader.nextbyte()
                cx16.r5H = cx16.r5L & 15
                cx16.r5L >>= 4
                repeat cx16.r4L {
                    gfx2.next_pixel(cx16.r5L)
                    gfx2.next_pixel(cx16.r5H)
                }
                px += cx16.r4L*2
            } else {
                gfx2.next_pixel(cx16.r4L >> 4)
                gfx2.next_pixel(cx16.r4L & 15)
                px += 2
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do8bpp_rle(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        while py < height {
            cx16.r4L = fileloader.nextbyte()
            if cx16.r4L>>6==3 {
                cx16.r4L &= %00111111
                cx16.r5L = fileloader.nextbyte()
                repeat cx16.r4L
                    gfx2.next_pixel(cx16.r5L)
                px += cx16.r4L
            } else {
                gfx2.next_pixel(cx16.r4L)
                px++
            }
            if px==width
                if not next_scanline()
                    return true
        }

        return true
    }

    sub do1bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        repeat height {
            repeat width/8 {
                cx16.r0L = fileloader.nextbyte()
                gfx2.set_8_pixels_from_bits(cx16.r0L, 1, 0)
            }
        }

        return true
    }

    sub do4bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        repeat height {
            repeat width/4 {
                cx16.r4L = fileloader.nextbyte()
                gfx2.next_pixel(cx16.r4L >> 4)
                gfx2.next_pixel(cx16.r4L & 15)
            }
        }

        return true
    }

    sub do8bpp(uword width, uword height) -> ubyte {
        start_plot(width, height)
        gfx2.position(offsetx, offsety)
        repeat height {
            repeat width {
                gfx2.next_pixel(fileloader.nextbyte())
            }
        }

        return true
    }
}
