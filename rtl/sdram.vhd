----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: sdram.vhdl
-- Description: SDRAM controller
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity sdram is
	generic (
		constant cas_lat : std_logic_vector(1 downto 0) := "10"; -- CL = 2
		constant IN_FREQ : integer                      := 120   -- Input Clock Frequency = 120,000,000 Hz
	);
	port (
		-- Host side
		clk_in              : in std_logic;
		reset               : in std_logic                     := '0';
		rw                  : in std_logic                     := '0'; -- [ 0-> Read , 1-> Write ]
		exe                 : in std_logic                     := '0';
		stop                : in std_logic                     := '0';
		burst_len           : in integer range 0 to 256        := 0;
		addr                : in std_logic_vector(21 downto 0) := (others => '0'); -- Address from host to SDRAM
		data_w              : in std_logic_vector(15 downto 0) := (others => '0'); -- Data from host to SDRAM
		ready               : out std_logic                    := '0';             -- Set to '1' when the memory is ready
		data_r              : out std_logic_vector(15 downto 0);                   -- Data from SDRAM to host
		data_is_ready       : out std_logic := '0';                                -- Set to '1' when the data is ready to read
		ready_to_write      : out std_logic := '0';
		initialization_done : out std_logic := '0';
		-- SDRAM side
		cke     : out std_logic; -- Clock-enable to SDRAM
		clk     : out std_logic;
		cs      : out std_logic;                       -- Chip-select to SDRAM
		ras     : out std_logic;                       -- SDRAM row address strobe
		cas     : out std_logic;                       -- SDRAM column address strobe
		we      : out std_logic;                       -- SDRAM write enable
		bank    : out std_logic_vector(1 downto 0);    -- SDRAM bank address
		address : out std_logic_vector(11 downto 0);   -- SDRAM row/column address
		data    : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
		dum     : out std_logic;                       -- Enable upper-byte of SDRAM databus if true
		dlm     : out std_logic                        -- Enable lower-byte of SDRAM databus if true
	);
end sdram;

architecture Behavioral of sdram is

	--Types
	type fsm_sdram_type is (
		SDR_INIT_WAIT, SDR_INIT_START, SDR_INIT_PRECHARGE, SDR_INIT_REFRESH1, SDR_INIT_MODE, SDR_INIT_REFRESH2, SDR_IDLE,
		SDR_START_RW, SDR_RW, SDR_TERM_R1, SDR_TERM_R2, SDR_REACTIVATE, SDR_TERM_WR);
	--Signals
	signal state      : fsm_sdram_type := SDR_INIT_WAIT;
	signal next_state : fsm_sdram_type := SDR_INIT_WAIT;

	signal command : std_logic_vector(3 downto 0) := "0000";

	signal bank_current : std_logic_vector(1 downto 0);
	signal row_current  : std_logic_vector(11 downto 0);
	signal col_current  : std_logic_vector(7 downto 0);
	signal current_col  : std_logic_vector(8 downto 0);
	signal data_buff    : std_logic_vector(15 downto 0);
	signal data_wl      : std_logic_vector(15 downto 0);

	signal timer_cnt     : integer range 0 to (IN_FREQ * 200) := 0; -- Max Timer ticks needed
	signal timer_enabled : std_logic                          := '0';

	signal data_dir : std_logic := '0'; --[0->Input,1->Output]

	signal read_sdram_data    : std_logic := '0';
	signal rwL                : std_logic := '0';
	signal burst_term_done    : std_logic := '0';
	signal startReadingStatus : std_logic := '0';
	signal stopReadingStatus  : std_logic := '0';
	--signal refresh_wait_cnt : natural range 0 to 700 := 0;
	signal addrL         : std_logic_vector(21 downto 0) := (others => '0');
	signal refresh_cnt   : integer range 0 to 10         := 0;
	signal burst_counter : integer range 0 to 256        := 0;
	signal burst_lenL    : integer range 0 to 256        := 0;
	-- SDRAM Mode Register

	-- Address Values
	--  _______________________________________________________________________________
	-- |  A11 A10 |     A9     |    A8    |  A7  |   A6 A5 A4  |     A3     | A2 A1 A0 |
	-- |__________|____________|__________|______|_____________|____________|__________|
	-- | Reserved | Write Mode | Reserved | Test | CAS Latency |Address Mode| burst len|
	-- |__________|____________|__________|______|_____________|____________|__________|
	-- |  x    x  |     x      |    x     |  x   |   x  x  x   |     x      |  x  x  x |
	-- |__________|____________|__________|______|_____________|____________|__________|

	--Constants
	constant MODE_REG_VALUE : std_logic_vector(11 downto 0) := "00" & "0" & "00" & "0" & cas_lat & "0" & "111";
	constant WAIT_200US     : natural                       := (IN_FREQ * 200);
	constant WAIT_7US       : natural                       := (IN_FREQ * 7);
	constant CAS_LAT_INT    : natural                       := to_integer(unsigned(cas_lat));

	-- SDRAM commands : cs, ras, cas, we.
	constant CMD_ACTIVATE  : std_logic_vector(3 downto 0) := "0011";
	constant CMD_PRECHARGE : std_logic_vector(3 downto 0) := "0010";
	constant CMD_WRITE     : std_logic_vector(3 downto 0) := "0100";
	constant CMD_READ      : std_logic_vector(3 downto 0) := "0101";
	constant CMD_MODE      : std_logic_vector(3 downto 0) := "0000";
	constant CMD_NOP       : std_logic_vector(3 downto 0) := "0111";
	constant CMD_REFRESH   : std_logic_vector(3 downto 0) := "0001";
	constant CMD_STOP      : std_logic_vector(3 downto 0) := "0110";

	alias row_l is addrL(19 downto 8);
begin
	(cs, ras, cas, we) <= command;

	bank_current <= addr(21 downto 20);
	row_current  <= addr(19 downto 8);
	col_current  <= addrL(7 downto 0);

	clk <= clk_in;

	data <= data_wl when data_dir = '1' else
		(others => 'Z');

	data_r    <= data_buff;
	data_buff <= data when read_sdram_data = '1' else
		(others => 'Z');
	data_is_ready <= read_sdram_data;
	data_wl       <= data_w;
	--Banks : 4 (2 Bits)
	--Rows : 4096 (12 Bits)
	--Columns : 256 (8 Bits)
	process (clk_in)
	begin
		if falling_edge(clk_in) then
			if reset = '1' then
				-- Reset controller
				state               <= SDR_INIT_WAIT;
				timer_cnt           <= 0;
				command             <= CMD_NOP;
				cke                 <= '0';
				ready               <= '1';
				address             <= "000000000000";
				current_col         <= (others => '0');
				initialization_done <= '0';
			else

				-- Delay = (timer_cnt + 2) / Freq.
				if timer_enabled = '1' and timer_cnt /= 0 then
					timer_cnt <= timer_cnt - 1;
					command   <= CMD_NOP;
				else
					if timer_enabled = '1' and timer_cnt = 0 then
						state         <= next_state;
						timer_enabled <= '0';
						command       <= CMD_NOP;
					else
						case state is
							when SDR_INIT_WAIT =>
								-- According To Datasheet (w9864g6kh_a02.pdf) Section 7.1
								next_state    <= SDR_INIT_START;
								timer_cnt     <= WAIT_200US; -- Pause For 200us
								dum           <= '1';        --Mask DQ
								dlm           <= '1';
								cke           <= '0';
								ready         <= '0';
								bank          <= "00";
								command       <= CMD_NOP;
								timer_enabled <= '1';
								address       <= "000000000000";
							when SDR_INIT_START =>
								cke           <= '1';
								next_state    <= SDR_INIT_PRECHARGE;
								timer_cnt     <= WAIT_200US;
								timer_enabled <= '1';
							when SDR_INIT_PRECHARGE =>
								next_state    <= SDR_INIT_REFRESH1;
								refresh_cnt   <= 8; -- Do 8 refresh cycles in the next state.
								command       <= CMD_PRECHARGE;
								timer_cnt     <= 3; -- Wait 2+2 cycles plus state overhead for 20.8ns > Trp(=20ns).
								timer_enabled <= '1';
								-- Precharge All Banks
								address(10) <= '1';
							when SDR_INIT_REFRESH1 =>
								if refresh_cnt = 0 then
									state <= SDR_INIT_MODE;
								else
									refresh_cnt   <= refresh_cnt - 1;
									command       <= CMD_REFRESH;
									timer_cnt     <= 8; -- Wait 7+2 cycles plus state overhead for 70ns refresh.
									timer_enabled <= '1';
									next_state    <= SDR_INIT_REFRESH1;
								end if;
							when SDR_INIT_MODE =>
								refresh_cnt   <= 8;
								address       <= MODE_REG_VALUE;
								command       <= CMD_MODE;
								timer_cnt     <= 1;
								timer_enabled <= '1';
								next_state    <= SDR_INIT_REFRESH2;
							when SDR_INIT_REFRESH2 =>
								if refresh_cnt = 0 then
									state               <= SDR_IDLE;
									command             <= CMD_NOP;
									ready               <= '1';
									initialization_done <= '1';
								else
									refresh_cnt   <= refresh_cnt - 1;
									command       <= CMD_REFRESH;
									timer_cnt     <= 8;
									timer_enabled <= '1';
									next_state    <= SDR_INIT_REFRESH2;
								end if;
							when SDR_IDLE =>
								data_dir <= '0';
								dum      <= '0';
								dlm      <= '0';
								if exe = '1' then
									ready         <= '0';
									next_state    <= SDR_START_RW;
									command       <= CMD_ACTIVATE;
									address       <= row_current;
									bank          <= bank_current;
									timer_cnt     <= 1; -- Trcd = 20ns
									timer_enabled <= '1';
									addrL         <= addr;
									rwL           <= rw;
									burst_lenL    <= burst_len;
								else
									command <= CMD_NOP;
									ready   <= '1';
								end if;

							when SDR_START_RW =>

								address         <= "0000" & col_current;
								burst_term_done <= '0';
								if rwL = '1' then
									burst_counter  <= 1;
									command        <= CMD_WRITE;
									ready_to_write <= '1';
									data_dir       <= '1';
									state          <= SDR_RW;
									current_col    <= std_logic_vector(resize(unsigned(col_current), current_col'length) + 1);
								else
									burst_counter <= 0;
									command       <= CMD_READ;
									data_dir      <= '0';
									timer_cnt     <= CAS_LAT_INT - 2;
									timer_enabled <= '1';
									next_state    <= SDR_RW;
									current_col   <= ("0" & col_current) and "011111111";
								end if;
							when SDR_REACTIVATE =>
								address <= (others  => '0');
								dum     <= '0';
								dlm     <= '0';
								if rwL = '1' then
									command        <= CMD_WRITE;
									ready_to_write <= '1';
									dum            <= '0';
									dlm            <= '0';
									state          <= SDR_RW;
									burst_counter  <= burst_counter + 1;
								else
									command       <= CMD_READ;
									timer_cnt     <= CAS_LAT_INT - 2;
									timer_enabled <= '1';
									next_state    <= SDR_RW;
								end if;
								current_col <= (others => '0');
							when SDR_RW            =>
								if (burst_counter /= to_integer(unsigned(current_col))) and (current_col = x"100") then
									if (rwL = '0') then
										timer_cnt       <= CAS_LAT_INT - 2; -- CAS Latency
										timer_enabled   <= '1';
										next_state      <= SDR_TERM_R1;
										command         <= CMD_PRECHARGE;
										read_sdram_data <= '0';
										bank            <= addrL(21 downto 20);
									else
										dum            <= '1';
										dlm            <= '1';
										timer_cnt      <= 0; -- Twr = 2 CLK
										timer_enabled  <= '1';
										next_state     <= SDR_TERM_WR;
										command        <= CMD_NOP;
										ready_to_write <= '0';
									end if;
								elsif burst_counter = burst_lenL then
									timer_enabled <= '1';
									if rwL = '0' then
										timer_cnt  <= 1; -- Trp = 20ns
										next_state <= SDR_IDLE;
										if burst_counter = to_integer(unsigned(current_col)) then
											command <= CMD_NOP;
										else
											command <= CMD_PRECHARGE;
										end if;
										read_sdram_data <= '0';
									else
										dum            <= '1';
										dlm            <= '1';
										timer_cnt      <= 1; -- Trp = 20 ns
										next_state     <= SDR_TERM_WR;
										command        <= CMD_NOP;
										ready_to_write <= '0';
									end if;
								elsif (rwL = '0') and (burst_counter = to_integer(unsigned(current_col))) and (burst_counter = (burst_lenL - CAS_LAT_INT)) then
									burst_counter <= burst_counter + 1;
									current_col   <= std_logic_vector(unsigned(current_col) + 1);
									command       <= CMD_PRECHARGE;
									bank          <= addrL(21 downto 20);
								else
									if rwL = '0' and read_sdram_data = '0' then
										read_sdram_data <= '1';
									end if;
									command       <= CMD_NOP;
									burst_counter <= burst_counter + 1;
									current_col   <= std_logic_vector(unsigned(current_col) + 1);
								end if;
							when SDR_TERM_R1 =>
								read_sdram_data <= '0';
								next_state      <= SDR_TERM_R2;
								timer_cnt       <= 1; -- Trp = 20ns
								timer_enabled   <= '1';
							when SDR_TERM_R2 =>
								timer_cnt     <= 1; -- Trcd = 20ns
								timer_enabled <= '1';
								address       <= std_logic_vector(unsigned(row_l) + 1);
								command       <= CMD_ACTIVATE;
								next_state    <= SDR_REACTIVATE;
								bank          <= addrL(21 downto 20);
							when SDR_TERM_WR =>
								if burst_counter = burst_lenL then
									next_state    <= SDR_IDLE;
									timer_cnt     <= 1; -- Trp = 20ns
									timer_enabled <= '1';
								else
									state <= SDR_TERM_R1;
								end if;
								command <= CMD_PRECHARGE;
								bank    <= addrL(21 downto 20);
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
end Behavioral;
