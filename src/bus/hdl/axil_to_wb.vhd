--##############################################################################
--# File : axil_to_wb.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite to Wishbone B4 (Synchronous, non-pipelined) bridge. At best, this
--# bridge can issue one read or one write request every four clock cycles.
--# This best-case thruput assumes that the the Wishbone slave responds in one
--# clock cycle, that the AXI Lite master read / write response channels are
--# always ready, and that write transaction address and data arrive at the same
--# time. If these factors are not met, then the thruput will be even lower.
--# C0: AXIL request
--# C1: Wishbone request
--# C2: Wishbone response
--# C3: AXIL response
--# This module has not been designed for maximum thruput, but rather for
--# simplicity. Most of the time, simple register access does not require high
--# thruput so any extra resources required to make this module better would
--# be wasted.
--# Writes are prioritized over reads, therefore, if the axi lite interface
--# issues back-to-back writes and a read at the same time, the read will not
--# get executed until the write requests stop.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.util_pkg.all;

entity axil_to_wb is
  port (
    clk        : in    std_logic;
    srst       : in    std_logic;
    s_axil_req : in    axil_req_t;
    s_axil_rsp : out   axil_rsp_t;
    m_wb_req   : out   wb_req_t;
    m_wb_rsp   : in    wb_rsp_t
  );
end entity;

architecture rtl of axil_to_wb is

  type state_t is (
    ST_IDLE, ST_WAIT_WB_WRITE_RESP, ST_WRITE_RESP_CMPLT, ST_WAIT_WB_READ_RESP,
    ST_READ_RESP_CMPLT
  );

  signal state : state_t;

begin

  -- ---------------------------------------------------------------------------
  prc_axil_to_wb : process (clk) is begin
    if rising_edge(clk) then
      case state is
        -- ---------------------------------------------------------------------
        when ST_IDLE =>
          -- Idle defaults
          m_wb_req.stb       <= '0';
          s_axil_rsp.awready <= '0';
          s_axil_rsp.wready  <= '0';
          s_axil_rsp.bvalid  <= '0';
          s_axil_rsp.arready <= '0';
          s_axil_rsp.rvalid  <= '0';

          -- Forward the AXIL wr request to Wishbone and complete the AXIL
          -- wr request
          if s_axil_req.awvalid and s_axil_req.wvalid then
            m_wb_req.stb       <= '1';
            m_wb_req.wen       <= '1';
            m_wb_req.addr      <= s_axil_req.awaddr;
            m_wb_req.wdat      <= s_axil_req.wdata;
            m_wb_req.wsel      <= s_axil_req.wstrb;
            s_axil_rsp.awready <= '1';
            s_axil_rsp.wready  <= '1';
            state              <= ST_WAIT_WB_WRITE_RESP;

          -- Forward the AXIL rd request to Wishbone and complete the AXIL
          -- rd request
          elsif s_axil_req.arvalid then
            m_wb_req.stb       <= '1';
            m_wb_req.wen       <= '0';
            m_wb_req.addr      <= s_axil_req.araddr;
            s_axil_rsp.arready <= '1';
            state              <= ST_WAIT_WB_READ_RESP;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WAIT_WB_WRITE_RESP =>
          s_axil_rsp.awready <= '0';
          s_axil_rsp.wready  <= '0';

          -- Wait for the Wishbone response then initiate the AXIL wr response
          if m_wb_rsp.err then
            m_wb_req.stb      <= '0';
            s_axil_rsp.bvalid <= '1';
            s_axil_rsp.bresp  <= AXI_RSP_SLVERR;
            state             <= ST_WRITE_RESP_CMPLT;
          elsif m_wb_rsp.ack then
            m_wb_req.stb      <= '0';
            s_axil_rsp.bvalid <= '1';
            s_axil_rsp.bresp  <= AXI_RSP_OKAY;
            state             <= ST_WRITE_RESP_CMPLT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_RESP_CMPLT =>
          -- Wait for the master to complete the AXIL wr response
          if s_axil_req.bready then
            s_axil_rsp.bvalid <= '0';
            state             <= ST_IDLE;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WAIT_WB_READ_RESP =>
          s_axil_rsp.arready <= '0';

          -- Wait for the Wishbone response then initiate the AXIL rd response
          if m_wb_rsp.err then
            m_wb_req.stb      <= '0';
            s_axil_rsp.rdata  <= m_wb_rsp.rdat;
            s_axil_rsp.rvalid <= '1';
            s_axil_rsp.rresp  <= AXI_RSP_SLVERR;
            state             <= ST_READ_RESP_CMPLT;
          elsif m_wb_rsp.ack then
            m_wb_req.stb      <= '0';
            s_axil_rsp.rdata  <= m_wb_rsp.rdat;
            s_axil_rsp.rvalid <= '1';
            s_axil_rsp.rresp  <= AXI_RSP_OKAY;
            state             <= ST_READ_RESP_CMPLT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_RESP_CMPLT =>
          -- Wait for the master to complete the AXIL rd response
          if s_axil_req.rready then
            s_axil_rsp.rvalid <= '0';
            state             <= ST_IDLE;
          end if;

        when others =>
          null;
      end case;

      if srst then
        s_axil_rsp.awready <= '0';
        s_axil_rsp.wready  <= '0';
        s_axil_rsp.bvalid  <= '0';
        s_axil_rsp.arready <= '0';
        s_axil_rsp.rvalid  <= '0';
        m_wb_req.stb       <= '0';
        state              <= ST_IDLE;
      end if;

    end if;
  end process;

end architecture;
