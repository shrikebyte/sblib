--##############################################################################
--# File : cdc_reset.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Reset synchronizer.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cdc_reset is
  generic (
    -- Number of extra synchronizer flip-flops.
    -- Total number of sync flops = 2 + G_EXTRA_SYNC
    G_EXTRA_SYNC : natural := 0
  );
  port (
    clk : in    std_ulogic;
    -- Async reset input
    arst : in    std_ulogic;
    -- Async assertion / sync de-assertion output
    srst : out   std_ulogic
  );
end entity;

architecture rtl of cdc_reset is

  constant SYNC_LEN : positive := 2 + G_EXTRA_SYNC;

  signal cdc_regs : std_ulogic_vector(SYNC_LEN - 1 downto 0) := (others=> '1');

  attribute async_reg                 : string;
  attribute shreg_extract             : string;
  attribute async_reg of cdc_regs     : signal is "TRUE";
  attribute shreg_extract of cdc_regs : signal is "NO";

begin

  -- Async assertion and sync de-assertion
  prc_arst_0_sync : process (clk, arst) is begin
    if arst then
      cdc_regs <= (others => '1');
    elsif rising_edge(clk) then
      cdc_regs <= cdc_regs(SYNC_LEN - 2 downto 0) & '0';
    end if;
  end process;

  srst <= cdc_regs(SYNC_LEN - 1);

end architecture;
