--##############################################################################
--# File : uart.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# UART
--#
--# There is no limit on the number of data bits. They are defined by the user
--# by setting the interface width of tdata. Recommended value is 8.
--# -------+--------------------------------------------------------------------
--# Signal | Description
--# -------+--------------------------------------------------------------------
--# s_axis
--# -------+--------------------------------------------------------------------
--# tdata  | UART Tx data.
--# tkeep  | Unused.
--# tlast  | Unused.
--# tuser  | Unused.
--# -------+--------------------------------------------------------------------
--# m_axis
--# -------+--------------------------------------------------------------------
--# tdata   | UART Rx data.
--# tkeep   | Unused.
--# tlast   | Unused.
--# tuser(0)| OVERRUN_ERROR - 1 = At least one frame prior to this one was dropped
--# tuser(1)| FRAMING_ERROR - 1 = This frame had a framing error
--# tuser(2)| PARITY_ERROR  - 1 = This frame had a parity error
--# --------+--------------------------------------------------------------------
--#
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity uart is
  generic (
    G_FPGA_CLK_HZ    : positive := 100_000_000;
    G_UART_BAUD_BPS  : positive := 115_200;
    G_BAUD_TOLERANCE : real     := 2.5; -- Percent error allowed in baud rate
    G_USE_PARITY     : boolean  := false;
    G_EVEN_PARITY    : boolean  := true -- true for even false for odd
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axis : view s_axis_view of axis_t(
      tdata(7 downto 0),
      tkeep(0 downto 0),
      tuser(0 downto 0)
    );
    --
    m_axis : view m_axis_view of axis_t(
      tdata(7 downto 0),
      tkeep(0 downto 0),
      tuser(2 downto 0)
    );
    --
    uart_txd : out   std_ulogic;
    uart_rxd : in    std_ulogic
  );
end entity;

architecture rtl of uart is

begin

  assert (G_FPGA_CLK_HZ / G_UART_BAUD_BPS) >= 8
    report "ERROR: uart: Baud rate should be at least 8x slower than the fpga clock"
    severity error;

  -- ---------------------------------------------------------------------------

  blk_tx : block is

    type state_t is (ST_IDLE, ST_DATA, ST_PARITY, ST_STOP);

    signal state  : state_t;
    signal tick   : std_ulogic;
    signal cnt    : natural range 0 to s_axis.tdata'length - 1;
    signal parity : std_ulogic;
    signal sr     : std_ulogic_vector(s_axis.tdata'length - 1 downto 0);

  begin

    prc_tx : process (clk) is begin
      if rising_edge(clk) then
        if s_axis.tvalid and s_axis.tready then
          s_axis.tready <= '0';
          sr            <= s_axis.tdata;
          if G_EVEN_PARITY then
            parity <= xor s_axis.tdata;
          else
            parity <= xnor s_axis.tdata;
          end if;
        end if;

        if tick then
          case state is
            when ST_IDLE =>
              if not s_axis.tready then
                uart_txd <= '0';
                state    <= ST_DATA;
              end if;

            when ST_DATA =>
              uart_txd <= sr(0);
              sr       <= '0' & sr(sr'high downto 1);
              if cnt = cnt'high then
                cnt   <= 0;
                state <= ST_PARITY when G_USE_PARITY else ST_STOP;
              else
                cnt <= cnt + 1;
              end if;

            when ST_PARITY =>
              uart_txd <= parity;
              state    <= ST_STOP;

            when ST_STOP =>
              s_axis.tready <= '1';
              uart_txd      <= '1';
              state         <= ST_IDLE;

          end case;

        end if;

        if srst then
          s_axis.tready <= '0';
          uart_txd      <= '1';
          cnt           <= 0;
          state         <= ST_STOP;
        end if;
      end if;
    end process;

    u_tx_tick : entity work.tick
    generic map (
      G_CLK_HZ    => G_FPGA_CLK_HZ,
      G_TICK_HZ   => G_UART_BAUD_BPS,
      G_TOLERANCE => G_BAUD_TOLERANCE
    )
    port map (
      clk  => clk,
      srst => srst,
      tick => tick
    );

  end block;

  -- ---------------------------------------------------------------------------

  blk_rx : block is

    type   state_t is (ST_IDLE, ST_START, ST_DATA, ST_PARITY, ST_STOP);
    signal state         : state_t;
    signal cnt           : natural range 0 to m_axis.tdata'length - 1;
    signal sr            : std_ulogic_vector(m_axis.tdata'length - 1 downto 0);
    signal tick_2x       : std_ulogic;
    signal tick_1x       : std_ulogic;
    signal tick_1x_en    : std_ulogic;
    signal tick_clr      : std_ulogic;
    signal uart_rxd_sync : std_ulogic;
    signal parity_err    : std_ulogic;
    signal overrun_err   : std_ulogic;

    constant OVERRUN_ERROR : integer := 0;
    constant FRAMING_ERROR : integer := 1;
    constant PARITY_ERROR  : integer := 2;

  begin

    m_axis.tkeep <= (others => '1');
    m_axis.tlast <= '1';

    tick_1x  <= tick_2x and tick_1x_en;
    tick_clr <= to_sl(state = ST_IDLE) and uart_rxd_sync;

    prc_rx : process (clk) is begin
      if rising_edge(clk) then
        tick_1x_en    <= not tick_1x_en when tick_2x;
        m_axis.tvalid <= '0' when m_axis.tready;

        case state is
          when ST_IDLE =>
            if not uart_rxd_sync then
              tick_1x_en <= '1';
              state      <= ST_START;
            end if;

          when ST_START =>
            if tick_2x then
              state <= ST_IDLE when uart_rxd_sync else ST_DATA;
            end if;

          when ST_DATA =>
            if tick_1x then
              sr <= uart_rxd_sync & sr(sr'high downto 1);
              if cnt = cnt'high then
                cnt   <= 0;
                state <= ST_PARITY when G_USE_PARITY else ST_STOP;
              else
                cnt <= cnt + 1;
              end if;
            end if;

          when ST_PARITY =>
            if tick_1x then
              if G_EVEN_PARITY then
                parity_err <= uart_rxd_sync xor (xor sr);
              else
                parity_err <= uart_rxd_sync xor (xnor sr);
              end if;
              state <= ST_STOP;
            end if;

          when ST_STOP =>
            if tick_1x then
              if m_axis.tready or not m_axis.tvalid then
                m_axis.tvalid               <= '1';
                m_axis.tdata                <= sr;
                m_axis.tuser(OVERRUN_ERROR) <= overrun_err;
                m_axis.tuser(FRAMING_ERROR) <= not uart_rxd_sync;
                m_axis.tuser(PARITY_ERROR)  <= parity_err;
                overrun_err                 <= '0';
              else
                overrun_err <= '1';
              end if;
              state <= ST_IDLE;
            end if;

        end case;

        if srst then
          m_axis.tvalid <= '0';
          tick_1x_en    <= '1';
          overrun_err   <= '0';
          parity_err    <= '0';
          cnt           <= 0;
          state         <= ST_IDLE;
        end if;
      end if;
    end process;

    u_rx_tick_2x : entity work.tick
    generic map (
      G_CLK_HZ    => G_FPGA_CLK_HZ,
      G_TICK_HZ   => G_UART_BAUD_BPS * 2,
      G_TOLERANCE => G_BAUD_TOLERANCE
    )
    port map (
      clk  => clk,
      srst => srst or tick_clr,
      tick => tick_2x
    );

    cdc_bit : entity work.cdc_bit
    generic map (
      G_WIDTH       => 1,
      G_USE_SRC_REG => false,
      G_EXTRA_SYNC  => 0
    )
    port map (
      src_bit(0) => uart_rxd,
      dst_clk    => clk,
      dst_bit(0) => uart_rxd_sync
    );

  end block;

end architecture;
