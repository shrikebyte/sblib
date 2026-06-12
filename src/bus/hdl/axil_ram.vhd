--##############################################################################
--# File     : axil_ram.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite RAM
--# Supports maximum thruput one read and one write per clock cycle.
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
    G_ADDR_WIDTH : positive                                                 := 10;
    G_RAM_STYLE  : string                                                   := "auto";
    G_RAM_INIT   : slv_arr_t(0 to (2 ** G_ADDR_WIDTH) - 1)(AXIL_DATA_RANGE) := (others=> (others=> '0'));
    G_RD_LATENCY : positive                                                 := 1
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view  s_axil_view
  );
end entity;

architecture rtl of axil_ram is

  signal reg : bus_reg_t;

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
    m_reg  => reg
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
    a_wen  => reg.wen and reg.wstrb,
    a_addr => reg.waddr(G_ADDR_WIDTH - 1 + 2 downto 2),
    a_wdat => reg.wdata,
    a_rdat => open,
    b_clk  => clk,
    b_wen  => (others=> '0'),
    b_addr => reg.raddr(G_ADDR_WIDTH - 1 + 2 downto 2),
    b_wdat => (others=> '0'),
    b_rdat => reg.rdata
  );

  reg.werr <= '0';
  reg.rerr <= '0';

end architecture;
