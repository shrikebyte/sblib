################################################################################
# File : cdc_reset.tcl
# Auth : David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_reset cdc_reset.tcl"
################################################################################

puts "INFO: cdc_reset: Applying reset CDC false path."

set cdc_regs [get_cells {cdc_regs_reg[*]}]
set_false_path -to $cdc_regs
