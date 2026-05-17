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
    G_RST_VAL : std_ulogic := '0';
    G_COUNT   : positive   := 16
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    din  : in    std_ulogic;
    dout : out   std_ulogic
  );
end entity;

architecture rtl of debounce is

  signal samples : std_ulogic_vector(1 downto 0);
  signal cnt     : integer range 0 to G_COUNT - 1;

begin

  prc_debounce : process (clk) is begin
    if rising_edge(clk) then
      samples <= samples(0) & din;

      if xor samples then
        cnt <= 0;
      elsif cnt = (G_COUNT - 1) then
        dout <= samples(0);
      else
        cnt <= cnt + 1;
      end if;

      if srst then
        dout <= G_RST_VAL;
        cnt  <= 0;
      end if;
    end if;
  end process;

end architecture;
