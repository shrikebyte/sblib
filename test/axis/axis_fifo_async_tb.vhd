--##############################################################################
--# File : axis_fifo_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Asynchronous AXIS FIFO testbench.
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

entity axis_fifo_async_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean := true;
    -- Ratio of input to output clock. When < 100, the input clock
    -- is slower. When > 100, the input clock is faster.
    G_CLK_RATIO     : integer  := 35;
    G_DEPTH         : positive := 64;
    G_PACKET_MODE   : boolean  := false;
    G_DROP_OVERSIZE : boolean  := false
  );
end entity;

architecture tb of axis_fifo_async_tb is

  -- TB Constants
  constant RESET_TIME        : time    := 1 us;
  constant CLK_PERIOD        : time    := 5 ns;
  constant CLK_PERIOD_INPUT  : time    := CLK_PERIOD * (real(G_CLK_RATIO) / 100.0);
  constant CLK_PERIOD_OUTPUT : time    := CLK_PERIOD;
  constant KW                : integer := 2;
  constant DW                : integer := 16;
  constant UW                : integer := 8;
  constant DBW               : integer := DW / KW;
  constant UBW               : integer := UW / KW;

  -- TB Signals
  signal s_clk   : std_logic := '1';
  signal m_clk   : std_logic := '1';
  signal arst    : std_logic := '1';
  signal s_srst  : std_logic := '1';
  signal s_srstn : std_logic := '0';
  signal m_srst  : std_logic := '1';
  signal m_srstn : std_logic := '0';

  -- DUT Signals
  signal s_axis : axis_t (
    tdata(DW downto 1),
    tkeep(KW downto 1),
    tuser(UW downto 1)
  );

  signal m_axis : axis_t (
    tdata(DW downto 1),
    tkeep(KW downto 1),
    tuser(UW downto 1)
  );

  signal s_ctl_drop       : std_ulogic := '0';
  signal s_sts_dropped    : std_ulogic;
  signal s_sts_depth_spec : u_unsigned(clog2(G_DEPTH) downto 0);
  signal s_sts_depth_comm : u_unsigned(clog2(G_DEPTH) downto 0);
  signal m_sts_dropped    : std_ulogic;
  signal m_sts_depth_spec : u_unsigned(clog2(G_DEPTH) downto 0);
  signal m_sts_depth_comm : u_unsigned(clog2(G_DEPTH) downto 0);

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
  signal m_bfm_sub_enable    : std_ulogic := '0';

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is

    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    procedure send_packet (
      packet_length_beats : positive;
      packet_dropped      : boolean := false
    ) is

      constant PACKET_LENGTH_BYTES : natural := packet_length_beats * KW;

      variable data      : integer_array_t := null_integer_array;
      variable data_copy : integer_array_t := null_integer_array;
      variable user      : integer_array_t := null_integer_array;
      variable user_copy : integer_array_t := null_integer_array;

    begin

      -- Random data packet
      random_integer_array (
        rnd           => rnd,
        integer_array => data,
        width         => PACKET_LENGTH_BYTES,
        bits_per_word => DBW,
        is_signed     => false
      );

      -- Random user packet
      random_integer_array (
        rnd           => rnd,
        integer_array => user,
        width         => PACKET_LENGTH_BYTES,
        bits_per_word => UBW,
        is_signed     => false
      );

      if not packet_dropped then
        data_copy                    := copy(data);
        push_ref(REF_DATA_QUEUE, data_copy);
        user_copy                    := copy(user);
        push_ref(REF_USER_QUEUE, user_copy);
        expected_num_packets_checked := expected_num_packets_checked + 1;
      end if;

      push_ref(DATA_QUEUE, data);
      push_ref(USER_QUEUE, user);
      expected_num_packets_sent := expected_num_packets_sent + 1;

    end procedure;

    procedure wait_until_done is begin
      wait until num_packets_checked = expected_num_packets_checked and
                 num_packets_sent = expected_num_packets_sent and
        rising_edge(m_clk);
    end procedure;

    procedure wait_s_clks (
      clks : natural
    ) is begin
      if clks > 0 then
        for i in 0 to clks - 1 loop
          wait until rising_edge(s_clk);
        end loop;
      end if;
    end procedure;

    procedure wait_m_clks (
      clks : natural
    ) is begin
      if clks > 0 then
        for i in 0 to clks - 1 loop
          wait until rising_edge(m_clk);
        end loop;
      end if;
    end procedure;

    variable drop : boolean;
    variable len  : positive;

  begin

    test_runner_setup(runner, RUNNER_CFG);
    rnd.InitSeed(get_string_seed(RUNNER_CFG));

    arst <= '1';
    wait for RESET_TIME;
    arst <= '0';

    if run("test_random_data") then
      wait_m_clks(1);
      m_bfm_sub_enable <= '1';

      for test_idx in 0 to G_DEPTH loop
        send_packet(rnd.Uniform(1, 3));
      end loop;

    elsif run("test_fill") then
      wait_m_clks(1);
      m_bfm_sub_enable <= '0';

      -- Send data while fifo not full
      while s_sts_depth_spec < G_DEPTH loop
        send_packet(rnd.Uniform(1, 3));
        wait_s_clks(1);
      end loop;

      -- Queue up one additional packet to ensure it overflows
      send_packet(5);

      -- Drain the fifo
      wait_m_clks(1);
      m_bfm_sub_enable <= '1';
    elsif run("test_oversized") then
      m_bfm_sub_enable <= '1';

      send_packet(G_DEPTH * 3 / 4);
      send_packet(G_DEPTH + 100, G_DROP_OVERSIZE);
      send_packet(1);
      send_packet(G_DEPTH + 1, G_DROP_OVERSIZE);
      send_packet(G_DEPTH - 1);
      send_packet(G_DEPTH);
      send_packet(G_DEPTH + 2, G_DROP_OVERSIZE);
      send_packet(G_DEPTH * 1 / 4);
    elsif run("test_drop") then
      m_bfm_sub_enable <= '1';
      s_ctl_drop       <= '0';

      -- Sometimes hold the drop signal during random packets
      for test_idx in 0 to 20 loop
        drop       := to_bool(rnd.RandInt(0, 1));
        len        := rnd.Uniform(1, 10);
        send_packet(len, G_PACKET_MODE and drop);
        s_ctl_drop <= to_sl(drop);
        wait until (s_axis.tvalid and s_axis.tready and s_axis.tlast) = '1' and
          rising_edge(s_clk);
        s_ctl_drop <= '0';
      end loop;

      -- Non-dropped packet
      send_packet(1);
      wait_until_done;

      -- Pulse the drop signal on tlast
      wait_s_clks(1);
      send_packet(10, G_PACKET_MODE);
      wait until (s_axis.tvalid and s_axis.tready and s_axis.tlast);
      s_ctl_drop <= '1';
      wait_s_clks(1);
      s_ctl_drop <= '0';
      wait_until_done;

      -- Pulse the drop signal in the middle of a packet
      wait_s_clks(1);
      send_packet(10, G_PACKET_MODE);
      wait_s_clks(5);
      s_ctl_drop <= '1';
      wait_s_clks(1);
      s_ctl_drop <= '0';
      wait_until_done;

      -- Non-dropped packet
      send_packet(5);
      wait_until_done;

      -- Pulse the drop signal before the next packet
      wait_s_clks(1);
      s_ctl_drop <= '1';
      wait_s_clks(3);
      s_ctl_drop <= '0';
      wait_s_clks(5);
      send_packet(10, G_PACKET_MODE);
      wait_until_done;

      -- Non-dropped packet
      send_packet(2);
      wait_until_done;
    elsif run("test_fill_lasts") then
      m_bfm_sub_enable <= '0';

      -- Send data while fifo not full
      while s_sts_depth_spec < G_DEPTH loop
        send_packet(1);
        wait until rising_edge(s_clk);
      end loop;

      -- Queue up a few additional packets
      send_packet(1);
      send_packet(1);
      send_packet(1);

      -- Drain the fifo
      m_bfm_sub_enable <= '1';
      wait_m_clks(10);
      m_bfm_sub_enable <= '0';
      wait_m_clks(10);
      m_bfm_sub_enable <= '1';
      wait_m_clks(10);
      m_bfm_sub_enable <= '0';
      wait_m_clks(10);
      m_bfm_sub_enable <= '1';

    end if;

    wait_until_done;

    test_runner_cleanup(runner);
  end process;

  -- ---------------------------------------------------------------------------
  prc_srst_s : process (s_clk) is begin
    if rising_edge(s_clk) then
      s_srst  <= arst;
      s_srstn <= not arst;
    end if;
  end process;

  prc_srst_m : process (m_clk) is begin
    if rising_edge(m_clk) then
      m_srst  <= arst;
      m_srstn <= not arst;
    end if;
  end process;

  s_clk <= not s_clk after CLK_PERIOD_INPUT / 2;
  m_clk <= not m_clk after CLK_PERIOD_OUTPUT / 2;

  -- ---------------------------------------------------------------------------
  u_axis_fifo_async : entity work.axis_fifo_async
  generic map (
    G_EXTRA_SYNC    => 0,
    G_DEPTH         => G_DEPTH,
    G_PACKET_MODE   => G_PACKET_MODE,
    G_DROP_OVERSIZE => G_DROP_OVERSIZE,
    G_USE_TLAST     => true,
    G_USE_TKEEP     => true,
    G_USE_TUSER     => true
  )
  port map (
    arst => arst,
    --
    --
    s_clk => s_clk,
    --
    s_axis => s_axis,
    --
    s_ctl_drop       => s_ctl_drop,
    s_sts_dropped    => s_sts_dropped,
    s_sts_depth_spec => s_sts_depth_spec,
    s_sts_depth_comm => s_sts_depth_comm,
    --
    --
    m_clk => m_clk,
    --
    m_axis => m_axis,
    --
    m_sts_dropped    => m_sts_dropped,
    m_sts_depth_spec => m_sts_depth_spec,
    m_sts_depth_comm => m_sts_depth_comm
  );

  u_bfm_axis_man : entity work.bfm_axis_man
  generic map (
    G_DATA_QUEUE   => DATA_QUEUE,
    G_USER_QUEUE   => USER_QUEUE,
    G_STALL_CONFIG => STALL_CFG
  )
  port map (
    clk              => s_clk,
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
    clk                 => m_clk,
    s_axis              => m_axis,
    enable              => m_bfm_sub_enable,
    num_packets_checked => num_packets_checked
  );

  -- ---------------------------------------------------------------------------
  gen_check_no_bubbles : if G_PACKET_MODE and G_DROP_OVERSIZE generate
    signal end_event, en : std_ulogic := '0';
  begin
    -- These inputs must be signals (not constants), so assign them here
    -- instead of the port map directly.
    end_event <= m_axis.tvalid and m_axis.tready and m_axis.tlast;
    en        <= m_srstn;

    check_stable(
      clock => m_clk,
      en    => en,
    -- Start check when valid arrives
      start_event => m_axis.tvalid,
    -- End check when last arrives
      end_event => end_event,
    -- Assert that valid is always asserted until last arrives
      expr => m_axis.tvalid,
      msg  => "There was a bubble in m_axis.tvalid!"
    );
  end generate;

end architecture;
