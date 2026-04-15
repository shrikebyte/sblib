--##############################################################################
--# File : wb_to_axil.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Wishbone B4 (Synchronous, non-pipelined) to AXI-Lite bridge.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity wb_to_axil is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_wb   : view  s_wb_view;
    m_axil : view  m_axil_view
  );
end entity;

architecture rtl of wb_to_axil is

  type state_t is (
    ST_IDLE, ST_WRITE_WAIT, ST_WRITE_RSP_WAIT, ST_READ_WAIT, ST_READ_RSP_WAIT
  );

  signal state : state_t;

begin

  prc_wb_to_axil : process (clk) is begin
    if rising_edge(clk) then
      -- Pulse
      s_wb.ack <= '0';
      s_wb.err <= '0';

      case state is

        -- ---------------------------------------------------------------------
        when ST_IDLE =>
          if s_wb.stb then
            if s_wb.wen then
              m_axil.awvalid <= '1';
              m_axil.awaddr  <= s_wb.addr;
              m_axil.wvalid  <= '1';
              m_axil.wdata   <= s_wb.wdat;
              m_axil.wstrb   <= s_wb.wsel;
              m_axil.bready  <= '0';
              state          <= ST_WRITE_WAIT;
            else
              m_axil.arvalid <= '1';
              m_axil.araddr  <= s_wb.addr;
              m_axil.rready  <= '0';
              state          <= ST_READ_WAIT;
            end if;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_WAIT =>
          if m_axil.awready and m_axil.wready then
            m_axil.awvalid <= '0';
            m_axil.wvalid  <= '0';
            m_axil.bready  <= '1';
            state          <= ST_WRITE_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_RSP_WAIT =>
          if m_axil.bvalid then
            m_axil.bready <= '0';
            s_wb.ack      <= '1';
            s_wb.err      <= to_sl(m_axil.bresp = AXI_RSP_SLVERR or
                m_axil.bresp = AXI_RSP_DECERR);
            state         <= ST_IDLE;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_WAIT =>
          if m_axil.arready then
            m_axil.arvalid <= '0';
            m_axil.rready  <= '1';
            state          <= ST_READ_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_RSP_WAIT =>
          if m_axil.rvalid then
            m_axil.rready <= '0';
            s_wb.ack      <= '1';
            s_wb.err      <= to_sl(m_axil.bresp = AXI_RSP_SLVERR or
                m_axil.bresp = AXI_RSP_DECERR);
            s_wb.rdat     <= m_axil.rdata;
            state         <= ST_IDLE;
          end if;

        when others =>
          null;
      end case;

      if srst then
        s_wb.ack       <= '0';
        s_wb.err       <= '0';
        m_axil.awvalid <= '0';
        m_axil.wvalid  <= '0';
        m_axil.bready  <= '0';
        m_axil.arvalid <= '0';
        m_axil.rready  <= '0';
        state          <= ST_IDLE;
      end if;

    end if;
  end process;

end architecture;
