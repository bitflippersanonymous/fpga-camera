--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	KAC_data.vhd
--
--	Reads data from image sensor and stuffs it into a FIFO.  The fifo cordinates
--	with ram control to dump its contents to the SDRAM
--
--**********************************************************************************

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;
use work.comp_pckgs.all;


ENTITY KAC_data IS

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
		init_cycle_complete : in std_logic;

	
		-- KAC-1310 I/O
		sof_KAC		: in std_logic;					--Start of frame
		vclk_KAC	: in std_logic;					--Start of line
		hclk_KAC	: in std_logic;					--valid pixel data
		pix_KAC 	: in std_logic_vector(9 downto 0)
	);
	
END KAC_data;

ARCHITECTURE KAC_data_arch OF KAC_data IS

	-- input mux state machine
	subtype state is integer range 4 downto 0; 
	SIGNAL current_state, next_state: state;

	-- dump_data_req and start_new_frame state machine
	subtype state_req is integer range 3 downto 0; 
	SIGNAL current_state_req, next_state_req: state_req;


	signal din 				: std_logic_VECTOR(15 downto 0);
	signal wr_en 			: std_logic;
	signal full 			: std_logic;
	signal empty 			: std_logic;
	signal almost_full 		: std_logic;
	signal almost_empty 	: std_logic;
	signal wr_count 		: std_logic_VECTOR(3 downto 0);
	signal rd_count 		: std_logic_VECTOR(3 downto 0);
	signal not_rst 			: std_logic;
	signal toggle 			: std_logic;
	signal test_pattern 	: std_logic_vector(15 downto 0);
	signal pixmux_r 		: std_logic_vector(7 downto 0);
	signal pixmux_next		: std_logic_vector(7 downto 0);
	signal dump_data_r		: std_logic;
	signal dump_data_next 	: std_logic;

	signal os_hclk_KAC 	: std_logic;
	signal os_sof_KAC 	: std_logic;
	
	--signal col_count	: integer range 1280 downto 0;
	--signal row_count	: integer range 1024 downto 0;

	
BEGIN
	
	not_rst <= not(rst);
	dump_data_req <= dump_data_r;



	
	-- Used to be sure the input data is going through all the buffers
	-- in order.
	-- Count values to simulate pixel input.  To be removed
	input_test: process( hclk_KAC, rst)
		variable i : integer range 1310719 downto 0;
	begin
		if rst='0' then
			i := 0; 
		
		elsif hclk_KAC'event and hclk_KAC='1' then
			i := i + 1;		
			
		end if;
		
	--din <= std_logic_vector(to_unsigned(i, test_pattern'length));

	end process input_test;

	-- Make The sof_KAC signal one 50mhz period long
	sof_oneshot: one_shot
	port map
		(
			clk => clk_50Mhz,
			sig_in => sof_KAC,
			rst => rst,
			sig_out => os_sof_KAC

		);

	
	--Coregen fifo built of distributed rams of depth 64.
	KAC_FIFO : asyn_fifo_distrib_64
		port map 
		(
			din => din,
			wr_en => wr_en,  
			wr_clk => clk_50Mhz,
			rd_en => rd_en,
			rd_clk => clk_50Mhz,
			ainit => not_rst,
			dout => dout,
			full => full,
			empty => empty,
			almost_full => almost_full,
			almost_empty => almost_empty,
			wr_count => wr_count,
			rd_count => rd_count
		);


-- Determine when the fifo needs to dump into memory.  Leave some extra
-- space incase the memory can't respond right away.
--
-- When SOF goes high it signals the start of a new frame.  When this happens, 
-- make sure the fifo has cleared the last frame.  When the fifo is done clearing
-- Signal start_new_frame to the memory controller so it can start the next frame
-- in a new memory block.
--
-- At 12.5Hmz:
-- From sof asserted to first hclk is >64 mclks default setting. (Table 39 KAC 
-- datasheet.  During this time, I will empty the fifo.  According to the scope
-- this is 550ns. Not enough to dump the entire fifo.
-- 
--
-- At 5Mhz:
-- Hmmm.. I'll have more time to dump the fifo.  

----------------------- DUMP DATA REQ AND START_NEW_FRAME --------

-- After alot of flusteration ... this works alot better if I register
-- the dump_data_req signal since it's used async in the ram_control
-- process.  I'm so happy!!!! It works now

------------------------------------------------------------------
	comb_state_change_req: process(current_state_req, rd_count, 
				almost_empty, empty, sof_KAC, dump_data_r) is
	begin

		--default actions
		next_state_req <= current_state_req;
		start_new_frame <= '0';	

		if rd_count = x"2" then
			dump_data_next <= '1';
		elsif almost_empty = '1' then
			dump_data_next <= '0';		
		else
			dump_data_next <= dump_data_r;
		end if;
		
		 --State machine actions				
		case current_state_req is
		when 0 =>

			if sof_KAC = '1' then
				next_state_req <= 1;
			end if;

		when 1 =>															
			if almost_empty = '0' then
				dump_data_next <= '1';
				
			else
				next_state_req <= 2;
			
			end if;			

		when 2 => 
			start_new_frame <= '1';
			next_state_req <= 3;
			
		when 3 => 
			if sof_KAC = '0' then
				next_state_req <= 0;
			end if;

		end case;
	end process comb_state_change_req;

	--Change state on clock
	update_req: process( clk_50Mhz, rst, next_state_req, dump_data_next) is
	begin
		if rst = '0' then
			current_state_req <= 0;
			dump_data_r <= '0';

		elsif clk_50Mhz'event and clk_50Mhz='1' then
			current_state_req 	<= next_state_req;
			dump_data_r 		<= dump_data_next;

		end if;
	end process update_req;	




------------------- PIXEL DATA PACKING -----------------------

	comb_state_change: process(current_state, pix_KAC, pixmux_r, 
				init_cycle_complete, hclk_KAC) is

	begin

		--default actions
		next_state <= current_state;
		wr_en <= '0';
		din <= (others=>'0');
		pixmux_next <= pixmux_r;
				
		case current_state is
		when 0 =>
			if init_cycle_complete = '1' then
				next_state <= 1;

			end if;

		when 1 =>															
			if hclk_KAC = '1' then
				pixmux_next <= pix_KAC(9 downto 2);
				next_state <= 2;
			end if;
		
		when 2 => 
			if hclk_KAC = '0' then
				next_state <= 3;
			end if;

		when 3 => 
			if hclk_KAC = '1' then
				din <= pix_KAC(9 downto 2) & pixmux_r;
				wr_en <= '1';
				next_state <= 4;
			end if;
		
		when 4 =>
			if hclk_KAC <= '0' then
				next_state <= 1;
			end if;

		end case;
	end process comb_state_change;

	--Change state on clock
	update: process( clk_50Mhz, rst, next_state, pixmux_next) is
	begin
		if rst = '0' then
			current_state <= 0;
			pixmux_r <= (others=>'0');
		elsif clk_50Mhz'event and clk_50Mhz='1' then
			current_state <= next_state;
			pixmux_r <= pixmux_next;
		end if;
	end process update;	



END KAC_data_arch;

