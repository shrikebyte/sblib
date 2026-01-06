--##############################################################################
--# File : cdc_pulse.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Pulse synchronizer.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity cdc_pulse is
  generic (
    --! Number of additional synchronizer flip-flops
    G_EXTRA_SYNC : natural := 0;
    --! Protect against pulse overloading at the input. If the user sends pulses
    --! infrequently or if the src clock is over 2x slower than the output clock
    --! then this can be set to false.
    --! When set to true, this guarantees that one or more input pulses will
    --! produce at least one output pulse. This does not guarantee that the same
    --! number of pulses will be produced at the output as were received at
    --! the input.
    G_USE_FEEDBACK : boolean := true
  );
  port (
    src_clk   : in    std_ulogic;
    src_pulse : in    std_ulogic;
    dst_clk   : in    std_ulogic;
    dst_pulse : out   std_ulogic
  );
end entity;

architecture rtl of cdc_pulse is

  constant SYNC_LEN : positive := 2 + G_EXTRA_SYNC;

  -- ---------------------------------------------------------------------------
  signal src_toggl     : std_ulogic                               := '0';
  signal dst_toggl_cdc : std_ulogic_vector(SYNC_LEN - 1 downto 0) := (others => '0');
  signal dst_toggl_ff  : std_ulogic                               := '0';

  -- ---------------------------------------------------------------------------
  attribute async_reg                      : string;
  attribute async_reg of dst_toggl_cdc     : signal is "TRUE";
  attribute shreg_extract                  : string;
  attribute shreg_extract of dst_toggl_cdc : signal is "NO";
  attribute dont_touch                     : string;
  attribute dont_touch of src_toggl        : signal is "TRUE";

begin

  -- ---------------------------------------------------------------------------
  gen_src : if G_USE_FEEDBACK generate

    signal src_toggl_fdbk_cdc : std_ulogic_vector(SYNC_LEN - 1 downto 0) := (others => '0');
    signal src_toggl_fdbk_ff  : std_ulogic := '0';
    signal src_locked         : std_ulogic := '0';

    -- ---------------------------------------------------------------------------
    attribute async_reg of src_toggl_fdbk_cdc     : signal is "TRUE";
    attribute shreg_extract of src_toggl_fdbk_cdc : signal is "NO";

  begin

    -- Create a toggle when src pulse is detected
    prc_src : process (src_clk) is begin
      if rising_edge(src_clk) then
        src_toggl_fdbk_cdc <= src_toggl_fdbk_cdc(SYNC_LEN - 2 downto 0) & dst_toggl_cdc(SYNC_LEN - 1);
        src_toggl_fdbk_ff  <= src_toggl_fdbk_cdc(SYNC_LEN - 1);

        if src_toggl_fdbk_cdc(SYNC_LEN - 1) xor src_toggl_fdbk_ff then
          src_locked <= '0';
        end if;

        if src_pulse and not src_locked then
          src_toggl  <= not src_toggl;
          src_locked <= '1';
        end if;

      end if;
    end process;

  else generate begin

    -- Create a toggle when src pulse is detected
    prc_src : process (src_clk) is begin
      if rising_edge(src_clk) then
        if src_pulse then
          src_toggl <= not src_toggl;
        end if;
      end if;
    end process;

  end generate;

  -- CDC regs for destination toggle
  prc_dst : process (dst_clk) is begin
    if rising_edge(dst_clk) then
      dst_toggl_cdc <= dst_toggl_cdc(SYNC_LEN - 2 downto 0) & src_toggl;
      dst_toggl_ff  <= dst_toggl_cdc(SYNC_LEN - 1);
    end if;
  end process;

  -- Translate toggle to pulse
  dst_pulse <= dst_toggl_cdc(SYNC_LEN - 1) xor dst_toggl_ff;

end architecture;
