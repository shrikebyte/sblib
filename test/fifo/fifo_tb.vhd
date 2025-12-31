--##############################################################################
--# File : fifo_tb.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! Synchronous fifo testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
use osvvm.randompkg.all;

entity fifo_tb is
  generic (
    RUNNER_CFG        : string;
    G_OUT_REG         : boolean := false;
    G_AXIS_STALL_PROB : integer := 10
  );
end entity;

architecture tb of fifo_tb is

  -- TB Constants
  constant RESET_TIME            : time    := 25 ns;
  constant CLK_PERIOD            : time    := 5 ns;
  constant CLK_TO_Q              : time    := 0.1 ns;
  constant AXIS_DATA_WIDTH       : integer := 8;
  constant AXIS_MAX_QUEUED_XFERS : integer := 4096;

  -- TB Signals
  signal clk          : std_logic := '1';
  signal arst         : std_logic := '1';
  signal srst         : std_logic := '1';
  signal srstn        : std_logic := '0';
  signal test_1_start : std_logic := '0';
  signal test_1_done  : std_logic := '0';

  -- Module Generics
  constant G_WIDTH         : positive := 8;
  constant G_DEPTH_P2      : positive := 9;
  constant G_ALM_EMPTY_LVL : natural  := 12;
  constant G_ALM_FULL_LVL  : natural  := 500;

  -- Module Ports
  signal s_valid   : std_logic;
  signal s_ready   : std_logic;
  signal s_data    : std_logic_vector(G_WIDTH - 1 downto 0);
  signal m_valid   : std_logic;
  signal m_ready   : std_logic;
  signal m_data    : std_logic_vector(G_WIDTH - 1 downto 0);
  signal alm_full  : std_logic;
  signal alm_empty : std_logic;
  signal fill_lvl  : std_logic_vector(G_DEPTH_P2 downto 0);

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

      -- -----------------------------------------------------------------------
      elsif run("test_1") then
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        test_1_start <= '1';
        wait until rising_edge(clk);
        test_1_start <= '0';

        wait until test_1_done;

      end if;

      wait for 100 ns;

    end loop;

    test_runner_cleanup(runner);

  end process;

  -- Watchdog
  test_runner_watchdog(runner, 100 us);

  -- ---------------------------------------------------------------------------
  -- Test 1 Helper processes
  -- ---------------------------------------------------------------------------
  prc_test_1_tx : process is

    type axis_xfer_t is record
      tdata : std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
      tlast : std_logic;
    end record;

    type axis_xfer_arr_t is array(natural range 0 to AXIS_MAX_QUEUED_XFERS - 1) of axis_xfer_t;

    variable xfers : axis_xfer_arr_t;

  begin
    wait until rising_edge(test_1_start);
    info("Start TX");

    -- Generate test data
    wait until rising_edge(clk);
    for i in 0 to 1023 loop
      xfers(i).tdata := std_logic_vector(to_unsigned(i, AXIS_DATA_WIDTH));
      xfers(i).tlast := '0';
    end loop;

    -- Transmit test data
    wait until rising_edge(clk);
    for i in 0 to 1023 loop
      push_axi_stream(net, TX_AXIS_BFM, xfers(i).tdata, xfers(i).tlast);
    end loop;

  end process;

  prc_test_1_rx : process is

    type axis_xfer_t is record
      tdata : std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
      tlast : std_logic;
    end record;

    type axis_xfer_arr_t is array(natural range 0 to AXIS_MAX_QUEUED_XFERS - 1) of axis_xfer_t;

    variable xfers : axis_xfer_arr_t;

  begin
    wait until rising_edge(test_1_start);
    info("Start RX");

    -- Wait until fifo fills
    wait until falling_edge(s_ready);
    info("FIFO Full");

    -- Generate test data
    wait until rising_edge(clk);
    for i in 0 to 1023 loop
      xfers(i).tdata := std_logic_vector(to_unsigned(i, AXIS_DATA_WIDTH));
      xfers(i).tlast := '0';
    end loop;

    -- Receive and check test data
    wait until rising_edge(clk);
    for i in 0 to 1023 loop
      check_axi_stream(net, RX_AXIS_BFM, xfers(i).tdata, xfers(i).tlast);
    end loop;

    wait until rising_edge(clk);
    test_1_done <= '1';
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
  u_dut : entity work.fifo
  generic map (
    G_WIDTH         => G_WIDTH,
    G_DEPTH_P2      => G_DEPTH_P2,
    G_ALM_EMPTY_LVL => G_ALM_EMPTY_LVL,
    G_ALM_FULL_LVL  => G_ALM_FULL_LVL,
    G_OUT_REG       => G_OUT_REG
  )
  port map (
    clk       => clk,
    srst      => srst,
    s_valid   => s_valid,
    s_ready   => s_ready,
    s_data    => s_data,
    m_valid   => m_valid,
    m_ready   => m_ready,
    m_data    => m_data,
    alm_full  => alm_full,
    alm_empty => alm_empty,
    fill_lvl  => fill_lvl
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
