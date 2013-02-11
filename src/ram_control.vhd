--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	ram_control.vhd  
--
--	
-- Memory arbitrator.  Handle access to memory. Control the FIFOs in other modules
-- Incorporates SDRAM controller. 

--**********************************************************************************



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.common.all;
use work.comp_pckgs.all;

ENTITY ram_control IS

	PORT
	(
		clk_50Mhz: in std_logic;
		rst: in std_logic;
		
		-- PP RAM access.  Control provided by MCSG
		pp_data_out 		: out std_logic_vector(15 downto 0); 
		start_upload 		: in std_logic;
		abort_upload 		: in std_logic;
		start_addr_upload 	: in std_logic_vector(22 downto 0);
		end_addr_upload 	: in std_logic_vector(22 downto 0);
		pp_fifo_wr_en 		: out std_logic;
		pp_fifo_need_data 	: in std_logic;

		-- KAC RAM access
		rd_en_KAC			: out std_logic;
		dout_KAC			: in std_logic_vector(15 downto 0);
		dump_data_req_KAC	: in std_logic;
		start_new_frame		: in std_logic;
	

		-- SDRAM side
		cke:		out	std_logic;				-- clock-enable to SDRAM
		cs_n:		out	std_logic;				-- chip-select to SDRAM
		ras_n:		out	std_logic;				-- command input to SDRAM
		cas_n:		out	std_logic;				-- command input to SDRAM
		we_n:		out	std_logic;				-- command input to SDRAM
		ba:			out	unsigned(1 downto 0);	-- SDRAM bank address bits
		sAddr:		out	unsigned(12-1 downto 0);	-- SDRAM row/column address
		sData:		inout unsigned(16-1 downto 0);	-- SDRAM in/out databus
		dqmh:		out	std_logic;					-- high databits I/O mask
		dqml:		out	std_logic					-- low databits I/O mask

	);
	
END ram_control;

ARCHITECTURE ram_control_arch OF ram_control IS

	-- Constants
	constant HRES : natural := 1280;
	constant VRES : natural := 1024;

	--Flags pport, misc
	signal uploading		: std_logic;
	signal pp_addr_pointer	: unsigned(19 downto 0);	
	signal pp_ram_page 		: unsigned(2 downto 0);		--Current readout page
	
	signal ram_page_full	: unsigned(2 downto 0); 	--Complete frame	
	signal ram_addr 		: unsigned(22 downto 0);	

	type semaphore is (NOBODY, KAC, PPORT);
	signal SDRAM_used_by 	: semaphore;

	--KAC signals
	signal addr_ptr_KAC 	: unsigned(19 downto 0);	
	signal ram_page_KAC		: unsigned(2 downto 0);		--Current writeout page


	--SDRAM Signals and constants
	signal rd, rd_next 		: std_logic;
	signal wr 				: std_logic;
	signal done 			: std_logic;
	signal hDOut 			: unsigned(16-1 downto 0);	-- Type conversion
	signal sdramCntl_state : std_logic_vector(3 downto 0);		
	
BEGIN

	pp_fifo_wr_en <= '1' when done = '1' and rd = '1' else '0';
	rd_en_KAC <= '1' when done = '1' and wr = '1' else '0';

	pp_data_out <= std_logic_vector(hDOut); --Conversions are fun! 

	-- The rd_en for the KAC_data fifo also can enable the write for the memory.
	-- Data  in: Enable KAC_data fifo read and RAM Write
	-- Data out: Enable PP_Fifo write and RAM read

--	B5 : block_ram_2kx16
--	port map 
--	(
--		addr => std_logic_vector(ram_addr(10 downto 0)),
--		clk => clk_50Mhz,
--		sinit => not_rst,
--		din => dout_KAC,
--		dout => pp_data_out,
--		we => rd_en_KAC_sig			 
--	);
	


	-- SDRAM memory controller module
	u1: sdramCntl
	generic map(
		FREQ => 50_000,								-- 50 MHz operation
		DATA_WIDTH => 16,
		HADDR_WIDTH => 23,
		SADDR_WIDTH => 12
	)
	port map(
		clk => clk_50Mhz, 				-- master clock
		rst => rst,						-- active high reset
		rd => rd,						-- SDRAM read control 
		wr => wr,						-- SDRAM write control 
		done => done,					-- SDRAM memory read/write done indicator
		hAddr => ram_addr,				-- host-side address from memory tester
		hDIn => unsigned(dout_KAC),		-- Data into sdram controller
		hDOut => hDOut,					-- data from SDRAM
		sdramCntl_state => sdramCntl_state,		-- (for testing)
		cke => cke,						-- SDRAM clock enable
		cs_n => cs_n,					-- SDRAM chip-select
		ras_n => ras_n,					-- SDRAM RAS
		cas_n => cas_n,					-- SDRAM CAS
		we_n => we_n,					-- SDRAM write-enable
		ba => ba,						-- SDRAM bank address
		sAddr => sAddr,					-- SDRAM address
		sData => sData,					-- SDRAM databus
		dqmh => dqmh,					-- SDRAM DQMH
		dqml => dqml					-- SDRAM DQML
	);


	-- Determine which address to use for ram
	ram_addr <= (others=>'0') when rst = '0' else 
				ram_page_KAC & addr_ptr_KAC when wr = '1' else
				pp_ram_page & pp_addr_pointer;


	-- Page the memory to prevent over writing
	ram_page: process (rst, clk_50Mhz, start_new_frame, ram_page_full, pp_ram_page,
						ram_page_KAC, start_upload ) is
			
	--Do I need to make a temp variable for the swap? NOPE!
	begin
		
		if rst = '0' then
			ram_page_KAC <= "000";
			ram_page_full <= "001";
			pp_ram_page <= "010";

		elsif clk_50Mhz'event and clk_50Mhz = '1' then

			-- They both could happen in the same 50Mhz clock.  unlikely, 
			-- but possible
			if start_new_frame = '1' and start_upload = '1' then
				pp_ram_page <= ram_page_KAC;				

			elsif start_new_frame = '1' then
				ram_page_full <= ram_page_KAC;
				ram_page_KAC <= ram_page_full;
			
			elsif start_upload = '1' then
				pp_ram_page <= ram_page_full;
				ram_page_full <= pp_ram_page;
			
			end if;
	
		end if;
	
	end process ram_page;



	-- Control access to the SDRAM with a semaphore.  When a FIFO request action, 
	-- respond by locking control of the memory, or waiting.  If memory is 
	-- available, signal the fifo to start transfering, and set SDRAM control 
	-- bits rd and wr.
	sem_control: process(clk_50Mhz, rst, SDRAM_used_by, pp_fifo_need_data, 
							dump_data_req_KAC, uploading, addr_ptr_KAC) is
	begin
		if rst='0' then
			rd_next <= '0';
			rd <= '0';
			SDRAM_used_by <= NOBODY;			
			wr <= '0';

		else
			
			--take semaphore
			if pp_fifo_need_data = '1' and uploading = '1' 
				and (SDRAM_used_by = NOBODY or SDRAM_used_by = PPORT) then
				
				SDRAM_used_by <= PPORT;				
				rd_next <= '1';		--SDRAM read
			
			elsif dump_data_req_KAC = '1' 
				and (SDRAM_used_by = NOBODY or SDRAM_used_by = KAC) then
		
				SDRAM_used_by <= KAC;
				wr <= '1';   
				
			else
	
				-- Default values if not specified below
				-- Done with transfer, release control of memory
				-- or it's not needed
				rd_next <= '0';
				wr <= '0';
				SDRAM_used_by <= NOBODY;
			
			end if;

			-- Delay the pp_fifo_wr_en signal by one clock to account for delay
			if clk_50Mhz'event and clk_50Mhz = '1' then
				rd <= rd_next;			
			end if;

		end if;
	end process sem_control;

	-- Control the KAC address pointer.  Reset it when a new frame is signaled.
	-- Only increment it once after a write is completed.  Prevent writing into
	-- next frame if there is no new frame signal
	KAC_fifo_empty: process(clk_50Mhz, rst, start_new_frame, wr, done, 
								addr_ptr_KAC ) is
	begin
		if rst='0' then
			addr_ptr_KAC <= (others=>'0');

		elsif clk_50Mhz'event and clk_50Mhz='1' then
			if start_new_frame = '1' then
				addr_ptr_KAC <= (others=>'0');
			elsif wr = '1' and done = '1' then					
				if addr_ptr_KAC < 655360 then  			-- Don't wrap around
					addr_ptr_KAC <= addr_ptr_KAC + 1;

				end if;

			end if;
		end if;

	end process KAC_fifo_empty;

	-- When the fifo needs data, check to see if memory is available, then set the 
	-- write flag and start clocking data at the fifo until it lowers need_data.	
	-- Update process to add new sdram stuff. Control how the address for the pport 
	-- is set
	pp_fifo_fill: process(clk_50Mhz, rst, pp_fifo_need_data, start_upload, 
			abort_upload, start_addr_upload, end_addr_upload, pp_addr_pointer) is
	begin
		if rst='0' then
			pp_addr_pointer <= (others=>'0');
			uploading <= '0';

		else

			--clocked events
			if clk_50Mhz'event and clk_50Mhz='1' then
				if start_upload = '1' then
					uploading <= '1';
					pp_addr_pointer <= unsigned(start_addr_upload(19 downto 0));
				
				elsif abort_upload = '1' or pp_addr_pointer > 
						unsigned(end_addr_upload(19 downto 0)) then
					uploading <= '0';
					pp_addr_pointer <= (others=>'0');
				
				--  Inc on done signal generated by sdram  
				elsif rd = '1' and done = '1' then 
					pp_addr_pointer <= pp_addr_pointer + 1;	
			
				end if;


			end if;
		end if;
	end process pp_fifo_fill;
	
END ram_control_arch;
















