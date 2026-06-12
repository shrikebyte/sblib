--##############################################################################
--# File : axil_init_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI-Lite initialization manager.
--# This runs a hard-coded sequence of read and write transactions after reset.
--# Intended to configure an FPGA at startup / reset without the need for
--# software init scripts or a soft-processor. This can also be used to run a
--# BIST at startup by checking register values to ensure they match expected.
--#
--# --------+-------------------------------------------------------------------
--# Signal  | Description
--# --------+-------------------------------------------------------------------
--# m_axis    Status stream. Each AXIL read / write instruction results in one
--#           AXIS status stream beat, which indicates the status of the
--#           instruction. This interface is optional. If unused, tie tready
--#           high, otherwise all of the axil transactions will be stalled.
--# --------+-------------------------------------------------------------------
--# tdata   | Read data for read instructions; Written data for write instrs
--# tkeep   | All ones for read instrs; AXI write strobes used for write instrs
--# tlast   | Indicates last transaction of the hard-coded sequence
--# tuser(0)| 1 = Write instruction; 0 = Read instruction
--# tuser(1)| 1 = Slave bus error
--# tuser(2)| 1 = Decoder bus error
--# tuser(3)| 1 = Data check error for a read transaction
--# --------+-------------------------------------------------------------------
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity axil_init_mgr is
  generic (
    -- Number of cycles to wait after reset before running the transactions
    G_RESET_DELAY : positive := 100;
    -- Transaction ROM
    G_XACTIONS : bus_xact_arr_t
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    m_axil : view  m_axil_view;
    --
    m_axis : view m_axis_view of axis_t(
      tdata(AXIL_DATA_RANGE),
      tkeep(AXIL_STRB_RANGE),
      tuser(3 downto 0)
    )
  );
end entity;

architecture rtl of axil_init_mgr is

  constant NUM_XACTIONS : integer := G_XACTIONS'length;
  constant STS_WRITE    : integer := 0;
  constant STS_SLVERR   : integer := 1;
  constant STS_DECERR   : integer := 2;
  constant STS_CHKERR   : integer := 3;

  type state_t is (
    ST_RESET, ST_STS_WAIT, ST_START, ST_DONE, ST_WRITE_WAIT, ST_WRITE_RSP_WAIT,
    ST_READ_WAIT, ST_READ_RSP_WAIT
  );

  signal state     : state_t;
  signal xact      : bus_xact_t;
  signal reset_cnt : integer range 0 to G_RESET_DELAY - 1;
  signal idx       : integer range 0 to NUM_XACTIONS - 1;

begin

  m_axil.awaddr <= xact.addr;
  m_axil.wdata  <= xact.data;
  m_axil.wstrb  <= xact.wstrb;
  m_axil.araddr <= xact.addr;

  -- ---------------------------------------------------------------------------
  prc_axil_init_mgr : process (clk) is begin
    if rising_edge(clk) then
      -- Register the output of the transaction rom so the synthesizer has the
      -- option of mapping it to BRAM
      xact <= G_XACTIONS(idx);

      case state is
        -- ---------------------------------------------------------------------
        when ST_RESET =>
          if reset_cnt = (G_RESET_DELAY - 1) then
            state <= ST_START;
          else
            reset_cnt <= reset_cnt + 1;
          end if;

        -- ---------------------------------------------------------------------
        when ST_START =>
          if xact.cmd = BUS_WRITE then
            m_axil.awvalid <= '1';
            m_axil.wvalid  <= '1';
            m_axil.bready  <= '0';
            state          <= ST_WRITE_WAIT;
          elsif xact.cmd = BUS_CHECK then
            m_axil.arvalid <= '1';
            m_axil.rready  <= '0';
            state          <= ST_READ_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_WAIT =>
          if m_axil.awready then
            m_axil.awvalid <= '0';
          end if;

          if m_axil.wready then
            m_axil.wvalid <= '0';
          end if;

          if not m_axil.awvalid and not m_axil.wvalid then
            m_axil.bready <= '1';
            state         <= ST_WRITE_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_RSP_WAIT =>
          if m_axil.bvalid then
            m_axil.bready <= '0';
            --
            m_axis.tvalid            <= '1';
            m_axis.tdata             <= xact.data;
            m_axis.tkeep             <= xact.wstrb;
            m_axis.tuser(STS_WRITE ) <= '1';
            m_axis.tuser(STS_SLVERR) <= to_sl(m_axil.bresp = AXI_RSP_SLVERR);
            m_axis.tuser(STS_DECERR) <= to_sl(m_axil.bresp = AXI_RSP_DECERR);
            m_axis.tuser(STS_CHKERR) <= '0'; -- No data checking for writes
            --
            if idx = (NUM_XACTIONS - 1) then
              m_axis.tlast <= '1';
            else
              m_axis.tlast <= '0';
              idx          <= idx + 1;
            end if;
            state <= ST_STS_WAIT;
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
            m_axis.tvalid            <= '1';
            m_axis.tdata             <= m_axil.rdata;
            m_axis.tkeep             <= (others => '1');
            m_axis.tuser(STS_WRITE ) <= '0';
            m_axis.tuser(STS_SLVERR) <= to_sl(m_axil.rresp = AXI_RSP_SLVERR);
            m_axis.tuser(STS_DECERR) <= to_sl(m_axil.rresp = AXI_RSP_DECERR);
            m_axis.tuser(STS_CHKERR) <= or ((m_axil.rdata xor xact.data) and xact.mask);
            --
            if idx = (NUM_XACTIONS - 1) then
              m_axis.tlast <= '1';
            else
              m_axis.tlast <= '0';
              idx          <= idx + 1;
            end if;
            state <= ST_STS_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_STS_WAIT =>
          if m_axis.tready then
            m_axis.tvalid <= '0';
            if m_axis.tlast then
              state <= ST_DONE;
            else
              state <= ST_START;
            end if;
          end if;

        -- ---------------------------------------------------------------------
        when ST_DONE =>
          null;

        when others =>
          null;
      end case;

      if srst then
        m_axis.tvalid <= '0';
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
