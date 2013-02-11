--**********************************************************************************

--	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	clock_generation.vhd  
--

-- Generate multiple frequency deskewed clocks using dlls.  There's some problem if 
-- I hold the reset asserted while waiting for the dlls to to lock I can only upload 
-- exactly 4 words.  Seems to work OK using the async rst instead of rst_int.

-- I need to manually reset it after loading the code because the dlls haven't locked on yet.
-- I need a way to hold everything reset until the dlls lock

--**********************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.comp_pckgs.all;


ENTITY clock_generation IS
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
	
END clock_generation;

ARCHITECTURE clock_generation_arch OF clock_generation IS

	signal lock	: std_logic;
	signal dllint_clk0 : std_logic;
	signal bufdllint_clk0 : std_logic;
	signal dllint_clk2x : std_logic;
	signal bufdllint_clk2x : std_logic;
	signal dllext_clk0 : std_logic;
	signal locked, lockint, lockext : std_logic;
	signal bufdllint_clkdv : std_logic;
	signal dllint_clkdv : std_logic;


BEGIN
	
	-- generate an internal clock sync'ed to the master clock
	dllint: CLKDLL 
	generic map 
		( CLKDV_DIVIDE => 10)
	port map
		(
			CLKIN=>bufclkin, 
			CLKFB=>bufdllint_clk0, 
			CLK0=>dllint_clk0,
			RST=>'0', 
			CLK90=>open, 
			CLK180=>open, 
			CLK270=>open,
			CLK2X=>dllint_clk2x, 
			CLKDV=>dllint_clkdv, 
			LOCKED=>lockint
		);

	-- generate an external SDRAM clock sync'ed to the master clock
	dllext: CLKDLL 
	port map
		(
			CLKIN=>bufclkin, 
			CLKFB=>bufsclkfb, 
			CLK0=>dllext_clk0, 
			RST=>'0', 
			CLK90=>open, 
			CLK180=>open, 
			CLK270=>open,
			CLK2X=>open, 
			CLKDV=>open, 
			LOCKED=>lockext
		);

	
	clkg: BUFG port map (I=>dllint_clk0, O=>bufdllint_clk0);
	clkg2x: BUFG port map(I=>dllint_clk2x, O=>bufdllint_clk2x);  
	clkhalfx: BUFG port map(I=>dllint_clkdv, O=>bufdllint_clkdv);  
	
	-- output the sync'ed SDRAM clock to the SDRAM
	sclk <= dllext_clk0;
	clk_12_5Mhz <= bufdllint_clkdv;
 	clk_50Mhz <= bufdllint_clk0;		-- SDRAM controller logic clock
	clk_100Mhz <= bufdllint_clk2x;	-- doubled clock to other FPGA logic;
	locked <= lockint and lockext;	-- indicate lock status of the DLLs


	-- synchronous reset.  internal reset flag is set active by config. bitstream
	-- and then gets reset after DLL clocks start.
	process(bufclkin)
	begin
		if(bufclkin'event and bufclkin='1') then
			if locked='0' then
				rst_int <= '0';				-- keep in reset until DLLs start up
			else
				rst_int <= rst_n;	-- else manually activate reset with pushbutton
			end if;
		end if;
	end process;

	
END clock_generation_arch;





