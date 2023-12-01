.PHONY:  all clean emu

all:  imageviewer.prg

clean:
	rm -f *.prg *.vice-*

imageviewer.prg: imageviewer.p8 bmp_module.p8 iff_module.p8 koala_module.p8 pcx_module.p8 doodle_module.p8
	p8compile $< -target cx16

emu: all
	mcopy -D o imageviewer.prg x:IMAGEVIEWER
	x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg imageviewer.prg

