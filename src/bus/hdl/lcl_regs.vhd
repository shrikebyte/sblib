--##############################################################################
--# File : lcl_regs.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Generic local register file
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity lcl_regs is
  generic (
    G_NUM_REGS : positive;
    G_MODES    : bus_reg_mode_arr_t(0 to G_NUM_REGS - 1);
    G_RST_VALS : slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE)
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_lcl : view s_lcl_view;
    --
    regs_in  : in    slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE);
    regs_out : out   slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE);
    regs_rd  : out   sl_arr_t(0 to G_NUM_REGS - 1);
    regs_wr  : out   sl_arr_t(0 to G_NUM_REGS - 1)
  );
end entity;

architecture rtl of lcl_regs is

  constant ADDR_LO_BIT : integer := clog2(AXIL_DATA_WIDTH / 8);
  constant ADDR_HI_BIT : integer := clog2(G_NUM_REGS) + ADDR_LO_BIT - 1;

  signal wr_sel   : integer range 0 to round_up_pwr2(G_NUM_REGS) - 1;
  signal rd_sel   : integer range 0 to round_up_pwr2(G_NUM_REGS) - 1;
  signal reg_file : slv_arr_t(0 to G_NUM_REGS - 1)(AXIL_DATA_RANGE);

begin

  -- ---------------------------------------------------------------------------
  wr_sel   <= to_integer(unsigned(s_lcl.waddr(ADDR_HI_BIT downto ADDR_LO_BIT)));
  rd_sel   <= to_integer(unsigned(s_lcl.raddr(ADDR_HI_BIT downto ADDR_LO_BIT)));
  regs_out <= reg_file;

  -- ---------------------------------------------------------------------------
  prc_write : process (clk) is begin
    if rising_edge(clk) then
      s_lcl.werr <= '0';
      regs_wr    <= (others => '0');

      for i in 0 to G_NUM_REGS - 1 loop
        case G_MODES(i) is
          when REG_RWP | REG_WP =>
            reg_file(i) <= G_RST_VALS(i);

          when REG_RW1C =>
            reg_file(i) <= reg_file(i) or regs_in(i);

          when others =>
            null;
        end case;

      end loop;

      if s_lcl.wen then
        if wr_sel < G_NUM_REGS then
          regs_wr(wr_sel) <= '1';

          case G_MODES(wr_sel) is
            when REG_WO | REG_RW | REG_WP | REG_RWP =>
              for i in AXIL_STRB_RANGE loop
                if s_lcl.wstrb(i) then
                  reg_file(wr_sel)((i + 1) * 8 - 1 downto i * 8) <=
                    s_lcl.wdata((i + 1) * 8 - 1 downto i * 8);
                end if;
              end loop;

            when REG_RW1C =>
              for i in AXIL_STRB_RANGE loop
                if s_lcl.wstrb(i) then
                  reg_file(wr_sel)((i + 1) * 8 - 1 downto i * 8) <=
                    reg_file(wr_sel)((i + 1) * 8 - 1 downto i * 8) and not
                    s_lcl.wdata((i + 1) * 8 - 1 downto i * 8);
                end if;
              end loop;

            when others =>
              s_lcl.werr <= '1';

          end case;

        else
          s_lcl.werr <= '1';
        end if;
      end if;

      if srst then
        s_lcl.werr <= '0';
        regs_wr    <= (others => '0');
        reg_file   <= G_RST_VALS;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_read : process (clk) is begin
    if rising_edge(clk) then
      s_lcl.rerr <= '0';
      regs_rd    <= (others => '0');

      if s_lcl.ren then
        if rd_sel < G_NUM_REGS then
          regs_rd(rd_sel) <= '1';

          case G_MODES(rd_sel) is
            when REG_RO | REG_RWP =>
              s_lcl.rdata <= regs_in(rd_sel);
            when REG_RW | REG_RW1C =>
              s_lcl.rdata <= reg_file(rd_sel);
            when others =>
              s_lcl.rerr <= '1';
          end case;

        else
          s_lcl.rerr <= '1';
        end if;
      end if;

      if srst then
        s_lcl.rerr <= '0';
        regs_rd    <= (others => '0');
      end if;
    end if;
  end process;

end architecture;
