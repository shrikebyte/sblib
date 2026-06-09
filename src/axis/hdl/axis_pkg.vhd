--##############################################################################
--# File : axis_pkg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI-Stream type definitions.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axis_pkg is

  -- AXI-Stream type
  type axis_t is record
    tvalid : std_ulogic;
    tready : std_ulogic;
    tdata  : std_ulogic_vector;
    tkeep  : std_ulogic_vector;
    tlast  : std_ulogic;
    tuser  : std_ulogic_vector;
  end record;

  -- AXI-Stream array
  type axis_arr_t is array(natural range <>) of axis_t;

  -- Manager view
	view m_axis_view of axis_t is
    tvalid : out;
    tready : in;
    tdata  : out;
    tkeep  : out;
    tlast  : out;
    tuser  : out;
  end view;

  -- Subordinate view
  alias s_axis_view is m_axis_view'converse;

  -- Probe view
  view p_axis_view of axis_t is
    tvalid : in;
    tready : in;
    tdata  : in;
    tkeep  : in;
    tlast  : in;
    tuser  : in;
  end view;

  procedure axis_attach (
    signal s_axis : view s_axis_view of axis_t;
    signal m_axis : view m_axis_view of axis_t
  );

  procedure axis_attach (
    signal s_axis : view (s_axis_view) of axis_arr_t;
    signal m_axis : view (m_axis_view) of axis_arr_t
  );

end package;

package body axis_pkg is

  procedure axis_attach (
    signal s_axis : view s_axis_view of axis_t;
    signal m_axis : view m_axis_view of axis_t
  ) is
  begin
    m_axis.tvalid <= s_axis.tvalid;
    s_axis.tready <= m_axis.tready;
    m_axis.tdata  <= s_axis.tdata;
    m_axis.tkeep  <= s_axis.tkeep;
    m_axis.tlast  <= s_axis.tlast;
    m_axis.tuser  <= s_axis.tuser;
  end procedure;

  procedure axis_attach (
    signal s_axis : view (s_axis_view) of axis_arr_t;
    signal m_axis : view (m_axis_view) of axis_arr_t
  ) is
  begin
    for i in s_axis'range loop
      m_axis(i).tvalid <= s_axis(i).tvalid;
      s_axis(i).tready <= m_axis(i).tready;
      m_axis(i).tdata  <= s_axis(i).tdata;
      m_axis(i).tkeep  <= s_axis(i).tkeep;
      m_axis(i).tlast  <= s_axis(i).tlast;
      m_axis(i).tuser  <= s_axis(i).tuser;
    end loop;
  end procedure;

end package body;
