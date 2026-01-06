--##############################################################################
--# File : axil_to_reg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI lite to register bus bridge.
--# This bridge supports full thruput to a simplified bus with fixed read
--# latency.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;

entity axil_to_reg is
  generic (
    G_RD_LATENCY : positive := 1
  );
  port (
    clk        : in    std_logic;
    srst       : in    std_logic;
    s_axil_req : in    axil_req_t;
    s_axil_rsp : out   axil_rsp_t;
    m_reg_req  : out   reg_req_t;
    m_reg_rsp  : in    reg_rsp_t
  );
end entity;

architecture rtl of axil_to_reg is

  signal awvalid : std_logic;
  signal awaddr  : std_logic_vector(31 downto 0);
  signal wvalid  : std_logic;
  signal wdata   : std_logic_vector(31 downto 0);
  signal wstrb   : std_logic_vector( 3 downto 0);
  signal arvalid : std_logic;
  signal araddr  : std_logic_vector(31 downto 0);
  signal awready : std_logic;
  signal wready  : std_logic;
  signal arready : std_logic;
  signal rvalid  : std_logic;
  signal rready  : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector( 1 downto 0);

  signal wen : std_logic;
  signal ren : std_logic;

begin

  -- ---------------------------------------------------------------------------
  -- Writes
  -- ---------------------------------------------------------------------------

  -- Write address ready skid buffer. This just registers s_axil_rsp.awready to
  -- break the combinatorial loop. The comb loop was needed to maintain full
  -- bandwidth with no stalls.
  u_axis_pipe_aw : entity work.strm_pipe
  generic map (
    G_WIDTH      => 32,
    G_READY_PIPE => true,
    G_DATA_PIPE  => false
  )
  port map (
    clk     => clk,
    srst    => srst,
    s_valid => s_axil_req.awvalid,
    s_ready => s_axil_rsp.awready,
    s_data  => s_axil_req.awaddr,
    m_valid => awvalid,
    m_ready => awready,
    m_data  => awaddr
  );

  -- Write data ready skid buffer. Break up comb ready loop.
  u_axis_pipe_w : entity work.strm_pipe
  generic map (
    G_WIDTH      => 32 + 4,
    G_READY_PIPE => true,
    G_DATA_PIPE  => false
  )
  port map (
    clk                   => clk,
    srst                  => srst,
    s_valid               => s_axil_req.wvalid,
    s_ready               => s_axil_rsp.wready,
    s_data(31 downto 0)   => s_axil_req.wdata,
    s_data(35 downto 32)  => s_axil_req.wstrb,
    m_valid               => wvalid,
    m_ready               => wready,
    m_data (31 downto 0)  => wdata,
    m_data (35 downto 32) => wstrb
  );

  -- Enable an outgoing write request when the incoming write address and write
  -- data are valid and when the write response is not stalled.
  wen <= awvalid and wvalid and not (s_axil_rsp.bvalid and not s_axil_req.bready);

  -- wready and awready are tied to wen. This makes the write transaction go
  -- thru. Although this looks like we are combinatorially setting the ready
  -- outputs, since we send the readys thru an axis pipeline module first, the
  -- paths get broken up there. The axis pipeline modules handle the axi
  -- buffering to ensure that no transactions are dropped.
  wready  <= wen;
  awready <= wen;

  -- Set write response to valid the cycle after the write request
  -- since the register bus always responds in one cycle. If another write is
  -- not happening and the master has set bready high, then we can now lower
  -- bvalid to end the write response transaction.
  prc_bvalid : process (clk) is begin
    if rising_edge(clk) then
      if srst then
        s_axil_rsp.bvalid <= '0';
      else
        if wen then
          s_axil_rsp.bvalid <= '1';
        elsif s_axil_req.bready then
          s_axil_rsp.bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Assign axil write response
  s_axil_rsp.bresp <= AXI_RSP_SLVERR when m_reg_rsp.werr else AXI_RSP_OKAY;

  -- Assign reg bus write request
  m_reg_req.wen   <= wen;
  m_reg_req.waddr <= awaddr;
  m_reg_req.wdata <= wdata;
  m_reg_req.wstrb <= wstrb;

  -- ---------------------------------------------------------------------------
  -- Reads
  -- ---------------------------------------------------------------------------

  -- Read address skid buffer. Break up comb ready loop.
  u_axis_pipe_ar : entity work.strm_pipe
  generic map (
    G_WIDTH      => 32,
    G_READY_PIPE => true,
    G_DATA_PIPE  => false
  )
  port map (
    clk     => clk,
    srst    => srst,
    s_valid => s_axil_req.arvalid,
    s_ready => s_axil_rsp.arready,
    s_data  => s_axil_req.araddr,
    m_valid => arvalid,
    m_ready => arready,
    m_data  => araddr
  );

  -- Enable an outgoing read request when the incoming read address
  -- is valid and when the last read response is not stalled. Reads are a bit
  -- simpler than writes because we only have to wait for one of the incoming
  -- channels to become valid (ar) instead of waiting for two of them (aw & w).
  ren <= arvalid and not (rvalid and not rready);

  -- arready becomes enabled at the same time as ren to complete the data
  -- transfer
  arready <= ren;

  -- Read response skid buffers. Notice that this has G_RD_LATENCY stages.
  -- This buffer is needed to maintain thruput because the slave read response
  -- is assumed to always take G_RD_LATENCY cycles. This buffer stores responses
  -- if the master is stalling the read response channel when there are still
  -- outstanding requests that the slave has not yet completed.
  u_axis_pipes_r : entity work.strm_pipes
  generic map (
    G_WIDTH      => 32 + 2,
    G_READY_PIPE => true,
    G_DATA_PIPE  => false,
    G_STAGES     => G_RD_LATENCY
  )
  port map (
    clk                   => clk,
    srst                  => srst,
    s_valid               => rvalid,
    s_ready               => rready,
    s_data(31 downto 0)   => rdata,
    s_data(33 downto 32)  => rresp,
    m_valid               => s_axil_rsp.rvalid,
    m_ready               => s_axil_req.rready,
    m_data (31 downto 0)  => s_axil_rsp.rdata,
    m_data (33 downto 32) => s_axil_rsp.rresp
  );

  -- Pulse rvalid exactly G_RD_LATENCY cycles after ren. Since we control the
  -- ren logic and since we know that a read response always comes in
  -- G_RD_LATENCY cycles, it is okay to just pulse rvalid, because we know that
  -- rready will always be high whenever an rvalid pulse arrives.
  u_shift_reg : entity work.shift_reg
  generic map (
    G_WIDTH     => 1,
    G_DEPTH     => G_RD_LATENCY - 1,
    G_RESET_VAL => "0",
    G_OUT_REG   => true
  )
  port map (
    clk  => clk,
    srst => srst,
    en   => '1',
    d(0) => ren,
    q(0) => rvalid
  );

  -- Assign axil read response
  rresp <= AXI_RSP_SLVERR when m_reg_rsp.rerr else AXI_RSP_OKAY;
  rdata <= m_reg_rsp.rdata;

  -- Assign reg bus read request
  m_reg_req.ren   <= ren;
  m_reg_req.raddr <= araddr;

end architecture;
