--**********************************************************************************

-- 	Copyright 2013, Ryan Henderson
--	CMOS digital camera controller and frame capture device
--
--	KAC_i2c.vhd
--
--	Provides direct access to control registers in image sensor. SRAM like interface
--	makes I2C interface transparent to MCSG.  Adapted from Dallas 1621 interface
--	by Richard Herveille OpenCores.
--
--**********************************************************************************



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use work.i2c.all;


entity KAC_i2c is
	generic ( I2C_ADDR : std_logic_vector(6 downto 0) );
	port (
		clk : in std_logic;
		nReset : in std_logic;
		start_KAC 	: in std_logic;
		done_KAC	: out std_logic;
		r_w_KAC  	: in std_logic;	--0=read 1=write
		Addr_KAC 	: in std_logic_vector(7 downto 0);
		Data_KAC_in : in std_logic_vector(7 downto 0);	
		Data_KAC_out: out std_logic_vector(7 downto 0);	

		SCL : inout std_logic;
		SDA : inout std_logic
	);
end entity KAC_i2c;

architecture KAC_i2c_arch of KAC_i2c is
	-- Remove the generic defining the constant
	constant SLAVE_ADDR : std_logic_vector(6 downto 0) := I2C_ADDR;
	constant CLK_CNT : unsigned(7 downto 0) := conv_unsigned(100, 8); --from 50Mhz

	signal cmd_ack : std_logic;
	signal D : std_logic_vector(7 downto 0);
	signal lack, store_dout : std_logic;

	signal start, read, write, ack, stop : std_logic;
	signal i2c_dout : std_logic_vector(7 downto 0);
	
begin
	-- hookup I2C controller
	u1: simple_i2c 
	port map ( clk => clk, ena => '1', clk_cnt => clk_cnt, nReset => nReset, 
				read => read, write => write, start => start, stop => stop, 
				ack_in => ack, cmd_ack => cmd_ack, Din => D, Dout => i2c_dout, 
				ack_out => lack, SCL => SCL, SDA => SDA);

	init_statemachine : block
		type states is (i1, i2, i3, t1, t2, t3, t4, ack_wait_read, 
							ack_wait_write, idle);
		signal state : states;
	begin
		-- There are a bunch of signals that should be in this sensitivity list, 
		-- but when I added them, things stopped working. I'll just leave it alone.
		nxt_state_decoder: process(clk, nReset, state, start_KAC, r_w_KAC)
			variable nxt_state : states;
			variable iD : std_logic_vector(7 downto 0);
			variable ierr : std_logic;
			variable istart, iread, iwrite, iack, istop : std_logic;
			variable istore_dout : std_logic;
			variable wait_for_ack : std_logic;

		begin
			nxt_state := state;
			ierr := '0';
			istore_dout := '0';
			done_KAC <= '0';

			istart := start;
			iread := read;
			iwrite := write;
			iack := ack;
			istop := stop;
			iD := D;

			case (state) is

				-- Write Sequence
				when i1 =>	-- send start condition, sent slave address + write
						nxt_state := i2;
						istart := '1';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '0';
						iD := (slave_addr & '0'); -- write to slave (R/W = '0')

				when i2 =>	-- send reg addr
					if (cmd_ack = '1') then
						nxt_state := i3;

						istart := '0';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '0';
						iD := Addr_KAC;
					end if;

				when i3 =>	-- send data to write there
					if (cmd_ack = '1') then
						nxt_state := ack_wait_write;

						istart := '0';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '1';
						iD := Data_KAC_in;
					end if;


				-- Read Sequence
				when t1 =>	-- send start condition, sent slave address + write
				--	if (cmd_ack = '1') then
						nxt_state := t2;

						istart := '1';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '0';
						iD := (slave_addr & '0'); -- write to slave (R/W = '0')
				--	end if;

				when t2 =>	-- send reg addr
					if (cmd_ack = '1') then
						nxt_state := t3;

						istart := '0';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '0';
						iD := Addr_KAC;
					end if;

				-- send (repeated) start condition, send slave address + read
				when t3 =>	
					if (cmd_ack = '1') then
						nxt_state := t4;

						istart := '1';
						iread := '0';
						iwrite := '1';
						iack := '0';
						istop := '0';
						iD := (slave_addr & '1'); -- read from slave (R/W = '1')
					end if;

				when t4 =>	
					if (cmd_ack = '1') then
						nxt_state := ack_wait_read;	

						istart := '0';
						iread := '1';
						iwrite := '0';
						iack := '1'; --ACK
						istop := '1';
						--istore_dout := '1';
					end if;

				when ack_wait_read =>	
					if (cmd_ack = '1') then
						nxt_state := idle;
						istart := '0';
						iread := '0';
						iwrite := '0';
						iack := '0';
						istop := '0';
						iD := x"00";
						done_KAC <= '1';
						istore_dout := '1';	-- Capture the value read
					end if;

				when ack_wait_write =>	
					if (cmd_ack = '1') then
						nxt_state := idle;
						istart := '0';
						iread := '0';
						iwrite := '0';
						iack := '0';
						istop := '0';
						iD := x"00";
						done_KAC <= '1';
					end if;

			
				when idle =>
					if start_KAC = '1' then
						if r_w_KAC = '0' then
							nxt_state := t1;	--do read
						else
							nxt_state := i1;	--do write
						end if;
					end if;
					
					--safe idle conditions and done
					istart := '0';
					iread := '0';
					iwrite := '0';
					iack := '0';
					istop := '0';
					iD := x"00";
					done_KAC <= '1';
	
			end case;

			

			-- genregs
			if (nReset = '0') then
				state <= idle;
				store_dout <= '0';
				start <= '0';
				read <= '0';
				write <= '0';
				ack <= '0';
				stop <= '0';
				D <= (others => '0');
				wait_for_ack := '0';
			elsif (clk'event and clk = '1') then
				state <= nxt_state;
				store_dout <= istore_dout;

				start <= istart;
				read <= iread;
				write <= iwrite;
				ack <= iack;
				stop <= istop;
				D <= iD;
			end if;
		end process nxt_state_decoder;
	end block init_statemachine;

	-- store temp
	gen_dout : process(clk)
	begin
		if (clk'event and clk = '1') then
			if (store_dout = '1') then
				Data_KAC_out <= i2c_dout; 
			end if;
		end if;
	end process gen_dout;


end architecture KAC_i2c_arch;


