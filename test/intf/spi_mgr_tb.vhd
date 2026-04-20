--##############################################################################
--# File : spi_mgr_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Spi manager testbench
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

entity spi_mgr_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean  := true;
    G_SCK_DIV       : positive := 2
  );
end entity;

architecture tb of spi_mgr_tb is

  constant G_CS_BITS : positive := 2;
  constant G_CS_LEAD : positive := 2;
  constant G_CS_LAG  : positive := 2;
  constant G_CS_IDLE : positive := 8;

  -- TB Constants
  constant RESET_TIME : time    := 50 ns;
  constant CLK_PERIOD : time    := 5 ns;
  constant DW         : integer := 16;
  constant UW         : integer := 2 + G_CS_BITS;

  -- TB Signals
  signal clk   : std_ulogic := '1';
  signal arst  : std_ulogic := '1';
  signal srst  : std_ulogic := '1';
  signal srstn : std_ulogic := '0';

  -- DUT Signals
  signal s_axis : axis_t (
    tdata(DW - 1 downto 0),
    tkeep(0 downto 0),
    tuser(UW - 1 downto 0)
  );

  signal m_axis : axis_t (
    tdata(DW - 1 downto 0),
    tkeep(0 downto 0),
    tuser(UW - 1 downto 0)
  );

  signal spi_sck  : std_ulogic;
  signal spi_csn  : std_ulogic_vector((2 ** G_CS_BITS) - 1 downto 0);
  signal spi_mosi : std_ulogic;
  signal spi_miso : std_ulogic;

  -- Testbench BFMs
  constant STALL_CFG : stall_configuration_t := (
    stall_probability => 0.2 * to_real(G_ENABLE_JITTER),
    min_stall_cycles  => 1,
    max_stall_cycles  => 3
  );

  constant DATA_QUEUE     : queue_t := new_queue;
  constant REF_DATA_QUEUE : queue_t := new_queue;
  constant USER_QUEUE     : queue_t := new_queue;
  constant REF_USER_QUEUE : queue_t := new_queue;

  signal num_packets_checked : natural    := 0;
  signal num_packets_sent    : natural    := 0;
  signal bfm_sub_enable      : std_ulogic := '0';

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is

    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    procedure spi_txrx (
      cpol : natural range 0 to 1;
      cpha : natural range 0 to 1;
      cs   : natural
    ) is

      variable data      : integer_array_t := null_integer_array;
      variable data_copy : integer_array_t := null_integer_array;
      variable user      : integer_array_t := new_3d(1, 1, 1, UW, false);
      variable user_copy : integer_array_t := new_3d(1, 1, 1, UW, false);

      variable tuser : u_unsigned(UW - 1 downto 0);

    begin

      -- Random data
      random_integer_array (
        rnd           => rnd,
        integer_array => data,
        width         => 1,
        bits_per_word => DW,
        is_signed     => false
      );

      tuser(0)                          := to_sl(cpol);
      tuser(1)                          := to_sl(cpha);
      tuser(G_CS_BITS + 2 - 1 downto 2) := to_unsigned(cs, G_CS_BITS);
      set(user, 0, to_integer(tuser));

      data_copy                    := copy(data);
      push_ref(REF_DATA_QUEUE, data_copy);
      user_copy                    := copy(user);
      push_ref(REF_USER_QUEUE, user_copy);
      expected_num_packets_checked := expected_num_packets_checked + 1;

      push_ref(DATA_QUEUE, data);
      push_ref(USER_QUEUE, user);
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
      bfm_sub_enable <= '1';

      for test_idx in 0 to 100 loop
        spi_txrx(rnd.Uniform(0, 1), rnd.Uniform(0, 1), rnd.Uniform(0, (2 ** G_CS_BITS) - 1));
      end loop;

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
  u_spi_mgr : entity work.spi_mgr
  generic map (
    G_SCK_DIV => G_SCK_DIV,
    G_CS_BITS => G_CS_BITS,
    G_CS_LEAD => G_CS_LEAD,
    G_CS_LAG  => G_CS_LAG,
    G_CS_IDLE => G_CS_IDLE
  )
  port map (
    clk      => clk,
    srst     => srst,
    s_axis   => s_axis,
    m_axis   => m_axis,
    spi_sck  => spi_sck,
    spi_csn  => spi_csn,
    spi_mosi => spi_mosi,
    spi_miso => spi_miso
  );

  -- Loopback
  spi_miso <= spi_mosi;

  u_bfm_axis_man : entity work.bfm_axis_man
  generic map (
    G_DATA_QUEUE   => DATA_QUEUE,
    G_USER_QUEUE   => USER_QUEUE,
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
    G_REF_USER_QUEUE => REF_USER_QUEUE,
    G_STALL_CONFIG   => STALL_CFG
  )
  port map (
    clk                 => clk,
    s_axis              => m_axis,
    num_packets_checked => num_packets_checked
  );

end architecture;
