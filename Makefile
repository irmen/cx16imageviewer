.PHONY:  all clean emu

all:  imageviewer.prg

clean:
	rm -f *.prg *.vice-*

imageviewer.prg: imageviewer.p8 bmp_module.p8 iff_module.p8 koala_module.p8 pcx_module.p8 fileloader.p8
	p8compile $< -target cx16

emu: all
	box16 -sdcard ~/cx16sdcard.img -prg imageviewer.prg -run

