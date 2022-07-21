----------------------------------------------------------------------------------
-- SIGA
-- Author: Hamidreza Mehrabian
-- File: raster_engine.vhdl
-- Description: Raster Engine
----------------------------------------------------------------------------------
library IEEE;
library work;

use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.siga_utilities.all;

-- Rectangle (Solid)
-- Bitmap
-- Line Bresenham
-- Circle Bresenham
entity raster_engine is
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
end raster_engine;

architecture Behavioral of raster_engine is
	signal raster_engine_busy : std_logic;
	signal frame_buffer_cmd   : siga_fb_cmd_t;
	signal
	re_param1_l,
	re_param2_l,
	re_param3_l
	: siga_re_params_t;

	signal
	re_x_draw,
	re_y_draw,
	re_w_draw,
	re_h_draw
	: siga_re_params_t;

	signal bre_decision : signed(10 downto 0);

	signal
	x_r_f, --X Rising or Falling?
	y_r_f  --Y Rising or Falling?
	: bit;

	type fsm_sdram_type is (
		RE_IDLE, RE_STATE_FILL_RECT, RE_STATE_LINE, RE_STATE_DRAW_CIRCLE, RE_STATE_FILL_CIRCLE, RE_STATE_FILL_RECT_BMP);

	signal re_state : fsm_sdram_type;
begin
	re_fb_fifo_wr <= frame_buffer_cmd;
	raster_cmd_proc :
	process (re_clk)
		variable re_t_draw : siga_re_params_t;
	begin
		if rising_edge(re_clk) then
			if raster_engine_busy = '0' and re_en = '1' then
				raster_engine_busy <= '1';
				case re_command is
					when RASTER_FILL_RECT =>
						--We are going to fill a rectancge
						frame_buffer_cmd.color <= re_color;                         --Color is fixed, Just latch it
						re_x_draw              <= to_integer(unsigned(re_point.x)); --Start point of drawing
						re_y_draw              <= to_integer(unsigned(re_point.y));
						re_param1_l            <= re_param1; --Latch Parameter 1
						re_param2_l            <= re_param2; --Latch Parameter 2
						re_param3_l            <= re_param1; --Clone Parameter 1
						re_w_draw              <= 0;
						re_h_draw              <= 0;
						re_state               <= RE_STATE_FILL_RECT; --Set state to fill rect
					when RASTER_FILL_RECT_BMP =>
						--We are going to fill a rectancge
						frame_buffer_cmd.color <= re_color;                         --Default Color
						re_x_draw              <= to_integer(unsigned(re_point.x)); --Start point of drawing
						re_y_draw              <= to_integer(unsigned(re_point.y));
						re_param1_l            <= re_param1; --Latch Parameter 1
						re_param2_l            <= re_param2; --Latch Parameter 2
						re_param3_l            <= re_param1; --Clone Parameter 1
						re_w_draw              <= 0;
						re_h_draw              <= 0;
						re_current_x           <= 0;
						re_current_y           <= 0;
						re_state               <= RE_STATE_FILL_RECT_BMP; --Set state to fill rect
					when RASTER_DRAW_LINE =>
						--We are going to draw a line
						frame_buffer_cmd.color <= re_color;                         --Color is fixed, Just latch it
						re_x_draw              <= to_integer(unsigned(re_point.x)); --Start point of drawing
						re_y_draw              <= to_integer(unsigned(re_point.y));
						re_param1_l            <= re_param1;                                                      --Latch Parameter 1
						re_param2_l            <= re_param2;                                                      --Latch Parameter 2
						re_param3_l            <= re_param3;                                                      --Latch Parameter 3
						re_w_draw              <= to_integer(abs(to_signed(re_param1, 10) - signed(re_point.x))); --DeltaX
						re_h_draw              <= to_integer(abs(to_signed(re_param2, 10) - signed(re_point.y))); --DeltaY
						--Bresenham error value
						bre_decision <= shift_left(abs(to_signed(re_param2, 11) - signed(re_point.y)), 1) - abs(to_signed(re_param1, 11) - signed(re_point.x));
						re_state     <= RE_STATE_LINE; --Set state to draw line

						if to_integer(unsigned(re_point.x)) > re_param1 then
							x_r_f <= '0'; --We must decrease x1 valuese to achive x2
						else
							x_r_f <= '1'; --We must increase x1 valuese to achive x2
						end if;
						if to_integer(unsigned(re_point.y)) > re_param2 then
							y_r_f <= '0'; --We must decrease y1 valuese to achive y2
						else
							y_r_f <= '1'; --We must increase y1 valuese to achive y2
						end if;
					when RASTER_DRAW_CIRCLE =>
						--We are going to draw a circle.
						frame_buffer_cmd.color <= re_color;                         --Color is fixed, Just latch it
						re_x_draw              <= to_integer(unsigned(re_point.x)); --Start point of drawing
						re_y_draw              <= to_integer(unsigned(re_point.y));
						re_param1_l            <= re_param1; --Latch Parameter 1
						re_param2_l            <= 0;         --Latch Parameter 2
						re_param3_l            <= re_param1; --Latch Parameter 3
						re_w_draw              <= 0;         --Pixel Countetr. We need to set 8 pixels, for each drawing iteration (Bresenham Algorithm).
						re_h_draw              <= 0;
						--Bresenham decision value
						bre_decision                 <= 3 - shift_left(to_signed(re_param1, 11), 1);
						re_state                     <= RE_STATE_DRAW_CIRCLE; --Set state to draw circle
						frame_buffer_cmd.fill_length <= x"01";                --We draw pixel by pixel
					when RASTER_FILL_CIRCLE =>
						--We are going to draw a circle.
						frame_buffer_cmd.color <= re_color;                         --Color is fixed, Just latch it
						re_x_draw              <= to_integer(unsigned(re_point.x)); --Start point of drawing
						re_y_draw              <= to_integer(unsigned(re_point.y));
						re_param1_l            <= re_param1; --Latch Parameter 1
						re_param2_l            <= 0;         --Latch Parameter 2
						re_param3_l            <= re_param1; --Latch Parameter 3
						re_w_draw              <= 0;         --Pixel Countetr. We need to set 8 pixels, for each drawing iteration (Bresenham Algorithm).
						re_h_draw              <= 0;
						re_t_draw := 0;
						--Bresenham decision value
						bre_decision <= 3 - shift_left(to_signed(re_param1, 11), 1);
						re_state     <= RE_STATE_FILL_CIRCLE; --Set state to fill circle
				end case;
			end if;

			if re_fb_fifo_wr_full = '0' then
				case re_state is
					when RE_IDLE =>
						--NOP!
					when RE_STATE_FILL_RECT =>
						--Param 1: Rectangle Width
						--Param 2: Rectangle Height
						--Param 3: Reserved

						--Calculate new x,y
						frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_w_draw, frame_buffer_cmd.pos.x'length));
						frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_h_draw, frame_buffer_cmd.pos.y'length));
						--We have a new command for framebuffer block
						re_fb_fifo_wr_enq <= '1';
						--Is required width more than 255? (Maximum burst length of filling by framebuffer command)
						if re_param1_l > 255 then
							frame_buffer_cmd.fill_length <= x"FF";             --Fill 255 pixel
							re_param1_l                  <= re_param1_l - 255; --Reduce 255 drew pixels
							re_w_draw                    <= re_w_draw + 255;   --Calculate entire width of drew pixels
						else
							--Fill remainded pixels
							frame_buffer_cmd.fill_length <= std_logic_vector(to_unsigned(re_param1_l, frame_buffer_cmd.fill_length'length));
							re_param1_l                  <= re_param3_l;
							re_w_draw                    <= 0;
							if re_param2_l /= 0 then
								re_param2_l <= re_param2_l - 1;
								re_h_draw   <= re_h_draw + 1;
							else
								--Filling rectangle done
								re_state           <= RE_IDLE;
								raster_engine_busy <= '0';
								re_fb_fifo_wr_enq  <= '0';
							end if;
						end if;
					when RE_STATE_FILL_RECT_BMP =>
						--Param 1: Rectangle Width
						--Param 2: Rectangle Height
						--Param 3: Reserved
						--Draw one by one
						frame_buffer_cmd.fill_length <= x"01";
						--Calculate new x,y
						frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_w_draw, frame_buffer_cmd.pos.x'length));
						frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_h_draw, frame_buffer_cmd.pos.y'length));

						re_current_x <= re_w_draw;
						re_current_y <= re_h_draw;
						--We have a new command for framebuffer block
						re_fb_fifo_wr_enq <= '1';
						--Is Dynamic Color Enabled?
						--if re_bmp_color_en = '1' then
						frame_buffer_cmd.color <= re_color;
						--end if;
						if re_w_draw = (re_param1_l - 1) then
							re_w_draw <= 0;
							if re_h_draw = (re_param2_l - 1) then
								--Filling bitmap done
								re_state           <= RE_IDLE;
								raster_engine_busy <= '0';
								re_fb_fifo_wr_enq  <= '0';
								re_h_draw          <= 0;
							else
								re_h_draw <= re_h_draw + 1;
							end if;
						else
							re_w_draw <= re_w_draw + 1;
						end if;

					when RE_STATE_LINE =>
						--Param 1: X2 of line
						--Param 2: Y2 of line
						--Param 3: Width of line
						frame_buffer_cmd.fill_length <= x"01";
						frame_buffer_cmd.pos.x       <= std_logic_vector(to_unsigned(re_x_draw, frame_buffer_cmd.pos.x'length));
						frame_buffer_cmd.pos.y       <= std_logic_vector(to_unsigned(re_y_draw, frame_buffer_cmd.pos.y'length));
						if re_x_draw /= re_param1_l then
							re_fb_fifo_wr_enq <= '1';
							if x_r_f = '1' then
								re_x_draw <= re_x_draw + 1;
							else
								re_x_draw <= re_x_draw - 1;
							end if;
							if bre_decision < 0 then
								bre_decision <= bre_decision + shift_left(to_signed(re_h_draw, 11), 1);
							else
								if y_r_f = '1' then
									re_y_draw <= re_y_draw + 1;
								else
									re_y_draw <= re_y_draw - 1;
								end if;
								bre_decision <= bre_decision + shift_left(to_signed(re_h_draw, 11), 1) - shift_left(to_signed(re_w_draw, 11), 1);
							end if;
						else
							--Drawing line done
							re_state           <= RE_IDLE;
							raster_engine_busy <= '0';
							re_fb_fifo_wr_enq  <= '0';
						end if;
					when RE_STATE_DRAW_CIRCLE =>
						--Param 1: Radius
						--Param 2: Resereved
						--Param 3: Resereved
						re_fb_fifo_wr_enq <= '1';
						re_w_draw         <= re_w_draw + 1;
						if re_w_draw = 0 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_param3_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 1 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw - re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_param3_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 2 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw - re_param3_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 3 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw - re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw - re_param3_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 4 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_param2_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 5 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw - re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw + re_param2_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 6 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw + re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw - re_param2_l, frame_buffer_cmd.pos.y'length));
						elsif re_w_draw = 7 then
							frame_buffer_cmd.pos.x <= std_logic_vector(to_unsigned(re_x_draw - re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y <= std_logic_vector(to_unsigned(re_y_draw - re_param2_l, frame_buffer_cmd.pos.y'length));
						else
							--Calculate new point
							if re_param3_l >= re_param2_l then
								re_w_draw   <= 0;
								re_param2_l <= re_param2_l + 1;
								if bre_decision > 0 then
									re_param3_l  <= re_param3_l - 1;
									bre_decision <= bre_decision + 18 + shift_left(to_signed(re_param2_l - re_param3_l, 11), 2);
								else
									bre_decision <= bre_decision + 10 + shift_left(to_signed(re_param2_l, 11), 2);
								end if;
							else
								--Drawing circle done
								re_state           <= RE_IDLE;
								raster_engine_busy <= '0';
								re_fb_fifo_wr_enq  <= '0';
							end if;
						end if;
					when RE_STATE_FILL_CIRCLE =>
						--Param 1: Radius
						--Param 2: Resereved
						--Param 3: Resereved
						re_fb_fifo_wr_enq <= '1';
						if re_param2_l = 0 then
							re_t_draw := 1;
						else
							re_t_draw := re_param2_l;
						end if;
						re_w_draw <= re_w_draw + 1;
						if re_w_draw = 0 then
							frame_buffer_cmd.pos.x       <= std_logic_vector(to_unsigned(re_x_draw - re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y       <= std_logic_vector(to_unsigned(re_y_draw + re_param3_l, frame_buffer_cmd.pos.y'length));
							frame_buffer_cmd.fill_length <= std_logic_vector(shift_left(to_unsigned(re_t_draw, frame_buffer_cmd.fill_length'length), 1));
						elsif re_w_draw = 1 then
							frame_buffer_cmd.pos.x       <= std_logic_vector(to_unsigned(re_x_draw - re_param2_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y       <= std_logic_vector(to_unsigned(re_y_draw - re_param3_l, frame_buffer_cmd.pos.y'length));
							frame_buffer_cmd.fill_length <= std_logic_vector(shift_left(to_unsigned(re_t_draw, frame_buffer_cmd.fill_length'length), 1));
						elsif re_w_draw = 2 then
							frame_buffer_cmd.pos.x       <= std_logic_vector(to_unsigned(re_x_draw - re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y       <= std_logic_vector(to_unsigned(re_y_draw + re_param2_l, frame_buffer_cmd.pos.y'length));
							frame_buffer_cmd.fill_length <= std_logic_vector(shift_left(to_unsigned(re_param3_l, frame_buffer_cmd.fill_length'length), 1));
						elsif re_w_draw = 3 then
							frame_buffer_cmd.pos.x       <= std_logic_vector(to_unsigned(re_x_draw - re_param3_l, frame_buffer_cmd.pos.x'length));
							frame_buffer_cmd.pos.y       <= std_logic_vector(to_unsigned(re_y_draw - re_param2_l, frame_buffer_cmd.pos.y'length));
							frame_buffer_cmd.fill_length <= std_logic_vector(shift_left(to_unsigned(re_param3_l, frame_buffer_cmd.fill_length'length), 1));
						else
							--Calculate new point
							if re_param3_l >= re_param2_l then
								re_w_draw   <= 0;
								re_param2_l <= re_param2_l + 1;
								if bre_decision > 0 then
									re_param3_l  <= re_param3_l - 1;
									bre_decision <= bre_decision + 18 + shift_left(to_signed(re_param2_l - re_param3_l, 11), 2);
								else
									bre_decision <= bre_decision + 10 + shift_left(to_signed(re_param2_l, 11), 2);
								end if;
							else
								--Drawing circle done
								re_state           <= RE_IDLE;
								raster_engine_busy <= '0';
								re_fb_fifo_wr_enq  <= '0';
							end if;
						end if;
				end case;
			else
				re_fb_fifo_wr_enq <= '0'; --Framebuffer FIFO is full. wait...
			end if;
		end if;
	end process;
end Behavioral;
