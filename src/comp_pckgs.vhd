--****************************************************************

--	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--	
--	comp_pckgs.vhd
--
--	  Contains packages common and comp_pckgs. package common
--	defines some constants and functions used in the design.
--	comp_pckgs define components for entities in the desin
--	so they can be instantiated and used.  Was easier to keep them
-- 	here in one place then spread them throughout the design
-- 	by defining them in the architectures.

--****************************************************************

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package common is

	constant YES:	std_logic := '1';
	constant NO:	std_logic := '0';
	constant HI:	std_logic := '1';
	constant LO:	std_logic := '0';
	function log2(v: in natural) return natural;
	
end package common;
		
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package body common is

function log2(v: in natural) return natural is
	variable n: natural;
	variable logn: natural;
begin
	n := 1;
	for i in 0 to 128 loop
		logn := i;
		exit when (n>=v);
		n := n * 2;
	end loop;
	return logn;
end function log2;

end package body common;



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package comp_pckgs is

	-- Xilinx specific components 
	component IBUFG
		port(
			O:	out	std_ulogic;
			I:	in	std_ulogic
		);
	end component;

	component BUFG
		port(
	  	O:	out	std_ulogic;
			I:	in	std_ulogic
		);
	end component;

	component BUF
		port(
	  	O:	out	std_ulogic;
		I:	in	std_ulogic
		);
	end component;

	component OBUF
		port(
			O:	out	std_ulogic;
			I:	in	std_ulogic
		);
	end component;

	component IBUF
		port(
	  		O:	out	std_ulogic;
			I:	in	std_ulogic
		);
	end component;

	component CLKDLL
	generic ( CLKDV_DIVIDE : natural := 2);
	port(
		CLKIN:	in  std_ulogic := '0';
		CLKFB:	in  std_ulogic := '0';
		RST:	in  std_ulogic := '0';
		CLK0:	out std_ulogic := '0';
		CLK90:	out std_ulogic := '0';
		CLK180:	out std_ulogic := '0';
		CLK270:	out std_ulogic := '0';
		CLK2X:	out std_ulogic := '0';
		CLKDV:	out std_ulogic := '0';
		LOCKED:	out std_ulogic := '0'
	);
	end component;

	-- Entities defined by me
	component signal_debounce
	generic 
		(
			delay: natural := 4  -- must be a power of 2!   2, 4, 8, 16...
		);		

	PORT
		(
			clk_50Mhz: in std_logic;
			sig_in: in std_logic;  --in unbuffered from the parallel port
			rst: in std_logic;
			sig_out: out std_logic

		);
	end component;

	component clock_generation 
	PORT
		(
			bufclkin	: in std_logic;
			rst_n 		: in std_logic;
			bufsclkfb	: in std_logic;		--feedback clock from sdram
			rst_int		: out std_logic;
			clk_12_5Mhz	: out std_logic;
			clk_50Mhz 	: out std_logic;
			clk_100Mhz 	: out std_logic;
			sclk		: out std_logic
		);
	end component;

	component clockdivider
		GENERIC ( divide_by : natural );
		PORT(
				clk, rst	: in std_logic;
				slow_clk	: out std_logic
			);
	end component;

	component ms_delay
	PORT(
			clk, rst, start	: in std_logic;
			delay_complete	: out std_logic
		);
	end component;


	component LEDDecoder
	  Port ( 	d : in std_logic_vector(3 downto 0);
	           	s : out std_logic_vector(6 downto 0));
	end component;

	component one_shot
		PORT
		(
			clk: in std_logic;
			sig_in: in std_logic;  --in unbuffered from the parallel port
			rst: in std_logic;
			sig_out: out std_logic

		);
	end component;

	component master_control_signal_generator
		PORT
		(
			clk_50Mhz: in std_logic;
			clk_12_5Mhz : in std_logic;
			clk_pp: in std_logic;
			rst: in std_logic;
			cmd: in std_logic_vector(5 downto 0);
			start_upload: out std_logic;
			abort_upload: out std_logic;
			start_addr: out std_logic_vector(22 downto 0);
			end_addr: out std_logic_vector(22 downto 0);
			init_cycle_complete: out std_logic;

			init_KAC 	: out std_logic;
			sync_KAC 	: out std_logic;				-- out KAC sync pin
			start_KAC 	: out std_logic;
			done_KAC	: in std_logic;
			r_w_KAC  	: out std_logic;				-- 0=read 1=write
			Addr_KAC 	: out std_logic_vector(7 downto 0);
			Data_KAC_in : out std_logic_vector(7 downto 0);	
			Data_KAC_out: in std_logic_vector(7 downto 0)	

		);
	end component;

	component ram_control
		PORT
		(
			clk_50Mhz: in std_logic;
			rst: in std_logic;
		
			-- PP ram access.  Control provided by MCSG
			pp_data_out 		: out std_logic_vector(15 downto 0); 
			start_upload 		: in std_logic;
			abort_upload 		: in std_logic;
			start_addr_upload 	: in std_logic_vector(22 downto 0);
			end_addr_upload 	: in std_logic_vector(22 downto 0);
			pp_fifo_wr_en 		: out std_logic;
			pp_fifo_need_data 	: in std_logic;

			-- Internal logic I/O
			rd_en_KAC			: out std_logic;
			dout_KAC			: in std_logic_vector(15 downto 0);
			dump_data_req_KAC	: in std_logic;
			start_new_frame		: in std_logic;

			-- SDRAM side
			cke		: out std_logic;			-- clock-enable to SDRAM
			cs_n	: out std_logic;			-- chip-select to SDRAM
			ras_n	: out std_logic;			-- command input to SDRAM
			cas_n	: out std_logic;			-- command input to SDRAM
			we_n	: out std_logic;			-- command input to SDRAM
			ba		: out unsigned(1 downto 0);	-- SDRAM bank address bits
			sAddr	: out unsigned(12-1 downto 0);	-- SDRAM row/column address
			sData	: inout unsigned(16-1 downto 0);-- SDRAM in/out databus
			dqmh	: out std_logic;				-- high databits I/O mask
			dqml	: out std_logic					-- low databits I/O mask

		);
	end component;

	component pp_upload
	PORT
	(
		clk_50Mhz: in std_logic;
		clk_pp: buffer std_logic;		--debounced clk from pport
		rst: in std_logic;
		pps: out std_logic_vector(6 downto 3);
		ppd: in std_logic_vector(6 downto 0);	
		upload_data: in std_logic_vector(15 downto 0);	--input to fifo			
		wr_en: in std_logic;
		need_data: out std_logic;   --indicats fifo status, use to control wr_en
		start_upload : in std_logic;
		cmd: out std_logic_vector(5 downto 0)
	);
	end component;

	-- EDIF pulled in during P&R.
	component block_ram_2kx16
		port (
		addr: IN std_logic_VECTOR(10 downto 0);
		clk: IN std_logic;
		din: IN std_logic_VECTOR(15 downto 0);
		dout: OUT std_logic_VECTOR(15 downto 0);
		sinit: IN std_logic;
		we: IN std_logic);
	end component;

	-- This is using a block ram... some of the outputs are dangling... fix it
	-- Parallel port
	component asyn_fifo_distrib
	port (
		din: IN std_logic_VECTOR(15 downto 0);
		wr_en: IN std_logic;
		wr_clk: IN std_logic;
		rd_en: IN std_logic;
		rd_clk: IN std_logic;
		ainit: IN std_logic;
		dout: OUT std_logic_VECTOR(15 downto 0);
		full: OUT std_logic;
		empty: OUT std_logic;
		almost_full: OUT std_logic;
		almost_empty: OUT std_logic;
		wr_count: OUT std_logic_VECTOR(3 downto 0));
	end component;

	-- For KAC
	component asyn_fifo_distrib_64
		port (
		din: IN std_logic_VECTOR(15 downto 0);
		wr_en: IN std_logic;
		wr_clk: IN std_logic;
		rd_en: IN std_logic;
		rd_clk: IN std_logic;
		ainit: IN std_logic;
		dout: OUT std_logic_VECTOR(15 downto 0);
		full: OUT std_logic;
		empty: OUT std_logic;
		almost_full: OUT std_logic;
		almost_empty: OUT std_logic;
		wr_count: OUT std_logic_VECTOR(3 downto 0);
		rd_count: OUT std_logic_VECTOR(3 downto 0));
	end component;

	component KAC_i2c 
		generic ( I2C_ADDR : std_logic_vector(6 downto 0) );
		port (
			clk : in std_logic;
			nReset : in std_logic;
			start_KAC : in std_logic;
			done_KAC : out std_logic;
			r_w_KAC  : in std_logic;	--0=read 1=write
			Addr_KAC : in std_logic_vector(7 downto 0);
			Data_KAC_in : in std_logic_vector(7 downto 0);	
			Data_KAC_out: out std_logic_vector(7 downto 0);	

			SCL : inout std_logic;
			SDA : inout std_logic
		);
	end component;

	component KAC_data
		PORT
		(
			clk_50Mhz	: in std_logic;
			clk_12_5Mhz	: in std_logic;
			rst			: in std_logic;
		
			-- Internal logic I/O
			rd_en			: in std_logic;
			dout			: out std_logic_vector(15 downto 0);
			dump_data_req	: out std_logic;
			start_new_frame	: out std_logic;
			init_cycle_complete	: in std_logic;

			-- KAC-1310 I/O
			sof_KAC		: in std_logic;
			vclk_KAC	: in std_logic;
			hclk_KAC	: in std_logic;
			pix_KAC 	: in std_logic_vector(9 downto 0)
		);
	
	END component;



	component sdramCntl
		generic(
			FREQ:	natural := 50_000;		-- operating frequency in KHz
			DATA_WIDTH: natural := 16;		-- host & SDRAM data width
			HADDR_WIDTH: natural := 23;		-- host-side address width
			SADDR_WIDTH: natural := 12		-- SDRAM-side address width
		);
		port(
			clk		: in std_logic;				-- master clock

			-- host side
			rst		: in std_logic;				-- reset
			rd		: in std_logic;				-- read data
			wr		: in std_logic;				-- write data
			done	: out std_logic;				-- read/write op done
			hAddr	: in unsigned(HADDR_WIDTH-1 downto 0);	-- address from host
			hDIn	: in unsigned(DATA_WIDTH-1 downto 0);	-- data from host
			hDOut	: out unsigned(DATA_WIDTH-1 downto 0);	-- data to host
			sdramCntl_state: out std_logic_vector(3 downto 0);		

			-- SDRAM side
			cke		: out std_logic;				-- clock-enable to SDRAM
			cs_n	: out std_logic;				-- chip-select to SDRAM
			ras_n	: out std_logic;				-- command input to SDRAM
			cas_n	: out std_logic;				-- command input to SDRAM
			we_n	: out std_logic;				-- command input to SDRAM
			ba		: out unsigned(1 downto 0);		-- SDRAM bank address bits
			sAddr	: out unsigned(SADDR_WIDTH-1 downto 0);	-- row/column address
			sData	: inout unsigned(DATA_WIDTH-1 downto 0);-- SDRAM in/out databus
			dqmh	: out std_logic;				-- high databits I/O mask
			dqml	: out std_logic					-- low databits I/O mask
		);
	end component;

	-- Used by test bench
	component digital_camera
		PORT
		(
			-- Test Ports
			init_cycle_complete_test_port: out std_logic;

			-- XSA-100 MISC
			clkin 	: in std_logic;
			rst		: in std_logic;
			s		: out std_logic_vector(6 downto 0);	-- Segments
			ce_n	: out std_logic;					-- Flash enable
			dips	: in std_logic_vector(3 downto 0);	-- 4 Dip switches
			pps		: out std_logic_vector(6 downto 3);	-- Status pins for upload
			ppd		: in std_logic_vector(6 downto 0);	-- For download 

			-- XSA-100 SDRAM
			sclkfb	: in std_logic;
			sclk	: out std_logic;
			cke		: out std_logic;				-- clock-enable to SDRAM
			cs_n	: out std_logic;				-- chip-select to SDRAM
			ras_n	: out std_logic;				-- command input to SDRAM
			cas_n	: out std_logic;				-- command input to SDRAM
			we_n	: out std_logic;				-- command input to SDRAM
			ba		: out unsigned(1 downto 0);		-- SDRAM bank address bits
			sAddr	: out unsigned(12-1 downto 0);	-- SDRAM row/column address
			sData	: inout unsigned(16-1 downto 0);-- SDRAM in/out databus
			dqmh	: out std_logic;				-- high databits I/O mask
			dqml	: out std_logic;				-- low databits I/O mask


			--KAC-1310 
			mclk_KAC	: out std_logic;
			init_KAC	: out std_logic;
		--	sync_KAC	: out std_logic;
			sof_KAC		: in std_logic;						--Start of frame
			vclk_KAC	: in std_logic;						--Start of line
			hclk_KAC	: in std_logic;						--Pixel clk
			pix_KAC		: in std_logic_vector(9 downto 0);	-- Pixel data
			scl 		: inout std_logic;
			sda 		: inout std_logic
		);
	END component;

end package comp_pckgs;
