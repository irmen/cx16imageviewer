# cx16imageviewer
Multi file format image viewer for Commander X16.

Supports:

- C64 Koala files
- IFF ILBM and PBM files, including CRNG and CCRT color cycling! (famously produced with DeluxePaint)
- BMP files
- PCX files

of 2 to 256 colors. Display resolution is fixed 320x240.

## Compiling

The program is written in Prog8. Requires recent prog8 compiler and 64tass assembler to compile.
Simply type ``p8compile imageviewer.p8 -target cx16`` or just ``make``.


## Todo

- fix the lack of colorcycling in the .LBM images saved by Dos Dpaint
- IFF: implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js
