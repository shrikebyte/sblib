--##############################################################################
--# File : axis_pipes.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Cascaded axi stream pipeline registers.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_pipes is
  generic (
    G_DW    : positive;
    G_UW    : positive;
    --
    G_STAGES     : positive := 1;
    G_DATA_PIPE  : boolean  := true;
    G_READY_PIPE : boolean  := true
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axis : view s_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(G_DW / 8 - 1 downto 0),
      tuser(G_UW - 1 downto 0)
    );
    --
    m_axis : view m_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(G_DW / 8 - 1 downto 0),
      tuser(G_UW - 1 downto 0)
    )
  );
end entity;

architecture rtl of axis_pipes is

  signal int_axis : axis_arr_t(0 to G_STAGES)(
    tdata(G_DW - 1 downto 0),
    tkeep(G_DW / 8 - 1 downto 0),
    tuser(G_UW - 1 downto 0)
  );

begin

  axis_attach(s_axis, int_axis(0));
  axis_attach(int_axis(G_STAGES), m_axis);

  gen_pipes : for i in 0 to G_STAGES - 1 generate

    u_axis_pipe : entity work.axis_pipe
    generic map (
      G_DW         => G_DW,
      G_UW         => G_UW,
      G_READY_PIPE => G_READY_PIPE,
      G_DATA_PIPE  => G_DATA_PIPE
    )
    port map (
      clk    => clk,
      srst   => srst,
      s_axis => int_axis(i),
      m_axis => int_axis(i + 1)
    );

  end generate;

end architecture;
