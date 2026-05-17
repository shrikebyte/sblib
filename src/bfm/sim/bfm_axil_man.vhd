--##############################################################################
--# File : bfm_axil_man.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI lite manager BFM. This is just an axil record wrapper around the vunit
--# bfm
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

entity bfm_axil_man is
  generic (
    G_BUS_HANDLE : bus_master_t
  );
  port (
    clk    : in    std_ulogic;
    m_axil : view  m_axil_view
  );
end entity;

architecture sim of bfm_axil_man is

begin

  u_axi_lite_master : entity vunit_lib.axi_lite_master
  generic map (
    BUS_HANDLE => G_BUS_HANDLE
  )
  port map (
    aclk    => clk,
    arready => m_axil.arready,
    arvalid => m_axil.arvalid,
    araddr  => m_axil.araddr,
    rready  => m_axil.rready,
    rvalid  => m_axil.rvalid,
    rdata   => m_axil.rdata,
    rresp   => m_axil.rresp,
    awready => m_axil.awready,
    awvalid => m_axil.awvalid,
    awaddr  => m_axil.awaddr,
    wready  => m_axil.wready,
    wvalid  => m_axil.wvalid,
    wdata   => m_axil.wdata,
    wstrb   => m_axil.wstrb,
    bvalid  => m_axil.bvalid,
    bready  => m_axil.bready,
    bresp   => m_axil.bresp
  );

end architecture;
