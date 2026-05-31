--##############################################################################
--# File : tick.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Tick generator for creating a periodic clock-enable pulse
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;

entity tick is
  generic (
    -- Input clock frequency
    G_CLK_HZ    : positive := 100_000_000;
    -- Desired output pulse frequency
    G_TICK_HZ   : positive range 1 to G_CLK_HZ := 1_000_000;
    -- Allowed output error tolerance, as a percentage from 0.0 to 100.0
    -- This is the allowed difference between the requested output frequency and
    -- the actual output frequency.
    G_TOLERANCE : real range 0.0 to 100.0 := 2.5
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    en   : in    std_ulogic := '1';
    tick : out   std_ulogic
  );
end entity;

architecture rtl of tick is

  constant DIV : natural := ((G_CLK_HZ + (G_TICK_HZ / 2)) / G_TICK_HZ);
  constant ACTUAL : real := real(G_CLK_HZ) / real(DIV);
  constant TOL : real := abs(ACTUAL - real(G_TICK_HZ)) / real(G_TICK_HZ) * 100.0;
  signal cnt : natural range 0 to DIV - 1;

begin

  assert TOL < G_TOLERANCE
    report "ERROR: tick: Actual freq is too different from requested freq"
    severity error;

  assert false
    report "NOTE: tick: Requested freq: " & real'image(real(G_TICK_HZ)) &
      " Actual freq: " & real'image(ACTUAL) &
      " Requested tolerance (%): " & real'image(G_TOLERANCE) &
      " Actual difference (%): " & real'image(TOL)
    severity note;

  prc_tick : process (clk) begin
    if rising_edge(clk) then
      if en then
        if cnt = (DIV - 1) then
          cnt  <= 0;
          tick <= '1';
        else
          cnt  <= cnt + 1;
          tick <= '0';
        end if;
      end if;

      if srst then
        cnt  <= 0;
        tick <= '0';
      end if;
    end if;
  end process;

end architecture;
