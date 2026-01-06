--##############################################################################
--# File : cdc_bit.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Simple bit synchronizer. This can be used to sync one bit or several
--# unrelated bits to a common clock. Includes the option to register the
--# input signal before syncing. If the input signal comes from off-chip, then
--# there is likely no src_clk, but if there is a src_clk for src_bit
--# and the application can handle the extra cycle of latency, then it is
--# recommended to enable the 'G_USE_SRC_REG' generic.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity cdc_bit is
  generic (
    --! True: Register the input; False: Don't register the input; If set to
    --! false then src_clk is unused.
    G_USE_SRC_REG : boolean := false;
    --! Number of extra synchronizer flip-flops.
    G_EXTRA_SYNC : natural := 0
  );
  port (
    src_clk : in    std_ulogic := 'U';
    src_bit : in    std_ulogic_vector;
    dst_clk : in    std_ulogic;
    dst_bit : out   std_ulogic_vector
  );
end entity;

architecture rtl of cdc_bit is

  constant SYNC_LEN : positive := 2 + G_EXTRA_SYNC;
  constant DW       : natural  := src_bit'length;

  type cdc_regs_t is array(natural range 0 to SYNC_LEN - 1) of
    std_ulogic_vector(DW - 1 downto 0);

  signal src_reg  : std_ulogic_vector(DW - 1 downto 0);
  signal cdc_regs : cdc_regs_t;

  attribute async_reg                 : string;
  attribute async_reg of cdc_regs     : signal is "TRUE";
  attribute shreg_extract             : string;
  attribute shreg_extract of cdc_regs : signal is "NO";
  attribute dont_touch                : string;
  attribute dont_touch of src_reg     : signal is "TRUE";

begin

  -- ---------------------------------------------------------------------------
  gen_src_clk : if G_USE_SRC_REG generate

    prc_src_clk : process (src_clk) is begin
      if rising_edge(src_clk) then
        src_reg <= src_bit;
      end if;
    end process;

  else generate

    src_reg <= src_bit;

  end generate;

  -- ---------------------------------------------------------------------------
  prc_bit_sync : process (dst_clk) is begin
    if rising_edge(dst_clk) then
      cdc_regs(0) <= src_reg;

      for i in 1 to SYNC_LEN - 1 loop
        cdc_regs(i) <= cdc_regs(i - 1);
      end loop;

    end if;
  end process;

  dst_bit <= cdc_regs(SYNC_LEN - 1);

end architecture;
