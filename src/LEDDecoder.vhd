--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	LEDDecoder.vhd
--
--
--**********************************************************************************


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity LEDDecoder is
    Port ( d : in std_logic_vector(3 downto 0);
           s : out std_logic_vector(6 downto 0));
end LEDDecoder;

architecture Behavioral of LEDDecoder is

begin
	
	s <= 	"1110111" when d=x"0" else
			"0010010" when d=x"1" else
			"1011101" when d=x"2" else
			"1011011" when d=x"3" else
			"0111010" when d=x"4" else
			"1101011" when d=x"5" else
			"1101111" when d=x"6" else
			"1010010" when d=x"7" else
			"1111111" when d=x"8" else
			"1111011" when d=x"9" else
			"1111110" when d=x"A" else
			"0101111" when d=x"B" else
			"0001101" when d=x"C" else
			"0011111" when d=x"D" else
			"1101101" when d=x"E" else
			"1101100";

end Behavioral;
