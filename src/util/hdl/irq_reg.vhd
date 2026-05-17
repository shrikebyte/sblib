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
use ieee.numeric_std.all;

entity irq_reg is
  generic (
    G_WIDTH : positive
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    clr  : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    en   : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    set  : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    sts  : out   std_ulogic_vector(G_WIDTH - 1 downto 0);
    irq  : out   std_ulogic
  );
end entity;

architecture rtl of irq_reg is

begin

  prc_irq : process (clk) is begin
    if rising_edge(clk) then

      for i in sts'range loop
        if clr(i) then
          sts(i) <= '0';
        elsif set(i) then
          sts(i) <= '1';
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
