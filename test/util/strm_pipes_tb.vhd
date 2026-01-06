--##############################################################################
--# File : strm_pipes_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Stream pipes module testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
use osvvm.randompkg.all;

entity strm_pipes_tb is
  generic (
    RUNNER_CFG        : string;
    G_STAGES          : integer := 1;
    G_READY_PIPE      : boolean := true;
    G_DATA_PIPE       : boolean := true;
    G_AXIS_STALL_PROB : integer := 10
  );
end entity;

architecture tb of strm_pipes_tb is

  -- ---------------------------------------------------------------------------
  -- Testbench Constants
  constant RESET_TIME            : time    := 25 ns;
  constant CLK_PERIOD            : time    := 5 ns;
  constant CLK_TO_Q              : time    := 0.1 ns;
  constant AXIS_DATA_WIDTH       : integer := 8;
  constant AXIS_MAX_QUEUED_XFERS : integer := 4096;

  -- ---------------------------------------------------------------------------
  -- Testbench Signals
  signal clk   : std_logic := '1';
  signal arst  : std_logic := '1';
  signal srst  : std_logic := '1';
  signal srstn : std_logic := '0';

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

  -- ---------------------------------------------------------------------------
  -- DUT Signals
  signal s_valid : std_logic;
  signal s_ready : std_logic;
  signal s_data  : std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
  signal m_valid : std_logic;
  signal m_ready : std_logic;
  signal m_data  : std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);

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
  -- variable tlast_exp : std_logic;

  begin

    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop

      arst <= '1';
      wait for RESET_TIME;
      arst <= '0';

      -- -----------------------------------------------------------------------
      if run("test_0") then
        info("Send a 256 beats with a counting pattern through the dut");

        -- Generate test data
        wait until rising_edge(clk);
        for i in 0 to 255 loop
          xfers(i).tdata := std_logic_vector(to_unsigned(i, AXIS_DATA_WIDTH));
          xfers(i).tlast := '0';
        end loop;

        -- Transmit test data
        wait until rising_edge(clk);
        for i in 0 to 255 loop
          push_axi_stream(net, TX_AXIS_BFM, xfers(i).tdata, xfers(i).tlast);
        end loop;

        -- Receive and check test data
        wait until rising_edge(clk);
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

  -- ---------------------------------------------------------------------------
  -- Clocks & Resets
  clk <= not clk after CLK_PERIOD / 2;

  prc_srst : process (clk) is begin
    if rising_edge(clk) then
      srst  <= arst;
      srstn <= not arst;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- DUT
  u_axis_pipes : entity work.strm_pipes
  generic map (
    G_STAGES     => G_STAGES,
    G_READY_PIPE => G_READY_PIPE,
    G_DATA_PIPE  => G_DATA_PIPE,
    G_WIDTH      => AXIS_DATA_WIDTH
  )
  port map (
    clk     => clk,
    srst    => srst,
    s_valid => s_valid,
    s_ready => s_ready,
    s_data  => s_data,
    m_valid => m_valid,
    m_ready => m_ready,
    m_data  => m_data
  );

  -- ---------------------------------------------------------------------------
  -- Tx BFM
  u_tx_axis_bfm : entity vunit_lib.axi_stream_master
  generic map (
    MASTER => TX_AXIS_BFM
  )
  port map (
    aclk     => clk,
    areset_n => srstn,
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
    aclk     => clk,
    areset_n => srstn,
    tvalid   => m_valid,
    tready   => m_ready,
    tdata    => m_data,
    tlast    => '0'
  );

end architecture;
