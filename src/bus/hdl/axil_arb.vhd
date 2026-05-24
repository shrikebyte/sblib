--##############################################################################
--# File : axil_arb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite N:1 fixed-priority arbiter
--# Highest index has the highest priority.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_arb is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view (s_axil_view) of bus_axil_arr_t;
    m_axil : view  m_axil_view
  );
end entity;

architecture rtl of axil_arb is

  type   wr_state_t is (ST_WR_IDLE, ST_WR_W, ST_WR_B);
  signal wr_state : wr_state_t;
  signal wr_sel   : natural range s_axil'range;

  type   rd_state_t is (ST_RD_IDLE, ST_RD_AR, ST_RD_R);
  signal rd_state : rd_state_t;
  signal rd_sel   : natural range s_axil'range;

  signal aw_en : std_ulogic;
  signal w_en  : std_ulogic;
  signal b_en  : std_ulogic;
  signal ar_en : std_ulogic;
  signal r_en  : std_ulogic;

begin

  -- ---------------------------------------------------------------------------
  prc_wr_select : process (clk) is begin
    if rising_edge(clk) then
      case wr_state is
        when ST_WR_IDLE =>
          for i in s_axil'range loop
            if s_axil(i).awvalid then
              wr_sel   <= i;
              aw_en    <= '1';
              w_en     <= '1';
              wr_state <= ST_WR_W;
            end if;
          end loop;

        when ST_WR_W =>
          if m_axil.awvalid and m_axil.awready then
            aw_en <= '0';
          end if;

          if m_axil.wvalid and m_axil.wready then
            w_en <= '0';
          end if;

          if not aw_en and not w_en then
            b_en     <= '1';
            wr_state <= ST_WR_B;
          end if;

        when ST_WR_B =>
          if m_axil.bvalid and m_axil.bready then
            b_en     <= '0';
            wr_state <= ST_WR_IDLE;
          end if;

      end case;

      if srst then
        wr_sel   <= s_axil'low;
        aw_en    <= '0';
        w_en     <= '0';
        b_en     <= '0';
        wr_state <= ST_WR_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_rd_select : process (clk) is begin
    if rising_edge(clk) then
      case rd_state is
        when ST_RD_IDLE =>
          for i in s_axil'range loop
            if s_axil(i).arvalid then
              rd_sel   <= i;
              ar_en    <= '1';
              r_en     <= '0';
              rd_state <= ST_RD_AR;
            end if;
          end loop;

        when ST_RD_AR =>
          if m_axil.arvalid and m_axil.arready then
            ar_en    <= '0';
            r_en     <= '1';
            rd_state <= ST_RD_R;
          end if;

        when ST_RD_R =>
          if m_axil.rvalid and m_axil.rready then
            ar_en    <= '0';
            r_en     <= '0';
            rd_state <= ST_RD_IDLE;
          end if;

      end case;

      if srst then
        rd_sel   <= s_axil'low;
        ar_en    <= '0';
        r_en     <= '0';
        rd_state <= ST_RD_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  m_axil.awvalid <= s_axil(wr_sel).awvalid and aw_en;
  m_axil.awaddr  <= s_axil(wr_sel).awaddr;
  m_axil.wvalid  <= s_axil(wr_sel).wvalid and w_en;
  m_axil.wdata   <= s_axil(wr_sel).wdata;
  m_axil.wstrb   <= s_axil(wr_sel).wstrb;
  m_axil.bready  <= s_axil(wr_sel).bready and b_en;
  m_axil.arvalid <= s_axil(rd_sel).arvalid and ar_en;
  m_axil.araddr  <= s_axil(rd_sel).araddr;
  m_axil.rready  <= s_axil(rd_sel).rready and r_en;

  -- ---------------------------------------------------------------------------
  gen_assign : for i in s_axil'range generate
    s_axil(i).awready <= m_axil.awready and aw_en and to_sl(i = wr_sel);
    s_axil(i).wready  <= m_axil.wready and w_en and to_sl(i = wr_sel);
    s_axil(i).bvalid  <= m_axil.bvalid and b_en and to_sl(i = wr_sel);
    s_axil(i).bresp   <= m_axil.bresp;
    s_axil(i).arready <= m_axil.arready and ar_en and to_sl(i = rd_sel);
    s_axil(i).rvalid  <= m_axil.rvalid and r_en and to_sl(i = rd_sel);
    s_axil(i).rresp   <= m_axil.rresp;
    s_axil(i).rdata   <= m_axil.rdata;
  end generate;

end architecture;
