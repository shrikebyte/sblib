--#############################################################################
--# File : cdc_vector.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ===========================================================================
--# Handshake vector synchronizer based on AXIS. If sync'ing counters, it is
--# recommended to use cdc_gray for lower resource utilization and lower
--# latency.
--# If syncing a slowly changing non-axis vector, such as a software-accessible
--# control or status vector, it is allowed to tie src_valid and dst_ready
--# high.
--#############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity cdc_vector is
  generic (
    G_EXTRA_SYNC : natural := 0
  );
  port (
    src_clk   : in    std_ulogic;
    src_ready : out   std_ulogic := '1';
    src_valid : in    std_ulogic := '1';
    src_data  : in    std_ulogic_vector;
    --
    dst_clk   : in    std_ulogic;
    dst_ready : in    std_ulogic := '1';
    dst_valid : out   std_ulogic := '0';
    dst_data  : out   std_ulogic_vector
  );
end entity;

architecture rtl of cdc_vector is

  constant DW : natural := src_data'length;

  signal src_xact      : std_ulogic;
  signal src_data_reg  : std_ulogic_vector(DW - 1 downto 0);
  signal src_req_pulse : std_ulogic := '0';
  signal src_ack_pulse : std_ulogic;
  signal dst_req_pulse : std_ulogic;
  signal dst_ack_pulse : std_ulogic;

begin

  -- Detect a new request & register the input data
  prc_new_request : process (src_clk) is begin
    if rising_edge(src_clk) then
      src_req_pulse <= src_xact;

      if src_xact then
        src_data_reg <= src_data;
        src_ready    <= '0';
      elsif src_ack_pulse then
        src_ready <= '1';
      end if;

    end if;
  end process;

  src_xact <= src_valid and src_ready;

  -- CDC the request to the destination domain
  u_cdc_pulse_req : entity work.cdc_pulse
  generic map (
    G_EXTRA_SYNC   => G_EXTRA_SYNC,
    G_USE_FEEDBACK => false
  )
  port map (
    src_clk   => src_clk,
    src_pulse => src_req_pulse,
    dst_clk   => dst_clk,
    dst_pulse => dst_req_pulse
  );

  -- Hold destination valid high until destination is ready to accept
  -- transaction
  prc_hold_valid : process (dst_clk) is begin
    if rising_edge(dst_clk) then
      if dst_req_pulse then
        dst_valid <= '1';
        dst_data  <= src_data_reg;
      elsif dst_ack_pulse then
        dst_valid <= '0';
      end if;
    end if;
  end process;

  -- Ack when a valid transaction has completed
  dst_ack_pulse <= dst_valid and dst_ready;

  -- CDC the acknowledge back to the source domain
  u_cdc_pulse_ack : entity work.cdc_pulse
  generic map (
    G_EXTRA_SYNC   => G_EXTRA_SYNC,
    G_USE_FEEDBACK => false
  )
  port map (
    src_clk   => dst_clk,
    src_pulse => dst_ack_pulse,
    dst_clk   => src_clk,
    dst_pulse => src_ack_pulse
  );

end architecture;
