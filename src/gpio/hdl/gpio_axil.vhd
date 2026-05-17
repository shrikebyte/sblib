--##############################################################################
--# File : gpio_axil.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite GPIO
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.gpio_regs_pkg.all;
use work.gpio_register_record_pkg.all;

entity gpio_axil is
  generic (
    -- Use double-flop input synchronizer
    G_SYNC_I : boolean := false;
    -- Default output value
    G_RST_VAL_O : std_ulogic_vector(AXIL_DATA_RANGE) := (others => '0');
    -- Default tri-state value
    G_RST_VAL_T : std_ulogic_vector(AXIL_DATA_RANGE) := (others => '0')
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;
    irq  : out   std_logic;
    --
    s_axil : view s_axil_view;
    --
    gpio_i : in    std_ulogic_vector(AXIL_DATA_RANGE) := (others => '0');
    gpio_o : out   std_ulogic_vector(AXIL_DATA_RANGE);
    gpio_t : out   std_ulogic_vector(AXIL_DATA_RANGE)
  );
end entity;

architecture rtl of gpio_axil is

  signal u : gpio_regs_up_t;
  signal d : gpio_regs_down_t;
  signal r : gpio_reg_was_read_t;
  signal w : gpio_reg_was_written_t;

  signal gpio_in : std_ulogic_vector(AXIL_DATA_RANGE);
  signal edge    : std_ulogic_vector(AXIL_DATA_RANGE);
  signal irq_sts : std_ulogic_vector(AXIL_DATA_RANGE);

begin

  -- ---------------------------------------------------------------------------
  u_reg_file : entity work.gpio_register_file_axi_lite
  port map (
    clk             => clk,
    reset           => srst,
    s_axil          => s_axil,
    regs_up         => u,
    regs_down       => d,
    reg_was_read    => r,
    reg_was_written => w
  );

  -- ---------------------------------------------------------------------------
  gen_sync : if G_SYNC_I generate

    u_cdc_bit : entity work.cdc_bit
    generic map (
      G_USE_SRC_REG => false,
      G_EXTRA_SYNC  => 0
    )
    port map (
      src_bit => gpio_i,
      dst_clk => clk,
      dst_bit => gpio_in
    );

  else generate

    gpio_in <= gpio_i;

  end generate;

  -- ---------------------------------------------------------------------------
  u_edge_detect : entity work.edge_detect
  generic map (
    G_WIDTH => AXIL_DATA_WIDTH
  )
  port map (
    clk  => clk,
    srst => srst,
    din  => gpio_in,
    both => edge
  );

  u_irq_reg : entity work.irq_reg
  generic map (
    G_WIDTH => AXIL_DATA_WIDTH
  )
  port map (
    clk  => clk,
    srst => srst,
    clr  => std_logic_vector(d.isr.isr),
    en   => std_logic_vector(d.ier.ier),
    set  => edge,
    sts  => irq_sts,
    irq  => irq
  );

  u.isr.isr <= unsigned(irq_sts);
  u.din.din <= unsigned(gpio_in);

  -- ---------------------------------------------------------------------------
  prc_sticky_regs : process (clk) is begin
    if rising_edge(clk) then
      if w.dout then
        gpio_o <= std_logic_vector(d.dout.dout);
      end if;

      if w.tri then
        gpio_t <= std_logic_vector(d.tri.tri);
      end if;

      if srst then
        gpio_o <= G_RST_VAL_O;
        gpio_t <= G_RST_VAL_T;
      end if;
    end if;
  end process;

  u.dout.dout <= unsigned(gpio_o);
  u.tri.tri   <= unsigned(gpio_t);

end architecture;
