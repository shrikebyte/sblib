--##############################################################################
--# File : axil_to_apb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite to APB bridge.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_to_apb is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view  s_axil_view;
    m_apb  : view  m_apb_view
  );
end entity;

architecture rtl of axil_to_apb is

  signal wb        : bus_wb_t;
  signal wb_stb_re : std_ulogic;

begin

  u_axil_to_wb : entity work.axil_to_wb
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => s_axil,
    m_wb   => wb
  );

  -- This works because axil_to_wb guarantees that wb.stb is dropped low
  -- between transactions.
  u_edge_detect : entity work.edge_detect
  generic map (
    G_WIDTH   => 1,
    G_RST_VAL => "0"
  )
  port map (
    clk     => clk,
    srst    => srst,
    din(0)  => wb.stb,
    rise(0) => wb_stb_re
  );

  m_apb.psel    <= wb.stb;
  m_apb.penable <= wb.stb and not wb_stb_re;
  m_apb.pwrite  <= wb.wen;
  m_apb.paddr   <= wb.addr;
  m_apb.pwdata  <= wb.wdat;
  m_apb.pstrb   <= wb.wsel;
  wb.rdat       <= m_apb.prdata;
  wb.ack        <= m_apb.pready;
  wb.err        <= m_apb.pslverr;

end architecture;
