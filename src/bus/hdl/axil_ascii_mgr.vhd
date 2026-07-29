--##############################################################################
--# File : axil_ascii_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite wrapper around wb_ascii_mgr.
--# See wb_ascii_mgr for description.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_ascii_mgr is
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axis : view s_axis_view of axis_t(
      tdata(7 downto 0),
      tkeep(0 downto 0),
      tuser(0 downto 0)
    );
    --
    m_axis : view m_axis_view of axis_t(
      tdata(7 downto 0),
      tkeep(0 downto 0),
      tuser(0 downto 0)
    );
    --
    m_axil : view  m_axil_view
  );
end entity;

architecture rtl of axil_ascii_mgr is

  signal wb : bus_wb_t;

begin

  u_wb_ascii_mgr : entity work.wb_ascii_mgr
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => s_axis,
    m_axis => m_axis,
    m_wb   => wb
  );

  u_wb_to_axil : entity work.wb_to_axil
  port map (
    clk    => clk,
    srst   => srst,
    s_wb   => wb,
    m_axil => m_axil
  );

end architecture;
