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

entity axil_arbiter is
  generic (
    G_NUM_MASTERS : positive
  );
  port (
    clk        : in    std_logic;
    srst       : in    std_logic;
    s_axil_req : in    axil_req_arr_t(0 to G_NUM_MASTERS - 1);
    s_axil_rsp : out   axil_rsp_arr_t(0 to G_NUM_MASTERS - 1);
    m_axil_req : out   axil_req_t;
    m_axil_rsp : in    axil_rsp_t
  );
end entity;

architecture rtl of axil_arbiter is

  type   wr_state_t is (ST_WR_IDLE, ST_WR_WRITING);
  signal wr_state  : wr_state_t;
  signal wr_select : natural range 0 to G_NUM_MASTERS - 1;

  type   rd_state_t is (ST_RD_IDLE, ST_RD_READING);
  signal rd_state  : rd_state_t;
  signal rd_select : natural range 0 to G_NUM_MASTERS - 1;

begin

  -- ---------------------------------------------------------------------------
  prc_wr_select : process (clk) is begin
    if rising_edge(clk) then

      case wr_state is
        when ST_WR_IDLE =>
          for i in 0 to G_NUM_MASTERS - 1 loop
            if s_axil_req(i).awvalid then
              wr_select <= i;
              wr_state  <= ST_WR_WRITING;
            end if;
          end loop;

        when ST_WR_WRITING =>
          if m_axil_rsp.bvalid and m_axil_req.bready then
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
          for i in 0 to G_NUM_MASTERS - 1 loop
            if s_axil_req(i).arvalid then
              rd_select <= i;
              rd_state  <= ST_RD_READING;
            end if;
          end loop;

        when ST_RD_READING =>
          if m_axil_rsp.rvalid and m_axil_req.rready then
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
  prc_assign_wr_req : process (all) is begin
    if wr_state = ST_WR_WRITING then
      m_axil_req.awvalid <= s_axil_req(wr_select).awvalid;
      m_axil_req.awprot  <= s_axil_req(wr_select).awprot;
      m_axil_req.awaddr  <= s_axil_req(wr_select).awaddr;
      m_axil_req.wvalid  <= s_axil_req(wr_select).wvalid;
      m_axil_req.wdata   <= s_axil_req(wr_select).wdata;
      m_axil_req.wstrb   <= s_axil_req(wr_select).wstrb;
      m_axil_req.bready  <= s_axil_req(wr_select).bready;
    else
      m_axil_req.awvalid <= '0';
      m_axil_req.awprot  <= (others=> '-');
      m_axil_req.awaddr  <= (others=> '-');
      m_axil_req.wvalid  <= '0';
      m_axil_req.wdata   <= (others=> '-');
      m_axil_req.wstrb   <= (others=> '-');
      m_axil_req.bready  <= '0';
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_rd_req : process (all) is begin
    if rd_state = ST_RD_READING then
      m_axil_req.arvalid <= s_axil_req(rd_select).arvalid;
      m_axil_req.arprot  <= s_axil_req(rd_select).arprot;
      m_axil_req.araddr  <= s_axil_req(rd_select).araddr;
      m_axil_req.rready  <= s_axil_req(rd_select).rready;
    else
      m_axil_req.arvalid <= '0';
      m_axil_req.arprot  <= (others=> '-');
      m_axil_req.araddr  <= (others=> '-');
      m_axil_req.rready  <= '0';
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_rsp : process (all) is begin
    for master in 0 to G_NUM_MASTERS - 1 loop

      s_axil_rsp(master) <= m_axil_rsp;

      if wr_select /= master or wr_state /= ST_WR_WRITING then
        s_axil_rsp(master).awready <= '0';
        s_axil_rsp(master).wready  <= '0';
        s_axil_rsp(master).bvalid  <= '0';
      end if;

      if rd_select /= master or rd_state /= ST_RD_READING then
        s_axil_rsp(master).arready <= '0';
        s_axil_rsp(master).rvalid  <= '0';
      end if;

    end loop;
  end process;

end architecture;
