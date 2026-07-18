cd sw/vendor/yosyshq_icestorm/iceprog/
./iceprog -d i:0x0403:0x6011 -I B -t

make flash-prog

picocom -b 9600 -r -l --imap lfcrlf /dev/serial/by-id/usb-FTDI_Quad_RS232-HS-if02-port0

make app LINKER=flash_load TARGET=pynq-z2 PROJECT=example_w25q128jw_write

make vivado-fpga FPGA_BOARD=pynq-z2


dont' forget to verible at the end