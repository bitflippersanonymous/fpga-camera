--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	pullup.vhd
--
--	Used in testbench to pull up I2C lines

--**********************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;


entity PULLUP is
    port(v101: OUT std_logic);
end PULLUP;

architecture archPULLUP of PULLUP is
    
    
begin
    v101 <= 'H';
    
end archPULLUP;
