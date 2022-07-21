----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: example.vhdl
-- Desc.: An example for SIGA functionality
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;
entity top is
	port (
		V_SYNC    : out std_logic;
		H_SYNC    : out std_logic;
		V_R       : out std_logic_vector(4 downto 0);
		V_G       : out std_logic_vector(5 downto 0);
		V_B       : out std_logic_vector(4 downto 0);
		CLK       : in std_logic;
		SDRAM_CKE : out std_logic;
		SDRAM_CLK : out std_logic;

		SDRAM_DQMH : out std_logic;
		SDRAM_DQML : out std_logic;

		SDRAM_RAS_N : out std_logic;
		SDRAM_CAS_N : out std_logic;
		SDRAM_WE_N  : out std_logic;
		SDRAM_CS_N  : out std_logic;
		SDRAM_A0    : out std_logic;
		SDRAM_A1    : out std_logic;
		SDRAM_A2    : out std_logic;
		SDRAM_A3    : out std_logic;
		SDRAM_A4    : out std_logic;
		SDRAM_A5    : out std_logic;
		SDRAM_A6    : out std_logic;
		SDRAM_A7    : out std_logic;
		SDRAM_A8    : out std_logic;
		SDRAM_A9    : out std_logic;
		SDRAM_A10   : out std_logic;
		SDRAM_A11   : out std_logic;
		--SDRAM_A12 : out STD_LOGIC;
		SDRAM_BA1 : out std_logic;
		SDRAM_BA0 : out std_logic;

		SDRAM_DQ0  : inout std_logic;
		SDRAM_DQ1  : inout std_logic;
		SDRAM_DQ2  : inout std_logic;
		SDRAM_DQ3  : inout std_logic;
		SDRAM_DQ4  : inout std_logic;
		SDRAM_DQ5  : inout std_logic;
		SDRAM_DQ6  : inout std_logic;
		SDRAM_DQ7  : inout std_logic;
		SDRAM_DQ8  : inout std_logic;
		SDRAM_DQ9  : inout std_logic;
		SDRAM_DQ10 : inout std_logic;
		SDRAM_DQ11 : inout std_logic;
		SDRAM_DQ12 : inout std_logic;
		SDRAM_DQ13 : inout std_logic;
		SDRAM_DQ14 : inout std_logic;
		SDRAM_DQ15 : inout std_logic;

		KEY1 : in std_logic;
		KEY2 : in std_logic;
		KEY3 : in std_logic;
		KEY4 : in std_logic;
		LED1 : out std_logic;
		LED2 : out std_logic;
		LED3 : out std_logic
	);
end top;

architecture Behavioral of top is

	component frame_buffer
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
			fb_fifo_wr_enq  : in std_logic;
			fb_fifo_wr_full : out std_logic
		);
	end component;

	component raster_engine is
		port (
			re_command : in siga_re_cmd_t;
			re_point   : in siga_point2_t;
			re_color   : in siga_rgb_t;
			re_param1  : in siga_re_params_t;
			re_param2  : in siga_re_params_t;
			re_param3  : in siga_re_params_t;

			re_fb_fifo_wr      : out siga_fb_cmd_t;
			re_fb_fifo_wr_enq  : out std_logic;
			re_fb_fifo_wr_full : in std_logic;

			re_current_x : out siga_re_params_t;
			re_current_y : out siga_re_params_t;

			re_clk          : in std_logic;
			re_en           : in std_logic;
			re_rst          : in std_logic;
			re_bmp_color_en : in std_logic;
			re_busy         : out std_logic
		);
	end component;

	--PLL IP genrated ( CLK_IN1 = 48MHz , CLK_OUT1 = 120MHz , CLK_OUT2 = 36MHz )
	component clock
		port (-- Clock in ports
			CLK_IN1 : in std_logic;
			-- Clock out ports
			CLK_OUT1 : out std_logic;
			CLK_OUT2 : out std_logic;

			-- Status and control signals
			LOCKED : out std_logic
		);
	end component;

	type rect_data_t is record
		left   : std_logic_vector(9 downto 0);
		top    : std_logic_vector(9 downto 0);
		width  : std_logic_vector(9 downto 0);
		height : std_logic_vector(9 downto 0);
	end record rect_data_t;

	type image2d is array (0 to 58, 0 to 119) of std_logic_vector(15 downto 0);

	constant my_image : image2d := (
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"0000", x"0000", x"01d2", x"dfff", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3b2c", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"61d2", x"dfff", x"fffb", x"91c0", x"3c9b", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fffb", x"91c0", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"01d2", x"dfff", x"ffff", x"fffb", x"91cc", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96db", x"91c0", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"000c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"61d2", x"9320", x"0000", x"000c", x"b7f6", x"6000", x"0000", x"3c9b", x"ffff", x"fff6", x"600c", x"9487", x"0000", x"0000", x"3c9b", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fff6", x"6000", x"65bf", x"ffff", x"ffff", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"6327", x"0000", x"3c9b", x"fff6", x"6000", x"0000", x"0000", x"0007", x"96df", x"ffff", x"ffff", x"b320", x"0000", x"0000", x"0000", x"01d2", x"dff6", x"600c", x"9487", x"0000", x"0000", x"65bf", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"fdac", x"0000", x"0000", x"0007", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fed2", x"39d2", x"dfff", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"6000", x"3c9b", x"ffff", x"b320", x"0007", x"96df", x"fed2", x"380c", x"b7ff", x"fff6", x"6000", x"3c9b", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"dc87", x"3c9b", x"ffff", x"fed2", x"39d2", x"dfff", x"ffff", x"b320", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"65bf", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"b320", x"3c9b", x"ffff", x"ffff", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"fed2", x"39d2", x"dfff", x"fff6", x"6007", x"96df", x"fff6", x"6000", x"0336", x"ffff", x"fdac", x"000c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"000c", x"b7ff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"0336", x"ffff", x"fffb", x"91c7", x"96df", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"b320", x"65bf", x"ffff", x"dc87", x"3c9b", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"b320", x"65bf", x"ffff", x"ffff", x"ffff", x"dc87", x"0336", x"ffff", x"fff6", x"6000", x"0000", x"000c", x"b7ff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"01d2", x"dfff", x"fed2", x"39d2", x"dfff", x"fff6", x"6007", x"96df", x"fff6", x"600c", x"b7ff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"000c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"0336", x"ffff", x"fffb", x"91c7", x"96df", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"b320", x"65bf", x"ffff", x"dc87", x"3c9b", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"01d2", x"dfff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"ffff", x"fdac", x"000c", x"b7ff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"fed2", x"39d2", x"dfff", x"fff6", x"6000", x"0000", x"0000", x"3c9b", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"65bf", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"0336", x"ffff", x"fffb", x"91c7", x"96df", x"fff6", x"6000", x"3c9b", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"dc87", x"3c9b", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"b320", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"01d2", x"dfff", x"ffff", x"fff6", x"600c", x"b7ff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"b320", x"01d2", x"dfff", x"fdac", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"3c9b", x"ffff", x"ffff", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"0336", x"ffff", x"fffb", x"91c7", x"96df", x"fff6", x"600c", x"9487", x"0000", x"0000", x"65bf", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"ffff", x"ffff", x"ffff", x"fed2", x"3800", x"0000", x"0000", x"0000", x"000c", x"b7ff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"0000", x"0000", x"0000", x"01d2", x"dfff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"b320", x"0000", x"0000", x"032c", x"61d2", x"dfff", x"fed2", x"3800", x"0000", x"0000", x"0000", x"65bf", x"fff6", x"600c", x"b7ff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"3c9b", x"ffff", x"ffff", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"600c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fed2", x"3800", x"0000", x"0000", x"000c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3b2c", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96db", x"91c0", x"65bf", x"ffff", x"ffff", x"fdac", x"0000", x"0000", x"0007", x"96df", x"ffff", x"fdac", x"0000", x"0000", x"0007", x"96df", x"ffff", x"dc87", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0336", x"ffff", x"fffb", x"91c7", x"6327", x"0000", x"3c9b", x"fff6", x"6000", x"0000", x"0000", x"0007", x"96df", x"fffb", x"91c0", x"0000", x"0000", x"01d2", x"dfff", x"fdac", x"0000", x"0000", x"0000", x"65bf", x"ffff", x"fffb", x"91c7", x"6327", x"0000", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fed2", x"39d2", x"dfff", x"fdac", x"0336", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"ffff", x"fff6", x"6007", x"96df", x"ffff", x"ffff", x"ffff", x"fed2", x"39d2", x"dfff", x"ffff", x"b320", x"65bf", x"ffff", x"dc87", x"3c9b", x"ffff", x"fed2", x"39d2", x"dfff", x"ffff", x"b320", x"65bf", x"fffb", x"91c0", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"fffb", x"91c7", x"96df", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"fed2", x"3807", x"96df", x"fffb", x"91c0", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fff6", x"6007", x"96df", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"dc87", x"3c9b", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"01d2", x"dfff", x"fffb", x"91c7", x"96df", x"ffff", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"b320", x"3c9b", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"fed2", x"39d2", x"dfff", x"fffb", x"91c7", x"96df", x"ffff", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"b320", x"65bf", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"ffff", x"fdac", x"01d2", x"ded2", x"3807", x"96df", x"ffff", x"ffff", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"ffff", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"fdac", x"01d2", x"dfff", x"ffff", x"b320", x"01d2", x"dfff", x"fffb", x"91c7", x"96df", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"fed2", x"3807", x"96df", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"b320", x"3c9b", x"ffff", x"ffff", x"ffff", x"fff6", x"6007", x"96df", x"dc87", x"0000", x"0000", x"0007", x"96df", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"b320", x"0000", x"0000", x"032c", x"61d2", x"dfff", x"ffff", x"dc87", x"0000", x"01d2", x"dfff", x"fdac", x"0000", x"0000", x"0000", x"65bf", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"fffb", x"91c0", x"0007", x"96df", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"000c", x"b7ff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"ffff", x"ffff", x"fed2", x"3800", x"0000", x"0000", x"0000", x"0000", x"0007", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fed2", x"380c", x"b7ff", x"fffb", x"91c7", x"6327", x"3c9b", x"ffff", x"ffff", x"ffff", x"fdac", x"01c7", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"fff6", x"6000", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fdac", x"01d2", x"dfff", x"fffb", x"91c7", x"95b2", x"380c", x"b7ff", x"ffff", x"fffb", x"91c7", x"95b2", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"ffff", x"b320", x"3c9b", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0336", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"000c", x"b7fb", x"91c0", x"0000", x"0000", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"fffb", x"91c7", x"96db", x"91c0", x"65bf", x"ffff", x"fed2", x"39d2", x"ded2", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"fed2", x"39d2", x"dfff", x"ffff", x"b320", x"65bf", x"fdac", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fff6", x"6000", x"65bf", x"fffb", x"91c7", x"96df", x"fdac", x"0336", x"ffff", x"b320", x"65bf", x"fed2", x"380c", x"b7ff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0000", x"0000", x"3c9b", x"fff6", x"6000", x"000c", x"b7ff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"b320", x"3c9b", x"fffb", x"91c7", x"96df", x"fff6", x"6007", x"96d6", x"600c", x"b7ff", x"fed2", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"dc87", x"0336", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fff6", x"6000", x"000c", x"b7ff", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fff6", x"6000", x"65bf", x"fffb", x"91c7", x"96df", x"ffff", x"b320", x"0000", x"3c9b", x"ffff", x"fed2", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"fed2", x"380c", x"b7ff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"65bf", x"fffb", x"91c7", x"96df", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"fffb", x"91c0", x"0000", x"0000", x"0000", x"3c9b", x"ffff", x"fffb", x"91c7", x"96df", x"ffff", x"fed2", x"3807", x"96df", x"ffff", x"fed2", x"380c", x"b7ff", x"fffb", x"91c0", x"65bf", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"dc87", x"3c9b", x"ffff", x"ffff", x"ffff", x"dc87", x"0000", x"0000", x"0007", x"96df", x"dc87", x"0000", x"0000", x"0000", x"0336", x"ffff", x"ffff", x"dc87", x"0000", x"01d2", x"dfff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"),
		(x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff", x"ffff"));

	signal fb_fifo_wr     : siga_fb_cmd_t;
	signal fb_fifo_wr_enq : std_logic := '0';

	signal rect_data : rect_data_t;

	signal CLK36MHZ  : std_logic := '0';
	signal CLK120MHZ : std_logic := '0';

	signal data_to_write : std_logic_vector(15 downto 0);
	signal pixel_offset  : std_logic_vector(18 downto 0);
	signal reset         : std_logic := '0';
	signal wr_en         : std_logic := '0';
	signal sddata        : std_logic_vector(15 downto 0);
	signal sdaddr        : std_logic_vector(11 downto 0);
	signal sdbank        : std_logic_vector(1 downto 0);
	signal clk_ok        : std_logic := '0';

	signal fb_wre          : std_logic;
	signal fb_exe          : std_logic;
	signal fb_wr_data      : std_logic_vector(15 downto 0);
	signal fb_rd_data      : std_logic_vector(15 downto 0);
	signal fb_wr_address   : std_logic_vector(23 downto 0);
	signal fb_ready        : std_logic;
	signal fb_clk_out      : std_logic;
	signal fb_base_address : std_logic_vector(21 downto 0) := (others => '0');
	signal fb_vsync_int    : std_logic;
	signal fb_fifo_wr_full : std_logic;
	signal led_status      : std_logic := '1';

	signal x_img            : integer range 0 to 24 := 0;
	signal y_img            : integer range 0 to 61 := 0;
	signal drawing_started1 : std_logic             := '0';
	signal drawing_done1    : std_logic             := '0';
	signal drawing_started2 : std_logic             := '0';
	signal drawing_done2    : std_logic             := '0';
	signal drawing_started3 : std_logic             := '0';
	signal drawing_done3    : std_logic             := '0';
	signal drawing_started4 : std_logic             := '0';
	signal drawing_done4    : std_logic             := '0';
	signal drawing_started5 : std_logic             := '0';

	signal counter_lines : integer range 0 to 800 := 0;

	signal counter              : integer range 0 to 120000000 := 0;
	signal suspend_fifo_writing : std_logic                    := '0';
	signal re_command           : siga_re_cmd_t;
	signal re_point             : siga_point2_t;
	signal re_color             : siga_rgb_t;
	signal re_param1            : siga_re_params_t;
	signal re_param2            : siga_re_params_t;
	signal re_param3            : siga_re_params_t;

	signal re_fb_fifo_wr      : siga_fb_cmd_t;
	signal re_fb_fifo_wr_enq  : std_logic;
	signal re_fb_fifo_wr_full : std_logic;

	signal re_busy : std_logic;
	signal re_en   : std_logic := '0';

	signal re_current_x    : siga_re_params_t := 0;
	signal re_current_y    : siga_re_params_t := 0;
	signal re_bmp_color_en : std_logic        := '0';
	signal re_color_out    : siga_rgb_t;
begin
	LED1 <= led_status;
	clk_pll : clock
	port map
	(-- Clock in ports
		CLK_IN1 => CLK,
		-- Clock out ports
		CLK_OUT1 => CLK120MHZ,
		CLK_OUT2 => CLK36MHZ,
		LOCKED   => clk_ok);

	raster_engine_block : raster_engine
	port map(re_command, re_point, re_color, re_param1, re_param2, re_param3, fb_fifo_wr, fb_fifo_wr_enq, fb_fifo_wr_full, re_current_x, re_current_y, CLK120MHZ, re_en, reset, re_bmp_color_en, re_busy);
	frame_buffer_block : frame_buffer
	port map(CLK120MHZ, CLK36MHZ, reset, V_SYNC, H_SYNC, V_R, V_G, V_B, SDRAM_CKE, SDRAM_CLK, SDRAM_CS_N, SDRAM_RAS_N, SDRAM_CAS_N, SDRAM_WE_N, sdbank, sdaddr, sddata, SDRAM_DQMH, SDRAM_DQML, fb_wre, fb_exe, fb_wr_data, fb_rd_data, fb_wr_address, fb_ready, fb_clk_out, fb_base_address, fb_vsync_int, fb_fifo_wr, fb_fifo_wr_enq, fb_fifo_wr_full);
	(SDRAM_DQ15, SDRAM_DQ14, SDRAM_DQ13, SDRAM_DQ12, SDRAM_DQ11, SDRAM_DQ10, SDRAM_DQ9, SDRAM_DQ8, SDRAM_DQ7, SDRAM_DQ6, SDRAM_DQ5, SDRAM_DQ4, SDRAM_DQ3, SDRAM_DQ2, SDRAM_DQ1, SDRAM_DQ0) <= sddata;
	(SDRAM_A11, SDRAM_A10, SDRAM_A9, SDRAM_A8, SDRAM_A7, SDRAM_A6, SDRAM_A5, SDRAM_A4, SDRAM_A3, SDRAM_A2, SDRAM_A1, SDRAM_A0)                                                             <= sdaddr;
	(SDRAM_BA1, SDRAM_BA0)                                                                                                                                                                 <= sdbank;

	re_color <= siga_word_to_rgb(my_image(re_current_y, re_current_x)) when drawing_started4 = '1' else
		re_color_out;
	reset <= not clk_ok;
	process (CLK120MHZ)
	begin
		if rising_edge(CLK120MHZ) then
			if drawing_started4 = '1' then
				--Draw Rect Test
				re_bmp_color_en <= '1';
				re_en           <= '1';
				re_command      <= RASTER_FILL_RECT_BMP;
				re_param1       <= 120;
				re_param2       <= 59;
				re_point.x      <= "0011100000";
				re_point.y      <= "0011100000";

				drawing_done4 <= '1';
				if re_current_y >= 58 and re_current_x >= 118 then
					drawing_started4 <= '0';
				end if;
			elsif drawing_started3 = '1' then
				--Draw Circle
				re_command       <= RASTER_FILL_CIRCLE;
				drawing_done3    <= '1';
				drawing_started3 <= '0';
				re_en            <= '1';
				re_color_out     <= siga_int_to_rgb(3, 23, 20);
				re_param1        <= 80;
				re_point.x       <= "0101000000";
				re_point.y       <= "0011111000";
			elsif drawing_started2 = '1' then
				--Draw Line
				re_command       <= RASTER_DRAW_LINE;
				drawing_started2 <= '0';
				drawing_done1    <= '1';
				re_en            <= '1';
				re_color_out     <= siga_int_to_rgb(22, 12, 31);
				re_param1        <= 400;
				re_param2        <= 300;
				re_point.x       <= "0001111100";
				re_point.y       <= "0001110100";
			elsif drawing_started1 = '1' then
				--Draw Rect
				re_command       <= RASTER_FILL_RECT;
				drawing_done1    <= '1';
				drawing_started1 <= '0';
				re_en            <= '1';
				re_color_out     <= siga_int_to_rgb(25, 50, 25);
				re_param1        <= 600;
				re_param2        <= 400;
				re_point.x       <= "0001100100";
				re_point.y       <= "0001100100";
			else
				re_en <= '0';
			end if;

			if KEY1 = '0' and drawing_done1 = '0' then
				drawing_started1 <= '1';
			end if;
			if KEY2 = '0' and drawing_done2 = '0' then
				drawing_started2 <= '1';
			end if;
			if KEY3 = '0' and drawing_done3 = '0' then
				drawing_started3 <= '1';
			end if;
			if KEY4 = '0' and drawing_done4 = '0' then
				drawing_started4 <= '1';
			end if;
		end if;
	end process;
end Behavioral;
