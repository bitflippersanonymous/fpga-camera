/**********************************************************

	FPGA Digital Camera Controller
	Copyright 2013 Ryan Henderson
	Some parts are copyrighted by their respective authors
	License: GPLv3

***********************************************************/

Explination of files:

digital_camera.vhd			
	Project top level

digital_camera_tb.vhd			
	Top level test bench
	
Asyn_fifo_distrib.vhd	
	Xilinx Core Generator simulation file
		
Asyn_fifo_distrib.edn
	Pulled in by P&R

Asyn_fifo_distrib_64.vhd
Asyn_fifo_distrib_64.edn
	Same as other fifo only 64 deep vs 16

block_ram_2kx16.vhd
block_ram_2kx16.edn
	9 Block RAMs

clock_generation.vhd
	2 DLLs for clock sync and divide

clockdivider.vhd
	Generic clock divider.  Counter

comp_pckgs.vhd
	components for entities in design

I2C.vhd
	OpenCores I2C simple

KAC_data.vhd
	Captures and buffers data from camera in FIFO.

KAC_i2c.vhd
	Controls camera by i2c

LEDDecoder.vhd
	For the one segment on XSA-100 board

master_control_signal_generator.vhd
	Communicates with I2C controller, host PC, ram_control
	to control operation.

ms_delay.vhd
	Startup delay for camera, SDRAM

one_shot.vhd
	Shortens signals to one clock pulse

pp_upload.vhd
	Reads from fifo buffer to send data in nibbles through parallel port

pullup.vhd
	Used in testbench to pullup I2C lines

ram_control.vhd
	Arbitrates SDRAM access

sdramcntl.vhd
	Xess provided Interface to SDRAM

signal_debounce.vhd
	Handles hardware switch bounce

