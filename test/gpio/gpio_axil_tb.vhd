--##############################################################################
--# File : gpio_axil_tb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXIL GPIO testbench
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;
use vunit_lib.axi_lite_master_pkg.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.gpio_regs_pkg.all;

entity gpio_axil_tb is
  generic (
    RUNNER_CFG : string
  );
end entity;

architecture tb of gpio_axil_tb is

  -- Clock period
  constant CLK_PERIOD : time := 10 ns;
  constant CLK_TO_Q   : time := 1 ns;

  -- Generics
  constant G_SYNC_I    : boolean                            := true;
  constant G_RST_VAL_O : std_ulogic_vector(AXIL_DATA_RANGE) := x"00112233";
  constant G_RST_VAL_T : std_ulogic_vector(AXIL_DATA_RANGE) := x"00445566";

  -- Ports
  signal clk    : std_logic := '1';
  signal srst   : std_logic := '1';
  signal irq    : std_logic;
  signal axil   : bus_axil_t;
  signal gpio_i : std_ulogic_vector(AXIL_DATA_RANGE);
  signal gpio_o : std_ulogic_vector(AXIL_DATA_RANGE);
  signal gpio_t : std_ulogic_vector(AXIL_DATA_RANGE);

  constant AXIM : bus_master_t := new_bus(
      data_length => AXIL_DATA_WIDTH, address_length => AXIL_ADDR_WIDTH
    );

  function addr (
    idx : natural
  ) return std_logic_vector is begin
    return std_logic_vector(to_unsigned(idx * 4, AXIL_ADDR_WIDTH));
  end function;

begin

  prc_main : process is

    procedure prd_cycle (
      cnt : in positive := 1
    ) is
    begin
      for i in 0 to cnt - 1 loop
        wait until rising_edge(clk);
        wait for CLK_TO_Q;
      end loop;
    end procedure;

    variable data : std_logic_vector(axil_data_range) := (others => '0');

  begin

    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop

      prd_cycle;
      srst <= '1';
      prd_cycle(16);
      srst <= '0';

      if run("test_0") then
        info("test_0");

        gpio_i <= (others => '0');

        prd_cycle(4);

        -- ---------------------------------------------------------------------
        info("Check defaults");
        data := G_RST_VAL_O;
        check_axi_lite(net, AXIM, addr(gpio_dout), AXI_RSP_OKAY, data, "Check default out reg.");

        prd_cycle(4);
        check_equal(gpio_o, G_RST_VAL_O, "Check default out sig.");

        data := G_RST_VAL_T;
        check_axi_lite(net, AXIM, addr(gpio_tri), AXI_RSP_OKAY, data, "Check default tri reg.");

        prd_cycle(4);
        check_equal(gpio_t, G_RST_VAL_T, "Check default tri sig.");

        data := (others => '0');
        check_axi_lite(net, AXIM, addr(gpio_din), AXI_RSP_OKAY, data, "Check default in reg.");

        data := (others => '0');
        check_axi_lite(net, AXIM, addr(gpio_ier), AXI_RSP_OKAY, data, "Check default irq en reg.");

        data := (others => '0');
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check default irq sts reg.");

        -- ---------------------------------------------------------------------
        info("Write to the interrupt enable register.");
        data := x"11223344";
        write_axi_lite(net, AXIM, addr(gpio_ier), data, AXI_RSP_OKAY, x"F");
        check_axi_lite(net, AXIM, addr(gpio_ier), AXI_RSP_OKAY, data, "Check irq en reg after writing to it.");

        info("Write to the data out register.");
        data := x"11223344";
        write_axi_lite(net, AXIM, addr(gpio_dout), data, AXI_RSP_OKAY, x"F");
        check_axi_lite(net, AXIM, addr(gpio_dout), AXI_RSP_OKAY, data, "Check data out reg after writing to it.");

        prd_cycle(4);
        check_equal(gpio_o, data, "Check data out sig after writing it.");

        check_equal(irq, '0', "Verify interrupt is not latched.");

        info("Write to the tri-state register.");
        data := x"44556677";
        write_axi_lite(net, AXIM, addr(gpio_tri), data, AXI_RSP_OKAY, x"F");
        check_axi_lite(net, AXIM, addr(gpio_tri), AXI_RSP_OKAY, data, "Check tri reg after writing to it.");

        prd_cycle(4);
        check_equal(gpio_t, data, "Check tri sig after writing to it.");

        -- ---------------------------------------------------------------------
        info("Pulse an input bit that should not trigger an interrupt.");
        gpio_i(31) <= '1';
        prd_cycle(4);
        data       := x"80000000";
        check_axi_lite(net, AXIM, addr(gpio_din), AXI_RSP_OKAY, data, "Check din register during pulse 0.");
        data       := x"80000000";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check irq status register during pulse 0.");
        prd_cycle;
        gpio_i(31) <= '0';
        prd_cycle(4);
        data       := x"00000000";
        check_axi_lite(net, AXIM, addr(gpio_din), AXI_RSP_OKAY, data, "Check din register after pulse 0.");
        data       := x"80000000";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check irq status register after pulse 0.");
        check_equal(irq, '0', "Verify interrupt is not latched after pulse 0.");
        prd_cycle(4);

        info("Pulse an input bit that should trigger an interrupt.");
        gpio_i(2) <= '1';
        prd_cycle(4);
        data      := x"00000004";
        check_axi_lite(net, AXIM, addr(gpio_din), AXI_RSP_OKAY, data, "Check din register during pulse 1.");
        data      := x"80000004";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check irq status register during pulse 1.");
        prd_cycle;
        gpio_i(2) <= '0';
        prd_cycle(4);
        data      := x"00000000";
        check_axi_lite(net, AXIM, addr(gpio_din), AXI_RSP_OKAY, data, "Check din register after pulse 1.");
        data      := x"80000004";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check irq status register after pulse 1.");
        check_equal(irq, '1', "Verify interrupt is latched after pulse 1.");
        prd_cycle(4);

        info("Clear the first irq status bit");
        data := x"80000000";
        write_axi_lite(net, AXIM, addr(gpio_isr), data, AXI_RSP_OKAY, x"F");
        data := x"00000004";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check isr after clearing first bit.");
        prd_cycle(4);
        check_equal(irq, '1', "Verify interrupt is still latched.");

        info("Clear the second irq status bit");
        data := x"00000004";
        write_axi_lite(net, AXIM, addr(gpio_isr), data, AXI_RSP_OKAY, x"F");
        data := x"00000000";
        check_axi_lite(net, AXIM, addr(gpio_isr), AXI_RSP_OKAY, data, "Check isr after clearing second bit.");
        prd_cycle(4);
        check_equal(irq, '0', "Verify interrupt signal has lowered.");

      end if;

      test_runner_cleanup(runner);

    end loop;
  end process;

  -- ---------------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  -- ---------------------------------------------------------------------------
  u_gpio_axil : entity work.gpio_axil
  generic map (
    G_SYNC_I    => G_SYNC_I,
    G_RST_VAL_O => G_RST_VAL_O,
    G_RST_VAL_T => G_RST_VAL_T
  )
  port map (
    clk    => clk,
    srst   => srst,
    irq    => irq,
    s_axil => axil,
    gpio_i => gpio_i,
    gpio_o => gpio_o,
    gpio_t => gpio_t
  );

  -- ---------------------------------------------------------------------------
  u_bfm_axil_mgr : entity work.bfm_axil_mgr
  generic map (
    G_BUS_HANDLE => AXIM
  )
  port map (
    clk    => clk,
    m_axil => axil
  );

end architecture;
