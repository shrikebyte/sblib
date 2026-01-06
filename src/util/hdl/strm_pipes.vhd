--##############################################################################
--# File : strm_pipes.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Stream pipeline registers. Has options to pipeline both the
--# "forward" data / valid and the "backward" ready signals.
--# This module just chains together multiple instances of strm_pipe.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;

entity strm_pipes is
  generic (
    G_WIDTH      : natural  := 8;
    G_READY_PIPE : boolean  := true;
    G_DATA_PIPE  : boolean  := true;
    G_STAGES     : positive := 1
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;
    --
    s_valid : in    std_logic;
    s_ready : out   std_logic;
    s_data  : in    std_logic_vector(G_WIDTH - 1 downto 0);
    --
    m_valid : out   std_logic;
    m_ready : in    std_logic;
    m_data  : out   std_logic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of strm_pipes is

  signal valid : std_logic_vector(0 to G_STAGES);
  signal ready : std_logic_vector(0 to G_STAGES);
  signal data  : slv_arr_t(0 to G_STAGES)(G_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  valid(0)        <= s_valid;
  s_ready         <= ready(0);
  data(0)         <= s_data;
  m_valid         <= valid(G_STAGES);
  ready(G_STAGES) <= m_ready;
  m_data          <= data(G_STAGES);

  -- ---------------------------------------------------------------------------
  gen_pipes : for i in 0 to G_STAGES - 1 generate

    u_axis_pipe : entity work.strm_pipe
    generic map (
      G_WIDTH      => G_WIDTH,
      G_READY_PIPE => G_READY_PIPE,
      G_DATA_PIPE  => G_DATA_PIPE
    )
    port map (
      clk     => clk,
      srst    => srst,
      s_valid => valid(i),
      s_ready => ready(i),
      s_data  => data(i),
      m_valid => valid(i + 1),
      m_ready => ready(i + 1),
      m_data  => data(i + 1)
    );

  end generate;

end architecture;
