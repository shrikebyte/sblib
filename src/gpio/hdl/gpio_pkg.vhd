--##############################################################################
--# File : gpio_pkg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Defines the IO types needed for the gpio_axil module. This package must be
--# used by the module that instantiates gpio_axil.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use work.gpio_regs_pkg.gpio_chan_range;

package gpio_pkg is

  type gpio_mode_t is (GPIO_MODE_OUT, GPIO_MODE_IN, GPIO_MODE_INOUT, GPIO_MODE_DISABLE);

  type gpio_mode_arr_t is array(natural range <>) of gpio_mode_t;

  subtype gpio_range is gpio_chan_range;

end package;
