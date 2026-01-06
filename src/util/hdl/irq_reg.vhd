--##############################################################################
--# File : irq_reg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Interrupt register
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity irq_reg is
  generic (
    --! Bit width of the interrupt vector
    G_WIDTH : positive := 32
  );
  port (
    --! Clock
    clk : in    std_logic;
    --! Synchronous reset
    srst : in    std_logic;
    --! Pulse to clear the sticky interrupt
    clr : in    std_logic_vector(G_WIDTH - 1 downto 0);
    --! Enable the interrupt source to set the global interrupt
    en : in    std_logic_vector(G_WIDTH - 1 downto 0);
    --! Pulse to set the sticky interrupt
    src : in    std_logic_vector(G_WIDTH - 1 downto 0);
    --! Interrupt status
    sts : out   std_logic_vector(G_WIDTH - 1 downto 0);
    --! Global interrupt status
    irq : out   std_logic
  );
end entity;

architecture rtl of irq_reg is

begin

  -- ---------------------------------------------------------------------------
  prc_irq : process (clk) is begin
    if rising_edge(clk) then

      for i0 in 0 to G_WIDTH - 1 loop
        if clr(i0) then
          sts(i0) <= '0';
        elsif src(i0) then
          sts(i0) <= '1';
        end if;
      end loop;

      irq <= or (sts and en);

      if srst then
        sts <= (others=> '0');
        irq <= '0';
      end if;
    end if;
  end process;

end architecture;
