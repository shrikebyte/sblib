--##############################################################################
--# File : strm_pipe.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Stream pipeline register. Has options to pipeline both the
--# "forward" data / valid and the "backward" ready signals.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;

entity strm_pipe is
  generic (
    G_WIDTH      : positive := 8;
    G_READY_PIPE : boolean  := true;
    G_DATA_PIPE  : boolean  := true
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

architecture rtl of strm_pipe is

  -- Internal signals to connect the ready pipe to the data pipe
  signal valid_int : std_logic;
  signal ready_int : std_logic;
  signal data_int  : std_logic_vector(G_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  gen_ready_pipe : if G_READY_PIPE generate

    signal data_buf : std_logic_vector(G_WIDTH - 1 downto 0);

  begin

    prc_ready_pipe : process (clk) is begin
      if rising_edge(clk) then
        if s_ready then
          data_buf <= s_data;
        end if;

        if valid_int then
          s_ready <= ready_int;
        end if;

        if srst then
          s_ready <= '1';
        end if;
      end if;
    end process;

    valid_int <= s_valid or not s_ready;
    data_int  <= s_data when s_ready else data_buf;

  else generate

    valid_int <= s_valid;
    s_ready   <= ready_int;
    data_int  <= s_data;

  end generate;

  -- ---------------------------------------------------------------------------
  gen_data_pipe : if G_DATA_PIPE generate begin

    prc_data_pipe : process (clk) is begin
      if rising_edge(clk) then
        if ready_int then
          m_valid <= valid_int;
          m_data  <= data_int;
        end if;

        if srst then
          m_valid <= '0';
        end if;
      end if;
    end process;

    ready_int <= m_ready or not m_valid;

  else generate

    m_valid   <= valid_int;
    ready_int <= m_ready;
    m_data    <= data_int;

  end generate;

end architecture;
