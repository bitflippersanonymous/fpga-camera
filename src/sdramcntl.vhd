--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	sdramcntl.vhd  
--
--	Written by D. Vanden Bout, Xess	Corp.
--
--	Simplifies the SDRAM on the XSA-100 board to a SRAM like interface. Handles init
-- 	bank switching and refresh.  Instantiated by ram control. Slightly modified

--**********************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.common.all;

entity sdramCntl is
	generic(
		FREQ:	natural := 50_000;		-- operating frequency in KHz
		DATA_WIDTH: natural := 16;		-- host & SDRAM data width
		HADDR_WIDTH: natural := 23;		-- host-side address width
		SADDR_WIDTH: natural := 12		-- SDRAM-side address width
	);
	port(
		clk:	in	std_logic;			-- master clock

		-- host side
		rst:		in	std_logic;				-- reset
		rd:			in	std_logic;				-- read data
		wr:			in	std_logic;				-- write data
		done:		out	std_logic;				-- read/write op done
		hAddr:		in	unsigned(HADDR_WIDTH-1 downto 0);	-- address from host
		hDIn:		in	unsigned(DATA_WIDTH-1 downto 0);	-- data from host
		hDOut:		out	unsigned(DATA_WIDTH-1 downto 0);	-- data to host
		sdramCntl_state: out std_logic_vector(3 downto 0);		

		-- SDRAM side
		cke:		out	std_logic;			-- clock-enable to SDRAM
		cs_n:		out	std_logic;			-- chip-select to SDRAM
		ras_n:	out	std_logic;				-- command input to SDRAM
		cas_n:	out	std_logic;				-- command input to SDRAM
		we_n:		out	std_logic;			-- command input to SDRAM
		ba:			out	unsigned(1 downto 0);	-- SDRAM bank address bits
		sAddr:		out	unsigned(SADDR_WIDTH-1 downto 0);	-- row/column address
		sData:		inout unsigned(DATA_WIDTH-1 downto 0);	-- in/out databus
		dqmh:		out	std_logic;			-- high databits I/O mask
		dqml:		out	std_logic			-- low databits I/O mask
	);
end sdramCntl;



architecture arch of sdramCntl is

	-- constants
	constant NRows:	natural := 4096;	-- number of rows in SDRAM
	constant NCols:	natural := 512;		-- number of columns in SDRAM
	constant ColCmdPos: natural := 10;	-- position of command bit in SDRAM column address
	constant Tinit:	natural	:= 200;		-- min initialization interval (us)
	constant Tras:	natural := 45;		-- min interval between active to precharge commands (ns)
	constant Trc:		natural := 67;	-- min interval between active to active commands (ns)
	constant Trcd:	natural := 20;		-- min interval between active and R/W commands (ns)
	constant Tref:	natural := 64_000_000;	-- maximum refresh interval (ns)
	constant Trfc:	natural := 66;		-- duration of refresh operation (ns)
	constant Trp:		natural := 20;	-- min precharge command duration (ns)
	constant Twr:		natural := 15;	-- write recovery time (ns)
	constant Ccas:	natural := 3;		-- CAS latency (cycles)
	constant Cmrd:	natural	:= 3;		-- mode register setup time (cycles)
	constant RfshCycles: natural := 8;	-- number of refresh cycles needed to init RAM

	constant ROW_LEN:			natural := log2(NRows);	-- number of row address bits
	constant COL_LEN:			natural := log2(NCols);	-- number of column address bits
	constant NORM:				natural := 1_000_000;		-- normalize ns * KHz
	constant INIT_CYCLES:	natural := 1 + ((Tinit * FREQ) / 1000);	-- SDRMA power-on initialization interval
	constant RAS_CYCLES:	natural := 1 + ((Tras * FREQ) / NORM);	-- active-to-precharge interval
	constant RC_CYCLES:		natural := 1 + ((Trc * FREQ) / NORM);	-- active-to-active interval
	constant RCD_CYCLES:	natural := 1 + ((Trcd * FREQ) / NORM);	-- active-to-R/W interval
	constant REF_CYCLES:	natural := 1 + (((Tref/NROWS) * FREQ) / NORM);	-- interval between row refreshes
	constant RFC_CYCLES:	natural := 1 + ((Trfc * FREQ) / NORM);	-- refresh operation interval
	constant RP_CYCLES:		natural := 1 + ((Trp * FREQ) / NORM);	-- precharge operation interval
	constant WR_CYCLES:		natural := 1 + ((Twr * FREQ) / NORM);	-- write recovery time
	
	-- states of the SDRAM controller state machine
	type cntlState is (
		INITWAIT,			-- initialization - waiting for power-on initialization to complete
		INITPCHG,			-- initialization - doing precharge of banks
		INITSETMODE,		-- initialization - set SDRAM mode
		INITRFSH,			-- initialization - do refreshes
		REFRESH,			-- refresh a row of the SDRAM
		RW,					-- wait for read/write operations to SDRAM
		RDDONE,				-- indicate that the SDRAM read is done
		WRDONE,				-- indicate that the SDRAM write is done
		ACTIVATE			-- open a row of the SDRAM for reading/writing
	);
	signal state_r, state_next: cntlState;	-- state register and next state

	constant AUTO_PCHG_ON:	std_logic := '1';	-- set sAddr(10) to this value to auto-precharge the bank
	constant AUTO_PCHG_OFF:	std_logic := '0';	-- set sAddr(10) to this value to disable auto-precharge
	constant ALL_BANKS:		std_logic := '1';	-- set sAddr(10) to this value to select all banks
	constant ACTIVE_BANK:	std_logic := '0';	-- set sAddr(10) to this value to select only the active bank
	signal bank: unsigned(ba'range);
	signal row: unsigned(ROW_LEN - 1 downto 0);
	signal col: unsigned(COL_LEN - 1 downto 0);
	signal col_tmp: unsigned(sAddr'high-1 downto sAddr'low);
	signal changeRow: std_logic;
	signal dirOut: std_logic;				-- high when driving data to SDRAM
	
	-- registers
	signal activeBank_r, activeBank_next: unsigned(bank'range);	-- currently active SDRAM bank
	signal activeRow_r, activeRow_next: unsigned(row'range);		-- currently active SDRAM row
	signal inactiveFlag_r, inactiveFlag_next: std_logic;	-- 1 when all SDRAM rows are inactive
	signal initFlag_r, initFlag_next: std_logic;			-- 1 when initializing SDRAM
	signal doRfshFlag_r, doRfshFlag_next: std_logic;	-- 1 when a row refresh operation is required
	signal wrFlag_r, wrFlag_next: std_logic;					-- 1 when writing data to SDRAM
	signal rdFlag_r, rdFlag_next: std_logic;					-- 1 when reading data from SDRAM
	signal rfshCntr_r, rfshCntr_next: unsigned(log2(RfshCycles+1)-1 downto 0);	-- counts initialization refreshes

	-- timer registers that count down times for various SDRAM operations
	signal timer_r, timer_next: unsigned(log2(INIT_CYCLES+1)-1 downto 0);	-- current SDRAM op time
	signal rasTimer_r, rasTimer_next: unsigned(log2(RAS_CYCLES+1)-1 downto 0);	-- active-to-precharge time
	signal wrTimer_r, wrTimer_next: unsigned(log2(WR_CYCLES+1)-1 downto 0);	-- write-to-precharge time
	signal refTimer_r, refTimer_next: unsigned(log2(REF_CYCLES+1)-1 downto 0);	-- time between row refreshes

	-- SDRAM commands
	subtype sdramCmd is unsigned(5 downto 0);
	-- cmd = (cs_n,ras_n,cas_n,we_n,dqmh,dqml)
	constant NOP_CMD:		sdramCmd := "011100";
	constant ACTIVE_CMD:	sdramCmd := "001100";
	constant READ_CMD:		sdramCmd := "010100";
	constant WRITE_CMD:		sdramCmd := "010000";
	constant PCHG_CMD:		sdramCmd := "001011";
	constant MODE_CMD:		sdramCmd := "000011";
	constant RFSH_CMD:		sdramCmd := "000111";
	signal cmd: sdramCmd;
	
	-- SDRAM mode register
	subtype sdramMode is unsigned(11 downto 0);
	constant MODE: sdramMode := "00" & "0" & "00" & "011" & "0" & "000";

	signal logic0 : std_logic;
	
begin

	logic0 <= '0';
	
	
	hDOut	<= sData(hDOut'range);	-- connect SDRAM data bus to host data bus
	sData <= hDIn(sData'range) when dirOut='1' else (others=>'Z');	-- connect host data bus to SDRAM data bus

	combinatorial: process(rd,wr,hAddr,hDIn,state_r,bank,row,col,changeRow,
		activeBank_r,activeRow_r,initFlag_r,doRfshFlag_r,rdFlag_r,wrFlag_r,
		rfshCntr_r,timer_r,rasTimer_r,wrTimer_r,refTimer_r,cmd,col_tmp,inactiveFlag_r)
	begin
		-- attach bits in command to SDRAM control signals
		(cs_n,ras_n,cas_n,we_n,dqmh,dqml) <= cmd;
		
		-- get bank, row, column from host address
		bank <= hAddr(bank'length + ROW_LEN + COL_LEN - 1 downto ROW_LEN + COL_LEN);
		row <= hAddr(ROW_LEN + COL_LEN - 1 downto COL_LEN);
		col <= hAddr(COL_LEN - 1 downto 0);
		-- extend column (if needed) until it is as large as the (SDRAM address bus - 1)
		col_tmp <= (others=>'0');		-- set it to all zeroes
		col_tmp(col'range) <= col;	-- write column into the lower bits

		-- default operations
		cke <= YES;			-- enable SDRAM clock input
		cmd <= NOP_CMD;	-- set SDRAM command to no-operation
		if initFlag_r = YES then
			cs_n <= HI;
			dqml <= HI;
			dqmh <= HI;
		end if;
		done <= NO;			-- pending SDRAM operation is not done
		ba <= bank;			-- set SDRAM bank address bits
		-- set SDRAM address to column with interspersed command bit
		sAddr(ColCmdPos-1 downto 0) <= col_tmp(ColCmdPos-1 downto 0);
		sAddr(sAddr'high downto ColCmdPos+1) <= col_tmp(col_tmp'high downto ColCmdPos); 
		sAddr(ColCmdPos) <= AUTO_PCHG_OFF;	-- set command bit to disable auto-precharge
		dirOut <= NO;
	
		-- default register updates
		state_next <= state_r;
		inactiveFlag_next <= inactiveFlag_r;
		activeBank_next <= activeBank_r;
		activeRow_next <= activeRow_r;
		initFlag_next <= initFlag_r;
		doRfshFlag_next <= doRfshFlag_r;
		rdFlag_next <= rdFlag_r;
		wrFlag_next <= wrFlag_r;
		rfshCntr_next <= rfshCntr_r;
	
		-- update timers
		if timer_r /= TO_UNSIGNED(0,timer_r'length) then
			timer_next <= timer_r - 1;
		else
			timer_next <= timer_r;
		end if;
		
		if rasTimer_r /= TO_UNSIGNED(0,rasTimer_r'length) then
			rasTimer_next <= rasTimer_r - 1;
		else
			rasTimer_next <= rasTimer_r;
		end if;
		
		if wrTimer_r /= TO_UNSIGNED(0,wrTimer_r'length) then
			wrTimer_next <= wrTimer_r - 1;
		else
			wrTimer_next <= wrTimer_r;
		end if;
		
		if refTimer_r /= TO_UNSIGNED(0,refTimer_r'length) then
			refTimer_next <= refTimer_r - 1;
		else
			-- on timeout, reload the timer with the interval between row refreshes
			-- and set the flag that indicates a refresh operation is needed.
			refTimer_next <= TO_UNSIGNED(REF_CYCLES,refTimer_next'length);
			doRfshFlag_next <= YES;
		end if;

		-- determine if another row or bank in the SDRAM is being addressed
		if row /= activeRow_r or bank /= activeBank_r or inactiveFlag_r = YES then
			changeRow <= YES;
		else
			changeRow <= NO;
		end if;
		
		-- ***** compute next state and outputs *****
		
		-- SDRAM initialization			
		if state_r = INITWAIT then
			-- initiate wait for SDRAM power-on initialization
--			timer_next <= TO_UNSIGNED(INIT_CYCLES,timer_next'length);	-- set timer for init interval
			cs_n <= HI;
			dqml <= HI;
			dqmh <= HI;
			initFlag_next <= YES;			-- indicate initialization is in progress
			if timer_r = TO_UNSIGNED(0,timer_r'length) then
				state_next <= INITPCHG;	-- precharge SDRAM after power-on initialization
			end if;
			sdramCntl_state <= "0001";

		-- don't do anything if the previous operation has not completed yet.
		-- Place this before anything else so operations in the previous state
		-- complete before any operations in the new state are executed.
		elsif timer_r /= TO_UNSIGNED(0,timer_r'length) then
			sdramCntl_state <= "0000";

		elsif state_r = INITPCHG then
			cmd <= PCHG_CMD;	-- initiate precharge of the SDRAM
			sAddr(ColCmdPos) <= ALL_BANKS;	-- precharge all banks
			timer_next <= TO_UNSIGNED(RP_CYCLES,timer_next'length);	-- set timer for this operation
			-- now setup the counter for the number of refresh ops needed during initialization
			rfshCntr_next <= TO_UNSIGNED(RfshCycles,rfshCntr_next'length);
			state_next <= INITRFSH;	-- perform refresh ops after setting the mode
			sdramCntl_state <= "0010";
		elsif state_r = INITRFSH then
			-- refresh the SDRAM a number of times during initialization
			if rfshCntr_r /= TO_UNSIGNED(0,rfshCntr_r'length) then
				-- do a refresh operation if the counter is not zero yet
				cmd <= RFSH_CMD;	-- refresh command goes to SDRAM
				timer_next <= TO_UNSIGNED(RFC_CYCLES,timer_next'length);	-- refresh operation interval
				rfshCntr_next <= rfshCntr_r - 1;	-- decrement refresh operation counter
				state_next <= INITRFSH;	-- return to this state while counter is non-zero
			else
				-- refresh op counter reaches zero, so set the operating mode of the SDRAM
				state_next <= INITSETMODE;
			end if;
			sdramCntl_state <= "0100";
		elsif state_r = INITSETMODE then
			-- set the mode register in the SDRAM
			cmd <= MODE_CMD;	-- initiate loading of mode register in the SDRAM
			sAddr <= MODE;		-- output mode register bits onto the SDRAM address bits
			timer_next <= TO_UNSIGNED(Cmrd,timer_next'length);	-- set timer for this operation
			state_next <= RW;	-- process read/write operations after initialization is done
			initFlag_next <= NO;	-- reset flag since initialization is done
			sdramCntl_state <= "0011";
			
		-- refresh a row of the SDRAM when the refresh timer hits zero and sets the flag
		-- and the SDRAM is no longer being initialized or read/written.
		-- Place this before the RW state so the host can't block refreshes by doing
		-- continuous read/write operations.
		elsif doRfshFlag_r = YES and initFlag_r = NO and wrFlag_r = NO and rdFlag_r = NO then
			if rasTimer_r = TO_UNSIGNED(0,rasTimer_r'length) and wrTimer_r = TO_UNSIGNED(0,wrTimer_r'length) then
				doRfshFlag_next <= NO;		-- reset the flag that initiates a refresh operation
				cmd <= PCHG_CMD;	-- initiate precharge of the SDRAM
				sAddr(ColCmdPos) <= ALL_BANKS;	-- precharge all banks
				timer_next <= TO_UNSIGNED(RP_CYCLES,timer_next'length);	-- set timer for this operation
				inactiveFlag_next <= YES;	-- all rows are inactive after a precharge operation
				state_next <= REFRESH;	-- refresh the SDRAM after the precharge
			end if;
			sdramCntl_state <= "0101";
		elsif state_r = REFRESH then
			cmd <= RFSH_CMD;			-- refresh command goes to SDRAM
			timer_next <= TO_UNSIGNED(RFC_CYCLES,timer_next'length);	-- refresh operation interval
			-- after refresh is done, resume writing or reading the SDRAM if in progress
			state_next <= RW;
			sdramCntl_state <= "0110";

		-- do nothing but wait for read or write operations
		elsif state_r = RW then
			if rd = YES then
				-- the host has initiated a read operation
				rdFlag_next <= YES;		-- set flag to indicate a read operation is in progress
				-- if a different row or bank is being read, then precharge the SDRAM and activate the new row
				if changeRow = YES then
					-- wait for any row activations or writes to finish before doing a precharge
					if rasTimer_r = TO_UNSIGNED(0,rasTimer_r'length) and wrTimer_r = TO_UNSIGNED(0,wrTimer_r'length) then
						cmd <= PCHG_CMD;	-- initiate precharge of the SDRAM
						sAddr(ColCmdPos) <= ALL_BANKS;	-- precharge all banks
						timer_next <= TO_UNSIGNED(RP_CYCLES,timer_next'length);	-- set timer for this operation
						inactiveFlag_next <= YES;	-- all rows are inactive after a precharge operation
						state_next <= ACTIVATE;	-- activate the new row after the precharge is done
					end if;
				-- read from the currently active row
				else
					cmd <= READ_CMD;	-- initiate a read of the SDRAM
					timer_next <= TO_UNSIGNED(Ccas,timer_next'length);	-- setup timer for read access
					state_next <= RDDONE;	-- read the data from SDRAM after the access time
				end if;
				sdramCntl_state <= "0111";
			elsif wr = YES then
				-- the host has initiated a write operation
				-- if a different row or bank is being written, then precharge the SDRAM and activate the new row
				if changeRow = YES then
					wrFlag_next <= YES;		-- set flag to indicate a write operation is in progress
					-- wait for any row activations or writes to finish before doing a precharge
					if rasTimer_r = TO_UNSIGNED(0,rasTimer_r'length) and wrTimer_r = TO_UNSIGNED(0,wrTimer_r'length) then
						cmd <= PCHG_CMD;	-- initiate precharge of the SDRAM
						sAddr(ColCmdPos) <= ALL_BANKS;	-- precharge all banks
						timer_next <= TO_UNSIGNED(RP_CYCLES,timer_next'length);	-- set timer for this operation
						inactiveFlag_next <= YES;	-- all rows are inactive after a precharge operation
						state_next <= ACTIVATE;	-- activate the new row after the precharge is done
					end if;
				-- write to the currently active row
				else
					cmd <= WRITE_CMD;	-- initiate the write operation
					dirOut <= YES;
					-- set timer so precharge doesn't occur too soon after write operation
					wrTimer_next <= TO_UNSIGNED(WR_CYCLES,wrTimer_next'length);
					state_next <= WRDONE;	-- go back and wait for another read/write operation
				end if;
				sdramCntl_state <= "1000";
			else
				null;	-- no read or write operation, so do nothing
				sdramCntl_state <= "1001";
			end if;

		-- enter this state when the data read from the SDRAM is available
		elsif state_r = RDDONE then
			rdFlag_next <= NO;	-- set flag to indicate the read operation is over
			done <= YES;				-- tell the host that the data is ready
			state_next <= RW;		-- go back and do another read/write operation
			sdramCntl_state <= "1010";

		-- enter this state when the data is written to the SDRAM
		elsif state_r = WRDONE then
			dirOut <= YES;
			wrFlag_next <= NO;		-- set flag to indicate the write operation is over
			done <= YES;			-- tell the host that the data is ready
			state_next <= RW;		-- go back and do another read/write operation
			sdramCntl_state <= "1011";

		-- activate a row of the SDRAM
		elsif state_r = ACTIVATE then
			cmd <= ACTIVE_CMD;	-- initiate the SDRAM activation operation
			sAddr <= (others=>'0');		-- output the address for the row that will be activated
			sAddr(row'range) <= row;
			activeBank_next <= bank;	-- remember the active SDRAM row
			activeRow_next <= row;		-- remember the active SDRAM bank
			inactiveFlag_next <= NO;	-- the SDRAM is no longer inactive
			rasTimer_next <= TO_UNSIGNED(RCD_CYCLES,rasTimer_next'length);
			timer_next <= TO_UNSIGNED(RCD_CYCLES,timer_next'length);
			state_next <= RW;	-- go back and do the read/write operation that caused this activation
			sdramCntl_state <= "1100";

		-- no operation
		else
			null;
			sdramCntl_state <= "1101";
		
		end if;
						
	end process combinatorial;


	-- update registers on the rising clock edge	
	update: process(clk)
	begin
		if clk'event and clk='1' then
			if rst = NO then
				state_r				<= INITWAIT;
				activeBank_r		<= (others=>'0');
				activeRow_r			<= (others=>'0');
				inactiveFlag_r		<= YES;
				initFlag_r			<= YES;
				doRfshFlag_r		<= NO;
				rdFlag_r			<= NO;
				wrFlag_r			<= NO;
				rfshCntr_r			<= TO_UNSIGNED(0,rfshCntr_r'length);
				timer_r				<= TO_UNSIGNED(INIT_CYCLES,timer_r'length);
				refTimer_r			<= TO_UNSIGNED(REF_CYCLES,refTimer_r'length);
				rasTimer_r			<= TO_UNSIGNED(0,rasTimer_r'length);
				wrTimer_r			<= TO_UNSIGNED(0,wrTimer_r'length);
			else
				state_r				<= state_next;
				activeBank_r		<= activeBank_next;
				activeRow_r			<= activeRow_next;
				inactiveFlag_r		<= inactiveFlag_next;
				initFlag_r			<= initFlag_next;
				doRfshFlag_r		<= doRfshFlag_next;
				rdFlag_r			<= rdFlag_next;
				wrFlag_r			<= wrFlag_next;
				rfshCntr_r			<= rfshCntr_next;
				timer_r				<= timer_next;
				refTimer_r			<= refTimer_next;
				rasTimer_r			<= rasTimer_next;
				wrTimer_r			<= wrTimer_next;
			end if;
		end if;
	end process update;

end arch;
