--##############################################################################
--# File : axis_broadcast.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Broadcasts one input stream to several output streams.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_broadcast is
  generic (
    G_NUM_M : positive;
    G_DW    : positive;
    G_UW    : positive
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
    m_axis : view (m_axis_view) of axis_arr_t(0 to G_NUM_M - 1)(
      tdata(G_DW - 1 downto 0),
      tkeep(G_DW / 8 - 1 downto 0),
      tuser(G_UW - 1 downto 0)
    )
  );
end entity;

architecture rtl of axis_broadcast is

  signal axis_tvalid : std_ulogic_vector(0 to G_NUM_M - 1);
  signal axis_tready : std_ulogic_vector(0 to G_NUM_M - 1);
  signal axis_tdata  : std_ulogic_vector(G_DW - 1 downto 0);
  signal axis_tkeep  : std_ulogic_vector(G_DW / 8 - 1 downto 0);
  signal axis_tlast  : std_ulogic;
  signal axis_tuser  : std_ulogic_vector(G_UW - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  s_axis.tready <= (and axis_tready) or not (or axis_tvalid);

  -- ---------------------------------------------------------------------------
  prc_broadcast : process (clk) is begin
    if rising_edge(clk) then

      for i in 0 to G_NUM_M - 1 loop
        if axis_tready(i) then
          axis_tvalid(i) <= '0';
        end if;
      end loop;

      if s_axis.tvalid and s_axis.tready then
        axis_tvalid <= (others=> '1');
        axis_tdata  <= s_axis.tdata;
        axis_tkeep  <= s_axis.tkeep;
        axis_tlast  <= s_axis.tlast;
        axis_tuser  <= s_axis.tuser;
      end if;

      if srst then
        axis_tvalid <= (others=> '0');
      end if;
    end if;
  end process;

  gen_assign_outputs : for i in 0 to G_NUM_M - 1 generate
    axis_tready(i)   <= m_axis(i).tready;
    m_axis(i).tvalid <= axis_tvalid(i);
    m_axis(i).tdata  <= axis_tdata;
    m_axis(i).tkeep  <= axis_tkeep;
    m_axis(i).tlast  <= axis_tlast;
    m_axis(i).tuser  <= axis_tuser;
  end generate;

end architecture;
