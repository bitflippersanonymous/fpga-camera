--******************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	signal_debounce.vhd
--
--	  Debounce circuit to reduce false triggering from switch bounce
--	or other problems.  Generic delay for number of clocks to wait
--	for bounces to stop.  The size of the delay counter is adjusted
-- 	based off this generic delay. State machine that requires x clocks
-- 	to occur after a state changes, before it can change states again.

-- modelsim is giving an error during simulation about vector
-- truncation numberic_std.to_unsigned

--******************************************************************************



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.common.all;

ENTITY signal_debounce IS
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
	
END signal_debounce;

ARCHITECTURE signal_debounce_arch OF signal_debounce IS

	
	subtype state is integer range 1 downto 0; 
	SIGNAL current_state, next_state: state;
	SIGNAL start, done: std_logic;
	
	--used to wait for bounce to settle
	SIGNAL state_time: unsigned (log2(delay)-1 downto 0);  


BEGIN
	
	
	comb_state_change: process(current_state, done, sig_in) is
	begin

		--default actions
		next_state <= current_state;

		case current_state is
		--stay in this state until the timer has expired, and
		--sig_in has changed to a 1
		when 0 =>											
			state_time <= TO_UNSIGNED(delay, state_time'length);			
			if done = '1' and sig_in = '0' then
				next_state <= 1;
			else
				start <= '1';
				next_state <= 0;
			end if;
		
		--stay in this state until the timer has expired, and
		--sig_in has changed to a 0
		when 1 =>														
			state_time <= TO_UNSIGNED(delay, state_time'length);			
			if done = '1' and sig_in = '1' then
				next_state <= 0;
			else
				start <= '1';
				next_state <= 1;
			end if;
		end case;
	end process comb_state_change;


	--Change state on clock
	state_reg: process( clk_50Mhz, rst ) is
	begin
		if rst = '0' then
			current_state <= 0;
		elsif clk_50Mhz'event and clk_50Mhz='1' then
			current_state <= next_state;
		end if;
	end process state_reg;	

	--Time to wait in each state
	state_timer: process(start, clk_50Mhz, rst) is
		VARIABLE counter: unsigned (log2(delay)-1 downto 0);
	begin

		if rst = '0' then
			counter := (others=>'0');
			done <= '0';
		elsif clk_50Mhz'event and clk_50Mhz='1' then
			if start='1' then
				counter := (counter+1);
				if counter = state_time then --
					done <= '1';
					counter := (others=>'0');
				else
					done <= '0';
				end if;
			else
				done <= '0';
			end if;					
		end if;
	end process state_timer;

	--Use the states to encode the output
	sig_out <= 	'0' when current_state = 1 else
				'1';

	
END signal_debounce_arch;



