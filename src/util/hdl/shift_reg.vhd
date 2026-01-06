--##############################################################################
--# File : shift_reg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Shift Register
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;

entity shift_reg is
  generic (
    G_WIDTH : positive;
    G_DEPTH : natural;
    --! Only applicable if G_OUT_REG is true
    G_RESET_VAL : std_logic_vector(G_WIDTH - 1 downto 0) := (others => '0');
    --! Adds an additional output register to the shift register, changing the
    --! depth to G_DEPTH + 1
    G_OUT_REG : boolean := false
  );
  port (
    clk : in    std_logic;
    --! srst is only applicable if G_OUT_REG is true
    srst : in    std_logic := '0';
    en   : in    std_logic := '1';
    d    : in    std_logic_vector(G_WIDTH - 1 downto 0);
    q    : out   std_logic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of shift_reg is

begin

  -- ---------------------------------------------------------------------------
  -- Comb passthru
  gen_sr : if G_DEPTH = 0 and G_OUT_REG = false generate

    q <= d;

  -- ---------------------------------------------------------------------------
  -- Reg passthru
  elsif G_DEPTH = 0 and G_OUT_REG = true generate

    prc_out_reg : process (clk) is begin
      if rising_edge(clk) then
        if en then
          q <= d;
        end if;

        if srst then
          q <= G_RESET_VAL;
        end if;
      end if;
    end process;

  -- ---------------------------------------------------------------------------
  -- Shift register
  else generate

    signal sr : slv_arr_t(G_DEPTH - 1 downto 0)(G_WIDTH - 1 downto 0) := (others=> G_RESET_VAL);

  begin

    prc_sr : process (clk) is begin
      if rising_edge(clk) then
        if en then
          sr <= sr(G_DEPTH - 2 downto 0) & d;
        end if;
      end if;
    end process;

    gen_out_reg : if G_OUT_REG generate

      signal cnt : integer range 0 to G_DEPTH;

    begin

      prc_out_reg : process (clk) is begin
        if rising_edge(clk) then
          if en then
            if cnt = G_DEPTH then
              q <= sr(G_DEPTH - 1);
            else
              cnt <= cnt + 1;
            end if;
          end if;

          if srst then
            q   <= G_RESET_VAL;
            cnt <= 0;
          end if;
        end if;
      end process;

    else generate begin

      q <= sr(G_DEPTH - 1);

    end generate;

  end generate;

end architecture;
