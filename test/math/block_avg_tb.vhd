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

  constant G_AVGSEL_WIDTH : positive := 4;

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
    tdata(DW-1 downto 0),
    tkeep(0 downto 0),
    tuser(0 downto 0)
  );

  signal m_axis : axis_t (
    tdata(DW-1 downto 0),
    tkeep(0 downto 0),
    tuser(0 downto 0)
  );

  signal ctl_avgsel : u_unsigned(G_AVGSEL_WIDTH - 1 downto 0);

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

  function make_bit_mask(total_width : natural; num_ones : natural) return std_ulogic_vector is
    variable result : std_ulogic_vector(total_width - 1 downto 0) := (others => '0');
  begin
    if num_ones >= total_width then
      result := (others => '1');
    elsif num_ones > 0 then
      result(num_ones - 1 downto 0) := (others => '1');
    end if;
    return result;
  end function;

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is

    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    procedure transact (
      avgsel : u_unsigned(G_AVGSEL_WIDTH - 1 downto 0);
    ) is

      variable data      : integer_array_t := null_integer_array;
      variable data_copy : integer_array_t := new_3d(1, 1, 1, 1, false);
      variable user      : integer_array_t := new_3d(1, 1, 1, 1, false);
      variable user_copy : integer_array_t := new_3d(1, 1, 1, 1, false);

      variable accum : integer := 0;

      function calc_avg(avg : int_arr_t) return integer is
        variable accum : integer := 0;
      begin
        for i in avg'range loop
          accum := accum + avg(i);
        end loop;
        return accum / avg'length;
      end function;

      variable num_samps : integer := 2 ** to_integer(avgsel);

    begin

      -- Random data
      random_integer_array (
        rnd           => rnd,
        integer_array => data,
        width         => num_samps,
        bits_per_word => DW,
        is_signed     => false
      );

      tuser(0) := to_sl(cpol);
      tuser(1) := to_sl(cpha);
      tuser(G_WIDTH_BITS+2-1 downto 2) := to_unsigned(width, G_WIDTH_BITS);
      tuser(G_CS_BITS+G_WIDTH_BITS+2-1 downto G_WIDTH_BITS+2) := to_unsigned(cs, G_CS_BITS);
      set(user, 0, to_integer(tuser));

      data_copy := copy(data);
      push_ref(REF_DATA_QUEUE, data_copy);
      user_copy := copy(user);
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

    procedure wait_clks (
      clks : natural
    ) is begin
      if clks > 0 then
        for i in 0 to clks - 1 loop
          wait until rising_edge(clk);
        end loop;
      end if;
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
        spi_txrx(rnd.Uniform(0, 1), rnd.Uniform(0, 1), rnd.Uniform(0, (2 ** G_WIDTH_BITS)-1), rnd.Uniform(0, (2 ** G_CS_BITS)-1));
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
  u_block_avg : entity work.block_avg
  generic map(
    G_SIGNED       => G_SIGNED,
    G_AVGSEL_WIDTH => G_AVGSEL_WIDTH
  )
  port map(
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

end architecture;
