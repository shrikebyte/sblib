--##############################################################################
--# File : axil_regs.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Generic AXI-Lite register file
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_regs is
  generic (
    G_NUM_REGS : positive;
    G_MODES    : bus_reg_mode_arr_t(0 to G_NUM_REGS - 1);
    G_RST_VALS : slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE)
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axil : view s_axil_view;
    --
    regs_in  : in    slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE);
    regs_out : out   slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE);
    regs_rd  : out   sl_arr_t(0 to G_NUM_REGS - 1);
    regs_wr  : out   sl_arr_t(0 to G_NUM_REGS - 1)
  );
end entity;

architecture rtl of axil_regs is

  signal lcl : bus_lcl_t;

begin

  u_axil_to_lcl : entity work.axil_to_lcl
  generic map (
    G_WR_LATENCY => 1,
    G_RD_LATENCY => 1
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => s_axil,
    m_lcl  => lcl
  );

  u_lcl_regs : entity work.lcl_regs
  generic map (
    G_NUM_REGS => G_NUM_REGS,
    G_MODES    => G_MODES,
    G_RST_VALS => G_RST_VALS
  )
  port map (
    clk      => clk,
    srst     => srst,
    s_lcl    => lcl,
    regs_in  => regs_in,
    regs_out => regs_out,
    regs_rd  => regs_rd,
    regs_wr  => regs_wr
  );

end architecture;
