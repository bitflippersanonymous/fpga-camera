--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	master_control_signal_generator.vhd  aka MCSG
--
--	Recv's commands from pport.  Controls other components. Startup delay.
--
--**********************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.common.all;
use work.comp_pckgs.all;

ENTITY master_control_signal_generator IS
	PORT
	(
		clk_50Mhz: in std_logic;
		clk_12_5Mhz	: in std_logic;
		clk_pp: in std_logic;
		rst: in std_logic;
		cmd: in std_logic_vector(5 downto 0);
		start_upload: out std_logic;
		abort_upload: out std_logic;
		start_addr: out std_logic_vector(22 downto 0);
		end_addr: out std_logic_vector(22 downto 0);
		init_cycle_complete: out std_logic;

		init_KAC 	: out std_logic;
		sync_KAC 	: out std_logic;				-- out KAC sync pin
		start_KAC 	: out std_logic;
		done_KAC	: in std_logic;
		r_w_KAC  	: out std_logic;						-- 0=read 1=write
		Addr_KAC 	: out std_logic_vector(7 downto 0);
		Data_KAC_in : out std_logic_vector(7 downto 0);	
		Data_KAC_out: in std_logic_vector(7 downto 0)	

	);
	
END master_control_signal_generator;

ARCHITECTURE MCSG_arch OF master_control_signal_generator IS

--KAC Signals	
	--States to control KAC via I2C
	subtype state_KAC is integer range 3 downto 0; 
	signal current_state_KAC, next_state_KAC: state_KAC;

	signal init_cycle_complete_r : std_logic;
	signal delay_start : std_logic;
	signal delay_complete : std_logic;
	
--PP signals	
	-- States to read commands from pc
	subtype state is integer range 15 downto 0; 
	signal current_state, next_state: state;
	
	signal start_addr_r, start_addr_next: std_logic_vector(22 downto 0);
	signal end_addr_r, end_addr_next: std_logic_vector(22 downto 0);
	signal start_upload_sig, abort_upload_sig: std_logic;
	
	--Names for Parallel port commands
	constant NOP:	std_logic_vector(5 downto 0) := "000000";  
	constant STARTUPLOAD:	std_logic_vector(5 downto 0) := "000001";
	constant ABORTUPLOAD:	std_logic_vector(5 downto 0) := "000010";
	
	constant READ : std_logic := '0';
	constant WRITE : std_logic := '1';

	

BEGIN

	init_cycle_complete <= init_cycle_complete_r;	

	--KAC I2C stuff
	sync_KAC <= '0';								-- out KAC sync pin
	Start_KAC <= '1' when init_cycle_complete_r = '1' else '0';
	r_w_KAC <= READ;
	Addr_KAC <= x"0F";
	Data_KAC_in <= x"55";

	
	--PP 
	start_addr <= start_addr_r;
	end_addr <= end_addr_r;	
	
	--signal oneshots.  The commands are coming in off the parallel port so this state
	--machine is controlled with that clock.  The problem is, the start_upload and abort_upload
	--signals to the memory controller will not match the 50MHz clock.  If they are high 
	--for one state here, then they would be high for thousands of 50Mhz clk cycles.  The one
	--shot makes them just go high for 1 50MHz cycle.
	start_upload_oneshot: one_shot
	port map 
    (
        CLK => clk_50Mhz,				
    	RST => rst,
		sig_in => start_upload_sig,
		sig_out => start_upload
	);
	
	abort_upload_oneshot: one_shot
	port map 
    (
        CLK => clk_50Mhz,				
    	RST => rst,
		sig_in => abort_upload_sig,
		sig_out => abort_upload
	);
	
	wait_for_KAC_to_init: ms_delay
	PORT MAP
		(
			clk => clk_12_5Mhz,
			rst => rst,
			start => delay_start,	--also starts on reset
			delay_complete => delay_complete
		);	


------------------------------------------------------------------------------------
-- PC command reader
-- this is a huge state machine that can easily be reduced down.  
-- States 1 - 9 could all be one state.  The bit order for start and end addr look 
-- a little funny but it's a right shift that makes the host software a little 
-- easier.

	pc_command_reader: process(current_state, cmd, start_addr_r, end_addr_r) is
	begin

		--default actions
		next_state <= current_state;
		start_addr_next <= start_addr_r;	
		end_addr_next <= end_addr_r;
		start_upload_sig <= '0';
		abort_upload_sig <= '0';	 		

		case current_state is
		when 0 =>											--NOP
			if cmd = STARTUPLOAD then
				next_state <= 1;
			elsif cmd = ABORTUPLOAD then
				next_state <= 10;
			else
				next_state <= 0;
			end if;
		
		when 1 =>											--Start Upload
			start_addr_next(5 downto 0) <= cmd;
			next_state <= 2;
	
		when 2 =>											--Load start addr
			start_addr_next(11 downto 6) <= cmd;
			next_state <= 3;

		when 3 =>
			start_addr_next(17 downto 12) <= cmd;
			next_state <= 4;

		when 4 =>
			start_addr_next(22 downto 18) <= cmd(4 downto 0);
			next_state <= 5;

		when 5 =>
			end_addr_next(5 downto 0) <= cmd;
			next_state <= 6;

		when 6 =>
			end_addr_next(11 downto 6) <= cmd;
			next_state <= 7;

		when 7 =>
			end_addr_next(17 downto 12) <= cmd;
			next_state <= 8;

		when 8 =>
			end_addr_next(22 downto 18) <= cmd(4 downto 0);
			next_state <= 9;
		
		when 9 =>				-- Could also branch to any other action
			start_upload_sig <= '1';
			if cmd = STARTUPLOAD then   
				next_state <= 1;
			elsif cmd = ABORTUPLOAD then
				next_state <= 10;
			else
				next_state <= 0;
			end if;


		when 10 =>
			abort_upload_sig <= '1';
			start_addr_next <= (others=>'0');
			end_addr_next <= (others=>'0');
			next_state <= 0;
		
		when others =>
			next_state <= 0;

		end case;
	end process pc_command_reader;


	--Change state on clock
	state_reg: process( clk_pp, rst ) is
	begin
		if rst = '0' then
			current_state <= 0;
			start_addr_r <= (others=>'0');
			end_addr_r <= (others=>'0');
		elsif clk_pp'event and clk_pp='1' then
			--Update state and registers
			current_state <= next_state;
			start_addr_r <= start_addr_next;
			end_addr_r <= end_addr_next;			
		end if;
	end process state_reg;	


	
------------------------------------------------------------------------------------	
-- KAC control																		
-- Cycle the init pulse on powerup.  
-- 0 then 1 then wait 1ms then 0 and init_cycle_complete
-- is asserted until reset.	
-- Also, SDRAM needs 200us of delay for startup


	KAC_Control: process(current_state_KAC, delay_complete) is
	begin

		--default actions
		next_state_KAC <= current_state_KAC;
		delay_start <= '0';
		init_cycle_complete_r <= '0';
		init_KAC <= '0';					--'0' Active '1' standby mode

		case current_state_KAC is
		when 0 =>										
			next_state_KAC <= 1;
			init_KAC <= '1';

		when 1 =>	
			delay_start <= '1';	
			init_KAC <= '1';		
						
			if delay_complete = '1' then
				next_state_KAC <= 2;
			end if;

		when 2 =>										
			delay_start <= '1';
							
			if delay_complete = '1' then
				next_state_KAC <= 3;
			end if;

		when 3 =>										
			init_cycle_complete_r <= '1';



		end case;
	end process KAC_Control;


	--Change state on clock
	KAC_state_update: process( clk_12_5Mhz, rst ) is
	begin
		if rst = '0' then
			current_state_KAC <= 0;
		elsif clk_12_5Mhz'event and clk_12_5Mhz='1' then 
			current_state_KAC <= next_state_KAC;
		end if;
	end process KAC_state_update;	




	
END MCSG_arch;



