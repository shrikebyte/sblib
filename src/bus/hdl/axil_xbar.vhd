--##############################################################################
--# File : axil_xbar.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite crossbar.
--# Designed for simplicity and low area. Only supports one
--# transaction at a time.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_xbar is
  generic (
    G_NUM_M     : positive;
    G_NUM_S     : positive;
    G_BASEADDRS : slv_arr_t(0 to G_NUM_S - 1)(AXIL_ADDR_RANGE)
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view (s_axil_view) of bus_axil_arr_t(0 to G_NUM_S - 1);
    m_axil : view (m_axil_view) of bus_axil_arr_t(0 to G_NUM_M - 1)
  );
end entity;

architecture rtl of axil_xbar is

  signal i0_axil : bus_axil_t;

begin

  u_axil_arbiter : entity work.axil_arb
  generic map (
    G_NUM_S => G_NUM_S
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => s_axil,
    m_axil => i0_axil
  );

  u_axil_decoder : entity work.axil_dec
  generic map (
    G_NUM_M     => G_NUM_M,
    G_BASEADDRS => G_BASEADDRS
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => i0_axil,
    m_axil => m_axil
  );

end architecture;
