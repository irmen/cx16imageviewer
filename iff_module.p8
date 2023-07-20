%import gfx2
%import palette
%import fileloader

iff_module {
    uword cmap
    uword num_colors
    uword[24] cycle_rates
    uword[24] cycle_rate_ticks
    ubyte[24] cycle_reverseflags
    ubyte[24] cycle_lows
    ubyte[24] cycle_highs
    ubyte num_cycles

    sub show_image(uword filenameptr) -> ubyte {
        ubyte load_ok = false
        uword size
        ubyte[32] buffer
        uword camg = 0
        ubyte format            ; 'i' (ILBM) or 'p' (PBM)
        str chunk_id = "????"
        uword chunk_size_hi
        uword chunk_size_lo
        uword scanline_data_ptr = sys.progend()

        uword width
        uword height
        ubyte num_planes
        ubyte compression
        ubyte have_cmap = false
        ubyte cycle_crng = false
        ubyte cycle_ccrt = false
        num_cycles = 0
        cmap = memory("palette", 256*4, 0)       ; only use 768 of these, but this allows re-use of the same block that the bmp module allocates

        if fileloader.load(filenameptr, 0) {
            size = fileloader.nextbytes(buffer, 12)
            if size==12 {
                if buffer[0]=='f' and buffer[1]=='o' and buffer[2]=='r' and buffer[3]=='m' {
                    if buffer[9]=='l' and buffer[10]=='b' and buffer[11]=='m'
                        format = buffer[8]
                    else if buffer[9]=='b' and buffer[10]=='m' and buffer[11]==' '
                        format = buffer[8]

                    if not format {
                        fileloader.load_error_details = "not ilbm or pbm"
                        return false
                    }

                    while read_chunk_header() {
                        if chunk_id == "bmhd" {
                            void fileloader.nextbytes(buffer, chunk_size_lo)
                            read_aligned()
                            width = mkword(buffer[0], buffer[1])
                            height = mkword(buffer[2], buffer[3])
                            num_planes = buffer[8]
                            num_colors = $0001 << num_planes
                            compression = buffer[10]
                        }
                        else if chunk_id == "camg" {
                            void fileloader.nextbytes(buffer, chunk_size_lo)
                            read_aligned()
                            camg = mkword(buffer[2], buffer[3])
                            if camg & $0800 {
                                fileloader.load_error_details = "ham mode not supported"
                                break
                            }
                        }
                        else if chunk_id == "cmap" {
                            have_cmap = true
                            void fileloader.nextbytes(cmap, chunk_size_lo)
                            read_aligned()
                        }
                        else if chunk_id == "crng" {
                            ; DeluxePaint color cycle range
                            if not cycle_ccrt {
                                cycle_crng = true
                                void fileloader.nextbytes(buffer, chunk_size_lo)
                                read_aligned()
                                ubyte flags = buffer[5]
                                if not flags
                                    flags = buffer[4]   ; DOS deluxepaint writes them sometimes in the other byte?
                                ; bit 0 should be "active" flag but many images don't have this set even though the range is active.
                                ; so we check the cycling speed instead to see if it is >0.
                                cycle_rates[num_cycles] = mkword(buffer[2], buffer[3])
                                if cycle_rates[num_cycles] {
                                    cycle_rate_ticks[num_cycles] = 1
                                    cycle_lows[num_cycles] = buffer[6]
                                    cycle_highs[num_cycles] = buffer[7]
                                    cycle_reverseflags[num_cycles] = flags & 2 != 0
                                    num_cycles++
                                }
                            } else
                                skip_chunk()
                        }
                        else if chunk_id == "ccrt" {
                            ; Graphicraft color cycle range
                            if not cycle_crng {
                                cycle_ccrt = true
                                void fileloader.nextbytes(buffer, chunk_size_lo)
                                read_aligned()
                                ubyte direction = buffer[1]
                                if direction {
                                    ; delay_sec = buffer[4] * 256 * 256 * 256 + buffer[5] * 256 * 256 + buffer[6] * 256 + buffer[7]
                                    ; delay_micro = buffer[8] * 256 * 256 * 256 + buffer[9] * 256 * 256 + buffer[10] * 256 + buffer[11]
                                    ; We're ignoring the delay_sec field for now. Not many images will have this slow of a color cycle anyway (>1 sec per cycle)
                                    ; rate = int(16384 // (60*delay_micro/1e6))
                                    ; float rate = (65*16384.0) / (mkword(buffer[9], buffer[10]) as float)  ; fairly good approximation using float arithmetic
                                    cycle_rates[num_cycles] = 33280 / (mkword(buffer[9], buffer[10]) >> 5)      ; reasonable approximation using only 16-bit integer arithmetic
                                    cycle_rate_ticks[num_cycles] = 1
                                    cycle_lows[num_cycles] = buffer[2]
                                    cycle_highs[num_cycles] = buffer[3]
                                    cycle_reverseflags[num_cycles] = direction == 1    ; weird, the spec say that -1 = reversed but several example images that I have downloaded are the opposite
                                    num_cycles++
                                }
                            } else
                                skip_chunk()
                        }
                        else if chunk_id == "body" {
                            gfx2.clear_screen()
                            if camg & $0004
                                height /= 2     ; interlaced: just skip every odd scanline later
                            if camg & $0080 and have_cmap
                                make_ehb_palette()
                            if format=='i' {
                                palette.set_rgb8(cmap, num_colors)
                                if compression
                                    decode_rle()
                                else
                                    decode_raw()
                                load_ok = true
                            }
                            else if format=='p' {
                                palette.set_rgb8(cmap, num_colors)
                                if compression
                                    decode_pbm_byterun1()
                                else
                                    decode_pbm_raw()
                                load_ok = true
                            }
                            break   ; done after body
                        }
                        else {
                            skip_chunk()
                        }
                    }
                } else
                    fileloader.load_error_details = "not iff ilbm"
            }
            else
                fileloader.load_error_details = "no header"

            fileloader.close()
        }

        return load_ok

        sub read_chunk_header() -> ubyte {
            size = fileloader.nextbytes(buffer, 8)
            if size==8 {
                chunk_id[0] = buffer[0]
                chunk_id[1] = buffer[1]
                chunk_id[2] = buffer[2]
                chunk_id[3] = buffer[3]
                chunk_size_hi = mkword(buffer[4], buffer[5])
                chunk_size_lo = mkword(buffer[6], buffer[7])
                return true
            }
            return false
        }

        sub skip_chunk() {
            if chunk_size_hi > 255 {
                txt.print("outrageous chunk size. corrupt?")
                sys.exit(1)
            }

            repeat lsb(chunk_size_hi) {
                repeat 256 {
                    void fileloader.nextbytes(scanline_data_ptr, 256)
                }
            }
            repeat chunk_size_lo
                void fileloader.nextbyte()
            read_aligned()
        }

        sub read_aligned() {
            ; IFF spec says that:
            ; "All data objects larger than a byte are aligned on even byte addresses
            ;  relative to the start of the file. This may require padding.""
            ; "This means that every odd-length "chunk" (see below) must be padded
            ;  so that the next one will fall on an even boundary."
            ; Check that we read such a padding byte if it occurs
            if chunk_size_lo & 1
                void fileloader.nextbyte()
        }

        sub make_ehb_palette() {
            ; generate 32 additional Extra-Halfbrite colors in the cmap
            uword ehb_cmap = cmap+32*3
            ubyte i
            for i in 0 to 32*3-1 {
                @(ehb_cmap+i) = @(cmap+i)>>1
            }
        }

        ubyte bitplane_stride
        uword interleave_stride
        uword offsetx
        uword offsety
        uword @zp y

        sub start_plot() {
            bitplane_stride = lsb(width>>3)
            interleave_stride = (bitplane_stride as uword) * num_planes
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

        sub decode_raw() {
            start_plot()
            ubyte interlaced = (camg & $0004) != 0
            for y in 0 to height-1 {
                void fileloader.nextbytes(scanline_data_ptr, interleave_stride)
                if interlaced
                    void fileloader.nextbytes(scanline_data_ptr, interleave_stride)
                gfx2.position(offsetx, offsety+y)
                planar_to_chunky_scanline()
            }
        }

        sub decode_rle() {
            start_plot()
            ubyte interlaced = (camg & $0004) != 0
            for y in 0 to height-1 {
                decode_rle_scanline()
                if interlaced
                    decode_rle_scanline()
                gfx2.position(offsetx, offsety+y)
                planar_to_chunky_scanline()
            }
        }

        sub decode_rle_scanline() {
            uword @zp x = interleave_stride
            uword plane_ptr = scanline_data_ptr

            while x {
                cx16.r4L = fileloader.nextbyte()
                if cx16.r4L > 128 {
                    cx16.r5L = fileloader.nextbyte()
                    repeat 2+(cx16.r4L^255) {
                        @(plane_ptr) = cx16.r5L
                        plane_ptr++
                        x--
                    }
                } else if cx16.r4L < 128 {
                    repeat cx16.r4L+1 {
                        @(plane_ptr) = fileloader.nextbyte()
                        plane_ptr++
                        x--
                    }
                } else
                    break
            }
        }

        sub planar_to_chunky_scanline() {
            ; ubyte[8] masks = [128,64,32,16,8,4,2,1]
            uword @zp x
            for x in 0 to width-1 {
                ; ubyte mask = masks[lsb(x) & 7]
                uword @shared pixptr = x/8 + scanline_data_ptr
                cx16.r5L = 0
                %asm {{
                    bra  +
_masks  .byte 128, 64, 32, 16, 8, 4, 2, 1
+                   lda  p8_pixptr
                    sta  P8ZP_SCRATCH_W1
                    lda  p8_pixptr+1
                    sta  P8ZP_SCRATCH_W1+1
                    lda  p8_x
                    and  #7
                    tay
                    lda  _masks,y
                    sta  P8ZP_SCRATCH_B1        ; mask
                    phx
                    ldx  p8_num_planes
-                   lda  (P8ZP_SCRATCH_W1)
                    clc
                    and  P8ZP_SCRATCH_B1
                    beq  +
                    sec
+                   ror  cx16.r5L                   ; shift planar bit into chunky byte
                    lda  P8ZP_SCRATCH_W1
                    ; clc
                    adc  p8_bitplane_stride
                    sta  P8ZP_SCRATCH_W1
                    bcc  +
                    inc  P8ZP_SCRATCH_W1+1
+                   dex
                    bne  -
                    plx
                    lda  #8
                    sec
                    sbc  p8_num_planes
                    beq  +
-                   lsr  cx16.r5L
                    dec  a
                    bne  -
+
                }}

; the assembly above is the optimized version of this:
;                repeat num_planes {
;                    clear_carry()
;                    if @(pixptr) & mask
;                        set_carry()
;                    ror(cx16.r5L)           ; shift planar bit into chunky byte
;                    pixptr += bitplane_stride
;                }
;                cx16.r5L >>= 8-num_planes

                gfx2.next_pixel(cx16.r5L)
            }
        }

        sub decode_pbm_byterun1() {
            start_plot()
            gfx2.position(0, 0)
            repeat height {
                cx16.r5 = width
                while cx16.r5 {
                    cx16.r3L = fileloader.nextbyte()
                    if cx16.r3L > 128 {
                        cx16.r3H = fileloader.nextbyte()
                        cx16.r6 = 257-cx16.r3L
                        repeat cx16.r6
                            gfx2.next_pixel(cx16.r3H)
                        cx16.r5 -= cx16.r6
                    } else if cx16.r3L < 128 {
                        cx16.r3L++
                        repeat cx16.r3L
                            gfx2.next_pixel(fileloader.nextbyte())
                        cx16.r5 -= cx16.r3L
                    }
                }
            }
        }

        sub decode_pbm_raw() {
            start_plot()
            gfx2.position(0, 0)
            repeat height {
                repeat width {
                    gfx2.next_pixel(fileloader.nextbyte())
                }
            }
        }
    }

    sub cycle_colors_each_jiffy() {
        if num_cycles==0
            return

        ; TODO implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js

        ubyte changed = false
        ubyte ci
        for ci in 0 to num_cycles-1 {
            cycle_rate_ticks[ci]--
            if cycle_rate_ticks[ci]==0 {
                changed = true
                cycle_rate_ticks[ci] = 16384 / cycle_rates[ci]
                do_cycle(cycle_lows[ci], cycle_highs[ci], cycle_reverseflags[ci])
            }
        }

        if changed
            palette.set_rgb8(cmap, num_colors)     ; set the new palette

        sub do_cycle(uword low, uword high, ubyte reversed) {
            low *= 3
            high *= 3
            uword bytecount = high-low
            uword cptr
            ubyte red
            ubyte green
            ubyte blue

            if reversed {
                cptr = cmap + low
                red = @(cptr)
                green = @(cptr+1)
                blue = @(cptr+2)
                repeat bytecount {
                    @(cptr) = @(cptr+3)
                    cptr++
                }
                @(cptr) = red
                cptr++
                @(cptr) = green
                cptr++
                @(cptr) = blue
            } else {
                cptr = cmap + high
                red = @(cptr)
                cptr++
                green = @(cptr)
                cptr++
                blue = @(cptr)
                repeat bytecount {
                    @(cptr) = @(cptr-3)
                    cptr--
                }
                @(cptr) = blue
                cptr--
                @(cptr) = green
                cptr--
                @(cptr) = red
            }
        }
    }
}
