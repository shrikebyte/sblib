--##############################################################################
--# File : cnt_reg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Count register
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cnt_reg is
  generic (
    G_WIDTH : positive := 32
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    clr  : in    std_ulogic;
    inc  : in    std_ulogic;
    cnt  : out   u_unsigned(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of cnt_reg is

  constant MAX : u_unsigned(cnt'range) := (others=>'1');

begin

  prc_cnt : process (clk) is begin
    if rising_edge(clk) then
      if inc = '1' and cnt /= MAX then
        cnt <= cnt + 1;
      end if;

      if srst or clr then
        cnt <= (others=> '0');
      end if;
    end if;
  end process;

end architecture;
