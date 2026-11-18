--##############################################################################
--# File : tribuf.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Tri-state IO buffer. Prefer using this to vendor primitives for better
--# portability. Most tools should be able to infer an io buffer from this
--# module.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tribuf is
  generic (
    G_WIDTH : positive
  );
  port (
    i  : out   std_ulogic_vector(G_WIDTH - 1 downto 0);
    o  : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    t  : in    std_ulogic_vector(G_WIDTH - 1 downto 0);
    io : inout std_ulogic_vector(G_WIDTH - 1 downto 0) -- pad
  );
end entity;

architecture rtl of tribuf is

begin

  i <= io;

  gen_bufs : for j in 0 to G_WIDTH - 1 generate
    io(j) <= 'Z' when t(j) else o(j);
  end generate;

end architecture;
