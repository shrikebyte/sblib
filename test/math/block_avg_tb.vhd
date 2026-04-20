--##############################################################################
--# File : block_avg_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Block Averager testbench
--##############################################################################

-- TODO: Update axis bfms to support:
--  1. Optional tuser
--  2. Signed data

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

entity block_avg_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean := true;
    G_SIGNED        : boolean := false
  );
end entity;

architecture tb of block_avg_tb is

  constant G_MAX_AVGSEL : positive := 7;

  -- TB Constants
  constant RESET_TIME : time    := 50 ns;
  constant CLK_PERIOD : time    := 5 ns;
  constant DW         : integer := 16;

  -- TB Signals
  signal clk   : std_ulogic := '1';
  signal arst  : std_ulogic := '1';
  signal srst  : std_ulogic := '1';
  signal srstn : std_ulogic := '0';

  -- DUT Signals
  signal s_axis : axis_t (
    tdata(DW - 1 downto 0),
    tkeep(0 downto 0),
    tuser(0 downto 0)
  );

  signal m_axis : axis_t (
    tdata(DW - 1 downto 0),
    tkeep(0 downto 0),
    tuser(0 downto 0)
  );

  signal ctl_avgsel : natural range 0 to G_MAX_AVGSEL;

  -- Testbench BFMs
  constant STALL_CFG : stall_configuration_t := (
    stall_probability => 0.2 * to_real(G_ENABLE_JITTER),
    min_stall_cycles  => 1,
    max_stall_cycles  => 3
  );

  constant SEL_QUEUE      : queue_t := new_queue;
  constant DATA_QUEUE     : queue_t := new_queue;
  constant REF_DATA_QUEUE : queue_t := new_queue;
  constant USER_QUEUE     : queue_t := new_queue;
  constant REF_USER_QUEUE : queue_t := new_queue;

  signal num_packets_checked : natural := 0;
  signal num_packets_sent    : natural := 0;

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is

    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    procedure transact (
      avgsel : natural range 0 to G_MAX_AVGSEL
    ) is

      variable data      : integer_array_t := null_integer_array;
      variable result    : integer_array_t := new_3d(1, 1, 1, DW, G_SIGNED);
      variable accum     : integer         := 0;
      variable num_samps : integer         := 2 ** avgsel;
      variable user      : integer_array_t := new_3d(num_samps, 1, 1, 1, false);
      variable ref_user  : integer_array_t := new_3d(1, 1, 1, 1, false);

    begin

      -- Random data
      random_integer_array (
        rnd           => rnd,
        integer_array => data,
        width         => num_samps,
        bits_per_word => DW,
        is_signed     => G_SIGNED
      );

      -- Calc average
      for i in 0 to num_samps - 1 loop
        accum := accum + get(data, i);
        set(user, i, 0);
      end loop;
      set(result, 0, accum / num_samps);
      set(ref_user, 0, 0);

      push_ref(REF_DATA_QUEUE, result);
      push_ref(REF_USER_QUEUE, ref_user);
      expected_num_packets_checked := expected_num_packets_checked + 1;

      push_ref(DATA_QUEUE, data);
      push_ref(USER_QUEUE, user);
      expected_num_packets_sent := expected_num_packets_sent + 1;

      push(SEL_QUEUE, avgsel);

    end procedure;

    procedure overflow is

      variable num_samps : integer         := 2 ** G_MAX_AVGSEL;
      variable data      : integer_array_t := new_3d(num_samps, 1, 1, DW, G_SIGNED);
      variable result    : integer_array_t := new_3d(1, 1, 1, DW, G_SIGNED);
      variable accum     : integer         := 0;
      variable user      : integer_array_t := new_3d(num_samps, 1, 1, 1, false);
      variable ref_user  : integer_array_t := new_3d(1, 1, 1, 1, false);

    begin

      -- Calc average
      for i in 0 to num_samps - 1 loop
        if G_SIGNED then
          set(data, i, -1 * (2 ** DW));
        else
          set(data, i, (2 ** DW) - 1);
        end if;
        set(user, i, 0);
        accum := accum + get(data, i);
      end loop;
      set(result, 0, accum / num_samps);
      set(ref_user, 0, 0);

      push_ref(REF_DATA_QUEUE, result);
      push_ref(REF_USER_QUEUE, ref_user);
      expected_num_packets_checked := expected_num_packets_checked + 1;

      push_ref(DATA_QUEUE, data);
      push_ref(USER_QUEUE, user);
      expected_num_packets_sent := expected_num_packets_sent + 1;

      push(SEL_QUEUE, G_MAX_AVGSEL);

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

      for test_idx in 0 to 99 loop
        transact(rnd.Uniform(0, G_MAX_AVGSEL));
      end loop;

    elsif run("test_overflow") then
      overflow;
      overflow;

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
  u_block_avg : entity work.block_avg
  generic map (
    G_SIGNED     => G_SIGNED,
    G_MAX_AVGSEL => G_MAX_AVGSEL
  )
  port map (
    clk        => clk,
    srst       => srst,
    s_axis     => s_axis,
    m_axis     => m_axis,
    ctl_avgsel => ctl_avgsel
  );

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

  -- ---------------------------------------------------------------------------
  prc_avgsel : process is begin
    while is_empty(SEL_QUEUE) loop
      wait until rising_edge(clk);
    end loop;

    ctl_avgsel <= pop(SEL_QUEUE);

    wait until (s_axis.tvalid and s_axis.tready and s_axis.tlast) = '1'
      and rising_edge(clk);

  end process;

end architecture;
