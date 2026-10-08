--##############################################################################
--# File : axil_fifo.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite FIFO
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_fifo is
  generic (
    -- Depth of the FIFO. Must be a power of 2.
    G_DEPTH : positive
  );
  port (
    clk    : in   std_ulogic;
    srst   : in   std_ulogic;
    s_axil : view s_axil_view;
    m_axil : view m_axil_view
  );
end entity;

architecture rtl of axil_fifo is

  signal aw0 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal aw1 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal w0  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal w1  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal b0  : axis_t (tdata(7 downto 0), tkeep(0 downto 0), tuser(AXIL_RSP_RANGE));
  signal b1  : axis_t (tdata(7 downto 0), tkeep(0 downto 0), tuser(AXIL_RSP_RANGE));
  signal ar0 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal ar1 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(AXIL_STRB_RANGE), tuser(0 downto 0));
  signal r0  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(AXIL_RSP_RANGE));
  signal r1  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(AXIL_RSP_RANGE));

begin

  -- ---------------------------------------------------------------------------
  u_axis_fifo_aw : entity work.axis_fifo
  generic map (
    G_DW             => AXIL_ADDR_WIDTH,
    G_UW             => 1,
    G_DEPTH          => G_DEPTH,
    G_USE_TKEEP      => false,
    G_USE_TLAST      => false,
    G_USE_TUSER      => false,
    G_PACKET_MODE    => false,
    G_DROP_OVERSIZE  => false,
    G_DROP_WHEN_FULL => false
  )
  port map(
    clk    => clk,
    srst   => srst,
    s_axis => aw0,
    m_axis => aw1
  );
  aw0.tvalid     <= s_axil.awvalid;
  s_axil.awready <= aw0.tready;
  aw0.tdata      <= s_axil.awaddr;
  --
  m_axil.awvalid <= aw1.tvalid;
  aw1.tready     <= m_axil.awready;
  m_axil.awaddr  <= aw1.tdata;

  -- ---------------------------------------------------------------------------
  u_axis_fifo_w : entity work.axis_fifo
  generic map (
    G_DW             => AXIL_DATA_WIDTH,
    G_UW             => 1,
    G_DEPTH          => G_DEPTH,
    G_USE_TKEEP      => true,
    G_USE_TLAST      => false,
    G_USE_TUSER      => false,
    G_PACKET_MODE    => false,
    G_DROP_OVERSIZE  => false,
    G_DROP_WHEN_FULL => false
  )
  port map(
    clk    => clk,
    srst   => srst,
    s_axis => w0,
    m_axis => w1
  );
  w0.tvalid     <= s_axil.wvalid;
  s_axil.wready <= w0.tready;
  w0.tdata      <= s_axil.wdata;
  w0.tkeep      <= s_axil.wstrb;
  --
  m_axil.wvalid <= w1.tvalid;
  w1.tready     <= m_axil.wready;
  m_axil.wdata  <= w1.tdata;
  m_axil.wstrb  <= w1.tkeep;

  -- ---------------------------------------------------------------------------
  u_axis_fifo_b : entity work.axis_fifo
  generic map (
    G_DW             => 8,
    G_UW             => AXIL_RSP_WIDTH,
    G_DEPTH          => G_DEPTH,
    G_USE_TKEEP      => false,
    G_USE_TLAST      => false,
    G_USE_TUSER      => true,
    G_PACKET_MODE    => false,
    G_DROP_OVERSIZE  => false,
    G_DROP_WHEN_FULL => false
  )
  port map(
    clk    => clk,
    srst   => srst,
    s_axis => b0,
    m_axis => b1
  );
  b0.tvalid     <= m_axil.bvalid;
  m_axil.bready <= b0.tready;
  b0.tuser      <= m_axil.bresp;
  --
  s_axil.bvalid <= b1.tvalid;
  b1.tready     <= s_axil.bready;
  s_axil.bresp  <= b1.tuser;

  -- ---------------------------------------------------------------------------
  u_axis_fifo_ar : entity work.axis_fifo
  generic map (
    G_DW             => AXIL_ADDR_WIDTH,
    G_UW             => 1,
    G_DEPTH          => G_DEPTH,
    G_USE_TKEEP      => false,
    G_USE_TLAST      => false,
    G_USE_TUSER      => false,
    G_PACKET_MODE    => false,
    G_DROP_OVERSIZE  => false,
    G_DROP_WHEN_FULL => false
  )
  port map(
    clk    => clk,
    srst   => srst,
    s_axis => ar0,
    m_axis => ar1
  );
  ar0.tvalid     <= s_axil.arvalid;
  s_axil.arready <= ar0.tready;
  ar0.tdata      <= s_axil.araddr;
  --
  m_axil.arvalid <= ar1.tvalid;
  ar1.tready     <= m_axil.arready;
  m_axil.araddr  <= ar1.tdata;

  -- ---------------------------------------------------------------------------
  u_axis_fifo_r : entity work.axis_fifo
  generic map (
    G_DW             => AXIL_DATA_WIDTH,
    G_UW             => AXIL_RSP_WIDTH,
    G_DEPTH          => G_DEPTH,
    G_USE_TKEEP      => false,
    G_USE_TLAST      => false,
    G_USE_TUSER      => true,
    G_PACKET_MODE    => false,
    G_DROP_OVERSIZE  => false,
    G_DROP_WHEN_FULL => false
  )
  port map(
    clk    => clk,
    srst   => srst,
    s_axis => r0,
    m_axis => r1
  );
  r0.tvalid     <= m_axil.rvalid;
  m_axil.rready <= r0.tready;
  r0.tdata      <= m_axil.rdata;
  r0.tuser      <= m_axil.rresp;
  --
  s_axil.rvalid <= r1.tvalid;
  r1.tready     <= s_axil.rready;
  s_axil.rdata  <= r1.tdata;
  s_axil.rresp  <= r1.tuser;

end architecture;
