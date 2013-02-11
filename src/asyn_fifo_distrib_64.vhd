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

-- You must compile the wrapper file asyn_fifo_distrib_64.vhd when simulating
-- the core, asyn_fifo_distrib_64. When compiling the wrapper file, be sure to
-- reference the XilinxCoreLib VHDL simulation library. For detailed
-- instructions, please refer to the "Coregen Users Guide".

-- The synopsys directives "translate_off/translate_on" specified
-- below are supported by XST, FPGA Express, Exemplar and Synplicity
-- synthesis tools. Ensure they are correct for your synthesis tool(s).

-- synopsys translate_off
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

Library XilinxCoreLib;
ENTITY asyn_fifo_distrib_64 IS
	port (
	din: IN std_logic_VECTOR(15 downto 0);
	wr_en: IN std_logic;
	wr_clk: IN std_logic;
	rd_en: IN std_logic;
	rd_clk: IN std_logic;
	ainit: IN std_logic;
	dout: OUT std_logic_VECTOR(15 downto 0);
	full: OUT std_logic;
	empty: OUT std_logic;
	almost_full: OUT std_logic;
	almost_empty: OUT std_logic;
	wr_count: OUT std_logic_VECTOR(3 downto 0);
	rd_count: OUT std_logic_VECTOR(3 downto 0));
END asyn_fifo_distrib_64;

ARCHITECTURE asyn_fifo_distrib_64_a OF asyn_fifo_distrib_64 IS

component wrapped_asyn_fifo_distrib_64
	port (
	din: IN std_logic_VECTOR(15 downto 0);
	wr_en: IN std_logic;
	wr_clk: IN std_logic;
	rd_en: IN std_logic;
	rd_clk: IN std_logic;
	ainit: IN std_logic;
	dout: OUT std_logic_VECTOR(15 downto 0);
	full: OUT std_logic;
	empty: OUT std_logic;
	almost_full: OUT std_logic;
	almost_empty: OUT std_logic;
	wr_count: OUT std_logic_VECTOR(3 downto 0);
	rd_count: OUT std_logic_VECTOR(3 downto 0));
end component;

-- Configuration specification 
	for all : wrapped_asyn_fifo_distrib_64 use entity XilinxCoreLib.async_fifo_v3_0(behavioral)
		generic map(
			c_wr_count_width => 4,
			c_has_rd_err => 0,
			c_data_width => 16,
			c_has_almost_full => 1,
			c_rd_err_low => 0,
			c_has_wr_ack => 0,
			c_wr_ack_low => 0,
			c_fifo_depth => 63,
			c_rd_count_width => 4,
			c_has_wr_err => 0,
			c_has_almost_empty => 1,
			c_rd_ack_low => 0,
			c_has_wr_count => 1,
			c_use_blockmem => 0,
			c_has_rd_ack => 0,
			c_has_rd_count => 1,
			c_wr_err_low => 0,
			c_enable_rlocs => 0);
BEGIN

U0 : wrapped_asyn_fifo_distrib_64
		port map (
			din => din,
			wr_en => wr_en,
			wr_clk => wr_clk,
			rd_en => rd_en,
			rd_clk => rd_clk,
			ainit => ainit,
			dout => dout,
			full => full,
			empty => empty,
			almost_full => almost_full,
			almost_empty => almost_empty,
			wr_count => wr_count,
			rd_count => rd_count);
END asyn_fifo_distrib_64_a;

-- synopsys translate_on

