--##############################################################################
--# File : axil_xbar.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite crossbar.
--# Designed for simplicity and low area. Only supports one
--# transaction at a time.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;

entity axil_xbar is
  generic (
    G_NUM_MASTERS : positive;
    G_NUM_SLAVES  : positive;
    G_BASEADDRS   : slv_arr_t(0 to G_NUM_SLAVES - 1)(AXIL_ADDR_WIDTH - 1 downto 0)
  );
  port (
    clk        : in    std_logic;
    srst       : in    std_logic;
    s_axil_req : in    axil_req_arr_t;
    s_axil_rsp : out   axil_rsp_arr_t;
    m_axil_req : out   axil_req_arr_t;
    m_axil_rsp : in    axil_rsp_arr_t
  );
end entity;

architecture rtl of axil_xbar is

  signal axil_req : axil_req_t;
  signal axil_rsp : axil_rsp_t;

begin

  -- ---------------------------------------------------------------------------
  u_axil_arbiter : entity work.axil_arbiter
  generic map (
    G_NUM_MASTERS => G_NUM_MASTERS
  )
  port map (
    clk        => clk,
    srst       => srst,
    s_axil_req => s_axil_req,
    s_axil_rsp => s_axil_rsp,
    m_axil_req => axil_req,
    m_axil_rsp => axil_rsp
  );

  -- ---------------------------------------------------------------------------
  u_axil_decoder : entity work.axil_decoder
  generic map (
    G_NUM_SLAVES => G_NUM_SLAVES,
    G_BASEADDRS  => G_BASEADDRS
  )
  port map (
    clk        => clk,
    srst       => srst,
    s_axil_req => axil_req,
    s_axil_rsp => axil_rsp,
    m_axil_req => m_axil_req,
    m_axil_rsp => m_axil_rsp
  );

end architecture;
