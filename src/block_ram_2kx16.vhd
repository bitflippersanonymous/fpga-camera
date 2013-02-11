----------------------------------------------------------------------
-- This file is owned and controlled by Xilinx and must be used     --
-- solely for design, simulation, implementation and creation of    --
-- design files limited to Xilinx devices or technologies. Use      --
-- with non-Xilinx devices or technologies is expressly prohibited  --
-- and immediately terminates your license.                         --
--                                                                  --
-- Xilinx products are not intended for use in life support         --
-- appliances, devices, or systems. Use in such applications are    --
-- expressly prohibited.                                            --
--                                                                  --
-- Copyright (C) 2001, Xilinx, Inc.  All Rights Reserved.           --
----------------------------------------------------------------------

-- You must compile the wrapper file block_ram_2kx16.vhd when simulating
-- the core, block_ram_2kx16. When compiling the wrapper file, be sure to
-- reference the XilinxCoreLib VHDL simulation library. For detailed
-- instructions, please refer to the "Coregen Users Guide".

-- The synopsys directives "translate_off/translate_on" specified
-- below are supported by XST, FPGA Express, Exemplar and Synplicity
-- synthesis tools. Ensure they are correct for your synthesis tool(s).

-- synopsys translate_off
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

Library XilinxCoreLib;
ENTITY block_ram_2kx16 IS
	port (
	addr: IN std_logic_VECTOR(10 downto 0);
	clk: IN std_logic;
	din: IN std_logic_VECTOR(15 downto 0);
	dout: OUT std_logic_VECTOR(15 downto 0);
	sinit: IN std_logic;
	we: IN std_logic);
END block_ram_2kx16;

ARCHITECTURE block_ram_2kx16_a OF block_ram_2kx16 IS

component wrapped_block_ram_2kx16
	port (
	addr: IN std_logic_VECTOR(10 downto 0);
	clk: IN std_logic;
	din: IN std_logic_VECTOR(15 downto 0);
	dout: OUT std_logic_VECTOR(15 downto 0);
	sinit: IN std_logic;
	we: IN std_logic);
end component;

-- Configuration specification 
	for all : wrapped_block_ram_2kx16 use entity XilinxCoreLib.blkmemsp_v3_1(behavioral)
		generic map(
			c_reg_inputs => 0,
			c_addr_width => 11,
			c_has_sinit => 1,
			c_has_rdy => 0,
			c_width => 16,
			c_has_en => 0,
			c_mem_init_file => "mif_file_16_1",
			c_depth => 2047,
			c_has_nd => 0,
			c_has_default_data => 1,
			c_default_data => "0",
			c_limit_data_pitch => 8,
			c_pipe_stages => 0,
			c_has_rfd => 0,
			c_has_we => 1,
			c_sinit_value => "0",
			c_has_limit_data_pitch => 0,
			c_enable_rlocs => 0,
			c_has_din => 1,
			c_write_mode => 0);
BEGIN

U0 : wrapped_block_ram_2kx16
		port map (
			addr => addr,
			clk => clk,
			din => din,
			dout => dout,
			sinit => sinit,
			we => we);
END block_ram_2kx16_a;

-- synopsys translate_on

