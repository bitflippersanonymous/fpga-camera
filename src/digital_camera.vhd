--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	digital_camera.vhd
--
--	Top level file for the project
-- 
-- ppd(7) is tied to program pin.  0 is clk

--**********************************************************************************



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.comp_pckgs.all;


ENTITY digital_camera IS
	PORT(

--Test Ports
		init_cycle_complete_test_port: out std_logic;

-- XSA-100 MISC
		clkin	: in std_logic;
		rst		: in std_logic;
		s		: out std_logic_vector(6 downto 0);	-- Segments
		ce_n	: out std_logic;					-- Flash enable
		dips	: in std_logic_vector(3 downto 0);	-- 4 Dip switches
		pps		: out std_logic_vector(6 downto 3);	-- pport status pins for upload
		ppd		: in std_logic_vector(6 downto 0);	-- pport data pins for download 

-- XSA-100 SDRAM
		sclkfb		: in std_logic;
		sclk		: out std_logic;
		cke			: out std_logic;				-- clock-enable to SDRAM
		cs_n		: out std_logic;				-- chip-select to SDRAM
		ras_n		: out std_logic;				-- command input to SDRAM
		cas_n		: out std_logic;				-- command input to SDRAM
		we_n		: out std_logic;				-- command input to SDRAM
		ba			: out unsigned(1 downto 0);	-- SDRAM bank address bits
		sAddr		: out unsigned(12-1 downto 0);	-- SDRAM row/column address
		sData		: inout unsigned(16-1 downto 0);-- SDRAM in/out databus
		dqmh		: out std_logic;				-- high databits I/O mask
		dqml		: out std_logic;				-- low databits I/O mask


--KAC-1310 
		mclk_KAC	: out std_logic;
		init_KAC	: out std_logic;
		--sync_KAC	: out std_logic;	--Can also be done through I2C.  Save pins
		sof_KAC		: in std_logic;
		vclk_KAC	: in std_logic;
		hclk_KAC	: in std_logic;
		pix_KAC		: in std_logic_vector(9 downto 0);		
		scl 		: inout std_logic;
		sda 		: inout std_logic
		


		);
END digital_camera;

ARCHITECTURE digital_camera_arch OF digital_camera IS
-- Signals arranged by who outputs them

	-- pport_01
	signal clk_pp : std_logic;
	signal cmd : std_logic_vector(5 downto 0);
	signal pp_fifo_need_data : std_logic;
	
	-- MCSG_01
	signal start_upload : std_logic;
	signal abort_upload : std_logic;
	signal start_addr_upload : std_logic_vector(22 downto 0);
	signal end_addr_upload : std_logic_vector(22 downto 0);
	signal start_KAC : std_logic;
	signal r_w_KAC : std_logic;
	signal Data_KAC_in : std_logic_vector(7 downto 0);
	signal Addr_KAC : std_logic_vector(7 downto 0);
	signal init_cycle_complete : std_logic;

	-- ram_control_0
	signal ram_to_pp_data : std_logic_vector(15 downto 0);
	signal pp_fifo_wr_en : std_logic;

	-- KAC_I2C_01
	signal done_KAC	: std_logic;
	signal Data_KAC_out : std_logic_vector(7 downto 0);

	-- KAC_data
	signal rd_en_KAC			: std_logic;
	signal dout_KAC				: std_logic_vector(15 downto 0);
	signal dump_data_req_KAC	: std_logic;
	signal start_new_frame		: std_logic;

	-- Misc used by led decoder
	signal display_output : std_logic_vector(3 downto 0);	

	-- inphase_clks
	signal rst_int : std_logic;
	signal clk_12_5Mhz : std_logic;
	signal clk_50Mhz : std_logic;
	signal clk_100Mhz : std_logic;
	
	-- IBUFGs
	signal bufclkin	: std_logic;
	signal bufsclkfb : std_logic;
	signal bufhclk_KAC : std_logic;


	constant KAC_I2C_ADDR : std_logic_vector(6 downto 0) := "0110011";
	constant DS1621_I2C_ADDR : std_logic_vector(6 downto 0) := "1001111";


BEGIN

	ce_n <= '1';
	mclk_KAC <= clk_12_5Mhz;

	--test port for sim
--	init_cycle_complete_test_port <= init_cycle_complete; -- for test bench 'z'
	init_cycle_complete_test_port <= 'Z' ;



--SDRAM Test
	display_output <= 	"00" & pix_KAC(9 downto 8) when dips = "0111" else
						pix_KAC(7 downto 4) when dips = "1011" else
						pix_KAC(3 downto 0) when dips = "1101" else
						"0000";


	-- Just so I can use pin 18 which is a clock input, I need to put it on a global
	-- buffer.
	ibufghclk: IBUFG port map(I=>hclk_KAC, O=>bufhclk_KAC);
	ibufclkin: IBUFG port map(I=>clkin, O=>bufclkin);
	ibufsclkfb: IBUFG port map(I=>sclkfb, O=>bufsclkfb);
	inphase_clks: clock_generation
	PORT MAP
		(
			bufclkin => bufclkin,
			rst_n => rst,
			bufsclkfb => bufsclkfb,
			rst_int	=> rst_int,					
			clk_12_5Mhz => clk_12_5Mhz,
			clk_50Mhz =>  clk_50Mhz,
			clk_100Mhz => clk_100Mhz,
			sclk => sclk
		);

	see_somptin: LEDDecoder
	PORT MAP 
		(
			d => display_output,
			s => s
		);

-- Generate a 12.5Mhz clock for the image sensor.  Do this division with a dll so it
-- is not skewed.  Moved skew from 4ns to 2ns
--	generate_m_clk_KAC: clockdivider
--	GENERIC MAP ( divide_by => 5)
--	PORT MAP
--		(
--			clk => clkin,
--			rst => rst,
--			slow_clk => clk_12_5Mhz			
--		);
--	
--	clk_50Mhz <= clkin;
--	sclk <= bufsclkfb; --clkin;
--	bufhclk_KAC <= hclk_KAC;

	-- Control module.  Generates control signals based on commands from pc
	-- Controls KAC_I2C_01 and pport_01 modules
	MCSG_01: master_control_signal_generator  -- um, my names are getting a little out of hand
	port map
	(
	
		clk_50Mhz => clk_50Mhz,				-- in system clk
		clk_12_5Mhz => clk_12_5Mhz,			-- in same as mclk
		clk_pp => clk_pp,					-- in debounced clk from pport
		rst => rst,							-- in push button reset
		cmd => cmd, 						-- in cmds from pp_upload
		start_upload => start_upload,		-- out signal pp_upload to start
		abort_upload => abort_upload,		-- out signal pp_upload to abort
		start_addr => start_addr_upload,	-- out where in memory to start upload
		end_addr => end_addr_upload,		-- out where in memory to stop
		init_cycle_complete => init_cycle_complete, -- out wait for sensor & sdram		

		init_KAC => init_KAC,				-- out resets image sensor
		--sync_KAC => sync_KAC,				-- out KAC sync pin
		start_KAC => start_KAC,
		done_KAC => done_KAC,
		r_w_KAC => r_w_KAC,
		Addr_KAC => Addr_KAC,
		Data_KAC_in => Data_KAC_in,			-- Data to send by i2c
		Data_KAC_out => Data_KAC_out		-- Data back from i2c ... 
	);

	-- I2C interface tailored to read and write byte wide registers in the KAC 
	-- device.
	KAC_I2C_01: KAC_i2c
	GENERIC MAP (I2C_ADDR => KAC_I2C_ADDR) 
	PORT MAP
	(
		clk => clk_50Mhz,  				-- in system clk
		nReset => rst,					-- in push button reset
		start_KAC => start_KAC,			-- in start I2C transfer
		done_KAC => done_KAC,			-- out I2C transfer done
		r_w_KAC => r_w_KAC,				-- in direction of transfer 0 read 1 write
		Addr_KAC => Addr_KAC,			-- in Address of register in I2C device
		Data_KAC_in => Data_KAC_in,		-- in data to write at addressed register
		Data_KAC_out => Data_KAC_out,	-- out data read from addressed register
		SCL => SCL,						-- inout I2C clock line
		SDA => SDA						-- inout I2C data line
	);

	-- KAC pixel reader and formatter
	KAC_data_01: KAC_data
	port map
	(
		clk_50Mhz => clk_50Mhz,				--	: in std_logic;
		clk_12_5Mhz	=> clk_12_5Mhz,			--	: in std_logic;
		rst => rst,							--	: in std_logic;
		
		-- Internal logic I/O
		rd_en => rd_en_KAC,					--	: in std_logic;
		dout => dout_KAC,					--	: out std_logic_vector(15 downto 0);
		dump_data_req => dump_data_req_KAC, --	: out std_logic;
		start_new_frame => start_new_frame,
		init_cycle_complete => init_cycle_complete,	

		-- KAC-1310 I/O
		sof_KAC	=> sof_KAC,
		vclk_KAC => vclk_KAC,
		hclk_KAC => bufhclk_KAC,
		pix_KAC => pix_KAC					-- 	: in std_logic_vector(9 downto 0)
	);
	

	--PPort Module	
	pport_01: pp_upload
	port map
	(
		clk_50Mhz => clk_50Mhz,		-- in system clk
		clk_pp => clk_pp,			-- out debounced clk from pport
		rst => rst,					-- in push button reset
		pps => pps,					-- out parallel port status pins
		ppd => ppd,		-- in parallel port data pins including non-debounced clock

		upload_data => ram_to_pp_data,		-- in input to fifo		
		cmd => cmd,							-- out command from the pc to mcsg
		start_upload => start_upload,		-- reset fifo on upload start
		wr_en => pp_fifo_wr_en,				-- in control when to write to the fifo
		need_data => pp_fifo_need_data		-- out flag that fifo is almost empty
	);


	ram_control_01: ram_control
	PORT MAP
	(
		clk_50Mhz => clk_50Mhz, 				--	: in std_logic;
		rst => rst,								--	: in std_logic;
		
		-- PPort
		pp_data_out => ram_to_pp_data,			--	: out ..._vector(15 downto 0); 
		start_upload => start_upload,			--	: in std_logic;
		abort_upload => abort_upload,			--	: in std_logic;
		start_addr_upload => start_addr_upload, --	: in ..._vector(22 downto 0);
		end_addr_upload => end_addr_upload,		--	: in ..._vector(22 downto 0);
		pp_fifo_wr_en => pp_fifo_wr_en,			--	: out std_logic;
		pp_fifo_need_data => pp_fifo_need_data,	--	: in std_logic;
	
		-- KAC_data
		rd_en_KAC => rd_en_KAC,					--	: in std_logic;
		dout_KAC => dout_KAC,					--	: out ..._vector(15 downto 0);
		dump_data_req_KAC => dump_data_req_KAC, --	: out std_logic;
		start_new_frame => start_new_frame,


		-- SDRAM Controller stuff

		cke => cke, 						-- out clock-enable to SDRAM
		cs_n => cs_n,						-- out chip-select to SDRAM
		ras_n => ras_n,						-- out command input to SDRAM
		cas_n => cas_n,						-- out command input to SDRAM
		we_n => we_n,						-- out command input to SDRAM
		ba => ba,							-- out SDRAM bank address bits
		sAddr => sAddr,						-- out SDRAM row/column address
		sData => sData,						-- inout SDRAM in/out databus
		dqmh => dqmh,						-- out high databits I/O mask
		dqml => dqml						-- out low databits I/O mask
	);



END digital_camera_arch; 
