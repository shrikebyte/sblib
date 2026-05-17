--##############################################################################
--# File : pulse_extend.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Pulse extender
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_extend is
  generic (
    -- Active logic level of the pulse
    G_ACT_LVL : std_ulogic := '1';
    -- Length of the output pulse in clockcycles
    G_PULSE_LEN : positive := 4
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    din  : in    std_ulogic;
    dout : out   std_ulogic
  );
end entity;

architecture rtl of pulse_extend is

  signal cnt : integer range 0 to G_PULSE_LEN - 1;

begin

  prc_pulse_ext : process (clk) is begin
    if rising_edge(clk) then
      if din = G_ACT_LVL then
        cnt  <= 0;
        dout <= G_ACT_LVL;
      elsif cnt = (G_PULSE_LEN - 1) then
        dout <= not G_ACT_LVL;
      else
        cnt <= cnt + 1;
      end if;

      if srst then
        cnt  <= G_PULSE_LEN - 1;
        dout <= not G_ACT_LVL;
      end if;
    end if;
  end process;

end architecture;
