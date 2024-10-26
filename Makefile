.PHONY:  all clean emu

all:  imageviewer.prg

clean:
	rm -f *.prg *.vice-*

imageviewer.prg: src/imageviewer.p8 src/loader.p8 src/bmp_module.p8 src/iff_module.p8 src/koala_module.p8 src/pcx_module.p8 src/doodle_module.p8 src/bmx_module.p8
	prog8c $< -target cx16

emu: all
	mcopy -D o imageviewer.prg x:IMAGEVIEWER
	PULSE_LATENCY_MSEC=20 x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg imageviewer.prg

