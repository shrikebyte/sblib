--##############################################################################
--# File : axis_demux.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# De-multiplexes a stream.
--# The `sel` select input can be changed at any time. The demux "locks on" to
--# a packet when the input channel's tvalid is high at the same time as it's
--# `sel` is selected. The demux releases a channel after the tlast beat.
--# This module inserts one bubble cycle per packet, as this is the design that
--# uses the most reasonable tradeoff between the competing variables of
--# latency, utilization, and combinatorial loading on s_axis.tready. For large
--# packets, the bubble will be negligible compared to the overall packet, but
--# for packets sized one beat, the best possible thruput of this module is 50%.
--#
--# TODO: Consider an alternate implementation with no bubble cycles.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_demux is
  generic (
    G_NUM_M : positive;
    G_DW    : positive;
    G_UW    : positive
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    -- Output select
    sel : in    integer range 0 to G_NUM_M - 1;
    --
    s_axis : view s_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(G_DW / 8 - 1 downto 0),
      tuser(G_UW - 1 downto 0)
    );
    --
    m_axis : view (m_axis_view) of axis_arr_t(0 to G_NUM_M - 1)(
      tdata(G_DW - 1 downto 0),
      tkeep(G_DW / 8 - 1 downto 0),
      tuser(G_UW - 1 downto 0)
    )
  );
end entity;

architecture rtl of axis_demux is

  type state_t is (ST_UNLOCKED, ST_LOCKED);

  signal state   : state_t;
  signal sel_reg : integer range 0 to G_NUM_M - 1;
  signal oe      : std_ulogic;

  signal axis_tvalid : std_ulogic_vector(0 to G_NUM_M - 1);
  signal axis_tdata  : std_ulogic_vector(G_DW - 1 downto 0);
  signal axis_tkeep  : std_ulogic_vector(G_DW / 8 - 1 downto 0);
  signal axis_tlast  : std_ulogic;
  signal axis_tuser  : std_ulogic_vector(G_UW - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  oe            <= m_axis(sel_reg).tready or not m_axis(sel_reg).tvalid;
  s_axis.tready <= oe and to_sl(state = ST_LOCKED);

  -- ---------------------------------------------------------------------------
  prc_select : process (clk) is begin
    if rising_edge(clk) then
      if m_axis(sel_reg).tready then
        axis_tvalid(sel_reg) <= '0';
      end if;

      case state is
        when ST_UNLOCKED =>
          if s_axis.tvalid and oe then
            sel_reg <= sel;
            state   <= ST_LOCKED;
          end if;

        when ST_LOCKED =>
          if s_axis.tvalid and oe then
            axis_tvalid(sel_reg) <= '1';
            axis_tdata           <= s_axis.tdata;
            axis_tkeep           <= s_axis.tkeep;
            axis_tlast           <= s_axis.tlast;
            axis_tuser           <= s_axis.tuser;

            if s_axis.tlast then
              state <= ST_UNLOCKED;
            end if;
          end if;
      end case;

      if srst then
        axis_tvalid <= (others=> '0');
        sel_reg     <= sel_reg'low;
        state       <= ST_UNLOCKED;
      end if;
    end if;
  end process;

  gen_assign_outputs : for i in 0 to G_NUM_M - 1 generate
    m_axis(i).tvalid <= axis_tvalid(i);
    m_axis(i).tdata  <= axis_tdata;
    m_axis(i).tkeep  <= axis_tkeep;
    m_axis(i).tlast  <= axis_tlast;
    m_axis(i).tuser  <= axis_tuser;
  end generate;

end architecture;
