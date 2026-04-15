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
    G_BASEADDRS : slv_arr_t(open)(AXIL_ADDR_WIDTH - 1 downto 0)
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view (s_axil_view) of bus_axil_arr_t;
    m_axil : view (m_axil_view) of bus_axil_arr_t
  );
end entity;

architecture rtl of axil_xbar is

  signal i0_axil : bus_axil_t;

begin

  u_axil_arbiter : entity work.axil_arbiter
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => s_axil,
    m_axil => i0_axil
  );

  u_axil_decoder : entity work.axil_decoder
  generic map (
    G_BASEADDRS => G_BASEADDRS
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => i0_axil,
    m_axil => m_axil
  );

end architecture;
