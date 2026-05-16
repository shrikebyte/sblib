--##############################################################################
--# File : axil_decoder.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite 1:N decoder
--# Designed for simplicity and low utilization.
--#
--# Heavily inspired by: https://github.com/hdl-modules/hdl-modules/blob/main/modules/axi_lite/src/axi_lite_mux.vhd
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_decoder is
  generic (
    G_BASEADDRS  : slv_arr_t(open)(AXIL_ADDR_WIDTH - 1 downto 0)
  );
  port (
    clk    : in    std_logic;
    srst   : in    std_logic;
    s_axil : view  s_axil_view;
    m_axil : view (m_axil_view) of bus_axil_arr_t
  );
end entity;

architecture rtl of axil_decoder is

  -- ---------------------------------------------------------------------------
  type addr_decode_range_t is record
    hi : natural;
    lo : natural;
  end record;

  -- ---------------------------------------------------------------------------
  function check_baseaddrs (
    baseaddrs : slv_arr_t
  ) return boolean is
  begin
    for addr_idx in baseaddrs'range loop
      for bit_idx in baseaddrs(0)'range loop
        if baseaddrs(addr_idx)(bit_idx) /= '0' and baseaddrs(addr_idx)(bit_idx) /= '1' then
          report "Invalid character at address index "
                 & integer'image(addr_idx)
                 & ", bit index "
                 & integer'image(bit_idx)
                 & ": "
                 & std_logic'image(baseaddrs(addr_idx)(bit_idx))
            severity warning;

          return false;
        end if;
      end loop;

      for addr_test_idx in baseaddrs'range loop
        if addr_idx /= addr_test_idx and baseaddrs(addr_idx) = baseaddrs(addr_test_idx) then
          report "Duplicate address found at indexes "
                 & integer'image(addr_idx)
                 & " and "
                 & integer'image(addr_test_idx)
                 & ": "
                 & natural'image(to_integer(unsigned(baseaddrs(addr_idx))))
            severity warning;

          return false;
        end if;
      end loop;
    end loop;

    return true;
  end function;

  function find_addr_decode_range (
    baseaddrs : slv_arr_t
  ) return addr_decode_range_t is
    variable mask : std_logic_vector(baseaddrs(0)'range) := (others => '0');
    variable rtn  : addr_decode_range_t;
  begin
    assert check_baseaddrs(baseaddrs)
      report "The supplied address set is invalid. See messages above."
      severity failure;

    for i in baseaddrs'range loop
      mask := mask or baseaddrs(i);
    end loop;

    rtn.hi := find_hi_idx(mask);
    rtn.lo := find_lo_idx(mask);
    return rtn;
  end function;

  function decode (
    addr : std_logic_vector;
    decode_range : addr_decode_range_t;
    baseaddrs : slv_arr_t
  ) return natural is
    constant NO_MATCH : natural := baseaddrs'length;
  begin
    for i in baseaddrs'range loop
      if addr(decode_range.hi downto decode_range.lo) = baseaddrs(i)(decode_range.hi downto decode_range.lo) then
        return i;
      end if;
    end loop;
    return NO_MATCH;
  end function;

  -- ---------------------------------------------------------------------------
  constant DECODE_RANGE           : addr_decode_range_t := find_addr_decode_range(G_BASEADDRS);
  constant DECODE_ERR             : natural             := m_axil'length;
  constant SLAVE_DECODE_ERR_IDX   : natural             := DECODE_ERR;
  constant SLAVE_NOT_SELECTED_IDX : natural             := DECODE_ERR + 1;

  -- ---------------------------------------------------------------------------
  signal wr_decoded_idx : natural range 0 to DECODE_ERR;
  signal rd_decoded_idx : natural range 0 to DECODE_ERR;

  type   wr_state_t is (ST_WR_IDLE, ST_WR_WRITING, ST_WR_DECODE_ERR_W, ST_WR_DECODE_ERR_B);
  signal wr_state           : wr_state_t;
  signal wr_select          : natural range 0 to SLAVE_NOT_SELECTED_IDX;
  signal wr_dec_err_awready : std_logic;
  signal wr_dec_err_wready  : std_logic;
  signal wr_dec_err_bvalid  : std_logic;

  type   rd_state_t is (ST_RD_IDLE, ST_RD_READING, ST_RD_DECODE_ERR);
  signal rd_state           : rd_state_t;
  signal rd_select          : natural range 0 to SLAVE_NOT_SELECTED_IDX;
  signal rd_dec_err_arready : std_logic;
  signal rd_dec_err_rvalid  : std_logic;

begin

  -- ---------------------------------------------------------------------------
  wr_decoded_idx <= decode(s_axil.awaddr, DECODE_RANGE, G_BASEADDRS);
  rd_decoded_idx <= decode(s_axil.araddr, DECODE_RANGE, G_BASEADDRS);

  -- ---------------------------------------------------------------------------
  prc_wr_select : process (clk) is begin
    if rising_edge(clk) then
      case wr_state is
        when ST_WR_IDLE =>
          if s_axil.awvalid then
            if wr_decoded_idx = DECODE_ERR then
              wr_dec_err_awready <= '1';
              wr_dec_err_wready  <= '1';
              wr_select          <= SLAVE_DECODE_ERR_IDX;
              wr_state           <= ST_WR_DECODE_ERR_W;
            else
              wr_select <= wr_decoded_idx;
              wr_state  <= ST_WR_WRITING;
            end if;
          end if;

        when ST_WR_DECODE_ERR_W =>
          wr_dec_err_awready <= '0';

          if s_axil.wvalid and s_axil.wready then
            wr_dec_err_wready <= '0';
            wr_dec_err_bvalid <= '1';
            wr_state          <= ST_WR_DECODE_ERR_B;
          end if;

        when ST_WR_DECODE_ERR_B =>
          if s_axil.bvalid and s_axil.bready then
            wr_dec_err_bvalid <= '0';
            wr_select         <= SLAVE_NOT_SELECTED_IDX;
            wr_state          <= ST_WR_IDLE;
          end if;

        when ST_WR_WRITING =>
          if s_axil.bvalid and s_axil.bready then
            wr_select <= SLAVE_NOT_SELECTED_IDX;
            wr_state  <= ST_WR_IDLE;
          end if;
        when others =>
          null;
      end case;

      if srst then
        wr_dec_err_awready <= '0';
        wr_dec_err_wready  <= '0';
        wr_dec_err_bvalid  <= '0';
        wr_select          <= SLAVE_NOT_SELECTED_IDX;
        wr_state           <= ST_WR_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_rd_select : process (clk) is begin
    if rising_edge(clk) then
      case rd_state is
        when ST_RD_IDLE =>
          if s_axil.arvalid then
            if rd_decoded_idx = DECODE_ERR then
              rd_dec_err_arready <= '1';
              rd_dec_err_rvalid  <= '1';
              rd_select          <= SLAVE_DECODE_ERR_IDX;
              rd_state           <= ST_RD_DECODE_ERR;
            else
              rd_select <= rd_decoded_idx;
              rd_state  <= ST_RD_READING;
            end if;
          end if;

        when ST_RD_DECODE_ERR =>
          rd_dec_err_arready <= '0';

          if s_axil.rvalid and s_axil.rready then
            rd_dec_err_rvalid <= '0';
            rd_select         <= SLAVE_NOT_SELECTED_IDX;
            rd_state          <= ST_RD_IDLE;
          end if;

        when ST_RD_READING =>
          if s_axil.rvalid and s_axil.rready then
            rd_select <= SLAVE_NOT_SELECTED_IDX;
            rd_state  <= ST_RD_IDLE;
          end if;
        when others =>
          null;
      end case;

      if srst then
        rd_dec_err_arready <= '0';
        rd_dec_err_rvalid  <= '0';
        rd_select          <= SLAVE_NOT_SELECTED_IDX;
        rd_state           <= ST_RD_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_wr_rsp : process (all) is begin
    if wr_select = SLAVE_NOT_SELECTED_IDX then
      s_axil.awready <= '0';
      s_axil.wready  <= '0';
      s_axil.bvalid  <= '0';
      s_axil.bresp   <= (others => '-');
    elsif wr_select = SLAVE_DECODE_ERR_IDX then
      s_axil.awready <= wr_dec_err_awready;
      s_axil.wready  <= wr_dec_err_wready;
      s_axil.bvalid  <= wr_dec_err_bvalid;
      s_axil.bresp   <= AXI_RESP_DECERR;
    else
      s_axil.awready <= m_axil(wr_select).awready;
      s_axil.wready  <= m_axil(wr_select).wready;
      s_axil.bvalid  <= m_axil(wr_select).bvalid;
      s_axil.bresp   <= m_axil(wr_select).bresp;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_rd_rsp : process (all) is begin
    if rd_select = SLAVE_NOT_SELECTED_IDX then
      s_axil.arready <= '0';
      s_axil.rvalid  <= '0';
      s_axil.rdata   <= (others => '-');
      s_axil.rresp   <= (others => '-');
    elsif rd_select = SLAVE_DECODE_ERR_IDX then
      s_axil.arready <= rd_dec_err_arready;
      s_axil.rvalid  <= rd_dec_err_rvalid;
      s_axil.rdata   <= (others => '-');
      s_axil.rresp   <= AXI_RESP_DECERR;
    else
      s_axil.arready <= m_axil(rd_select).arready;
      s_axil.rvalid  <= m_axil(rd_select).rvalid;
      s_axil.rdata   <= m_axil(rd_select).rdata;
      s_axil.rresp   <= m_axil(rd_select).rresp;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_assign_req : process (all) is begin
    for slave in m_axil'range loop

      m_axil(slave).awvalid <= s_axil.awvalid;
      m_axil(slave).awaddr  <= s_axil.awaddr;
      m_axil(slave).wvalid  <= s_axil.wvalid;
      m_axil(slave).wstrb   <= s_axil.wstrb;
      m_axil(slave).wdata   <= s_axil.wdata;
      m_axil(slave).bready  <= s_axil.bready;
      m_axil(slave).arvalid <= s_axil.arvalid;
      m_axil(slave).araddr  <= s_axil.araddr;
      m_axil(slave).rready  <= s_axil.rready;

      if wr_select /= slave then
        m_axil(slave).awvalid <= '0';
        m_axil(slave).wvalid  <= '0';
        m_axil(slave).bready  <= '0';
      end if;

      if rd_select /= slave then
        m_axil(slave).arvalid <= '0';
        m_axil(slave).rready  <= '0';
      end if;
    end loop;
  end process;

end architecture;
