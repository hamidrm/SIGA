----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: sdram_rw_fifo.vhdl
-- Description: An asynchronous FIFO for VGA controller
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;

entity async_fifo is
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
end async_fifo;

architecture Behavioral of async_fifo is

    signal
    full,
    empty,
    ltt,
    htt
    : std_logic;
    signal
    write_ptr,
    sync_read_ptr_bin,
    read_ptr_gray_sync_0,
    read_ptr_gray_sync_1,
    write_ptrGray,
    read_ptr_bin,
    read_ptr,
    sync_write_ptr_bin,
    write_ptr_gray_sync_0,
    write_ptr_gray_sync_1,
    read_ptr_gray,
    write_ptr_bin
    : std_logic_vector(fifo_depth_width - 1 downto 0)            := (others => '0');
    signal counter : std_logic_vector(fifo_depth_width downto 0) := (others => '0');
    type
    afifo_mem_t
    is array (2 ** fifo_depth_width - 1 downto 0) of std_logic_vector(fifo_data_width - 1 downto 0);
    signal
    afifo_mem
    : afifo_mem_t;

begin
    write_side : process (clock_write)
    begin
        if rising_edge(clock_write) then
            if reset_write = '1' then
                write_ptr            <= (others => '0');
                write_ptrGray        <= (others => '0');
                sync_read_ptr_bin    <= (others => '0');
                read_ptr_gray_sync_0 <= (others => '0');
                read_ptr_gray_sync_1 <= (others => '0');
            else
                -- write pointer handling
                if en_write = '1' and not full = '1' then
                    write_ptr <= std_logic_vector(unsigned(write_ptr) + 1);
                end if;
                --write pointer to gray code conversion
                write_ptrGray <= write_ptr xor ('0' & write_ptr(fifo_depth_width - 1 downto 1));
                --gray coded read pointer synchronisation
                read_ptr_gray_sync_0 <= read_ptr_gray;
                read_ptr_gray_sync_1 <= read_ptr_gray_sync_0;
                --register read pointer in order to be resetable
                sync_read_ptr_bin <= read_ptr_bin;
            end if;
        end if;
    end process;
    --read pointer to binary conversion
    read_ptr_bin(fifo_depth_width - 1) <= read_ptr_gray_sync_1(fifo_depth_width - 1);
    gray2binR : for i in fifo_depth_width - 2 downto 0 generate
        read_ptr_bin(i) <= read_ptr_bin(i + 1) xor read_ptr_gray_sync_1(i);
    end generate;
    --set full flag
    full <= '1' when std_logic_vector(unsigned(write_ptr) + 1) = sync_read_ptr_bin else
        '0';
    full_write <= full;

    read_side : process (clock_read)
    begin
        if rising_edge(clock_read) then
            if reset_read = '1' then
                read_ptr              <= (others => '0');
                read_ptr_gray         <= (others => '0');
                sync_write_ptr_bin    <= (others => '0');
                write_ptr_gray_sync_0 <= (others => '0');
                write_ptr_gray_sync_1 <= (others => '0');
            else
                -- read pointer handling
                if en_read = '1' and not empty = '1' then
                    read_ptr <= std_logic_vector(unsigned(read_ptr) + 1);
                end if;
                --read pointer to gray code conversion
                read_ptr_gray <= read_ptr xor ('0' & read_ptr(fifo_depth_width - 1 downto 1));
                --gray coded write pointer synchronisation
                write_ptr_gray_sync_0 <= write_ptrGray;
                write_ptr_gray_sync_1 <= write_ptr_gray_sync_0;
                --register write pointer in order to be resetable
                sync_write_ptr_bin <= write_ptr_bin;
            end if;
        end if;
    end process;
    --write pointer to binary conversion
    write_ptr_bin(fifo_depth_width - 1) <= write_ptr_gray_sync_1(fifo_depth_width - 1);
    gray2binW : for i in fifo_depth_width - 2 downto 0 generate
        write_ptr_bin(i) <= write_ptr_bin(i + 1) xor write_ptr_gray_sync_1(i);
    end generate;
    --set empty flag
    empty <= '1' when read_ptr = sync_write_ptr_bin else
        '0';
    empty_read <= empty;
    ltt <= '1' when (counter <= "000010000") else
        '0';
    htt <= '1' when (counter >= "011100000") else
        '0';
    ltt_read  <= ltt;
    htt_write <= htt;
    counter   <= std_logic_vector(257 + resize(unsigned(sync_write_ptr_bin), counter'length) - unsigned(read_ptr)) when (read_ptr > sync_write_ptr_bin) else
        std_logic_vector(resize(unsigned(sync_write_ptr_bin) - unsigned(read_ptr), counter'length));
    dual_port_ram : process (clock_write)
    begin
        if rising_edge(clock_write) then
            if en_write = '1' and not full = '1' then
                afifo_mem(to_integer(unsigned(write_ptr))) <= data_write;
            end if;
        end if;
    end process;
    data_read <= afifo_mem(to_integer(unsigned(read_ptr)));

end Behavioral;
