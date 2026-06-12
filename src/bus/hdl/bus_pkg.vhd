--##############################################################################
--# File : bus_pkg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Bus package
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package bus_pkg is

  -- ---------------------------------------------------------------------------
  -- AXI Lite
  constant AXIL_DATA_WIDTH : positive := 32;
  constant AXIL_ADDR_WIDTH : positive := 32;
  constant AXIL_PROT_WIDTH : positive := 3;
  constant AXIL_RSP_WIDTH  : positive := 2;

  subtype axil_data_range is natural range AXIL_DATA_WIDTH - 1 downto 0;
  subtype axil_addr_range is natural range AXIL_ADDR_WIDTH - 1 downto 0;
  subtype axil_strb_range is natural range AXIL_DATA_WIDTH / 8 - 1 downto 0;
  subtype axil_prot_range is natural range AXIL_PROT_WIDTH - 1 downto 0;
  subtype axil_rsp_range is natural range AXIL_RSP_WIDTH - 1 downto 0;

  constant AXI_RSP_OKAY   : std_ulogic_vector(AXIL_RSP_RANGE) := b"00";
  constant AXI_RSP_EXOKAY : std_ulogic_vector(AXIL_RSP_RANGE) := b"01";
  constant AXI_RSP_SLVERR : std_ulogic_vector(AXIL_RSP_RANGE) := b"10";
  constant AXI_RSP_DECERR : std_ulogic_vector(AXIL_RSP_RANGE) := b"11";

  type bus_axil_t is record
    awvalid : std_ulogic;
    awready : std_ulogic;
    awaddr  : std_ulogic_vector(AXIL_ADDR_RANGE);
    wvalid  : std_ulogic;
    wready  : std_ulogic;
    wdata   : std_ulogic_vector(AXIL_DATA_RANGE);
    wstrb   : std_ulogic_vector(AXIL_STRB_RANGE);
    bvalid  : std_ulogic;
    bready  : std_ulogic;
    bresp   : std_ulogic_vector(AXIL_RSP_RANGE);
    arvalid : std_ulogic;
    arready : std_ulogic;
    araddr  : std_ulogic_vector(AXIL_ADDR_RANGE);
    rvalid  : std_ulogic;
    rready  : std_ulogic;
    rdata   : std_ulogic_vector(AXIL_DATA_RANGE);
    rresp   : std_ulogic_vector(AXIL_RSP_RANGE);
  end record;

  type bus_axil_arr_t is array(natural range <>) of bus_axil_t;

	view m_axil_view of bus_axil_t is
    awvalid : out;
    awready : in;
    awaddr  : out;
    wvalid  : out;
    wready  : in;
    wdata   : out;
    wstrb   : out;
    bvalid  : in;
    bready  : out;
    bresp   : in;
    arvalid : out;
    arready : in;
    araddr  : out;
    rvalid  : in;
    rready  : out;
    rdata   : in;
    rresp   : in;
  end view;

  alias s_axil_view is m_axil_view'converse;

  view p_axil_view of bus_axil_t is
    awvalid : in;
    awready : in;
    awaddr  : in;
    wvalid  : in;
    wready  : in;
    wdata   : in;
    wstrb   : in;
    bvalid  : in;
    bready  : in;
    bresp   : in;
    arvalid : in;
    arready : in;
    araddr  : in;
    rvalid  : in;
    rready  : in;
    rdata   : in;
    rresp   : in;
  end view;

  procedure axil_attach (
    signal s_axil : view s_axil_view of bus_axil_t;
    signal m_axil : view m_axil_view of bus_axil_t
  );

  -- ---------------------------------------------------------------------------
  -- Wishbone (Non-pipelined)
  type bus_wb_t is record
    stb  : std_ulogic;
    wen  : std_ulogic;
    addr : std_ulogic_vector(AXIL_ADDR_RANGE);
    wdat : std_ulogic_vector(AXIL_DATA_RANGE);
    wsel : std_ulogic_vector(AXIL_STRB_RANGE);
    ack  : std_ulogic;
    err  : std_ulogic;
    rdat : std_ulogic_vector(AXIL_DATA_RANGE);
  end record;

  type bus_wb_arr_t is array(natural range <>) of bus_wb_t;

	view m_wb_view of bus_wb_t is
  	stb  : out;
    wen  : out;
    addr : out;
    wdat : out;
    wsel : out;
    ack  : in;
    err  : in;
    rdat : in;
  end view;

  alias s_wb_view is m_wb_view'converse;

  view p_wb_view of bus_wb_t is
  	stb  : in;
    wen  : in;
    addr : in;
    wdat : in;
    wsel : in;
    ack  : in;
    err  : in;
    rdat : in;
  end view;

  procedure wb_attach (
    signal s_wb : view s_wb_view of bus_wb_t;
    signal m_wb : view m_wb_view of bus_wb_t
  );

  -- ---------------------------------------------------------------------------
  -- Advanced Peripheral Bus
  type bus_apb_t is record
    psel    : std_ulogic;
    penable : std_ulogic;
    pwrite  : std_ulogic;
    paddr   : std_ulogic_vector(AXIL_ADDR_RANGE);
    pwdata  : std_ulogic_vector(AXIL_DATA_RANGE);
    pstrb   : std_ulogic_vector(AXIL_STRB_RANGE);
    pready  : std_ulogic;
    pslverr : std_ulogic;
    prdata  : std_ulogic_vector(AXIL_DATA_RANGE);
  end record;

  type bus_apb_arr_t is array(natural range <>) of bus_apb_t;

  view m_apb_view of bus_apb_t is
    psel    : out;
    penable : out;
    pwrite  : out;
    paddr   : out;
    pwdata  : out;
    pstrb   : out;
    pready  : in;
    pslverr : in;
    prdata  : in;
  end view;

  alias s_apb_view is m_apb_view'converse;

  view p_apb_view of bus_apb_t is
    psel    : in;
    penable : in;
    pwrite  : in;
    paddr   : in;
    pwdata  : in;
    pstrb   : in;
    pready  : in;
    pslverr : in;
    prdata  : in;
  end view;

  procedure apb_attach (
    signal s_apb : view s_apb_view of bus_apb_t;
    signal m_apb : view m_apb_view of bus_apb_t
  );

  -- ---------------------------------------------------------------------------
  -- Register Bus
  -- ..This is a simple bus interface for basic components that don't need
  -- most of the features offered by busses like axi, but
  -- still require higher performance than can be offered by busses like apb.
  -- Read and write channels can operate independently.
  -- Slave is expected to always respond in a fixed number of cycles that is
  -- known by the master.
  -- Full duplex communication at 1 transfer per cycle for maximum bandwidth.
  -- Recommended to use this for user logic and connect to an axil adapter for
  -- external pipelining and interconnect logic.
  type bus_reg_t is record
    wen   : std_ulogic;
    waddr : std_ulogic_vector(AXIL_ADDR_RANGE);
    wstrb : std_ulogic_vector(AXIL_STRB_RANGE);
    wdata : std_ulogic_vector(AXIL_DATA_RANGE);
    werr  : std_ulogic;
    ren   : std_ulogic;
    raddr : std_ulogic_vector(AXIL_ADDR_RANGE);
    rdata : std_ulogic_vector(AXIL_DATA_RANGE);
    rerr  : std_ulogic;
  end record;

  type bus_reg_arr_t is array(natural range <>) of bus_reg_t;

  view m_reg_view of bus_reg_t is
    wen   : out;
    waddr : out;
    wstrb : out;
    wdata : out;
    werr  : in;
    ren   : out;
    raddr : out;
    rdata : in;
    rerr  : in;
  end view;

  alias s_reg_view is m_reg_view'converse;

  view p_reg_view of bus_reg_t is
    wen   : in;
    waddr : in;
    wstrb : in;
    wdata : in;
    werr  : in;
    ren   : in;
    raddr : in;
    rdata : in;
    rerr  : in;
  end view;

  procedure reg_attach (
    signal s_reg : view s_reg_view of bus_reg_t;
    signal m_reg : view m_reg_view of bus_reg_t
  );

  -- ---------------------------------------------------------------------------
  -- Transaction type
  type bus_cmd_t is (BUS_WRITE, BUS_CHECK);

  type bus_xact_t is record
    cmd   : bus_cmd_t;
    addr  : std_ulogic_vector(AXIL_ADDR_RANGE);
    data  : std_ulogic_vector(AXIL_DATA_RANGE);
    wstrb : std_ulogic_vector(AXIL_STRB_RANGE);
    mask  : std_ulogic_vector(AXIL_DATA_RANGE);
  end record;

  type bus_xact_arr_t is array(natural range <>) of bus_xact_t;

end package;

package body bus_pkg is

  procedure axil_attach (
    signal s_axil : view s_axil_view of bus_axil_t;
    signal m_axil : view m_axil_view of bus_axil_t
  ) is
  begin
    m_axil.awvalid <= s_axil.awvalid;
    s_axil.awready <= m_axil.awready;
    m_axil.awaddr  <= s_axil.awaddr;
    m_axil.wvalid  <= s_axil.wvalid;
    s_axil.wready  <= m_axil.wready;
    m_axil.wdata   <= s_axil.wdata;
    m_axil.wstrb   <= s_axil.wstrb;
    s_axil.bvalid  <= m_axil.bvalid;
    m_axil.bready  <= s_axil.bready;
    s_axil.bresp   <= m_axil.bresp;
    m_axil.arvalid <= s_axil.arvalid;
    s_axil.arready <= m_axil.arready;
    m_axil.araddr  <= s_axil.araddr;
    s_axil.rvalid  <= m_axil.rvalid;
    m_axil.rready  <= s_axil.rready;
    s_axil.rdata   <= m_axil.rdata;
    s_axil.rresp   <= m_axil.rresp;
  end procedure;

  procedure wb_attach (
    signal s_wb : view s_wb_view of bus_wb_t;
    signal m_wb : view m_wb_view of bus_wb_t
  ) is
  begin
    m_wb.stb  <= s_wb.stb;
    m_wb.wen  <= s_wb.wen;
    m_wb.addr <= s_wb.addr;
    m_wb.wdat <= s_wb.wdat;
    m_wb.wsel <= s_wb.wsel;
    s_wb.ack  <= m_wb.ack;
    s_wb.err  <= m_wb.err;
    s_wb.rdat <= m_wb.rdat;
  end procedure;

  procedure apb_attach (
    signal s_apb : view s_apb_view of bus_apb_t;
    signal m_apb : view m_apb_view of bus_apb_t
  ) is
  begin
    m_apb.psel    <= s_apb.psel;
    m_apb.penable <= s_apb.penable;
    m_apb.pwrite  <= s_apb.pwrite;
    m_apb.paddr   <= s_apb.paddr;
    m_apb.pwdata  <= s_apb.pwdata;
    m_apb.pstrb   <= s_apb.pstrb;
    s_apb.pready  <= m_apb.pready;
    s_apb.pslverr <= m_apb.pslverr;
    s_apb.prdata  <= m_apb.prdata;
  end procedure;

  procedure reg_attach (
    signal s_reg : view s_reg_view of bus_reg_t;
    signal m_reg : view m_reg_view of bus_reg_t
  ) is
  begin
    m_reg.wen   <= s_reg.wen;
    m_reg.waddr <= s_reg.waddr;
    m_reg.wstrb <= s_reg.wstrb;
    m_reg.wdata <= s_reg.wdata;
    s_reg.werr  <= m_reg.werr;
    m_reg.ren   <= s_reg.ren;
    m_reg.raddr <= s_reg.raddr;
    s_reg.rdata <= m_reg.rdata;
    s_reg.rerr  <= m_reg.rerr;
  end procedure;

end package body;
