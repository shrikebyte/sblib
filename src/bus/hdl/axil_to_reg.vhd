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
use work.bus_pkg.all;

entity axil_to_reg is
  generic (
    G_LATENCY : positive := 1
  );
  port (
    clk    : in   std_ulogic;
    srst   : in   std_ulogic;
    s_axil : view s_axil_view;
    m_reg  : view m_reg_view
  );
end entity;

architecture rtl of axil_to_reg is

  signal wen : std_logic;
  signal ren : std_logic;

  signal rvalid  : std_logic;
  signal rready  : std_logic;
  signal rdata   : std_logic_vector(31 downto 0);
  signal rresp   : std_logic_vector( 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  -- Writes
  -- ---------------------------------------------------------------------------

  -- Enable an outgoing write request when the incoming write address and write
  -- data are valid and when the prev write response is not stalled.
  wen <= s_axil.awvalid and s_axil.wvalid and not (s_axil.bvalid and not s_axil.bready);

  -- Complete the transfer
  s_axil.wready  <= wen;
  s_axil.awready <= wen;

  -- Set write response to valid the cycle after the write request
  -- since the register bus always responds in one cycle. If another write is
  -- not happening and the master has set bready high, then we can now lower
  -- bvalid to end the write response transaction.
  prc_bvalid : process (clk) is begin
    if rising_edge(clk) then
      if srst then
        s_axil.bvalid <= '0';
      else
        if wen then
          s_axil.bvalid <= '1';
        elsif s_axil.bready then
          s_axil.bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Assign axil write response
  s_axil.bresp <= AXI_RSP_SLVERR when m_reg.werr else AXI_RSP_OKAY;

  -- Assign reg bus write request
  m_reg.wen   <= wen;
  m_reg.waddr <= s_axil.awaddr;
  m_reg.wdata <= s_axil.wdata;
  m_reg.wstrb <= s_axil.wstrb;



  -- ---------------------------------------------------------------------------
  -- Reads
  -- ---------------------------------------------------------------------------

  -- Enable an outgoing read request when the incoming read address
  -- is valid and when the last read response is not stalled.
  ren <= s_axil.arvalid and not (rvalid and not rready);

  -- Complete the transfer
  s_axil.arready <= ren;

  -- Read response buffer.
  -- This is needed to maintain throughput because the slave read response
  -- is assumed to always take G_LATENCY cycles. This buffer stores responses
  -- if the master is stalling the read response channel while there are still
  -- outstanding requests that the slave has not yet completed.
  u_r_pipes : entity work.strm_pipes
  generic map (
    G_WIDTH      => 32 + 2,
    G_READY_PIPE => true,
    G_DATA_PIPE  => false,
    G_STAGES     => G_LATENCY
  )
  port map (
    clk                   => clk,
    srst                  => srst,
    s_valid               => rvalid,
    s_ready               => rready,
    s_data(31 downto 0)   => rdata,
    s_data(33 downto 32)  => rresp,
    m_valid               => s_axil.rvalid,
    m_ready               => s_axil.rready,
    m_data (31 downto 0)  => s_axil.rdata,
    m_data (33 downto 32) => s_axil.rresp
  );

  -- Pulse rvalid exactly G_RD_LATENCY cycles after ren. Since we control the
  -- ren logic and since we know that a read response always comes in
  -- G_RD_LATENCY cycles, it is okay to just pulse rvalid, because we know that
  -- rready will always be high whenever an rvalid pulse arrives.
  u_shift_reg : entity work.shift_reg
  generic map (
    G_WIDTH     => 1,
    G_DEPTH     => G_LATENCY - 1,
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
  rresp <= AXI_RSP_SLVERR when m_reg.rerr else AXI_RSP_OKAY;
  rdata <= m_reg.rdata;

  -- Assign reg bus read request
  m_reg.ren   <= ren;
  m_reg.raddr <= s_axil.araddr;

end architecture;
