--##############################################################################
--# File : cdc_reset.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--! Reset synchronizer.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cdc_reset is
  generic (
    -- Number of additional synchronizer flip-flops beyond the required 2.
    -- Ie: if this is set to 2, then there will be 4 sync flip flops.
    G_EXTRA_SYNC : natural := 0
  );
  port (
    clk  : in    std_ulogic;
    arst : in    std_ulogic;
    srst : out   std_ulogic
  );
end entity;

architecture rtl of cdc_reset is

  constant SYNC_LEN : positive := 2 + G_EXTRA_SYNC;

  signal cdc_regs : std_logic_vector(SYNC_LEN - 1 downto 0) := (others=> '1');
  signal arst_0   : std_logic;

  attribute async_reg                 : string;
  attribute shreg_extract             : string;
  attribute async_reg of cdc_regs     : signal is "TRUE";
  attribute shreg_extract of cdc_regs : signal is "NO";

begin

  -- Async assertion and sync de-assertion
  prc_arst_0_sync : process (clk, arst_0) is begin
    if arst then
      cdc_regs <= (others => '1');
    elsif rising_edge(clk) then
      cdc_regs <= cdc_regs(SYNC_LEN - 2 downto 0) & '0';
    end if;
  end process;

  srst <= cdc_regs(SYNC_LEN - 1);

end architecture;
