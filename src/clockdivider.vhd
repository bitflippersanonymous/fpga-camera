library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY clockdivider IS
	GENERIC ( divide_by : natural );
	PORT(
		clk, rst	: in std_logic;
		slow_clk	: out std_logic);
END clockdivider;

ARCHITECTURE clockdivider_arch OF clockdivider IS
BEGIN

	counter : process(clk, rst)
		
		variable count : integer range divide_by-1 downto 0; 	--100kHz from 50Mhz
		variable toggle : std_logic;
	
	begin
		--defaults
		count := count;
		toggle := toggle;

		if rst = '0' then
			toggle := '0';
			count := 0;
		elsif clk'event and clk = '1' then
			if count = divide_by-1 then
				count := 0;
				toggle := not(toggle);
			else
				count := count + 1;
			end if;		
		end if;


	slow_clk <= toggle;


	end process counter;

END clockdivider_arch; 
