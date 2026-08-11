--##############################################################################
--# File : wb_ascii_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Wishbone ASCII-based bus manager. This is a state machine with a human-
--# friendly character-based streaming interface on one end and a Wishbone
--# manager interface on the other end. This module is primarily intended to be
--# connected to a UART to enable processor-less terminal-based register access,
--# but since this uses a set of generic axi streams,
--# any other stream-based interface could be used to manage the bus.
--# For example, a UDP-based ethernet interface could be an alternative
--# to UART.
--#
--# The simple user protocol supports two commands: read and write, with
--# a few additional variants for shorthand convenience.
--#
--# | Command         | Command Format      | Success Resp  | Fail Resp |
--# |-----------------|---------------------|---------------|-----------|
--# | Read            | r aaaaaaaa          | dddddddd      | ! or ?    |
--# | Write           | w aaaaaaaa dddddddd | +             | ! or ?    |
--# | Read Increment  | n                   | dddddddd      | ! or ?    |
--# | Write Increment | m dddddddd          | +             | ! or ?    |
--# | Previous        | p                   | + or dddddddd | ! or ?    |
--#
--# The protocol was designed to work equally well with an interactive terminal
--# or a scripted software parser. An interactive terminal could be used
--# for short-term experiments and edits, while a software parser could be used
--# to programmatically interface with the device, for example, as a layer
--# between the hardware and a GUI.
--#
--# * Read (r) - Read data from an address
--# * Write (w) - Write data to an address
--# * Read Increment (n) - Read from the last command's address + 4
--# * Write Increment (m) - Write to the last command's address + 4
--# * Previous (p) - Re-run the previous command. If the last command was an
--#     increment command, then the address is NOT incremented again.
--# * Previous and increment commands default to using address and data of 0x0
--#   if no previous read or write commands have been issued.
--# * 'aaaaaaaa' is a 32-bit hex formatted address. It can be anywhere
--#    from 1 to 8 characters.
--# * 'dddddddd' is a 32-bit hex formatted data value. It can be anywhere
--#    from 1 to 8 characters.
--# * '+' is a write success response, returned by the FPGA.
--# * '!' is a bus error response, returned by the FPGA.
--# * '?' is an unknown command or parsing error, returned by the FPGA.
--# * '<LF>' is a line feed character
--#   (the enter key). This marks the end of every command or response (not
--#   shown in command table).
--# * Some terminal emulators use <CR><LF> for enter (carriage return followed
--#   by line feed). This protocol is only sensitive to <LF>. <CR> is ignored.
--# * Only supports 32-bit aligned access.
--# * Does not support write byte strobes.
--# * Does not support backspaces. To cancel a command use <ESC><LF>.
--# * Protocol is case insensitive.
--# * Leading zeros are optional in addresses and data.
--# * Only hex format is supported for address and data.
--# * No leading `0x` for the address and data.
--# * Tabs and/or spaces can be used as a delimiter between command words
--# * Extraneous tabs and spaces are trimmed.
--#
--# --------+-------------------------------------------------------------------
--# Signal  | Description
--# --------+-------------------------------------------------------------------
--# s_axis    ASCII command received by this module and sent by the user port
--# --------+-------------------------------------------------------------------
--# tdata   | ASCII response.
--# tkeep   | Unused.
--# tlast   | Unused.
--# tuser   | Unused.
--# --------+-------------------------------------------------------------------
--# m_axis    ASCII response sent by this module and received by the user port
--# --------+-------------------------------------------------------------------
--# tdata   | ASCII response.
--# tkeep   | Unused. Output tied to 1.
--# tlast   | Unused. Output tied to 1.
--# tuser   | Unused. Output tied to 0.
--# --------+-------------------------------------------------------------------
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.axis_pkg.all;

entity wb_ascii_mgr is
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
      tuser(0 downto 0)
    );
    --
    m_wb : view  m_wb_view
  );
end entity;

architecture rtl of wb_ascii_mgr is

  constant BITS_PER_CHAR  : positive := 4;
  constant CHARS_PER_ADDR : positive := AXIL_ADDR_WIDTH / BITS_PER_CHAR;
  constant CHARS_PER_DATA : positive := AXIL_DATA_WIDTH / BITS_PER_CHAR;

  type   state_t is (
    ST_RESET, ST_IDLE, ST_RX_DELIM0, ST_RX_ADDR, ST_RX_DELIM1, ST_RX_DATA,
    ST_BUS_START, ST_BUS_RESP, ST_TX_DATA, ST_SYNTAX_ERR, ST_DONE, ST_DONE1
  );
  signal state : state_t;

  signal rx_char   : character;
  signal addr_incr : std_ulogic_vector(AXIL_ADDR_RANGE);
  signal wen_prev  : std_ulogic;
  signal addr_prev : std_ulogic_vector(AXIL_ADDR_RANGE);
  signal wdat_prev : std_ulogic_vector(AXIL_DATA_RANGE);
  signal rdat      : std_ulogic_vector(AXIL_DATA_RANGE);
  signal cnt       : unsigned(clog2(maximum(CHARS_PER_ADDR, CHARS_PER_DATA)) downto 0);

begin

  m_axis.tkeep <= (others => '1');
  m_axis.tlast <= '1';
  m_axis.tuser <= (others => '0');
  m_wb.wsel    <= (others => '1');
  rx_char      <= to_char(s_axis.tdata);
  addr_incr    <= std_ulogic_vector(unsigned(addr_prev) + AXIL_STRB_WIDTH);

  prc_fsm : process (clk) is begin
    if rising_edge(clk) then
      case state is
        -- ---------------------------------------------------------------------
        when ST_RESET =>
          s_axis.tready <= '1';
          state         <= ST_IDLE;

        -- ---------------------------------------------------------------------
        when ST_IDLE =>
          if s_axis.tvalid then
            case rx_char is

              -- Read command
              when 'r' | 'R' =>
                m_wb.wen  <= '0';
                m_wb.addr <= (others => '0');
                state     <= ST_RX_DELIM0;

              -- Write command
              when 'w' | 'W' =>
                m_wb.wen  <= '1';
                m_wb.addr <= (others => '0');
                m_wb.wdat <= (others => '0');
                state     <= ST_RX_DELIM0;

              -- Read increment command
              when 'n' | 'N' =>
                m_wb.wen  <= '0';
                m_wb.addr <= addr_incr;
                state     <= ST_BUS_START;

              -- Write increment command
              when 'm' | 'M' =>
                m_wb.wen  <= '1';
                m_wb.addr <= addr_incr;
                m_wb.wdat <= (others => '0');
                state     <= ST_RX_DELIM1;

              -- Repeat previous command
              when 'p' | 'P' =>
                m_wb.wen  <= wen_prev;
                m_wb.addr <= addr_prev;
                m_wb.wdat <= wdat_prev;
                state     <= ST_BUS_START;

              -- Ignore whitespace
              when ' ' | HT | CR => null;

              -- Unexpected early return
              when LF =>
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
                s_axis.tready <= '0';
                state         <= ST_DONE;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;

            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_RX_DELIM0 =>
          cnt <= (others => '0');
          if s_axis.tvalid then
            case rx_char is

              -- Delimiter
              when ' ' | HT =>
                state <= ST_RX_ADDR;

              -- Unexpected early return
              when LF =>
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
                s_axis.tready <= '0';
                state         <= ST_DONE;

              -- Ignore carriage return
              when CR => null;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;
            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_RX_ADDR =>
          if s_axis.tvalid then
            -- Overflow
            if cnt = CHARS_PER_ADDR then
              state <= ST_SYNTAX_ERR;
            end if;

            case rx_char is
              when '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | 'A' |
                   'a' | 'B' | 'b' | 'C' | 'c' | 'D' | 'd' | 'E' | 'e' | 'F' | 'f' =>
                m_wb.addr <= m_wb.addr(AXIL_ADDR_WIDTH - 5 downto 0) & hex_to_nibble(rx_char);
                cnt       <= cnt + 1;

              -- Ignore carriage return
              when CR => null;

              when ' ' | HT =>
                cnt <= (others => '0');
                if cnt = 0 then
                  -- Ignore leading spaces
                  state <= ST_RX_ADDR;
                else
                  if m_wb.wen then
                    -- Go receive the write data
                    state <= ST_RX_DATA;
                  else
                    -- Go wait for the host to return before starting the read transaction
                    state <= ST_BUS_START;
                  end if;
                end if;

              when LF =>
                s_axis.tready <= '0';

                -- Unexpected return before getting any address chars
                if cnt = 0  then
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= to_ascii('?');
                  state         <= ST_DONE;
                else
                  if m_wb.wen then
                    -- Unexpected return before getting any write data chars
                    m_axis.tvalid <= '1';
                    m_axis.tdata  <= to_ascii('?');
                    state         <= ST_DONE;
                  else
                    -- Start the read transaction now
                    m_wb.stb      <= '1';
                    s_axis.tready <= '0';
                    state         <= ST_BUS_RESP;
                  end if;
                end if;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;

            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_RX_DELIM1 =>
          cnt <= (others => '0');
          if s_axis.tvalid then
            case rx_char is

              -- Delimiter
              when ' ' | HT =>
                state <= ST_RX_DATA;

              -- Unexpected early return
              when LF =>
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
                s_axis.tready <= '0';
                state         <= ST_DONE;

              -- Ignore carriage return
              when CR => null;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;
            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_RX_DATA =>
          if s_axis.tvalid then
            -- Overflow
            if cnt = CHARS_PER_DATA then
              state <= ST_SYNTAX_ERR;
            end if;

            case rx_char is
              when '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | 'A' |
                   'a' | 'B' | 'b' | 'C' | 'c' | 'D' | 'd' | 'E' | 'e' | 'F' | 'f' =>
                m_wb.wdat <= m_wb.wdat(AXIL_DATA_WIDTH - 5 downto 0) & hex_to_nibble(rx_char);
                cnt       <= cnt + 1;

              when ' ' | HT =>
                if cnt = 0 then
                  -- Ignore leading spaces
                  state <= ST_RX_DATA;
                else
                  -- Go wait for the host to return before starting the write transaction
                  state <= ST_BUS_START;
                end if;

              when LF =>
                s_axis.tready <= '0';

                if cnt = 0 then
                  -- Unexpected return before getting any write data chars
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= to_ascii('?');
                  state         <= ST_DONE;
                else
                  -- Start the write transaction now
                  m_wb.stb <= '1';
                  state    <= ST_BUS_RESP;
                end if;

              -- Ignore carriage return
              when CR => null;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;

            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_BUS_START =>
          if s_axis.tvalid then
            case rx_char is
              -- Start the transaction when host sends LF char
              when LF =>
                m_wb.stb      <= '1';
                s_axis.tready <= '0';
                state         <= ST_BUS_RESP;

              -- Ignore whitespace
              when ' ' | HT | CR => null;

              -- Unexpected character
              when others =>
                state <= ST_SYNTAX_ERR;

            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_BUS_RESP =>
          cnt <= (others => '0');

          -- Store the parameters of this transaction in case the next command
          -- is a repeat
          wen_prev  <= m_wb.wen;
          addr_prev <= m_wb.addr;
          wdat_prev <= m_wb.wdat;

          -- Bus error
          if m_wb.err then
            m_wb.stb      <= '0';
            m_axis.tvalid <= '1';
            m_axis.tdata  <= to_ascii('!');
            state         <= ST_DONE;
          elsif m_wb.ack then
            m_wb.stb <= '0';
            -- Write response
            if m_wb.wen then
              m_axis.tvalid <= '1';
              m_axis.tdata  <= to_ascii('+');
              state         <= ST_DONE;
            -- Read response
            else
              state <= ST_TX_DATA;
              rdat  <= m_wb.rdat;
            end if;
          end if;

        -- ---------------------------------------------------------------------
        when ST_TX_DATA =>
          if m_axis.tready or not m_axis.tvalid then
            if cnt = (CHARS_PER_DATA - 1) then
              state <= ST_DONE;
            end if;

            m_axis.tvalid <= '1';
            rdat          <= rdat(AXIL_DATA_WIDTH - 5 downto 0) & x"0";
            m_axis.tdata  <= to_ascii(nibble_to_hex(rdat(AXIL_DATA_WIDTH - 1 downto AXIL_DATA_WIDTH - 4)));
            cnt           <= cnt + 1;

          end if;

        -- ---------------------------------------------------------------------
        when ST_SYNTAX_ERR =>
          if s_axis.tvalid then
            case rx_char is
              when LF =>
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
                s_axis.tready <= '0';
                state         <= ST_DONE;
              when others => null;
            end case;

          end if;

        -- ---------------------------------------------------------------------
        when ST_DONE =>
          if m_axis.tready then
            m_axis.tvalid <= '1';
            m_axis.tdata  <= to_ascii(LF);
            state         <= ST_DONE1;
          end if;

        -- ---------------------------------------------------------------------
        when ST_DONE1 =>
          if m_axis.tready then
            m_axis.tvalid <= '0';
            s_axis.tready <= '1';
            state         <= ST_IDLE;
          end if;

      end case;

      if srst then
        s_axis.tready <= '0';
        m_axis.tvalid <= '0';
        wen_prev      <= '0';
        addr_prev     <= (others=> '0');
        wdat_prev     <= (others=> '0');
        m_wb.stb      <= '0';
        state         <= ST_RESET;
      end if;

    end if;
  end process;

end architecture;
