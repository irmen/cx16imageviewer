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


## Todo

- Make koala and doodle modules stream the file instead of requiring 10Kb buffer. Or store it in 2 Hiram banks.
- IFF: implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js
