--##############################################################################
--# File : axil_xbar_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite crossbar testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;
use vunit_lib.axi_lite_master_pkg.all;

entity axil_xbar_tb is
  generic (
    RUNNER_CFG : string
  );
end entity;

architecture tb of axil_xbar_tb is

  -- Testbench constants
  constant CLK_PERIOD : time := 10 ns;
  constant CLK_TO_Q   : time := 1 ns;

  -- DUT Generics
  constant G_NUM_S      : positive                             := 4;
  constant G_NUM_M      : positive                             := 6;
  constant G_ADDR_WIDTH : positive                             := 32;
  constant G_BASEADDRS  : bus_baseaddr_arr_t(0 to G_NUM_M - 1) := (
    0 => (x"0000_0000", 16),
    1 => (x"0001_0000", 16),
    2 => (x"000F_0000", 16),
    3 => (x"0110_0000", 10),
    4 => (x"6001_1000", 12),
    5 => (x"0300_2000", 12)
  );

  -- DUT Ports
  signal clk      : std_logic := '1';
  signal srst     : std_logic := '1';
  signal axil_cpu : bus_axil_arr_t(0 to G_NUM_S - 1);
  signal axil_ram : bus_axil_arr_t(0 to G_NUM_M - 1);

  type bus_mgr_arr_t is array(natural range <>) of bus_master_t;

  -- Testbench BFMs
  constant AXIM : bus_mgr_arr_t(0 to G_NUM_S - 1) := (
    0 => new_bus(AXIL_DATA_WIDTH, AXIL_ADDR_WIDTH),
    1 => new_bus(AXIL_DATA_WIDTH, AXIL_ADDR_WIDTH),
    2 => new_bus(AXIL_DATA_WIDTH, AXIL_ADDR_WIDTH),
    3 => new_bus(AXIL_DATA_WIDTH, AXIL_ADDR_WIDTH)
  );

begin

  prc_main : process is

    -- Helper Procedures
    procedure prd_wait_clk (
      cnt : in positive := 1
    ) is
    begin
      for i in 0 to cnt - 1 loop
        wait until rising_edge(clk);
        wait for CLK_TO_Q;
      end loop;
    end procedure;

    procedure prd_rst (
      cnt : in positive := 1
    ) is
    begin
      prd_wait_clk(1);
      srst <= '1';
      prd_wait_clk(cnt);
      srst <= '0';
    end procedure;

    variable addr  : std_logic_vector(31 downto 0)                      := (others => '0');
    variable data  : std_logic_vector(AXIL_DATA_WIDTH - 1 downto 0)     := (others => '0');
    variable wstrb : std_logic_vector(AXIL_DATA_WIDTH / 8 - 1 downto 0) := (others => '1');

  begin

    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop

      prd_rst(16);

      if run("test_0") then
        info("Running test_0");

        prd_wait_clk;

        -- Generate transactions
        for mgr in 0 to G_NUM_S - 1 loop
          for sub in 0 to G_NUM_M - 1 loop
            for transaction in 1 to 1 loop
              addr  := G_BASEADDRS(sub).addr or (
                std_logic_vector(
                  to_unsigned(transaction + (mgr * 16), AXIL_ADDR_WIDTH - 2)
                ) & b"00"
              );
              data  := addr;
              wstrb := x"F";
              write_axi_lite(net, AXIM(mgr), addr, data, AXI_RESP_OKAY, wstrb);
            end loop;
          end loop;
        end loop;

        -- Check transactions
        for mgr in 0 to G_NUM_S - 1 loop
          for sub in 0 to G_NUM_M - 1 loop
            for transaction in 1 to 1 loop
              addr := G_BASEADDRS(sub).addr or (
                std_logic_vector(
                  to_unsigned(transaction + (mgr * 16), AXIL_ADDR_WIDTH - 2)
                ) & b"00"
              );
              data := addr;
              check_axi_lite(net, AXIM(mgr), addr, AXI_RESP_OKAY, data, "Check during read loop failed.");
            end loop;
          end loop;
        end loop;

      -- elsif run("test_1") then
      --   info("Running test_1");

      end if;

      info("Test done");
      prd_wait_clk(16);

    end loop;

    test_runner_cleanup(runner);

  end process;

  test_runner_watchdog(runner, 100 us);

  -- ---------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  -- ---------------------------------------------------------------------------
  u_axil_xbar : entity work.axil_xbar
  generic map (
    G_NUM_S      => G_NUM_S,
    G_NUM_M      => G_NUM_M,
    G_ADDR_WIDTH => G_ADDR_WIDTH,
    G_BASEADDRS  => G_BASEADDRS
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => axil_cpu,
    m_axil => axil_ram
  );

  -- ---------------------------------------------------------------------------
  gen_mgrs : for i in 0 to G_NUM_S - 1 generate

    u_bfm_axil_mgr : entity work.bfm_axil_mgr
    generic map (
      G_BUS_HANDLE => AXIM(i)
    )
    port map (
      clk    => clk,
      m_axil => axil_cpu(i)
    );

  end generate;

  -- ---------------------------------------------------------------------------
  gen_subs : for i in 0 to G_NUM_M - 1 generate

    u_axil_ram : entity work.axil_ram
    generic map (
      G_ADDR_WIDTH => 10,
      G_RD_LATENCY => 2
    )
    port map (
      clk    => clk,
      srst   => srst,
      s_axil => axil_ram(i)
    );

  end generate;

end architecture;
