--##############################################################################
--# File : cdc_vector_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Vector CDC TB
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
use osvvm.randompkg.all;

entity cdc_vector_tb is
  generic (
    RUNNER_CFG        : string;
    G_CLK_RATIO       : integer := 35;
    G_AXIS_STALL_PROB : integer := 10
  );
end entity;

architecture tb of cdc_vector_tb is

  -- TB Constants
  constant RESET_TIME            : time     := 64 ns;
  constant CLK_PERIOD            : time     := 5 ns;
  constant CLK_PERIOD_0          : time     := CLK_PERIOD * (real(G_CLK_RATIO) / 100.0);
  constant CLK_PERIOD_1          : time     := CLK_PERIOD;
  constant CLK_TO_Q              : time     := 0.1 ns;
  constant AXIS_DATA_WIDTH       : integer  := 8;
  constant AXIS_MAX_QUEUED_XFERS : positive := 4096;

  -- TB Signals
  signal s_clk   : std_logic := '1';
  signal m_clk   : std_logic := '1';
  signal arst    : std_logic := '1';
  signal s_srst  : std_logic := '1';
  signal s_srstn : std_logic := '0';
  signal m_srst  : std_logic := '1';
  signal m_srstn : std_logic := '0';

  -- Module Generics
  constant G_WIDTH      : positive := 8;
  constant G_EXTRA_SYNC : natural  := 0;

  -- Module Ports
  signal s_valid : std_logic;
  signal s_ready : std_logic;
  signal s_data  : std_logic_vector(G_WIDTH - 1 downto 0);
  signal m_valid : std_logic;
  signal m_ready : std_logic;
  signal m_data  : std_logic_vector(G_WIDTH - 1 downto 0);

  -- ---------------------------------------------------------------------------
  -- Testbench BFM Configs
  constant TX_AXIS_BFM : axi_stream_master_t := new_axi_stream_master (
      data_length  => AXIS_DATA_WIDTH,
      stall_config => new_stall_config((real(G_AXIS_STALL_PROB) / 100.0), 0, 10)
    );
  constant RX_AXIS_BFM : axi_stream_slave_t  := new_axi_stream_slave (
      data_length  => AXIS_DATA_WIDTH,
      stall_config => new_stall_config((real(G_AXIS_STALL_PROB) / 100.0), 0, 10)
    );

begin

  -- ---------------------------------------------------------------------------
  prc_main : process is

    variable rnd : randomptype;

    type axis_xfer_t is record
      tdata : std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
      tlast : std_logic;
    end record;

    type axis_xfer_arr_t is array(natural range 0 to AXIS_MAX_QUEUED_XFERS - 1) of axis_xfer_t;

    variable xfers : axis_xfer_arr_t;

  begin

    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop

      arst <= '1';
      wait for RESET_TIME;
      arst <= '0';

      -- -----------------------------------------------------------------------
      if run("test_0") then
        info("Stream 256 beats with a counting pattern through the dut");

        -- Generate test data
        wait until rising_edge(s_clk);
        for i in 0 to 255 loop
          xfers(i).tdata := std_logic_vector(to_unsigned(i, AXIS_DATA_WIDTH));
          xfers(i).tlast := '0';
        end loop;

        -- Transmit test data
        wait until rising_edge(s_clk);
        for i in 0 to 255 loop
          push_axi_stream(net, TX_AXIS_BFM, xfers(i).tdata, xfers(i).tlast);
        end loop;

        -- Receive and check test data
        wait until rising_edge(m_clk);
        for i in 0 to 255 loop
          check_axi_stream(net, RX_AXIS_BFM, xfers(i).tdata, xfers(i).tlast);
        end loop;

      -- -- -----------------------------------------------------------------------
      -- elsif run("test_1") then

      --   info("Not implemented.");

      end if;

      wait for 100 ns;

    end loop;

    test_runner_cleanup(runner);

  end process;

  -- -- Watchdog
  test_runner_watchdog(runner, 100 us);

  -- ---------------------------------------------------------------------------
  -- Clocks & Resets
  s_clk <= not s_clk after CLK_PERIOD_0 / 2;
  m_clk <= not m_clk after CLK_PERIOD_1 / 2;

  prc_s_srst : process (s_clk) is begin
    if rising_edge(s_clk) then
      s_srst  <= arst;
      s_srstn <= not arst;
    end if;
  end process;

  prc_m_srst : process (m_clk) is begin
    if rising_edge(m_clk) then
      m_srst  <= arst;
      m_srstn <= not arst;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- DUT
  u_dut : entity work.cdc_vector
  generic map (
    G_EXTRA_SYNC => G_EXTRA_SYNC
  )
  port map (
    src_clk   => s_clk,
    src_valid => s_valid,
    src_ready => s_ready,
    src_data  => s_data,
    dst_clk   => m_clk,
    dst_valid => m_valid,
    dst_ready => m_ready,
    dst_data  => m_data
  );

  -- ---------------------------------------------------------------------------
  -- Tx BFM
  u_tx_axis_bfm : entity vunit_lib.axi_stream_master
  generic map (
    MASTER => TX_AXIS_BFM
  )
  port map (
    aclk     => s_clk,
    areset_n => s_srstn,
    tvalid   => s_valid,
    tready   => s_ready,
    tdata    => s_data,
    tlast    => open
  );

  -- ---------------------------------------------------------------------------
  -- Rx BFM
  u_rx_axis_bfm : entity vunit_lib.axi_stream_slave
  generic map (
    SLAVE => RX_AXIS_BFM
  )
  port map (
    aclk     => m_clk,
    areset_n => m_srstn,
    tvalid   => m_valid,
    tready   => m_ready,
    tdata    => m_data,
    tlast    => '0'
  );

end architecture;
