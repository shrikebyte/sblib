--##############################################################################
--# File     : axil_ram_shared.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXIL Shared RAM
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_ram_shared is
  generic (
    G_ADDR_WIDTH : positive                                                              := 10;
    G_RAM_STYLE  : string                                                                := "auto";
    G_RAM_INIT   : slv_arr_t(0 to (2 ** G_ADDR_WIDTH) - 1)(AXIL_DATA_RANGE) := (others=> (others=> '0'));
    G_RD_LATENCY : positive                                                              := 1
  );
  port (
    axil_clk  : in    std_ulogic;
    axil_srst : in    std_ulogic;
    s_axil    : view  s_axil_view;
    --
    ram_clk  : in    std_ulogic;
    ram_wen  : in    std_ulogic_vector(AXIL_STRB_RANGE)               := (others=> '0');
    ram_addr : in    std_ulogic_vector(G_ADDR_WIDTH + 2 - 1 downto 0) := (others=> '0');
    ram_wdat : in    std_ulogic_vector(AXIL_DATA_RANGE)               := (others=> '0');
    ram_rdat : out   std_ulogic_vector(AXIL_DATA_RANGE)
  );
end entity;

architecture rtl of axil_ram_shared is

  signal wb : bus_wb_t;

begin

  u_axil_to_wb : entity work.axil_to_wb
  port map (
    clk    => axil_clk,
    srst   => axil_srst,
    s_axil => s_axil,
    m_wb   => wb
  );

  u_wb_ram_shared : entity work.wb_ram_shared
  generic map (
    G_ADDR_WIDTH => G_ADDR_WIDTH,
    G_RAM_STYLE  => G_RAM_STYLE,
    G_RAM_INIT   => G_RAM_INIT,
    G_RD_LATENCY => G_RD_LATENCY
  )
  port map (
    wb_clk   => axil_clk,
    wb_srst  => axil_srst,
    s_wb     => wb,
    ram_clk  => ram_clk,
    ram_wen  => ram_wen,
    ram_addr => ram_addr,
    ram_wdat => ram_wdat,
    ram_rdat => ram_rdat
  );

end architecture;
