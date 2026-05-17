--##############################################################################
--# File     : axil_pipes.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Cascaded AXI Lite pipeline registers.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_pipes is
  generic (
    G_STAGES        : positive := 1;
    G_AW_DATA_PIPE  : boolean  := true;
    G_AW_READY_PIPE : boolean  := true;
    G_W_DATA_PIPE   : boolean  := true;
    G_W_READY_PIPE  : boolean  := true;
    G_B_DATA_PIPE   : boolean  := true;
    G_B_READY_PIPE  : boolean  := true;
    G_AR_DATA_PIPE  : boolean  := true;
    G_AR_READY_PIPE : boolean  := true;
    G_R_DATA_PIPE   : boolean  := true;
    G_R_READY_PIPE  : boolean  := true
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view s_axil_view;
    m_axil : view m_axil_view
  );
end entity;

architecture rtl of axil_pipes is

  signal aw0 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(-1 downto 0), tuser(-1 downto 0));
  signal aw1 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(-1 downto 0), tuser(-1 downto 0));
  signal w0  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(-1 downto 0));
  signal w1  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(AXIL_STRB_RANGE), tuser(-1 downto 0));
  signal b0  : axis_t (tdata(-1 downto 0), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal b1  : axis_t (tdata(-1 downto 0), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal ar0 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(-1 downto 0), tuser(-1 downto 0));
  signal ar1 : axis_t (tdata(AXIL_ADDR_RANGE), tkeep(-1 downto 0), tuser(-1 downto 0));
  signal r0  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));
  signal r1  : axis_t (tdata(AXIL_DATA_RANGE), tkeep(-1 downto 0), tuser(AXIL_RSP_RANGE));

begin

  -- ---------------------------------------------------------------------------
  u_axis_pipes_aw : entity work.axis_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_DATA_PIPE  => G_AW_DATA_PIPE,
    G_READY_PIPE => G_AW_READY_PIPE
  )
  port map (
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
  u_axis_pipes_w : entity work.axis_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_DATA_PIPE  => G_W_DATA_PIPE,
    G_READY_PIPE => G_W_READY_PIPE
  )
  port map (
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
  u_axis_pipes_b : entity work.axis_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_DATA_PIPE  => G_B_DATA_PIPE,
    G_READY_PIPE => G_B_READY_PIPE
  )
  port map (
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
  u_axis_pipes_ar : entity work.axis_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_DATA_PIPE  => G_AR_DATA_PIPE,
    G_READY_PIPE => G_AR_READY_PIPE
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => ar0,
    m_axis => ar1
  );

  ar0.tvalid     <= s_axil.bvalid;
  s_axil.arready <= ar0.tready;
  ar0.tdata      <= s_axil.araddr;
  --
  m_axil.arvalid <= ar1.tvalid;
  ar1.tready     <= m_axil.arready;
  m_axil.araddr  <= ar1.tdata;

  -- ---------------------------------------------------------------------------
  u_axis_pipes_r : entity work.axis_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_DATA_PIPE  => G_R_DATA_PIPE,
    G_READY_PIPE => G_R_READY_PIPE
  )
  port map (
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
