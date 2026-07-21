--##############################################################################
--# File : uart_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# UART testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;
use vunit_lib.random_pkg.all;

library osvvm;
use osvvm.randompkg.all;
use work.util_pkg.all;
use work.axis_pkg.all;
use work.bfm_pkg.all;

entity uart_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean := true;
    G_USE_PARITY    : boolean := true;
    G_EVEN_PARITY   : boolean := true
  );
end entity;

architecture tb of uart_tb is

  -- TB Constants
  constant RESET_TIME : time := 100 ns;
  constant CLK_PERIOD : time := 10 ns;

  -- TB Signals
  signal clk   : std_ulogic := '1';
  signal arst  : std_ulogic := '1';
  signal srst  : std_ulogic := '1';
  signal srstn : std_ulogic := '0';

  -- DUT Constants
  constant G_FPGA_CLK_HZ    : positive := 100_000_000;
  constant G_UART_BAUD_BPS  : positive := 100_000_000 / 8;
  constant G_BAUD_TOLERANCE : real     := 2.5;

  -- DUT Signals
  signal s_axis : axis_t (
    tdata(7 downto 0),
    tkeep(0 downto 0),
    tuser(0 downto 0)
  );

  signal m_axis : axis_t (
    tdata(7 downto 0),
    tkeep(0 downto 0),
    tuser(2 downto 0)
  );

  signal uart_txd : std_ulogic;
  signal uart_rxd : std_ulogic;

  -- Testbench BFMs
  constant STALL_CFG : stall_configuration_t := (
    stall_probability => 0.9 * to_real(G_ENABLE_JITTER),
    min_stall_cycles  => 8,
    max_stall_cycles  => G_FPGA_CLK_HZ / G_UART_BAUD_BPS * 7
  );

  constant DATA_QUEUE     : queue_t := new_queue;
  constant REF_DATA_QUEUE : queue_t := new_queue;

  signal num_packets_checked : natural := 0;
  signal num_packets_sent    : natural := 0;

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 ms);

  prc_main : process is

    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    procedure send_random is

      variable data      : integer_array_t := null_integer_array;
      variable data_copy : integer_array_t := null_integer_array;

    begin

      -- Random data
      random_integer_array (
        rnd           => rnd,
        integer_array => data,
        width         => 250,
        bits_per_word => 8,
        is_signed     => false
      );

      data_copy                    := copy(data);
      push_ref(REF_DATA_QUEUE, data_copy);
      expected_num_packets_checked := expected_num_packets_checked + 1;

      push_ref(DATA_QUEUE, data);
      expected_num_packets_sent := expected_num_packets_sent + 1;

    end procedure;

    procedure wait_until_done is begin
      wait until num_packets_checked = expected_num_packets_checked and
                 num_packets_sent = expected_num_packets_sent and
        rising_edge(clk);
    end procedure;

  begin

    test_runner_setup(runner, RUNNER_CFG);
    rnd.InitSeed(get_string_seed(RUNNER_CFG));

    arst <= '1';
    wait for RESET_TIME;
    arst <= '0';
    wait until rising_edge(clk);

    if run("test_random_data") then
      send_random;
    end if;

    wait_until_done;

    test_runner_cleanup(runner);
  end process;

  -- ---------------------------------------------------------------------------
  prc_srst : process (clk) is begin
    if rising_edge(clk) then
      srst  <= arst;
      srstn <= not arst;
    end if;
  end process;

  clk <= not clk after CLK_PERIOD / 2;

  -- ---------------------------------------------------------------------------
  u_uart : entity work.uart
  generic map (
    G_FPGA_CLK_HZ    => G_FPGA_CLK_HZ,
    G_UART_BAUD_BPS  => G_UART_BAUD_BPS,
    G_BAUD_TOLERANCE => G_BAUD_TOLERANCE,
    G_USE_PARITY     => G_USE_PARITY,
    G_EVEN_PARITY    => G_EVEN_PARITY
  )
  port map (
    clk      => clk,
    srst     => srst,
    s_axis   => s_axis,
    m_axis   => m_axis,
    uart_txd => uart_txd,
    uart_rxd => uart_rxd
  );

  -- Loopback
  uart_rxd <= uart_txd;

  u_bfm_axis_mgr : entity work.bfm_axis_mgr
  generic map (
    G_DATA_QUEUE   => DATA_QUEUE,
    G_ENABLE_TUSER => false,
    G_STALL_CONFIG => STALL_CFG
  )
  port map (
    clk              => clk,
    m_axis           => s_axis,
    num_packets_sent => num_packets_sent
  );

  u_bfm_axis_sub : entity work.bfm_axis_sub
  generic map (
    G_REF_DATA_QUEUE => REF_DATA_QUEUE,
    G_ENABLE_TUSER   => false,
    G_ENABLE_TKEEP   => false,
    G_ENABLE_TLAST   => false,
    G_STALL_CONFIG   => STALL_CFG
  )
  port map (
    clk                 => clk,
    s_axis              => m_axis,
    num_packets_checked => num_packets_checked
  );

  prc_monitor_tuser : process is begin
    wait until m_axis.tvalid = '1' and m_axis.tready = '1' and rising_edge(clk);
    assert or m_axis.tuser = '0'
      report "UART tuser indicated an error"
      severity failure;
  end process;

end architecture;
