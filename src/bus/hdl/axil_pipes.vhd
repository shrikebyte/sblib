--##############################################################################
--# File     : axil_pipes.vhd
--# Author   : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Cascaded AXI Lite pipeline registers.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;

entity axil_pipes is
  generic (
    G_STAGES        : positive := 1;
    G_AW_DATA_PIPE  : boolean := true;
    G_AW_READY_PIPE : boolean := true;
    G_W_DATA_PIPE   : boolean := true;
    G_W_READY_PIPE  : boolean := true;
    G_B_DATA_PIPE   : boolean := true;
    G_B_READY_PIPE  : boolean := true;
    G_AR_DATA_PIPE  : boolean := true;
    G_AR_READY_PIPE : boolean := true;
    G_R_DATA_PIPE   : boolean := true;
    G_R_READY_PIPE  : boolean := true
  );
  port (
    clk    : in   std_ulogic;
    srst   : in   std_ulogic;
    s_axil : view s_axil_view;
    m_axil : view m_axil_view
  );
end entity;

architecture rtl of axil_pipes is

begin

end architecture;
