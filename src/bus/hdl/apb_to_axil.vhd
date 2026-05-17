--##############################################################################
--# File : apb_to_axil.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# APB to AXI Lite bridge.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity apb_to_axil is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_apb  : view s_apb_view;
    m_axil : view m_axil_view
  );
end entity;

architecture rtl of apb_to_axil is

  signal wb : bus_wb_t;

begin

  u_wb_to_axil : entity work.wb_to_axil
  port map (
    clk    => clk,
    srst   => srst,
    s_wb   => wb,
    m_axil => m_axil
  );

  wb.stb  <= s_apb.psel and s_apb.penable;
  wb.wen  <= s_apb.pwrite;
  wb.addr <= s_apb.paddr;
  wb.wdat <= s_apb.pwdata;
  wb.wsel <= s_apb.pstrb;
  --
  s_apb.prdata  <= wb.rdat;
  s_apb.pready  <= wb.ack;
  s_apb.pslverr <= wb.err;

end architecture;
