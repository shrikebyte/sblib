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
    --! Width
    G_WIDTH : positive := 1;
    --! Register the output
    G_OUT_REG : boolean := false
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic := '0';
    din  : in    std_logic_vector(G_WIDTH - 1 downto 0);
    rise : out   std_logic_vector(G_WIDTH - 1 downto 0);
    fall : out   std_logic_vector(G_WIDTH - 1 downto 0);
    both : out   std_logic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of edge_detect is

  -- ---------------------------------------------------------------------------
  signal din_ff : std_logic_vector(G_WIDTH - 1 downto 0);
  signal rise_i : std_logic_vector(G_WIDTH - 1 downto 0);
  signal fall_i : std_logic_vector(G_WIDTH - 1 downto 0);
  signal both_i : std_logic_vector(G_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  prc_ff : process (clk) is
  begin
    if rising_edge(clk) then
      if srst then
        din_ff <= (others=> '0');
      else
        din_ff <= din;
      end if;
    end if;
  end process;

  rise_i <= not din_ff and din;
  fall_i <= din_ff and not din;
  both_i <= din_ff xor din;

  -- ---------------------------------------------------------------------------
  gen_out : if G_OUT_REG generate

    prc_out : process (clk) is begin
      if rising_edge(clk) then
        if srst then
          rise <= (others=> '0');
          fall <= (others=> '0');
          both <= (others=> '0');
        else
          rise <= rise_i;
          fall <= fall_i;
          both <= both_i;
        end if;
      end if;
    end process;

  else generate

    rise <= rise_i;
    fall <= fall_i;
    both <= both_i;

  end generate;

end architecture;
