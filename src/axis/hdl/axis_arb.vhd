--##############################################################################
--# File : axis_arb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Arbitrates packets with simple, fixed-priority. Higher
--# index has higher priority.
--#
--# NOTICE: Since this uses fixed-priority, if a higher channel holds valid high
--# on every clock cycle, then it will hog all of the bandwidth,
--# preventing the lower channels from ever sending data.
--#
--# TODO: Add round-robin arbitration option.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_arb is
  generic (
    G_NUM_S : positive;
    G_DW    : positive;
    G_UW    : positive
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axis : view (s_axis_view) of axis_arr_t(0 to G_NUM_S - 1)(
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

architecture rtl of axis_arb is

  signal sel : integer range 0 to G_NUM_S - 1;

begin

  -- ---------------------------------------------------------------------------
  prc_arb_sel : process (all) is begin

    -- Default
    sel <= sel'low;

    for i in 0 to G_NUM_S - 1 loop
      if s_axis(i).tvalid then
        sel <= i;
      end if;
    end loop;
  end process;

  -- ---------------------------------------------------------------------------
  u_axis_mux : entity work.axis_mux
  generic map (
    G_NUM_S => G_NUM_S ,
    G_DW    => G_DW    ,
    G_UW    => G_UW
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axis => s_axis,
    m_axis => m_axis,
    sel    => sel
  );

end architecture;
