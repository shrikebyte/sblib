--##############################################################################
--# File : pulse_extend.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Simple pulse extender
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_extend is
  generic (
    --! Active logic level of the pulse
    G_ACT_LVL : std_logic := '1';
    --! Length of the output pulse in clockcycles
    G_PULSE_LEN : positive := 4
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;
    din  : in    std_logic;
    dout : out   std_logic
  );
end entity;

architecture rtl of pulse_extend is

  -- ---------------------------------------------------------------------------
  signal cnt : integer range 0 to G_PULSE_LEN - 1;

begin

  -- ---------------------------------------------------------------------------
  prc_pulse_ext : process (clk) is begin
    if rising_edge(clk) then
      if srst then
        -- Counter resets the the expired state
        cnt <= G_PULSE_LEN - 1;
        -- Dout resets the not active state
        dout <= not G_ACT_LVL;
      else
        -- If new pulse at the input, then start the output pulse and clear the
        -- pulse counter
        if din = G_ACT_LVL then
          cnt  <= 0;
          dout <= G_ACT_LVL;
        -- If pulse counter expired, then dont set the output pulse
        elsif cnt = G_PULSE_LEN - 1 then
          dout <= not G_ACT_LVL;
        -- Otherwise, if counter has not expired, then keep incrementing it and
        -- enable the output pulse
        else
          cnt  <= cnt + 1;
          dout <= G_ACT_LVL;
        end if;
      end if;
    end if;
  end process;

end architecture;
