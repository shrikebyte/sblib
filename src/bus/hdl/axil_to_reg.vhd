--##############################################################################
--# File : axil_to_reg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI lite to register bus bridge.
--# This bridge supports full throughput to a simplified bus with fixed read
--# and write latency.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_to_reg is
  generic (
    G_WR_LATENCY : positive := 1;
    G_RD_LATENCY : positive := 1
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view s_axil_view;
    m_reg  : view m_reg_view
  );
end entity;

architecture rtl of axil_to_reg is

  signal rvalid  : std_ulogic;
  signal rdata   : std_ulogic_vector(AXIL_DATA_RANGE);
  signal rresp   : std_ulogic_vector(AXIL_RSP_RANGE);
  signal bvalid  : std_ulogic;
  signal bresp   : std_ulogic_vector(AXIL_RSP_RANGE);
  signal axil_r0 : axis_t(tdata(AXIL_DATA_RANGE), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal axil_r1 : axis_t(tdata(AXIL_DATA_RANGE), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal axil_b0 : axis_t(tdata(-1 downto 0), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal axil_b1 : axis_t(tdata(-1 downto 0), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));

begin

  -- ---------------------------------------------------------------------------
  -- Enable an outgoing read request when the read address
  -- is valid and when the read response is not stalled.
  m_reg.ren      <= s_axil.arvalid and (s_axil.rready or not s_axil.rvalid);
  m_reg.raddr    <= s_axil.araddr;
  s_axil.arready <= m_reg.ren;

  -- Pulse rvalid exactly G_RD_LATENCY cycles after ren. Since we control the
  -- ren logic and since we know that a read response always comes in
  -- G_RD_LATENCY cycles, it is okay to just pulse rvalid, because we know that
  -- rready will always be high whenever an rvalid pulse arrives.
  u_r_delay : entity work.shift_reg
  generic map (
    G_WIDTH   => 1,
    G_DEPTH   => G_RD_LATENCY - 1,
    G_RST_VAL => "0",
    G_OUT_REG => true
  )
  port map (
    clk  => clk,
    srst => srst,
    en   => '1',
    d(0) => m_reg.ren,
    q(0) => rvalid
  );
  rresp <= AXI_RSP_SLVERR when m_reg.rerr else AXI_RSP_OKAY;
  rdata <= m_reg.rdata;

  -- Read response buffer.
  -- This is needed to maintain throughput because the slave read response
  -- is assumed to always take G_RD_LATENCY cycles. This buffer stores responses
  -- if the master is stalling the read response channel while there are still
  -- outstanding requests that the slave has not yet completed.
  u_r_buffer : entity work.axis_pipes
  generic map (
    G_STAGES     => G_RD_LATENCY,
    G_DATA_PIPE  => false,
    G_READY_PIPE => true
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => axil_r0,
    m_axis => axil_r1
  );
  axil_r0.tvalid <= rvalid;
  axil_r0.tdata  <= rdata;
  axil_r0.tuser  <= rresp;
  --
  axil_r1.tready <= s_axil.rready;
  s_axil.rvalid  <= axil_r1.tvalid;
  s_axil.rdata   <= axil_r1.tdata;
  s_axil.rresp   <= axil_r1.tuser;

  -- ---------------------------------------------------------------------------
  m_reg.wen      <= s_axil.awvalid and s_axil.wvalid and (s_axil.bready or not s_axil.bvalid);
  m_reg.waddr    <= s_axil.awaddr;
  m_reg.wdata    <= s_axil.wdata;
  m_reg.wstrb    <= s_axil.wstrb;
  s_axil.wready  <= m_reg.wen;
  s_axil.awready <= m_reg.wen;

  u_b_delay : entity work.shift_reg
  generic map (
    G_WIDTH   => 1,
    G_DEPTH   => G_WR_LATENCY - 1,
    G_RST_VAL => "0",
    G_OUT_REG => true
  )
  port map (
    clk  => clk,
    srst => srst,
    en   => '1',
    d(0) => m_reg.wen,
    q(0) => bvalid
  );
  bresp <= AXI_RSP_SLVERR when m_reg.werr else AXI_RSP_OKAY;

  u_b_buffer : entity work.axis_pipes
  generic map (
    G_STAGES     => G_WR_LATENCY,
    G_DATA_PIPE  => false,
    G_READY_PIPE => true
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => axil_b0,
    m_axis => axil_b1
  );
  axil_b0.tvalid <= bvalid;
  axil_b0.tuser  <= bresp;
  --
  axil_b1.tready <= s_axil.bready;
  s_axil.bvalid  <= axil_b1.tvalid;
  s_axil.bresp   <= axil_b1.tuser;

end architecture;
