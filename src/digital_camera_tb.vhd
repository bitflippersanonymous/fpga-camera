--**********************************************************************************

--	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	digital_camera_tb.vhd
--
-- 	Test bench for camera top level
--	Exercises image sensor data input and parallel port output

--**********************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use WORK.comp_pckgs.all;


entity digital_camera_tb is
end digital_camera_tb;

architecture digital_camera_tb_arch of digital_camera_tb is
    constant RST_ACTIVE : STD_LOGIC := '0';
  	constant CLK_PERIOD   : time := 20 nS; 
	constant PPD_CLK_PERIOD : time := 500 nS;	--It's actually alot slower

	constant start_addr : unsigned(22 downto 0) := (others=>'0');
	constant end_addr : unsigned(22 downto 0) := to_unsigned((128*10)/2, 23);

	-- Size of the picture is variable to cut down on simulation time
	constant NUM_ROWS : integer := 10; --1024
	constant NUM_COLS : integer := 128; --1280;
	
	-- Test Ports
	signal init_cycle_complete_test_port : std_logic;
	
	-- XSA-100 interface
	signal rst	:  std_logic;							
	signal clk	:  std_logic;
	signal ce_n : std_logic;
	signal s	:  std_logic_vector(6 downto 0);							
	signal dips	:  std_logic_vector(3 downto 0);
	signal pps 	:  std_logic_vector(6 downto 3);
	signal ppd	:  std_logic_vector(6 downto 0); 

	-- SDRAM interface
	signal cke	:  std_logic;				-- SDRAM clock-enable
	signal cs_n	:  std_logic;				-- SDRAM chip-select
	signal ras_n:  std_logic;				-- SDRAM RAS
	signal cas_n:  std_logic;				-- SDRAM CAS
	signal we_n	:  std_logic;				-- SDRAM write-enable
	signal ba	:  unsigned( 1 downto 0);	-- SDRAM bank-address
	signal sAddr:  unsigned(11 downto 0);	-- SDRAM address bus
	signal sData:  unsigned(15 downto 0);	-- data bus to SDRAM
	signal dqmh	:  std_logic;				-- SDRAM DQMH
	signal dqml	:  std_logic;				-- SDRAM DQML
	signal sclk : std_logic;
	
	-- KAC interface
	signal mclk_KAC : std_logic;
	signal init_KAC : std_logic;
	--signal sync_KAC : std_logic;
	signal sof_KAC	: std_logic;			--Start of frame
	signal vclk_KAC	: std_logic;			--Start of line
	signal hclk_KAC	: std_logic;			--valid pixel data

	signal pix_KAC	: std_logic_vector(9 downto 0);

	signal scl 		: std_logic;
	signal sda 		: std_logic;

	-- pullup used for simulation only. Matches pullup.vhd
    component PULLUP
        port(v101: OUT std_logic);
    end component;
 


begin

	DUT: digital_camera
	PORT MAP
	(
				init_cycle_complete_test_port => init_cycle_complete_test_port,

				-- XSA-100 MISC
				clkin => clk,
				rst	=> rst,
				s => s,
				ce_n => ce_n,
				dips => dips,
				pps => pps,
				ppd => ppd,

				-- XSA-100 SDRAM
				sclkfb => sclk,  --without the dlls, it's not even used
				sclk => sclk,
				cke => cke,
				cs_n => cs_n,
				ras_n => ras_n,
				cas_n => cas_n,
				we_n => we_n,
				ba => ba,
				sAddr => sAddr,
				sData => sData,
				dqmh => dqmh,
				dqml => dqml,


				--KAC-1310 
				mclk_KAC => mclk_KAC,
				init_KAC => init_KAC,
				--sync_KAC => sync_KAC,
				sof_KAC	=> sof_KAC,
				vclk_KAC => vclk_KAC,
				hclk_KAC => hclk_KAC,
				pix_KAC => pix_KAC,
				scl => scl,	
				sda => sda
		);
	
	--Pull up the I2C lines for simulation
 	v109: PULLUP
        port map(v101 => scl);
    
    v110: PULLUP
        port map(v101 => sda);
    
  

	
	CREATE_CLK: process
	   variable i	: integer := 0;
	begin
	 	if i <= 2 then
			i := i + 1;
			rst <= RST_ACTIVE;
		else
			rst <= not(RST_ACTIVE);
		end if;
		
		CLK <= '0';
		wait for CLK_PERIOD/2;
		CLK <= '1';
		wait for CLK_PERIOD/2;

	end process;

		

	sData <= "0000" & sAddr when we_n = '1' else (others=>'0');

	video_sync_signals: process
		variable i : integer := 0;
		variable j : integer := 0;
		variable k : integer := 0;

	begin
		
		sof_KAC <= '0';
		vclk_KAC <= '0';
		hclk_KAC <= '0';
			
		wait until rst /= RST_ACTIVE;
		wait until init_cycle_complete_test_port = '1';			-- 0 active
		
		loop				
			sof_KAC <= '1';
		
			-- 8 m_clk delay after sof till first vclk
			for i in 0 to 7 loop
				wait until mclk_KAC'event and mclk_KAC = '1';
			end loop;
				
			for i in 0 to NUM_ROWS-1 loop
				vclk_KAC <= '1';
				for i in 0 to 63 loop				--vclk 0 after 64 mclk
					wait until mclk_KAC'event and mclk_KAC = '1';
				end loop;
				vclk_KAC <= '0';
		
				for j in 0 to NUM_COLS-1 loop
					wait until mclk_KAC'event and mclk_KAC = '1';
					hclk_KAC <= '1';
					wait until mclk_KAC'event and mclk_KAC = '0';
					hclk_KAC <= '0';
				end loop;
				sof_KAC <= '0';							--sof 0 after 1 row
			end loop;
			for k in 0 to 63 loop									
				wait until mclk_KAC'event and mclk_KAC = '1';
			end loop;

		end loop;

		wait;

	end process video_sync_signals;		


	-- At the same time as the parallel port is uploading, do a transfer from 
	-- the sensor to memory.  Testing the memory arbitrator.
	KAC_pixel_generate: process
		variable i : integer := 0;
	begin
	
		if rst = RST_ACTIVE	then
			pix_KAC <= (others=>'0');
			i := 0;
		else
			wait until init_cycle_complete_test_port = '1';		

			pix_KAC <= std_logic_vector(to_unsigned(i, pix_KAC'length));
			i := i + 1;
		end if;
		wait until hclk_KAC'event and hclk_KAC = '1';

	end process KAC_pixel_generate;

	
	-- Simulate the pc parallel port connnection.  Go through the steps to transfer
	-- data from start address to end address.
	pport_sdram_access: process
		variable i : integer := 0;
	begin
		dips <= (others=>'0');
		ppd <= (others=>'0');
		wait until rst = not(RST_ACTIVE);  -- INVERSE OF RST_ACTIVE.. but not X or U
		wait until init_cycle_complete_test_port = '1';		
		
		loop

			-- Send upload command and toggle clock pin
			ppd <= "000001" & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= "000001" & '1';
			wait for PPD_CLK_PERIOD/2;
	
			--Start address pad extra zero at top
			ppd <= std_logic_vector(start_addr(5 downto 0)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(start_addr(5 downto 0)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= std_logic_vector(start_addr(11 downto 6)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(start_addr(11 downto 6)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= std_logic_vector(start_addr(17 downto 12)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(start_addr(17 downto 12)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= '0' & std_logic_vector(start_addr(22 downto 18)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= '0' & std_logic_vector(start_addr(22 downto 18)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= std_logic_vector(end_addr(5 downto 0)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(end_addr(5 downto 0)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= std_logic_vector(end_addr(11 downto 6)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(end_addr(11 downto 6)) & '1';
			wait for PPD_CLK_PERIOD/2;

			ppd <= std_logic_vector(end_addr(17 downto 12)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= std_logic_vector(end_addr(17 downto 12)) & '1';
			wait for PPD_CLK_PERIOD/2;
		
			ppd <= '0' & std_logic_vector(end_addr(22 downto 18)) & '0';
			wait for PPD_CLK_PERIOD/2;
			ppd <= '0' & std_logic_vector(end_addr(22 downto 18)) & '1';

			--Generate some clocks on ppd(0) to upload the data
			--Go for length of data.  figure this, don't hard code it.
			for i in 0 to to_integer(end_addr-start_addr)*2 loop
				wait for PPD_CLK_PERIOD/2;
				ppd <= "000000" & '0';
				wait for PPD_CLK_PERIOD/2;
				ppd <= "000000" & '1';
			end loop;


			wait for PPD_CLK_PERIOD;
			--ppd <= "000000" & '0';
		
		end loop;
		
		wait;		--make sure to end it			
	end process;

 


end digital_camera_tb_arch;
