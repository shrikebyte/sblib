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
--# | Write           | w aaaaaaaa dddddddd | +             | ! or ?    |
--# | Read            | r aaaaaaaa          | dddddddd      | ! or ?    |
--# | Write Increment | w dddddddd          | +             | ! or ?    |
--# | Read Increment  | r                   | dddddddd      | ! or ?    |
--# | Previous        | p                   | + or dddddddd | ! or ?    |
--#
--# The protocol was designed to work equally well with an interactive terminal
--# or a scripted software parser. An interactive terminal could be used
--# for short-term experiments and edits, while a software parser could be used
--# to programmatically interface with the device, for example, as a layer
--# between the hardware and a GUI.
--#
--# * Write - Write data to an address
--# * Read - Read data from an address
--# * Write Increment - Write to the last command's address + 4
--# * Read Increment - Read from the last command's address + 4
--# * Previous - Re-run the previous command
--# * 'w' or 'W' is a write command.
--# * 'r' or 'R' is a read command.
--# * 'aaaaaaaa' is a 32-bit hex formatted address. It can be anywhere
--#    from 1 to 8 characters.
--# * 'dddddddd' is a 32-bit hex formatted data value. It can be anywhere
--#    from 1 to 8 characters.
--# * '+' is a write success response, returned by the FPGA.
--# * '!' is a bus error response, returned by the FPGA.
--# * '?' is a unknown command returned by the FPGA.
--# * '<LF>' is a line feed character
--#   (the enter key). This marks the end of every command or response (not
--#   shown in command table).
--# * Some terminal emulators use <CR><LF> for enter (carriage return followed
--#   by line feed). This protocol is only sensitive to <LF>. <CR> is ignored.
--# * Only supports 32-bit aligned access.
--# * Does not support write byte strobes.
--# * Does not support backspaces.
--# * Protocol is case insensitive.
--# * Leading zeros are optional in addresses and data.
--# * Only hex format is supported for address and data.
--# * No leading `0x` for the address and data.
--# * Extraneous spaces are trimmed.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
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

begin

end architecture;
