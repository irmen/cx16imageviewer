# cx16imageviewer

Multi file format image viewer for Commander X16.

Supports:

- C64 Koala (.koa) and Doodle (.dd/.ddl)
- IFF ILBM and PBM, including CRNG and CCRT color cycling!
- BMP
- PCX
- BMX (Commander X16 bitmap file)

of 2 to 256 colors. Display resolution is fixed 320x240.

## Compiling

The program is written in Prog8. Requires recent prog8 compiler and 64tass assembler to compile.
Simply type ``p8compile src/imageviewer.p8 -target cx16`` or just ``make``.


## Usage

Follow on screen instructions. It can display a single file or all image files found on the disk as a slide show.

Press any key to advance to the next image.

Press 'b' to convert the currently displayed image into a BMX format file (image.bmx).

Press stop/ctrl+c to stop palette cycling images, or to abort a slide show.


## Todo

- IFF: implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js
