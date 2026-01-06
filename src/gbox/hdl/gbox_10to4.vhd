--##############################################################################
--# File : gbox_10to4.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# This is a 10 to 4 synchronous gearbox
--# Data must always be ready at
--# the input. New data appears at din the cycle after ce. 4 and 10 both evenly
--# divide into 20, so that is the common buffer size we'll use. Every 5 cycles,
--# 2 new 10-bit words are shifted in, and every 1 cycle, 4 bits are shifted out
--# (implying that 20 bits are shifted out every 5 cycles). Now the rates are
--# aligned because we're shifting 20 bits in and 20 bits out every 5 cycles.
--# We generate 2 timing signals here, sel, and ce. ce pulses twice every 5
--# cycles to fill up buffer A. During those 5 cycles while A is being filled,
--# buffer B is being emptied. At the end of the 5 cycle period (when A is full
--# and B is empty), the buffers get swapped and the pattern continues.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gbox_10to4 is
  port (
    clk  : in    std_logic;
    srst : in    std_logic;
    oe   : in    std_logic;
    ce   : out   std_logic;
    din  : in    std_logic_vector(9 downto 0);
    dout : out   std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of gbox_10to4 is

  signal dreg0 : std_logic_vector(19 downto 0);
  signal dreg1 : std_logic_vector(19 downto 0);
  signal cnt   : integer range 0 to 4;
  signal sel   : std_logic;

begin

  -- ---------------------------------------------------------------------------
  -- sel=1 : dreg1 = output buffer and dreg0 = input buffer
  -- sel=0 : dreg0 = output buffer and dreg1 = input buffer
  prc_gearbox_10to4 : process (clk) is begin
    if rising_edge(clk) then
      if oe then
        if ce then
          if sel then
            dreg0 <= din & dreg0(19 downto 10);
          else
            dreg1 <= din & dreg1(19 downto 10);
          end if;
        end if;

        if sel then
          dreg1 <= b"0000" & dreg1(19 downto 4);
          dout  <= dreg1(3 downto 0);
        else
          dreg0 <= b"0000" & dreg0(19 downto 4);
          dout  <= dreg0(3 downto 0);
        end if;

      else
        dout <= b"0000";
      end if;

    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Pulse the input clock enable every 2/5 cycles.
  -- Swap the input/output buffers every 5 cycles.
  prc_ce : process (clk) is begin
    if rising_edge(clk) then
      if oe then
        if cnt = 4 then
          cnt <= 0;
          sel <= not sel;
        else
          cnt <= cnt + 1;
        end if;

        if cnt = 1 or cnt = 3 then
          ce <= '1';
        else
          ce <= '0';
        end if;

      else
        ce <= '0';
      end if;

      if srst then
        cnt <= 0;
        ce  <= '0';
        sel <= '0';
      end if;
    end if;
  end process;

end architecture;
