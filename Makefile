.PHONY:  all clean run

PROG8C ?= prog8c       # if that fails, try this alternative (point to the correct jar file location): java -jar prog8c.jar


all:  imageviewer.prg

clean:
	rm -f *.prg *.vice-*

imageviewer.prg: src/imageviewer.p8 src/loader.p8 src/bmp_module.p8 src/iff_module.p8 src/koala_module.p8 src/pcx_module.p8 src/doodle_module.p8 src/bmx_module.p8
	$(PROG8C) $< -target cx16

run: all
	mcopy -D o imageviewer.prg x:IMAGEVIEWER
	PULSE_LATENCY_MSEC=20 x16emu -sdcard ~/cx16sdcard.img -scale 2 -quality best -run -prg imageviewer.prg
