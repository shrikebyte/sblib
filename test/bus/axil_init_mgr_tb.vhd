--##############################################################################
--# File : axil_init_mgr_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite Init Manager testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
use osvvm.randompkg.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;
use work.bfm_pkg.all;

entity axil_init_mgr_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean := true
  );
end entity;

architecture tb of axil_init_mgr_tb is

  -- Testbench constants
  constant RESET_TIME : time := 200 ns;
  constant CLK_PERIOD : time := 10 ns;
  constant CLK_TO_Q   : time := 1 ns;

  -- DUT ports
  signal clk  : std_logic := '1';
  signal srst : std_logic := '1';
  signal axil : bus_axil_t;

  signal sts_axis : axis_t(
    tdata(AXIL_DATA_RANGE),
    tkeep(AXIL_STRB_RANGE),
    tuser(3 downto 0)
  );

  constant NUM_XACTIONS : integer                               := 11;
  constant XACTIONS     : bus_xact_arr_t(0 to NUM_XACTIONS - 1) := (
    0       => (
      cmd   => BUS_WRITE,
      wstrb => x"F",
      addr  => x"0000_0000",
      data  => x"1122_3344",
      mask  => x"00FF_FFFF"
    ),
    1       => (
      cmd   => BUS_WRITE,
      wstrb => x"F",
      addr  => x"0000_0004",
      data  => x"2233_4455",
      mask  => x"FFFF_FFFF"
    ),
    2       => (
      cmd   => BUS_WRITE,
      wstrb => x"F",
      addr  => x"0000_0008",
      data  => x"3344_5566",
      mask  => x"FFFF_FFFF"
    ),
    3       => (
      cmd   => BUS_WRITE,
      wstrb => x"3",
      addr  => x"0000_000C",
      data  => x"4455_6677",
      mask  => x"FFFF_FFFF"
    ),
    4       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0000",
      data  => x"0022_3344",
      mask  => x"00FF_FFFF"
    ),
    5       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0004",
      data  => x"2233_4455",
      mask  => x"FFFF_FFFF"
    ),
    6       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0008",
      data  => x"3344_5566",
      mask  => x"FFFF_FFFF"
    ),
    7       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_000C",
      data  => x"4455_6677",
      mask  => x"0000_FFFF"
    ),
    8       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0004",
      data  => x"2030_4050",
      mask  => x"F0F0_F0F0"
    ),
    9       => (
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0004",
      data  => x"0203_0405",
      mask  => x"0F0F_0F0F"
    ),
    10      => ( -- Data mismatch on purpose
      cmd   => BUS_CHECK,
      wstrb => x"F",
      addr  => x"0000_0004",
      data  => x"FFFF_FFFF",
      mask  => x"0F0F_0F0F"
    )
  );

  constant STALL_CFG : stall_configuration_t := (
    stall_probability => 0.5 * to_real(G_ENABLE_JITTER),
    min_stall_cycles  => 2,
    max_stall_cycles  => 10
  );

  constant DATA_QUEUE : queue_t := new_queue;
  constant USER_QUEUE : queue_t := new_queue;

  signal arst                : std_logic := '1';
  signal num_packets_checked : natural   := 0;

  signal chk_axis : axis_t(
    tdata(AXIL_DATA_RANGE),
    tkeep(0 downto 0),
    tuser(3 downto 0)
  );

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is

    variable rnd : randomptype;

    procedure gen_expected is

      variable data  : integer_array_t := new_3d(NUM_XACTIONS, 1, 1, 32, true);
      variable user  : integer_array_t := new_3d(NUM_XACTIONS, 1, 1, 4, false);
      variable tuser : unsigned(3 downto 0);

    begin

      for i in 0 to NUM_XACTIONS - 1 loop
        tuser(0) := '1' when XACTIONS(i).cmd = BUS_WRITE else '0';
        tuser(1) := '0';
        tuser(2) := '0';
        tuser(3) := '1' when i = 10 else '0';
        set(user, i, to_integer(tuser));
      end loop;

      set(data,  0, to_integer(signed(XACTIONS(0).data)));
      set(data,  1, to_integer(signed(XACTIONS(1).data)));
      set(data,  2, to_integer(signed(XACTIONS(2).data)));
      set(data,  3, to_integer(signed(XACTIONS(3).data)));
      set(data,  4, to_integer(signed(XACTIONS(0).data)));
      set(data,  5, to_integer(signed(XACTIONS(1).data)));
      set(data,  6, to_integer(signed(XACTIONS(2).data)));
      set(data,  7, to_integer(signed(XACTIONS(3).data and x"0000_FFFF")));
      set(data,  8, to_integer(signed(XACTIONS(1).data)));
      set(data,  9, to_integer(signed(XACTIONS(1).data)));
      set(data, 10, to_integer(signed(XACTIONS(1).data)));

      push_ref(DATA_QUEUE, data);
      push_ref(USER_QUEUE, user);

    end procedure;

    procedure wait_until_done is begin
      wait until num_packets_checked = 1 and rising_edge(clk);
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

    if run("test_0") then
      gen_expected;
      info("Test done");
      wait_clks(16);

    end if;

    wait_until_done;
    test_runner_cleanup(runner);
  end process;

  -- ---------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  prc_srst : process (clk) is begin
    if rising_edge(clk) then
      srst <= arst;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  u_axil_init_mgr : entity work.axil_init_mgr
  generic map (
    G_RESET_DELAY => 16,
    G_XACTIONS    => XACTIONS
  )
  port map (
    clk    => clk,
    srst   => srst,
    m_axil => axil,
    m_axis => sts_axis
  );

  -- ---------------------------------------------------------------------------
  u_axil_ram : entity work.axil_ram
  generic map (
    G_ADDR_WIDTH => 4,
    G_RD_LATENCY => 2
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => axil
  );

  u_bfm_axis_sub : entity work.bfm_axis_sub
  generic map (
    G_REF_DATA_QUEUE => DATA_QUEUE,
    G_REF_USER_QUEUE => USER_QUEUE,
    G_STALL_CONFIG   => STALL_CFG
  )
  port map (
    clk                 => clk,
    s_axis              => chk_axis,
    num_packets_checked => num_packets_checked
  );

  chk_axis.tvalid <= sts_axis.tvalid;
  sts_axis.tready <= chk_axis.tready;
  chk_axis.tdata  <= sts_axis.tdata;
  chk_axis.tkeep  <= "1";
  chk_axis.tlast  <= sts_axis.tlast;
  chk_axis.tuser  <= sts_axis.tuser;

end architecture;
