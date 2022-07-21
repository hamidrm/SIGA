----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: fb_fifo.vhdl
-- Description: Synchronous FIFO, used for buffering the frame buffer commands.
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;

entity fb_fifo is
	generic (
		constant fifo_depth_width : integer := 5
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
end fb_fifo;

architecture Behavioral of fb_fifo is
	type
	sfifo_ram_t is array ((2 ** fifo_depth_width) - 1 downto 0) of siga_fb_cmd_t;
	signal sfifo_ram    : sfifo_ram_t;
	signal fifo_full_s  : std_logic;
	signal fifo_empty_s : std_logic;
	signal fifo_index_a : integer range 0 to ((2 ** fifo_depth_width) - 1) := 0;
	signal fifo_index_b : integer range 0 to ((2 ** fifo_depth_width) - 1) := 0;
	signal fifo_counter : integer range 0 to (2 ** fifo_depth_width)       := 0;
begin

	do <= sfifo_ram(fifo_index_b);

	fifo_full_s <= '1' when fifo_counter = 2 ** fifo_depth_width else
		'0';
	fifo_empty_s <= '1' when fifo_counter = 1 else
		'0';

	full <= '1' when (fifo_counter > 2 ** fifo_depth_width - 2) else
		'0';
	empty <= fifo_empty_s;

	process (CLK)
	begin
		if rising_edge(clk) then
			if clr = '1' then
				fifo_index_a <= 0;
				fifo_index_b <= 0;
			else
				if enq = '1' and deq = '0' and fifo_full_s = '0' then
					fifo_counter <= fifo_counter + 1;
				elsif enq = '0' and deq = '1' and fifo_empty_s = '0' then
					fifo_counter <= fifo_counter - 1;
				end if;
				if (enq = '1' and fifo_full_s = '0') then
					sfifo_ram(fifo_index_a) <= DI;
					fifo_index_a            <= fifo_index_a + 1;
					if fifo_index_a = ((2 ** fifo_depth_width) - 1) then
						fifo_index_a <= 0;
					end if;
				end if;
				if (deq = '1' and fifo_empty_s = '0') then
					fifo_index_b <= fifo_index_b + 1;
					if fifo_index_b = ((2 ** fifo_depth_width) - 1) then
						fifo_index_b <= 0;
					end if;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
