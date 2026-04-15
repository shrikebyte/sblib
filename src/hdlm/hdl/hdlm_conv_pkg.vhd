--##############################################################################
--# File : hdlm_conv_pkg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Convert between bus_pkg types and hdl-modules types
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.axi_lite_pkg.all;
use work.util_pkg.all;
use work.bus_pkg.all;

package hdlm_conv_pkg is

  procedure axil_attach (
    signal s_axil     : view s_axil_view of bus_axil_t;
    signal m_axil_m2s : out axi_lite_m2s_t;
    signal m_axil_s2m : in axi_lite_s2m_t
  );

end package;

package body hdlm_conv_pkg is

  procedure axil_attach (
    signal s_axil     : view s_axil_view of bus_axil_t;
    signal m_axil_m2s : out axi_lite_m2s_t;
    signal m_axil_s2m : in axi_lite_s2m_t
  ) is
  begin
    m_axil_m2s.read.ar.valid                  <= s_axil.arvalid;
    m_axil_m2s.read.ar.addr(axil_addr_range)  <= unsigned(s_axil.araddr);
    m_axil_m2s.read.r.ready                   <= s_axil.rready;
    m_axil_m2s.write.aw.valid                 <= s_axil.awvalid;
    m_axil_m2s.write.aw.addr(axil_addr_range) <= unsigned(s_axil.awaddr);
    m_axil_m2s.write.w.valid                  <= s_axil.wvalid;
    m_axil_m2s.write.w.data(axil_data_range)  <= s_axil.wdata;
    m_axil_m2s.write.w.strb(axil_strb_range)  <= s_axil.wstrb;
    m_axil_m2s.write.b.ready                  <= s_axil.bready;
    --
    s_axil.arready  <= m_axil_s2m.read.ar.ready;
    s_axil.rvalid   <= m_axil_s2m.read.r.valid;
    s_axil.rdata    <= m_axil_s2m.read.r.data(axil_data_range);
    s_axil.rresp    <= m_axil_s2m.read.r.resp;
    s_axil.awready  <= m_axil_s2m.write.aw.ready;
    s_axil.wready   <= m_axil_s2m.write.w.ready;
    s_axil.bvalid   <= m_axil_s2m.write.b.valid;
    s_axil.bresp    <= m_axil_s2m.write.b.resp;
  end procedure;

end package body;
