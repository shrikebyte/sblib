--##############################################################################
--# File : axil_ascii_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# AXI Lite ASCII-based bus manager. This is a state machine with a human-
--# friendly character-based streaming interface on one end and an AXI Lite
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
--#     increment command, then the address is incremented again.
--# * Previous and increment commands default to using address and data of 0x0
--#   if no previous read or write commands have been issued.
--# * 'aaaaaaaa' is a 32-bit hex formatted address. It can be anywhere
--#    from 1 to 8 characters.
--# * 'dddddddd' is a 32-bit hex formatted data value. It can be anywhere
--#    from 1 to 8 characters.
--# * '+' is a write success response, returned by the FPGA.
--# * '!' is a bus error response, returned by the FPGA.
--# * '?' is a unknown command or parsing error, returned by the FPGA.
--# * '<LF>' is a line feed character
--#   (the enter key). This marks the end of every command or response (not
--#   shown in command table).
--# * Some terminal emulators use <CR><LF> for enter (carriage return followed
--#   by line feed). This protocol is only sensitive to <LF>. <CR> is ignored.
--# * Only supports 32-bit aligned access.
--# * Does not support write byte strobes.
--# * Does not support backspaces. To cancel a command use <ESC>.
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

entity axil_ascii_mgr is
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
    m_axil : view  m_axil_view
  );
end entity;

architecture rtl of axil_ascii_mgr is

  type state_t is (
    ST_IDLE, ST_DELIM0, ST_ADDR, ST_DELIM1, ST_DATA, ST_BUS_START,
    ST_BUS_RSP_WAIT, ST_END
  );
  signal state : state_t;
  signal wb : bus_wb_t;

  signal rx_char   : character;
  signal addr_incr : std_ulogic_vector(AXIL_ADDR_RANGE);
  signal wen_prev  : std_ulogic;
  signal addr_prev : std_ulogic_vector(AXIL_ADDR_RANGE);
  signal wdat_prev : std_ulogic_vector(AXIL_DATA_RANGE);

  signal cnt : integer range 0 to AXIL_STRB_WIDTH * 2; -- Character count

begin

  rx_char <= to_char(s_axis.tdata);
  addr_incr <= std_logic_vector(unsigned(addr_prev) + AXIL_STRB_WIDTH);

  prc_fsm : process (clk) is begin
    if rising_edge(clk) then
      case state is
        when ST_IDLE =>
          if s_axis.tvalid then
            case rx_char is
              when 'r' | 'R' =>
                state   <= ST_DELIM0;
                wb.wen  <= '0';
              when 'w' | 'W' =>
                state   <= ST_DELIM0;
                wb.wen  <= '1';
              when 'n' | 'N' =>
                state   <= ST_BUS_START;
                wb.wen  <= '0';
                wb.addr <= addr_incr;
              when 'm' | 'M' =>
                state   <= ST_DELIM1;
                wb.wen  <= '1';
                wb.addr <= addr_incr;
              when 'p' | 'P' =>
                state   <= ST_BUS_START;
                wb.wen  <= wen_prev;
                wb.addr <= addr_prev;
                wb.wdat <= wdat_prev;
              when ' ' | HT | CR =>
                state   <= ST_IDLE;
              when others =>
                state         <= ST_END;
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
            end case;
          end if;

        when ST_DELIM0 =>
          if s_axis.tvalid then
            case rx_char is
              when ' ' | HT =>
                state <= ST_ADDR;
              when others =>
                state         <= ST_END;
                m_axis.tvalid <= '1';
                m_axis.tdata  <= to_ascii('?');
            end case;
          end if;

        when ST_ADDR =>
          if s_axis.tvalid then
            if (rx_char = ' ' or rx_char = HT) then
              if cnt = 0 then

              else

              end if;
            else

            end if;
          end if;

        when ST_END =>
          m_axis.tvalid <= '1';
          m_axis.tdata  <= to_ascii(LF);
          state         <= ST_IDLE;

      end case;

      if srst then
        wen_prev  <= '0';
        addr_prev <= (others=>'0');
        wdat_prev <= (others=>'0');
        wb.stb    <= '0';
        state     <= ST_IDLE;
      end if;

    end if;
  end process;

  u_wb_to_axil : entity work.wb_to_axil
  port map(
    clk    => clk,
    srst   => srst,
    s_wb   => wb,
    m_axil => m_axil
  );

end architecture;
