--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	one_shot.vhd  
--
--	Reduces when a positive edge is detected on the input signal, a 1 clock long
--	high is output on sig_out.
--
--**********************************************************************************



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


ENTITY one_shot IS
	PORT
	(
		clk: in std_logic;
		sig_in: in std_logic;  
		rst: in std_logic;
		sig_out: out std_logic

	);
	
END one_shot;

ARCHITECTURE one_shot_arch OF one_shot IS

	
	subtype state is integer range 2 downto 0; 
	SIGNAL current_state, next_state: state;
	


BEGIN
	
	
	comb_state_change: process(current_state, sig_in) is
	begin

		--default actions
		next_state <= current_state;

		case current_state is
		when 0 =>					
			sig_out <= '0';
			if sig_in = '1' then
				next_state <= 1;
			end if;
		when 1 =>	
			sig_out <= '1';			
			next_state <= 2;

		when 2 =>					
			sig_out <= '0';
			if sig_in = '0' then
				next_state <= 0;
			end if;

		end case;
	end process comb_state_change;


	--Change state on clock
	state_reg: process( clk, rst ) is
	begin
		if rst = '0' then
			current_state <= 0;
		elsif clk'event and clk='1' then  
			current_state <= next_state;
		end if;
	end process state_reg;	

	
END one_shot_arch;



