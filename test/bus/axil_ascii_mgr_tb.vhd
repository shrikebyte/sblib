--##############################################################################
--# File : axil_ascii_mgr_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite ASCII Manager testbench
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

entity axil_ascii_mgr_tb is
  generic (
    RUNNER_CFG      : string;
    G_ENABLE_JITTER : boolean := true
  );
end entity;

architecture tb of axil_ascii_mgr_tb is

  -- Testbench constants
  constant RESET_TIME : time := 200 ns;
  constant CLK_PERIOD : time := 10 ns;

  -- Testbench signals
  signal clk  : std_logic := '1';
  signal srst : std_logic := '1';
  signal arst : std_logic := '1';

  -- DUT ports
  signal axil         : bus_axil_t;
  signal axis_host_tx : axis_t(tdata(7 downto 0), tkeep(0 downto 0), tuser(0 downto 0));
  signal axis_host_rx : axis_t(tdata(7 downto 0), tkeep(0 downto 0), tuser(0 downto 0));

  -- Testbench BFMs
  constant STALL_CFG : stall_configuration_t := (
    stall_probability => 0.5 * to_real(G_ENABLE_JITTER),
    min_stall_cycles  => 2,
    max_stall_cycles  => 10
  );

  constant TX_DATA_QUEUE : queue_t := new_queue;
  constant RX_DATA_QUEUE : queue_t := new_queue;

  signal num_packets_checked : natural := 0;
  signal num_packets_sent    : natural := 0;

begin

  -- ---------------------------------------------------------------------------
  test_runner_watchdog(runner, 100 us);

  prc_main : process is
    variable rnd                          : randomptype;
    variable expected_num_packets_checked : natural := 0;
    variable expected_num_packets_sent    : natural := 0;

    variable str : string(1 to 128) := (others => NUL);

    function strlen (
      str : string
    ) return natural is
    begin
      for i in str'range loop
        if str(i) = NUL then
          return i - str'low;
        end if;
      end loop;
      return str'length;
    end function;

    procedure send_ascii (
      cmd : string;
      rsp : string
    ) is

      variable cmd_len : positive := strlen(cmd);
      variable rsp_len : positive := strlen(rsp);

      variable tx_data : integer_array_t := new_1d (
        length    => cmd_len,
        bit_width => 8,
        is_signed => false
      );

      variable rx_data : integer_array_t := new_1d (
        length    => rsp_len,
        bit_width => 8,
        is_signed => false
      );

    begin

      for i in 0 to cmd_len - 1 loop
        set(tx_data, i, to_integer(to_ascii(cmd(i + 1))));
      end loop;

      for i in 0 to rsp_len - 1 loop
        set(rx_data, i, to_integer(to_ascii(rsp(i + 1))));
      end loop;

      push_ref(TX_DATA_QUEUE, tx_data);
      expected_num_packets_sent := expected_num_packets_sent + 1;

      push_ref(RX_DATA_QUEUE, rx_data);
      expected_num_packets_checked := expected_num_packets_checked + 1;

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

    if run("test_0") then
      info("Full-sized strings");
      send_ascii("w 00000000 11223344" & LF, "+" & LF);
      send_ascii("r 00000000" & LF, "11223344" & LF);

      info("Short strings");
      send_ascii("w 04 1234" & LF, "+" & LF);
      send_ascii("r 04" & LF, "00001234" & LF);

      info("Incrementing writes");
      send_ascii("m 1" & LF, "+" & LF);
      send_ascii("m 2" & LF, "+" & LF);
      send_ascii("m 3" & LF, "+" & LF);
      send_ascii("M 4" & LF, "+" & LF);
      send_ascii("m 5" & LF, "+" & LF);
      send_ascii("m 6" & LF, "+" & LF);
      send_ascii("m 7" & LF, "+" & LF);
      send_ascii("m 8" & LF, "+" & LF);

      info("Incrementing reads");
      send_ascii("R 00004" & LF, "00001234" & LF);
      send_ascii("n" & LF, "00000001" & LF);
      send_ascii("n" & LF, "00000002" & LF);
      send_ascii("N" & LF, "00000003" & LF);
      send_ascii("n" & LF, "00000004" & LF);
      send_ascii("N" & LF, "00000005" & LF);
      send_ascii("n" & LF, "00000006" & LF);
      send_ascii("n" & LF, "00000007" & LF);
      send_ascii("n" & LF, "00000008" & LF);

      info("Previous read");
      send_ascii("p" & LF, "00000008" & LF);
      send_ascii("P" & LF, "00000008" & LF);
      send_ascii("p" & LF, "00000008" & LF);

      info("Previous write");
      send_ascii("W 0 a" & LF, "+" & LF);
      send_ascii("P" & LF, "+" & LF);
      send_ascii("p" & LF, "+" & LF);
      send_ascii("p" & LF, "+" & LF);
      send_ascii("r 0" & LF, "0000000A" & LF);

      info("Strange but legal syntax");
      send_ascii("W                         0  " & HT & "B" & LF, "+" & LF);
      send_ascii(HT & "  r  0  " & HT & LF, "0000000B" & LF);
      send_ascii("m c" & CR & LF, "+" & LF);
      send_ascii(" r  04 " & CR & LF, "0000000C" & LF);
      send_ascii('m' & HT & 'd' & LF & CR, "+" & LF);

      info("Illegal syntax");
      send_ascii("123" & LF, "?" & LF);
      send_ascii("w" & LF, "?" & LF);
      send_ascii("r" & LF, "?" & LF);
      send_ascii("w 1" & LF, "?" & LF);
      send_ascii("w 1 2 3 4 " & LF, "?" & LF);
      send_ascii("p 20 " & LF, "?" & LF);
      send_ascii("?? .,     asdf \n " & LF, "?" & LF);
      send_ascii("P" & ESC & LF, "?" & LF);

      info("Overflow");
      send_ascii("w 123456789 12345678" & LF, "?" & LF);
      send_ascii("w 12345678 123456789" & LF, "?" & LF);
      send_ascii("r 123456789" & LF, "?" & LF);

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
  u_axil_ascii_mgr : entity work.axil_ascii_mgr
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => axis_host_tx,
    m_axis => axis_host_rx,
    m_axil => axil
  );

  -- ---------------------------------------------------------------------------
  u_axil_ram : entity work.axil_ram
  generic map (
    G_ADDR_WIDTH => 5,
    G_RD_LATENCY => 1
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => axil
  );

  u_bfm_axis_mgr : entity work.bfm_axis_mgr
  generic map (
    G_DATA_QUEUE   => TX_DATA_QUEUE,
    G_ENABLE_TUSER => false,
    G_STALL_CONFIG => STALL_CFG
  )
  port map (
    clk              => clk,
    m_axis           => axis_host_tx,
    num_packets_sent => num_packets_sent
  );

  u_bfm_axis_sub : entity work.bfm_axis_sub
  generic map (
    G_REF_DATA_QUEUE => RX_DATA_QUEUE,
    G_ENABLE_TUSER   => false,
    G_ENABLE_TKEEP   => false,
    G_ENABLE_TLAST   => false,
    G_STALL_CONFIG   => STALL_CFG
  )
  port map (
    clk                 => clk,
    s_axis              => axis_host_rx,
    num_packets_checked => num_packets_checked
  );

end architecture;
