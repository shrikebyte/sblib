--##############################################################################
--# File : axil_init_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI-Lite initialization manager state machine.
--# This runs a hard-coded sequence of read and write transactions after reset.
--# Intended to configure an FPGA at startup / reset without the need for
--# software init scripts or a soft-processor. This can also be used to run a
--# BIST at startup by checking register values to ensure they match expected.
--##############################################################################

-- TODO: Change this to explicitly use BRAM for transaction ROM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_init_mgr is
  generic (
    G_RESET_DELAY_CLKS : positive := 10;
    G_XACTIONS         : bus_xact_arr_t
  );
  port (
    clk    : in    std_logic;
    srst   : in    std_logic;
    m_axil : view  m_axil_view;
    --
    -- Valid data qualifier for the remaining m_sts_* signals
    m_sts_valid : out   std_logic;
    -- Indicates that the transaction had a bus error
    m_sts_bus_err : out   std_logic;
    -- Indicates that the transaction's read data did not match the expected data
    m_sts_chk_err : out   std_logic;
    -- Read data for the transaction (if it was a read)
    m_sts_chk_rdata : out   std_logic_vector(31 downto 0);
    -- Transaction index. Starts at 0 and counts up
    m_sts_xact_idx : out   unsigned(15 downto 0)
  );
end entity;

architecture rtl of axil_init_mgr is

  constant NUM_XACTIONS : integer := G_XACTIONS'length;

  type state_t is (
    ST_RESET, ST_START, ST_DONE, ST_WRITE_WAIT, ST_WRITE_RSP_WAIT,
    ST_READ_WAIT, ST_READ_RSP_WAIT
  );

  signal state : state_t;

  signal reset_cnt : integer range 0 to G_RESET_DELAY_CLKS - 1;
  signal idx       : integer range 0 to NUM_XACTIONS;

begin

  -- ---------------------------------------------------------------------------
  prc_axil_init_mgr : process (clk) is begin
    if rising_edge(clk) then
      -- Pulse
      m_sts_valid <= '0';

      case state is
        -- ---------------------------------------------------------------------
        when ST_RESET =>
          if reset_cnt = G_RESET_DELAY_CLKS - 1 then
            state <= ST_START;
          else
            reset_cnt <= reset_cnt + 1;
          end if;

        -- ---------------------------------------------------------------------
        when ST_START =>
          if idx = NUM_XACTIONS then
            state <= ST_DONE;
          elsif G_XACTIONS(idx).cmd = BUS_WRITE then
            m_axil.awvalid <= '1';
            m_axil.awaddr  <= G_XACTIONS(idx).addr;
            m_axil.wvalid  <= '1';
            m_axil.wdata   <= G_XACTIONS(idx).data;
            m_axil.wstrb   <= G_XACTIONS(idx).wstrb;
            m_axil.bready  <= '0';
            --
            state <= ST_WRITE_WAIT;
          elsif G_XACTIONS(idx).cmd = BUS_CHECK then
            m_axil.arvalid <= '1';
            m_axil.araddr  <= G_XACTIONS(idx).addr;
            m_axil.rready  <= '0';
            --
            state <= ST_READ_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_WAIT =>
          if m_axil.awready and m_axil.wready then
            m_axil.awvalid <= '0';
            m_axil.wvalid  <= '0';
            m_axil.bready  <= '1';
            --
            state <= ST_WRITE_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_RSP_WAIT =>
          if m_axil.bvalid then
            m_axil.bready <= '0';
            --
            m_sts_valid    <= '1';
            m_sts_xact_idx <= to_unsigned(idx, m_sts_xact_idx'length);
            m_sts_chk_err  <= '0';
            if m_axil.bresp = AXI_RSP_SLVERR or
               m_axil.bresp = AXI_RSP_DECERR then
              m_sts_bus_err <= '1';
            else
              m_sts_bus_err <= '0';
            end if;
            --
            idx   <= idx + 1;
            state <= ST_START;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_WAIT =>
          if m_axil.arready then
            m_axil.arvalid <= '0';
            m_axil.rready  <= '1';
            --
            state <= ST_READ_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_RSP_WAIT =>
          if m_axil.rvalid then
            m_axil.rready <= '0';
            --
            m_sts_valid     <= '1';
            m_sts_xact_idx  <= to_unsigned(idx, m_sts_xact_idx'length);
            m_sts_chk_rdata <= m_axil.rdata;
            if m_axil.rresp = AXI_RSP_SLVERR or
               m_axil.rresp = AXI_RSP_DECERR then
              m_sts_bus_err <= '1';
              m_sts_chk_err <= '0';
            elsif (m_axil.rdata and G_XACTIONS(idx).mask) /=
                  (G_XACTIONS(idx).data and G_XACTIONS(idx).mask) then
              m_sts_bus_err <= '0';
              m_sts_chk_err <= '1';
            else
              m_sts_bus_err <= '0';
              m_sts_chk_err <= '0';
            end if;
            --
            idx   <= idx + 1;
            state <= ST_START;
          end if;

        when others =>
          null;
      end case;

      if srst then
        m_sts_valid <= '0';
        --
        m_axil.awvalid <= '0';
        m_axil.wvalid  <= '0';
        m_axil.bready  <= '0';
        m_axil.arvalid <= '0';
        m_axil.rready  <= '0';
        --
        reset_cnt <= 0;
        idx       <= 0;
        state     <= ST_RESET;
      end if;

    end if;
  end process;

end architecture;
