--##############################################################################
--# File     : wb_ram_shared.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Wishbone Shared RAM
--# One port is connected via wishbone and the other is exposed as a native port
--# to FPGA fabric. This facilitates an easy method for software and hardware
--# share a memory block.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity wb_ram_shared is
  generic (
    -- Address width of the RAM. RAM uses word addressing and AXIL uses byte
    -- addressing. So the AXIL address is right-shifted by 2 by this module
    -- before being connected to the ram. This also means that the number of
    -- AXIL address bits used is equal to G_ADDR_WIDTH + 2.
    -- For consistency, the RAM address is also treated the same way as the
    -- AXIL address. Both are byte addresses aligned to increments of 4
    -- bytes. The bottom two bits of both axil address and ram address are
    -- ignored.
    G_ADDR_WIDTH : positive                                                              := 10;
    G_RAM_STYLE  : string                                                                := "auto";
    G_RAM_INIT   : slv_arr_t(0 to (2 ** G_ADDR_WIDTH) - 1)(AXIL_DATA_RANGE) := (others=> (others=> '0'));
    G_RD_LATENCY : positive                                                              := 1
  );
  port (
    wb_clk  : in    std_ulogic;
    wb_srst : in    std_ulogic;
    s_wb    : view  s_wb_view;
    --
    ram_clk  : in    std_ulogic;
    ram_wen  : in    std_ulogic_vector(AXIL_STRB_RANGE)               := (others=> '0');
    ram_addr : in    std_ulogic_vector(G_ADDR_WIDTH + 2 - 1 downto 0) := (others=> '0');
    ram_wdat : in    std_ulogic_vector(AXIL_DATA_RANGE)               := (others=> '0');
    ram_rdat : out   std_ulogic_vector(AXIL_DATA_RANGE)
  );
end entity;

architecture rtl of wb_ram_shared is

  signal wb_stb_re : std_ulogic;

begin

  -- ---------------------------------------------------------------------------
  u_edge_detect : entity work.edge_detect
  generic map (
    G_WIDTH   => 1,
    G_RST_VAL => "0"
  )
  port map (
    clk     => wb_clk,
    srst    => wb_srst,
    din(0)  => s_wb.stb and not s_wb.ack,
    rise(0) => wb_stb_re
  );

  gen_rd_latency_one : if G_RD_LATENCY = 1 generate begin

    -- Response happens on the next cycle for both reads and writes
    prc_rsp : process (wb_clk) is begin
      if rising_edge(wb_clk) then
        s_wb.ack <= wb_stb_re;

        if wb_srst then
          s_wb.ack <= '0';
        end if;
      end if;
    end process;

  else generate

    signal wb_rd_pulse : std_ulogic;
    signal wb_wr_pulse : std_ulogic;

  begin

    -- Subtract two cycles from the read latency here:
    --   One for the extra output register needed for a reset value
    --   One for the wb.ack register.
    u_shift_reg : entity work.shift_reg
    generic map (
      G_WIDTH   => 1,
      G_DEPTH   => G_RD_LATENCY - 2,
      G_RST_VAL => "0",
      G_OUT_REG => true
    )
    port map (
      clk  => wb_clk,
      srst => wb_srst,
      en   => '1',
      d(0) => wb_stb_re and not s_wb.wen,
      q(0) => wb_rd_pulse
    );

    wb_wr_pulse <= wb_stb_re and s_wb.wen;

    prc_rsp : process (wb_clk) is begin
      if rising_edge(wb_clk) then
        s_wb.ack <= wb_rd_pulse or wb_wr_pulse;

        if wb_srst then
          s_wb.ack <= '0';
        end if;
      end if;
    end process;

  end generate;

  s_wb.err <= '0';

  -- ---------------------------------------------------------------------------
  u_ram : entity work.ram
  generic map (
    G_BYTES_PER_ROW => 4,
    G_BYTE_WIDTH    => 8,
    G_ADDR_WIDTH    => G_ADDR_WIDTH,
    G_RAM_STYLE     => G_RAM_STYLE,
    G_RAM_INIT      => G_RAM_INIT,
    G_RD_LATENCY    => G_RD_LATENCY
  )
  port map (
    a_clk  => wb_clk,
    a_wen  => (wb_stb_re and s_wb.wen) and s_wb.wsel,
    a_addr => s_wb.addr(G_ADDR_WIDTH - 1 + 2 downto 2),
    a_wdat => s_wb.wdat,
    a_rdat => s_wb.rdat,
    b_clk  => ram_clk,
    b_wen  => ram_wen,
    b_addr => ram_addr(G_ADDR_WIDTH - 1 + 2 downto 2),
    b_wdat => ram_wdat,
    b_rdat => ram_rdat
  );

end architecture;
