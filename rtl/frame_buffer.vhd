----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: frame_buffer.vhdl
-- Description: Frame buffer controller
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;

entity frame_buffer is
	port (
		--Control Pins
		fb_main_clk : in std_logic;
		fb_vga_clk  : in std_logic;
		fb_rst      : in std_logic := '0';
		--Monitor Pins
		V_SYNC : out std_logic;
		H_SYNC : out std_logic;
		V_R    : out std_logic_vector(4 downto 0);
		V_G    : out std_logic_vector(5 downto 0);
		V_B    : out std_logic_vector(4 downto 0);
		--SDRAM Pins	
		sdram_cke     : out std_logic; -- Clock-enable to SDRAM
		sdram_clk     : out std_logic;
		sdram_cs      : out std_logic;                       -- Chip-select to SDRAM
		sdram_ras     : out std_logic;                       -- SDRAM row address strobe
		sdram_cas     : out std_logic;                       -- SDRAM column address strobe
		sdram_we      : out std_logic;                       -- SDRAM write enable
		sdram_bank    : out std_logic_vector(1 downto 0);    -- SDRAM bank address
		sdram_address : out std_logic_vector(11 downto 0);   -- SDRAM row/column address
		sdram_data    : inout std_logic_vector(15 downto 0); -- Data to/from SDRAM
		sdram_dum     : out std_logic;                       -- Enable upper-byte of SDRAM databus if true
		sdram_dlm     : out std_logic;                       -- Enable lower-byte of SDRAM databus if true
		--FrameBuffer Control Signals
		fb_wre          : in std_logic;
		fb_exe          : in std_logic;
		fb_wr_data      : in std_logic_vector(15 downto 0);
		fb_rd_data      : out std_logic_vector(15 downto 0);
		fb_wr_address   : in std_logic_vector(23 downto 0);
		fb_ready        : out std_logic;
		fb_clk_out      : in std_logic;
		fb_base_address : in std_logic_vector(21 downto 0);
		fb_vsync_int    : out std_logic;

		fb_fifo_wr      : in siga_fb_cmd_t;
		fb_fifo_wr_enq  : in std_logic := '0';
		fb_fifo_wr_full : out std_logic
	);
end frame_buffer;

architecture Behavioral of frame_buffer is

	component fb_fifo
		generic (
			fifo_depth_width : integer := 5 --So, The depth of our FIFO buffer of commands will be 32
		);

		port (
			di    : in siga_fb_cmd_t;
			do    : out siga_fb_cmd_t;
			clk   : in std_logic;
			enq   : in std_logic;
			deq   : in std_logic;
			clr   : in std_logic;
			empty : out std_logic;
			full  : out std_logic);
	end component;
	component vga800x600
		port (
			clk36mhz     : in std_logic;
			reset        : in std_logic;
			pixelcolor   : in std_logic_vector(15 downto 0);
			h_sync       : out std_logic                    := '0';
			v_sync       : out std_logic                    := '0';
			red          : out std_logic_vector(4 downto 0) := "00000";
			green        : out std_logic_vector(5 downto 0) := "000000";
			blue         : out std_logic_vector(4 downto 0) := "00000";
			color_domain : out std_logic                    := '0'
		);
	end component;
	component async_fifo
		generic (
			fifo_depth_width : natural := 8;
			fifo_data_width  : natural := 16
		);
		port (
			reset_read  : in std_logic;
			reset_write : in std_logic;
			clock_read  : in std_logic;
			clock_write : in std_logic;
			en_read     : in std_logic;
			en_write    : in std_logic;
			empty_read  : out std_logic;
			ltt_read    : out std_logic;
			htt_write   : out std_logic;
			full_write  : out std_logic := '0';
			data_read   : out std_logic_vector (fifo_data_width - 1 downto 0);
			data_write  : in std_logic_vector (fifo_data_width - 1 downto 0));
	end component;
	--	component async_fifo
	--		generic (
	--			addr_width : natural := 8;
	--			data_width : natural := 16
	--		);
	--		port (
	--			reset_read  : in std_logic;
	--			reset_write : in std_logic;
	--			clock_read  : in std_logic;
	--			clock_write : in std_logic;
	--			en_read     : in std_logic;
	--			en_write    : in std_logic;
	--			empty_read  : out std_logic;
	--			ltt_r       : out std_logic; --Lower than threshold
	--			htt_write   : out std_logic; --Higher than threshold
	--			full_write  : out std_logic := '0';
	--			data_read   : out std_logic_vector (data_width - 1 downto 0);
	--			data_write  : in std_logic_vector (data_width - 1 downto 0));
	--	end component;
	component sdram
		generic (
			cas_lat : std_logic_vector(1 downto 0) := "10"; -- CL = 2
			in_freq : integer                      := 120   -- Input Clock Frequency = 120,000,000 Hz
		);
		port (
			-- Host side
			clk_in              : in std_logic;
			reset               : in std_logic                     := '0';
			rw                  : in std_logic                     := '0'; -- [ 0-> Read , 1-> Write ]
			exe                 : in std_logic                     := '0';
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
	end component;

	--Screen 800x600
	constant screen_Width  : natural := 800;
	constant screen_Height : natural := 600;

	type fsm_fb_t is (
		FBS_IDLE, FBS_READING_FRAME, FBS_FIFO_WR_PROC, FBS_WRITING_BLOCK);
	--Control Signals
	signal fb_state             : fsm_fb_t                      := FBS_IDLE;
	signal fb_read_address      : std_logic_vector(18 downto 0) := (others => '0');
	signal fb_write_address     : std_logic_vector(18 downto 0);
	signal fb_sdram_page_offset : integer range 0 to 256 := 0;

	-- VGA Controller Signals
	signal drawing_domain   : std_logic := '0';
	signal pixel_color      : std_logic_vector(15 downto 0);
	signal vga_hold_signals : std_logic := '1';

	-- SDRAM Controller Signals
	signal sdram_rw_burst_length : natural := 256;
	signal sdram_linear_addr     : std_logic_vector(21 downto 0);
	signal
	sdram_data_wr,
	sdram_data_rd
	: std_logic_vector(15 downto 0);
	signal
	sdram_is_ready,
	sdram_data_is_ready,
	sdram_ready_to_write,
	sdram_initialization_done,
	sdram_write_enable,
	sdram_execute_cmd
	: std_logic := '0';

	-- Asynchron FIFO Signals
	signal afifo_enq : std_logic;
	signal
	afifo_out_data,
	afifo_in_data
	: std_logic_vector(15 downto 0);
	signal
	afifo_empty,
	afifo_full,
	afifo_ltt,
	afifo_gtt,
	afifo_deq
	: std_logic := '0';

	-- Writing Synchron FIFO Signals
	signal
	sfifo_in_data_wr,
	sfifo_out_data_wr
	: siga_fb_cmd_t;
	signal
	sfifo_clr_wr,
	sfifo_empty_wr,
	sfifo_full_wr,
	sfifo_enq_wr,
	sfifo_deq_wr
	: std_logic := '0';
	-- Filling Unit
	signal fb_fill_block_running : std_logic := '0';
	signal fb_fill_color         : std_logic_vector(15 downto 0);
	signal fb_fill_length        : std_logic_vector(7 downto 0);
	signal fb_fill_addr          : std_logic_vector(18 downto 0);

begin

	-- VGA Controller Unit
	vga800x600_block : vga800x600 port map(
		fb_vga_clk, vga_hold_signals, pixel_color, H_SYNC, V_SYNC, V_R, V_G, V_B, drawing_domain);

	-- SDRAM Controller Unit
	sdram_block : sdram port map(
		fb_main_clk, fb_rst, sdram_write_enable, sdram_execute_cmd, sdram_rw_burst_length, sdram_linear_addr, sdram_data_wr, sdram_is_ready, sdram_data_rd, sdram_data_is_ready,
		sdram_ready_to_write, sdram_initialization_done, sdram_cke, sdram_clk, sdram_cs, sdram_ras, sdram_cas, sdram_we, sdram_bank, sdram_address, sdram_data, sdram_dum, sdram_dlm);

	-- Asynchronous FIFO Unit
	sdram_rw_fifo_block : async_fifo port map(
		fb_rst, fb_rst, fb_vga_clk, fb_main_clk, afifo_deq, afifo_enq, afifo_empty, afifo_ltt, afifo_gtt, afifo_full, afifo_out_data, afifo_in_data);

	-- Write FIFO Unit
	sfifo_wr_block : fb_fifo port map(sfifo_in_data_wr, sfifo_out_data_wr, fb_main_clk, sfifo_enq_wr, sfifo_deq_wr, sfifo_clr_wr, sfifo_empty_wr, sfifo_full_wr);

	-- Hard Connections
	afifo_deq <= drawing_domain;
	afifo_enq <= (sdram_data_is_ready and (not afifo_full)) when (fb_state = FBS_READING_FRAME) else
		'0';
	pixel_color <= afifo_out_data when afifo_empty = '0' else
		x"001F";
	afifo_in_data <= sdram_data_rd when ((sdram_data_is_ready = '1')) else
		x"0000";

	sfifo_enq_wr     <= fb_fifo_wr_enq;
	sfifo_in_data_wr <= fb_fifo_wr;

	fb_fifo_wr_full <= sfifo_full_wr;

	fb_process :
	process (fb_main_clk)
	begin
		--Whenever fb_rst signal goes high or SDRAM initialization process hadn't been ended, hold Frame Buffer in reset state
		if fb_rst = '1' or sdram_initialization_done = '0' then
			fb_sdram_page_offset  <= 0;               --Reset page offset counter (each page = 256 word)
			fb_read_address       <= (others => '0'); --Reset reading address
			sdram_rw_burst_length <= 256;             --Reset the SDRAM Read/Write burst length
			fb_fill_block_running <= '0';
		elsif rising_edge(fb_main_clk) then
			--Now, We need a state machine here
			case fb_state is
				when FBS_IDLE =>
					-- If available elements in Asynchronous FIFO goes lower than threshold, Then please refill it!
					-- Otherwise, stay here or do what the boss required.
					if (afifo_ltt = '1') then
						sdram_linear_addr     <= fb_base_address(fb_base_address'high downto (fb_base_address'high - 2)) & (fb_read_address);
						sdram_rw_burst_length <= 256; -- Read words with maximum possible burst length
						sdram_execute_cmd     <= '1'; -- Say to the SDRAM controller that we have a new operation
						fb_state              <= FBS_READING_FRAME;
						sdram_write_enable    <= '0'; -- We need reading operation currentlly.
					end if;
				when FBS_READING_FRAME =>
					sdram_execute_cmd <= '0'; -- Okay, our SDRAM got it.
					if (sdram_data_is_ready = '1') then
						fb_sdram_page_offset <= fb_sdram_page_offset + 1;
						fb_read_address      <= std_logic_vector(unsigned(fb_read_address) + 1);
						if unsigned(fb_read_address) = (screen_width * screen_height - 1) then
							fb_read_address <= (others => '0');
						end if;
					end if;
					if (fb_sdram_page_offset = 256) or (afifo_full = '1') then
						fb_sdram_page_offset <= 0;
						if sfifo_empty_wr = '1' then
							fb_state <= FBS_IDLE;
						else
							fb_state     <= FBS_FIFO_WR_PROC;
							sfifo_deq_wr <= '1';
						end if;
					end if;
					if (afifo_full = '1') and (vga_hold_signals = '1') then
						vga_hold_signals <= '0';
					end if;
				when FBS_FIFO_WR_PROC =>
					--There are some things inside FIFO
					if fb_fill_block_running = '0' then
						sfifo_deq_wr          <= '0';
						fb_fill_color         <= (sfifo_out_data_wr.color.b) & (sfifo_out_data_wr.color.g) & (sfifo_out_data_wr.color.r);
						fb_fill_length        <= sfifo_out_data_wr.fill_length;
						fb_fill_addr          <= siga_point_to_linear(sfifo_out_data_wr.pos.x, sfifo_out_data_wr.pos.y);
						fb_fill_block_running <= '1';
					else
						if sdram_is_ready = '1' then
							sdram_rw_burst_length <= to_integer(unsigned(fb_fill_length));
							sdram_execute_cmd     <= '1';
							sdram_linear_addr     <= "000" & fb_fill_addr;
							sdram_write_enable    <= '1';
							sdram_data_wr         <= fb_fill_color;
							fb_state              <= FBS_WRITING_BLOCK;
						end if;
					end if;
				when FBS_WRITING_BLOCK =>
					sdram_execute_cmd  <= '0';
					sdram_write_enable <= '0';
					if sdram_is_ready = '1' then
						fb_fill_block_running <= '0';
						fb_state              <= FBS_IDLE;
					end if;
			end case;
		end if;
	end process;
end Behavioral;
