----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: vga800x600.vhdl
-- Description: VGA controller
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;

entity vga800x600 is
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

end vga800x600;

architecture Behavioral of vga800x600 is
	constant h_pol     : std_logic                        := '1';
	constant v_pol     : std_logic                        := '1';
	constant h_bp      : natural                          := 128;                           --Back Porch
	constant h_pw      : natural                          := 72;                            --Sync Pulse
	constant h_fp      : natural                          := 24;                            --Front Porch
	constant v_bp      : natural                          := 22;                            --Back Porch
	constant v_pw      : natural                          := 2;                             --Sync Pulse
	constant v_fp      : natural                          := 1;                             --Front Porch
	constant h_width   : natural                          := 800;                           --Horizontal Width
	constant v_height  : natural                          := 600;                           --Vertical Height
	constant h_max_clk : natural                          := h_fp + h_pw + h_bp + h_width;  --Horizontal Whole Width
	constant v_max_clk : natural                          := v_fp + v_pw + v_bp + v_height; --Vertical Whole Height
	signal h_counter   : integer range 0 to h_max_clk + 1 := 0;
	signal v_counter   : integer range 0 to v_max_clk + 1 := 0;

begin
	color_domain <= '1' when (reset = '0') and (h_counter < h_width) and (v_counter < v_height) else
		'0';
	process (reset, clk36mhz, pixelcolor)
	begin
		if reset = '1' then
			h_counter <= 0;
			v_counter <= 0;
		elsif clk36mhz = '1' and clk36mhz'event then
			if h_counter = h_max_clk then
				h_counter <= 0;
				if v_counter = v_max_clk then
					v_counter <= 0;
				else
					v_counter <= v_counter + 1;
				end if;
			else
				h_counter <= h_counter + 1;
			end if;
			if (h_counter < h_width) and (v_counter < v_height) then
				red   <= pixelcolor(4 downto 0);
				green <= pixelcolor(10 downto 5);
				blue  <= pixelcolor(15 downto 11);
			else
				red   <= "00000";
				green <= "000000";
				blue  <= "00000";
			end if;

			if (h_counter <= (h_width + h_fp + h_pw)) and (h_counter > (h_width + h_fp)) then
				h_sync        <= h_pol;
			else
				h_sync <= not h_pol;
			end if;
			if (v_counter <= (v_height + v_fp + v_pw)) and (v_counter > (v_height + v_fp)) then
				v_sync        <= v_pol;
			else
				v_sync <= not v_pol;
			end if;

		end if;
	end process;

end Behavioral;
