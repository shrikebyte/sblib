--##############################################################################
--# File : axil_arbiter.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite N:1 arbiter
--# Lowest master index has the highest priority. No round robin arbitration.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_arbiter is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view (s_axil_view) of bus_axil_arr_t;
    m_axil : view  m_axil_view
  );
end entity;

architecture rtl of axil_arbiter is

  type   wr_state_t is (ST_WR_IDLE, ST_WR_WRITING);
  signal wr_state  : wr_state_t;
  signal wr_select : natural range s_axil'range;

  type   rd_state_t is (ST_RD_IDLE, ST_RD_READING);
  signal rd_state  : rd_state_t;
  signal rd_select : natural range s_axil'range;

begin

  -- ---------------------------------------------------------------------------
  prc_wr_select : process (clk) is begin
    if rising_edge(clk) then

      case wr_state is
        when ST_WR_IDLE =>
          for i in s_axil'range loop
            if s_axil(i).awvalid then
              wr_select <= i;
              wr_state  <= ST_WR_WRITING;
            end if;
          end loop;

        when ST_WR_WRITING =>
          if m_axil.bvalid and m_axil.bready then
            wr_state <= ST_WR_IDLE;
          end if;
        when others =>
          null;
      end case;

      if srst then
        wr_select <= 0;
        wr_state  <= ST_WR_IDLE;
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
              rd_select <= i;
              rd_state  <= ST_RD_READING;
            end if;
          end loop;

        when ST_RD_READING =>
          if m_axil.rvalid and m_axil.rready then
            rd_state <= ST_RD_IDLE;
          end if;
        when others =>
          null;
      end case;

      if srst then
        rd_select <= 0;
        rd_state  <= ST_RD_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_req : process (all) is begin
    if wr_state = ST_WR_WRITING then
      m_axil.awvalid <= s_axil(wr_select).awvalid;
      m_axil.awaddr  <= s_axil(wr_select).awaddr;
      m_axil.wvalid  <= s_axil(wr_select).wvalid;
      m_axil.wdata   <= s_axil(wr_select).wdata;
      m_axil.wstrb   <= s_axil(wr_select).wstrb;
      m_axil.bready  <= s_axil(wr_select).bready;
    else
      m_axil.awvalid <= '0';
      m_axil.awaddr  <= (others=> '-');
      m_axil.wvalid  <= '0';
      m_axil.wdata   <= (others=> '-');
      m_axil.wstrb   <= (others=> '-');
      m_axil.bready  <= '0';
    end if;

    if rd_state = ST_RD_READING then
      m_axil.arvalid <= s_axil(rd_select).arvalid;
      m_axil.araddr  <= s_axil(rd_select).araddr;
      m_axil.rready  <= s_axil(rd_select).rready;
    else
      m_axil.arvalid <= '0';
      m_axil.araddr  <= (others=> '-');
      m_axil.rready  <= '0';
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  gen_assign_rsp : for i in s_axil'range generate
    signal writing : std_ulogic_vector(s_axil'range);
    signal reading : std_ulogic_vector(s_axil'range);
  begin
    writing(i) <= to_sl(wr_select = i and wr_state = ST_WR_WRITING);
    reading(i) <= to_sl(rd_select = i and rd_state = ST_RD_READING);
    --
    s_axil(i).awready <= m_axil.awready and writing(i);
    s_axil(i).wready  <= m_axil.wready and writing(i);
    s_axil(i).bvalid  <= m_axil.bvalid and writing(i);
    s_axil(i).bresp   <= m_axil.bresp;
    s_axil(i).arready <= m_axil.arready and reading(i);
    s_axil(i).rvalid  <= m_axil.rvalid and reading(i);
    s_axil(i).rresp   <= m_axil.rresp;
    s_axil(i).rdata   <= m_axil.rdata;
  end generate;

end architecture;
