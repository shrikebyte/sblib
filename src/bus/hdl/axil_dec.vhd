--##############################################################################
--# File : axil_dec.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite 1:N decoder
--# Inspired by: https://github.com/hdl-modules/hdl-modules/blob/main/modules/axi_lite/src/axi_lite_mux.vhd
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_dec is
  generic (
    G_NUM_M      : positive;
    G_ADDR_WIDTH : positive range 4 to AXIL_ADDR_WIDTH;
    G_BASEADDRS  : bus_baseaddr_arr_t(0 to G_NUM_M - 1)
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    s_axil : view  s_axil_view;
    m_axil : view (m_axil_view) of bus_axil_arr_t(0 to G_NUM_M - 1)
  );
end entity;

architecture rtl of axil_dec is

  -- ---------------------------------------------------------------------------
  constant DECODE_ERR : natural := G_NUM_M;

  -- ---------------------------------------------------------------------------
  impure function check_baseaddrs return boolean is begin
    for i in G_BASEADDRS'range loop

      -- Test valid address characters
      for bit_idx in G_BASEADDRS(0).addr'range loop
        if G_BASEADDRS(i).addr(bit_idx) /= '0' and G_BASEADDRS(i).addr(bit_idx) /= '1' then
          report "Invalid character at address index "
                 & integer'image(i)
                 & ", bit index "
                 & integer'image(bit_idx)
                 & ": "
                 & std_logic'image(G_BASEADDRS(i).addr(bit_idx))
            severity warning;
          return false;
        end if;
      end loop;

      -- Test address widths
      if G_BASEADDRS(i).width >= G_ADDR_WIDTH then
        report "Subordinate address width must be less than decoder address width "
               & integer'image(i)
               & ": "
               & natural'image(to_integer(unsigned(G_BASEADDRS(i).addr)))
          severity warning;
        return false;
      end if;

      for addr_test_idx in G_BASEADDRS'range loop
        if i /= addr_test_idx then -- Skip checking against self
          -- Test for dupe addresses
          if G_BASEADDRS(i).addr = G_BASEADDRS(addr_test_idx).addr then
            report "Duplicate address found at indexes "
                   & integer'image(i)
                   & " and "
                   & integer'image(addr_test_idx)
                   & ": "
                   & natural'image(to_integer(unsigned(G_BASEADDRS(i).addr)))
              severity warning;
            return false;
          end if;

          -- Test for address overlap.
          -- For example, consider:
          --   0 => addr = 0x10000, width = 16
          --   1 => addr = 0x15000, width = 12
          -- This endpoint module is ambiguous because device 1 is specified as
          -- residing withing device 0's reserved address allocation.
          -- If any masked address A is equal to another address B masked with A's
          -- address mask, that is an error.
          if G_BASEADDRS(i).addr(G_ADDR_WIDTH - 1 downto G_BASEADDRS(i).width) =
             G_BASEADDRS(addr_test_idx).addr(G_ADDR_WIDTH - 1 downto G_BASEADDRS(i).width) then
            report "Address overlap for indexes "
                   & integer'image(i)
                   & " and "
                   & integer'image(addr_test_idx)
              severity warning;
            return false;
          end if;
        end if;
      end loop;
    end loop;
    return true;
  end function;

  impure function decode (
    addr : std_logic_vector(AXIL_ADDR_RANGE)
  ) return natural is
  begin
    for i in G_BASEADDRS'range loop
      if addr(G_ADDR_WIDTH - 1 downto G_BASEADDRS(i).width) =
         G_BASEADDRS(i).addr(G_ADDR_WIDTH - 1 downto G_BASEADDRS(i).width) then
        return i;
      end if;
    end loop;
    return DECODE_ERR;
  end function;

  -- ---------------------------------------------------------------------------
  type   wr_state_t is (ST_WR_IDLE, ST_WR_W, ST_WR_B);
  signal wr_state : wr_state_t;
  signal wr_sel   : natural range 0 to DECODE_ERR;

  type   rd_state_t is (ST_RD_IDLE, ST_RD_AR, ST_RD_R);
  signal rd_state : rd_state_t;
  signal rd_sel   : natural range 0 to DECODE_ERR;

  signal aw_en : std_ulogic;
  signal w_en  : std_ulogic;
  signal b_en  : std_ulogic;
  signal ar_en : std_ulogic;
  signal r_en  : std_ulogic;

  signal i0_axil : bus_axil_arr_t(0 to DECODE_ERR);

begin

  -- ---------------------------------------------------------------------------
  assert check_baseaddrs
    report "The supplied address set is invalid. See messages above."
    severity failure;

  -- ---------------------------------------------------------------------------
  prc_wr_select : process (clk) is begin
    if rising_edge(clk) then
      case wr_state is
        when ST_WR_IDLE =>
          if s_axil.awvalid then
            wr_sel   <= decode(s_axil.awaddr);
            aw_en    <= '1';
            w_en     <= '1';
            wr_state <= ST_WR_W;
          end if;

        when ST_WR_W =>
          if s_axil.awvalid and s_axil.awready then
            aw_en <= '0';
          end if;

          if s_axil.wvalid and s_axil.wready then
            w_en <= '0';
          end if;

          if (not aw_en or (s_axil.awvalid and s_axil.awready)) and
             (not w_en or (s_axil.wvalid  and s_axil.wready)) then
            b_en     <= '1';
            wr_state <= ST_WR_B;
          end if;

        when ST_WR_B =>
          if s_axil.bvalid and s_axil.bready then
            b_en     <= '0';
            wr_state <= ST_WR_IDLE;
          end if;
      end case;

      if srst then
        aw_en    <= '0';
        w_en     <= '0';
        b_en     <= '0';
        wr_sel   <= wr_sel'low;
        wr_state <= ST_WR_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_rd_select : process (clk) is begin
    if rising_edge(clk) then
      case rd_state is
        when ST_RD_IDLE =>
          if s_axil.arvalid then
            rd_sel   <= decode(s_axil.araddr);
            ar_en    <= '1';
            r_en     <= '0';
            rd_state <= ST_RD_AR;
          end if;

        when ST_RD_AR =>
          if s_axil.arvalid and s_axil.arready then
            ar_en    <= '0';
            r_en     <= '1';
            rd_state <= ST_RD_R;
          end if;

        when ST_RD_R =>
          if s_axil.rvalid and s_axil.rready then
            ar_en    <= '0';
            r_en     <= '0';
            rd_state <= ST_RD_IDLE;
          end if;
      end case;

      if srst then
        ar_en    <= '0';
        r_en     <= '0';
        rd_sel   <= rd_sel'low;
        rd_state <= ST_RD_IDLE;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  s_axil.awready <= i0_axil(wr_sel).awready and aw_en;
  s_axil.wready  <= i0_axil(wr_sel).wready and w_en;
  s_axil.bvalid  <= i0_axil(wr_sel).bvalid and b_en;
  s_axil.bresp   <= i0_axil(wr_sel).bresp;
  s_axil.arready <= i0_axil(rd_sel).arready and ar_en;
  s_axil.rvalid  <= i0_axil(rd_sel).rvalid and r_en;
  s_axil.rdata   <= i0_axil(rd_sel).rdata;
  s_axil.rresp   <= i0_axil(rd_sel).rresp;

  -- ---------------------------------------------------------------------------
  gen_assign : for i in 0 to G_NUM_M - 1 generate
    i0_axil(i).awvalid <= s_axil.awvalid and aw_en and to_sl(i = wr_sel);
    i0_axil(i).awaddr  <= s_axil.awaddr;
    i0_axil(i).wvalid  <= s_axil.wvalid and w_en and to_sl(i = wr_sel);
    i0_axil(i).wdata   <= s_axil.wdata;
    i0_axil(i).wstrb   <= s_axil.wstrb;
    i0_axil(i).bready  <= s_axil.bready and b_en and to_sl(i = wr_sel);
    i0_axil(i).arvalid <= s_axil.arvalid and ar_en and to_sl(i = rd_sel);
    i0_axil(i).araddr  <= s_axil.araddr;
    i0_axil(i).rready  <= s_axil.rready and r_en and to_sl(i = rd_sel);
    --
    axil_attach(i0_axil(i), m_axil(i));
  end generate;

  -- ---------------------------------------------------------------------------
  -- This is an extra "dumb" subordinate that responds with a decode error
  -- whenever an out-of-range address is received
  i0_axil(DECODE_ERR).awready <= '1';
  i0_axil(DECODE_ERR).wready  <= '1';
  i0_axil(DECODE_ERR).bvalid  <= '1';
  i0_axil(DECODE_ERR).bresp   <= AXI_RSP_DECERR;
  i0_axil(DECODE_ERR).arready <= '1';
  i0_axil(DECODE_ERR).rvalid  <= '1';
  i0_axil(DECODE_ERR).rdata   <= x"DEAD_BEEF";
  i0_axil(DECODE_ERR).rresp   <= AXI_RSP_DECERR;

end architecture;
