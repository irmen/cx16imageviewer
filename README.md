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
Simply type ``p8compile imageviewer.p8 -target cx16`` or just ``make``.


## Todo

- Fileloader: don't load everything in hiram first, just stream it from disk (using MACPTR if available)
- IFF: implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js
