--##############################################################################
--# File     : axil_ram.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI lite ram.
--# Supports full thruput one read and one write per clock cycle.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_ram is
  generic (
    -- Address width of the RAM. RAM uses word addressing and AXIL uses byte
    -- addressing. So the AXIL address is left-shifted by 2 by this module
    -- before being connected to the ram. This also means that the number of
    -- AXIL address bits used is equal to G_ADDR_WIDTH + 2.
    G_ADDR_WIDTH : positive                                                              := 10;
    G_RAM_STYLE  : string                                                                := "auto";
    G_RAM_INIT   : slv_arr_t(0 to (2 ** G_ADDR_WIDTH) - 1)(AXIL_DATA_WIDTH - 1 downto 0) := (others=> (others=> '0'));
    G_RD_LATENCY : positive                                                              := 1
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view  s_axil_view
  );
end entity;

architecture rtl of axil_ram is

  signal i0_reg : bus_reg_t;

begin

  u_axil_to_reg : entity work.axil_to_reg
  generic map (
    G_WR_LATENCY => 1,
    G_RD_LATENCY => G_RD_LATENCY
  )
  port map (
    clk    => clk,
    srst   => srst,
    s_axil => s_axil,
    m_reg  => i0_reg
  );

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
    a_clk  => clk,
    a_en   => i0_reg.wen,
    a_wen  => i0_reg.wstrb,
    a_addr => i0_reg.waddr(G_ADDR_WIDTH - 1 + 2 downto 2),
    a_wdat => i0_reg.wdata,
    a_rdat => open,
    b_clk  => clk,
    b_en   => '1',
    b_wen  => (others=> '0'),
    b_addr => i0_reg.raddr(G_ADDR_WIDTH - 1 + 2 downto 2),
    b_wdat => (others=> '0'),
    b_rdat => i0_reg.rdata
  );

  i0_reg.werr <= '0';
  i0_reg.rerr <= '0';

end architecture;
