--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	pp_upload.vhd  
--
--	
--	Transfers data from sdram to host PC.  Uses a FIFO for a buffer.
--
--	Interface to pc parallel port
--	Uploads nibbles at a time through pp status pins.  
--	Low nibble when clk_db is low, high nibble when clk_db is high.
--	There was some noise on the parallel port d0 clk pin so a debounce circuit was
--	added.  This makes it ignore false clocks caused by bounce, but it also adds a 
--	nominal amount of delay.
--	This module is a little difficult because there are two clocks to deal with.  
--	The 50Mhz from the control module and the randomly ~50k to 200khz from the pport.  
--	The pport clk will pause for any amount of time at any moment as windows is 
--	multitasking.

--**********************************************************************************



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;
use work.comp_pckgs.all;


ENTITY pp_upload IS

	PORT
	(
		clk_50Mhz: in std_logic;
		clk_pp: buffer std_logic;		--debounced clk from pport
		rst: in std_logic;
		pps: out std_logic_vector(6 downto 3);
		ppd: in std_logic_vector(6 downto 0);	
		upload_data: in std_logic_vector(15 downto 0);	
		wr_en: in std_logic;
		need_data: out std_logic;   --Fifo status. set on fifo empty, cleared on full
		start_upload : in std_logic;
		cmd: out std_logic_vector(5 downto 0)
	);
	
END pp_upload;

ARCHITECTURE pp_upload_arch OF pp_upload IS


	signal data_out : std_logic_vector(15 downto 0);	--output of fifo
	signal cmd_r: std_logic_vector(5 downto 0); 	-- Command sent to MCSG
	signal full:  std_logic;
	signal empty: std_logic;
	signal almost_full: std_logic;
	signal almost_empty: std_logic;
	signal wr_count: std_logic_vector(3 downto 0);
	signal upper_lower_byte: std_logic;		--Toggle high / low half of fifo output
	signal rd_en: std_logic;
	signal not_clk_pp_sig : std_logic;	-- make signal globally static
	signal clk_pp_sig : std_logic;
	signal ainit : std_logic;

BEGIN

	not_clk_pp_sig <= not(clk_pp);
	ainit <= not(rst) or start_upload; 		--Active high reset
	

		--Debounce
	clk_debounce_01: signal_debounce 
	generic map 
	(	delay => 8	)		--8*(1/50Mhz) = 160ns
	port map 
	(	clk_50Mhz => clk_50Mhz, 
		sig_in => ppd(0), 
		rst => rst, 
		sig_out => clk_pp_sig
	);
	
--	clk_pp <= clk_pp_sig;
	buffet: buf port map(I => clk_pp_sig, O => clk_pp);
 
	
	pp_fifo : asyn_fifo_distrib
		port map (
			din => upload_data,		--memory
			wr_en => wr_en,			--control
			wr_clk => clk_50Mhz,	--fast clk. 
			rd_en => rd_en,			
			rd_clk => not_clk_pp_sig,	--Odd, but works
			ainit => ainit,			--active high to reset changed from just rst
			dout => data_out,		--to pport
			full => full,			--signals to control
			empty => empty,
			almost_full => almost_full,
			almost_empty => almost_empty,
			wr_count => wr_count
			);
	
	--If there's anything in the fifo (not empty) enable read.  not(empty) /= full
	--load fifo on 1 to 0 transition of pp_clk
	rd_en <= not(empty) and not(upper_lower_byte);	

	--data_out <= x"4321";	-- To test byte ordere

	-- send to a signal first so I can also send pps to the seven segments
	-- The  order here is a little interesting.  Makes it come out on right on 
	-- the other end data_out <= x"4321"; will appear in the data file on the 
	-- other end as 21 43 in byte addresses
	-- 0 and 1. 
	pps_mux: pps	<=  (others=>'0') when rst = '0' else
			data_out(3 downto 0) when clk_pp='0' and upper_lower_byte = '0' else
			data_out(15 downto 12) when clk_pp='1' and upper_lower_byte = '0' else
			data_out(11 downto 8) when clk_pp='0' and upper_lower_byte = '1' else
			data_out(7 downto 4);
							
	
	--signal to other modules the command that's coming from the host pc.
	cmd <= cmd_r;

	--read ppd pins and move them into the cmd reg.  	
	--Generate address for rom.  move that to control module. Generate
	--cmd valid signal.
	process(clk_pp, ppd, rst, start_upload, upper_lower_byte) is
	begin
		if rst='0' then
			cmd_r <= (others=>'0');
			upper_lower_byte <= '0';
		elsif clk_pp'event and clk_pp='1' then
			cmd_r <= ppd(6 downto 1);
			upper_lower_byte <= not(upper_lower_byte) and not(start_upload);

		end if;
	end process;

	
	--output need data signal, a flag indicating fifo status.  set on fifo empty, 
	--cleared on full
	
	--I can use the full and almost full flags because they are asserted on the 
	--clk_50Mhz edges. I can't use the empty and almost empty because they are 
	--asserted on the clk_pp (slow clk) edges. If I use them, then the counter 
	--will jump ahead when the fifo is empty but the signals don't say so yet.  
	--the wr_count is off of the clock on the write side, the 50Mhz, so it's safe 
	--to use. 
		
	need_data_flag_generate: 
	process(clk_50Mhz, rst) is
	begin
		if rst='0' then
			need_data <= '0';
		elsif clk_50Mhz'event and clk_50Mhz='1' then
			if wr_count <= x"3" then
				need_data <= '1';			--dff it
			elsif wr_count >= x"b" then		--delay to shut off the data
				need_data <= '0';
			end if;
		end if;
	end process need_data_flag_generate;

	
END pp_upload_arch;



















