%import gfx2
%import textio
%import diskio
%import string
%import loader
%zeropage basicsafe
%option no_sysinit

main {
    sub start() {
        void diskio.fastmode(1)
        void cx16.screen_mode(0, true)
        cx16.rombank(0)        ; switch to kernal rom (for faster file i/o)

        ; trick to check if we're running on sdcard or host system shared folder
        txt.print("\x93\nimage viewer for commander x16\nformats supported: ")
        uword ext
        for ext in loader.known_extensions {
            txt.print(ext)
            txt.spc()
        }
        txt.nl()
        txt.nl()
        if list_image_files_on_disk() {
            txt.print("\nwhen image is displayed, press a key to go to next image,\n and stop/ctrl+c to halt!\n")
            txt.print("\nenter file name or just enter to view all: ")
            ubyte i = txt.input_chars(diskio.list_filename)
            if i!=0 {
                uword extension = &diskio.list_filename + loader.rfind(&diskio.list_filename, '.')
                if loader.is_known_extension(extension) {
                    if loader.attempt_load(diskio.list_filename, true)
                        void txt.waitkey()
                } else load_error("unknown file extension", diskio.list_filename)
            }
            else
                show_pics_sdcard()
        }
        else
            txt.print("files are read with sequential file loading.\nin the emulator this currently only works with files on an sd-card image.\nsorry :(\n")

        loader.restore_screen_mode()
        palette.set_default16()
        txt.print("that was all folks!\n")

        cx16.rombank(4)        ; switch back to basic rom
    }

    sub list_image_files_on_disk() -> bool {
        if diskio.lf_start_list(0) {
            txt.print(" blocks   filename\n-------- -------------\n")
            while diskio.lf_next_entry() {
                uword extension = &diskio.list_filename + loader.rfind(&diskio.list_filename, '.')
                if loader.is_known_extension(extension) {
                    txt.spc()
                    print_uw_right(diskio.list_blocks)
                    txt.print("    ")
                    txt.print(diskio.list_filename)
                    txt.nl()
                }
            }
            diskio.lf_end_list()
            return true
        }
        return false
    }

    sub print_uw_right(uword value) {
        if value < 10
            txt.spc()
        if value < 100
            txt.spc()
        if value < 1000
            txt.spc()
        if value < 10000
            txt.spc()
        txt.print_uw(value)
    }

    sub show_pics_sdcard() {

        ; load and show the images on the disk with the given extensions.

        uword filenames = memory("filenames", 20*200, 0)
        uword @zp names_ptr = filenames
        ubyte num_files = diskio.list_filenames(0, filenames, sizeof(filenames))
        if num_files!=0 {
            gfx2.screen_mode(1)    ; 320*240, 256c
            while @(names_ptr)!=0 and not cbm.STOP2() {
                uword extension = names_ptr + loader.rfind(names_ptr, '.')
                if loader.is_known_extension(extension) {
                    if loader.attempt_load(names_ptr, false)
                        void txt.waitkey()
                    else
                        break
                }
                names_ptr += string.length(names_ptr) + 1
            }
        } else
            txt.print("no files in directory!\n")
    }

    sub load_error(uword what, uword filenameptr) {
        ; back to default text mode and palette
        loader.restore_screen_mode()
        cbm.CINT()
        void cx16.screen_mode(0, false)
        txt.print("load error: ")
        if what!=0
            txt.print(what)
        txt.print("\nfile: ")
        txt.print(filenameptr)
        txt.nl()
        cx16.rombank(4)        ; switch back to basic rom
        sys.exit(1)
    }

}
