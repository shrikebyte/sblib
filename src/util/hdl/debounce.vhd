--##############################################################################
--# File : debounce.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Ensures that an input is stable for G_COUNT clockcycles in a row before
--# transitioning the output.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
  generic (
    G_RST_VAL : std_logic := '0';
    G_COUNT   : positive  := 16
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic := '0';
    din  : in    std_logic;
    dout : out   std_logic
  );
end entity;

architecture rtl of debounce is

  signal samples : std_logic_vector(1 downto 0);
  signal cnt     : integer range 0 to G_COUNT - 1;

begin

  prc_debounce : process (clk) is begin
    if rising_edge(clk) then
      samples <= samples(0) & din;
      if xor samples then
        cnt <= 0;
      elsif cnt < G_COUNT - 1 then
        cnt <= cnt + 1;
      else
        dout <= samples(0);
      end if;

      if srst then
        dout <= G_RST_VAL;
        cnt  <= 0;
      end if;
    end if;
  end process;

end architecture;
