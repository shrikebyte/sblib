################################################################################
# File : axis_fifo_async.tcl
# Auth : Lukas Vik, with minor edits by David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref axis_fifo_async axis_fifo_async.tcl"
# Heavily inspired by
# https://github.com/hdl-modules/hdl-modules/blob/main/modules/fifo/scoped_constraints/asynchronous_fifo.tcl
################################################################################

set clk_write [get_clocks -quiet -of_objects [get_ports "s_clk"]]
set read_data [
  get_cells \
    -quiet \
    -filter {PRIMITIVE_GROUP==FLOP_LATCH || PRIMITIVE_GROUP==REGISTER} \
    "m_rd_data_reg*"
]

# These registers exist as FFs when the RAM is implemented as distributed RAM (LUTRAM).
# In this case there is a timing path from write clock to the read data registers which
# can be safely ignored in order for timing to pass.
# If the RAM is instead implemented as BRAM, the read data registers are internal in the
# BRAM primitive.
# This is also discussed in AMD UG903 and in various places in the forum.
# In recent Vivado versions (at least 2023.2), the cells show up even when the RAM is implemented as
# BRAM, hence why we filter for the primitive type.
if {${read_data} != "" && ${clk_write} != ""} {
  puts "INFO: axis_fifo_async.tcl: Setting false path to read data registers."
  set_false_path -setup -hold -from ${clk_write} -to ${read_data}
}
