--##############################################################################
--# File : edge_detect.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Edge detector. Pulses for one clock cycle on a positive edge, negative edge,
--# or both.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity edge_detect is
  generic (
    G_WIDTH : positive := 1;
    -- This should be set the the reset value of din to avoid a false pulse
    -- after reset. Alternatively, if you want a startup pulse, this could
    -- be set to the opposite reset value of din.
    G_RST_VAL : std_ulogic_vector(G_WIDTH - 1 downto 0) := (others=> '0')
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    din  : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    rise : out   std_ulogic_vector(G_WIDTH - 1 downto 0);
    fall : out   std_ulogic_vector(G_WIDTH - 1 downto 0);
    both : out   std_ulogic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of edge_detect is

  signal din_ff : std_ulogic_vector(din'range);

begin

  prc_ff : process (clk) is begin
    if rising_edge(clk) then
      if srst then
        din_ff <= G_RST_VAL;
      else
        din_ff <= din;
      end if;
    end if;
  end process;

  rise <= din and not din_ff;
  fall <= not din and din_ff;
  both <= din xor din_ff;

end architecture;
