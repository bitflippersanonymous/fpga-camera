--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	ms_delay.vhd  
--
--	Used by MCSG for startup delay.  Actually 320us, needs to be increased
--
--**********************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


ENTITY ms_delay IS
	PORT(
		clk, rst, start	: in std_logic;
		delay_complete	: out std_logic);
END ms_delay;

ARCHITECTURE ms_delay_arch OF ms_delay IS
BEGIN

	counter : process(clk, rst, start)
		
		variable count : integer range 800 downto 0; 	
	
	begin
		--defaults
		count := count;

		if rst = '0' or start = '0' then
			count := 0;
			delay_complete <= '0';	
		elsif clk'event and clk = '1' then
			if count = 800 then
				delay_complete <= '1';
				count := 0;
			else
				count := count + 1;
				delay_complete <= '0';	
			end if;	
		end if;


		end process counter;

END ms_delay_arch; 
