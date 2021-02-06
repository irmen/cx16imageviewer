.PHONY:  all clean

all:  imageviewer.prg

clean:
	rm -f *.prg *.vice-*

imageviewer.prg: imageviewer.p8 bmp_module.p8 iff_module.p8 koala_module.p8 pcx_module.p8
	p8compile $< -target cx16
