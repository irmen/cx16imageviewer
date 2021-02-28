# cx16imageviewer
Multi file format image viewer for Commander X16.

Supports:

- C64 Koala files
- IFF files, including CRNG and CCRT color cycling!
- BMP files
- PCX files

of 2 to 256 colors. Display resolution is 320x240.

## Compiling

The program is written in Prog8. Requires prog8 compiler 6.1 and 64tass assembler.

Simply type ``p8compile imageviewer.p8 -target cx16`` or just ``make``.


## Todo

IFF: implement Blend Shifting see http://www.effectgames.com/demos/canvascycle/palette.js
